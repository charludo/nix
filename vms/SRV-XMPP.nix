{
  config,
  outputs,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) domains gsv;
  certsDir = config.security.acme.certs."xmpp.${domains.home}".directory;
in
{
  vm = {
    id = 2222;
    name = "SRV-XMPP";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "64G";

    networking.nameservers = [ "1.1.1.1" ];
    networking.openPorts.tcp = [
      # Client connections
      5222
      # Client connections (direct TLS)
      5223
      # Server-to-server connections
      5269
      # Server-to-server connections (direct TLS)
      5270
      # File transfer proxy
      5281
    ];
  };

  age.secrets.cloudflare.rekeyFile = secrets.home-cloudflare;
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = private-settings.contact.acme;
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      environmentFile = config.age.secrets.cloudflare.path;
    };
    certs."xmpp.${domains.home}" = {
      group = config.services.prosody.group;
      extraDomainNames = map (v: "${v}.xmpp.${domains.home}") [
        "upload"
        "muc"
      ];
      reloadServices = [ "prosody.service" ];
    };
  };

  services.nginx.virtualHosts =
    let
      localhost = "http://localhost:5280";
    in
    {
      "xmpp.${domains.home}".locations = {
        "= /xmpp-websocket" = {
          proxyPass = localhost;
          proxyWebsockets = true;
        };
        "= /http-bind".proxyPass = localhost;
        "= /.well-known/host-meta".proxyPass = localhost;
        "= /.well-known/host-meta.json".proxyPass = localhost;
      };
      "muc.xmpp.${domains.home}" = {
        locations."/".proxyPass = localhost;
      };
      "upload.xmpp.${domains.home}" = {
        locations."/".proxyPass = localhost;
      };
    };

  services.prosody = {
    enable = true;
    admins = [
      "charlotte@xmpp.${domains.home}"
      "marie@xmpp.${domains.home}"
    ];
    allowRegistration = false;
    httpPorts = [ 5280 ];
    httpInterfaces = [ "*" ];
    httpsPorts = [ 5281 ];
    httpsInterfaces = [ "*" ];
    ssl.cert = "${certsDir}/cert.pem";
    ssl.key = "${certsDir}/key.pem";
    virtualHosts."xmpp" = {
      enabled = true;
      domain = "xmpp.${domains.home}";
      ssl.cert = "${certsDir}/cert.pem";
      ssl.key = "${certsDir}/key.pem";
    };
    c2sRequireEncryption = true;

    modules = {
      admin_adhoc = false;
      cloud_notify = true;
      pep = true;
      blocklist = true;
      bookmarks = true;
      dialback = true;
      ping = true;
      private = true;
      register = true;
      vcard = false;
      vcard_legacy = true;
      watchregistrations = true;
      tls = true;
      mam = true;
      csi = true;
      smacks = true;
      saslauth = true;
      roster = true;
      groups = true;
      carbons = true;
      announce = true;
      websocket = true;
      http_files = true;
      disco = true;
      bosh = true;
    };
    xmppComplianceSuite = true;

    muc = [
      {
        domain = "muc.xmpp.${domains.home}";
        restrictRoomCreation = false;
      }
    ];
    httpFileShare = {
      domain = "upload.xmpp.${domains.home}";
      daily_quota = 1000 * 1024 * 1024;
      size_limit = 100 * 1024 * 1024;
    };

    extraModules = [
      "turn_external"
      "csi_simple"
      "http_altconnect"
    ];
    extraConfig = ''
      turn_external_host = "turn.${domains.blog}"
      turn_external_port = ${builtins.toString outputs.nixosConfigurations.gsv.config.services.coturn.listening-port}
      turn_external_secret = "${gsv.turnSecret}"

      consider_bosh_secure = true;
      consider_websocket_secure = true;
      c2s_direct_tls_ports = { 5223 };
      s2s_direct_tls_ports = { 5270 };
    '';
  };

  nas.backup.enable = true;
  rsync."xmpp" = {
    tasks = [
      {
        from = "${config.services.prosody.dataDir}";
        to = "${config.nas.backup.stateLocation}/xmpp";
        chown = "${config.services.prosody.user}:${config.services.prosody.group}";
      }
    ];
  };
}
