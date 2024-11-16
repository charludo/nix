{ lib, inputs, ... }:
let
  inherit (inputs.private-settings) gsv contact;
in
{
  imports = [
    ./blocky.nix
    ./borg.nix
    ./crabfit.nix
    ./fail2ban.nix
    ./jitsi.nix
    ./mailserver.nix
    # ./matrix.nix
    ./monit.nix
    ./radicale.nix
    ./roundcube.nix
    # ./rustdesk.nix
    ./turn.nix
    ./wireguard.nix
  ];

  # SSL certificate
  sops.secrets.cloudflare = { };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = contact.acme;
      dnsProvider = "cloudflare";
      dnsResolver = gsv.dnsResolver;
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
        setRealIpFromConfig =
          lib.concatMapStrings (ip: "set_real_ip_from ${ip};\n")
            (lib.strings.splitString "\n" (builtins.readFile "${cloudflareIPs}"));
      in
      ''
        ${setRealIpFromConfig}
        real_ip_header CF-Connecting-IP;
      '';
    # virtualHosts."${gsv.domain}" = { default = true; enableACME = true; addSSL = true; locations."/".proxyPass = "http://127.0.0.1:5232/"; };
  };
}
