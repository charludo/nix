{
  config,
  lib,
  private-settings,
  secrets,
  ...
}:
{
  imports = [
    ./blocky.nix
    ./borg.nix
    ./cache.nix
    ./fail2ban.nix
    ./filebrowser.nix
    ./jitsi.nix
    ./mailserver.nix
    ./minecraft.nix
    ./monit.nix
    ./personal-site.nix
    ./radicale.nix
    ./rmfakecloud.nix
    ./roundcube.nix
    # ./rustdesk.nix
    ./turn.nix
    ./wireguard.nix
  ];

  # SSL certificate
  age.secrets.cloudflare.rekeyFile = secrets.gsv-cloudflare;
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = private-settings.contact.acme;
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      environmentFile = config.age.secrets.cloudflare.path;
    };
    certs = {
      "${private-settings.domains.webdesign}" = {
        group = config.services.nginx.group;
        dnsProvider = "hetzner";
        dnsResolver = "213.239.204.242:53";
        # TODO: replace with agenix path!
        environmentFile = "/var/lib/webdesign/acme";
        extraDomainNames = [
          "mail.${private-settings.domains.webdesign}"
          "www.${private-settings.domains.webdesign}"
        ];
      };
    };
  };

  # Setup reverse proxy settings common for all services
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    appendHttpConfig =
      let
        cloudflareIPs = builtins.fetchurl {
          url = "https://www.cloudflare.com/ips-v4";
          sha256 = "sha256:0ywy9sg7spafi3gm9q5wb59lbiq0swvf0q3iazl0maq1pj1nsb7h";
        };
        setRealIpFromConfig = lib.concatMapStrings (ip: "set_real_ip_from ${ip};\n") (
          lib.strings.splitString "\n" (builtins.readFile "${cloudflareIPs}")
        );
      in
      ''
        ${setRealIpFromConfig}
        real_ip_header CF-Connecting-IP;
      '';
    # virtualHosts."${gsv.domain}" = { default = true; enableACME = true; addSSL = true; locations."/".proxyPass = "http://127.0.0.1:5232/"; };
    # virtualHosts."_" = {
    # serverName = "_";
    # default = true;
    # locations."/" = {
    # return = "404";
    # };
    # };
  };
}
