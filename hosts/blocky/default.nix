{ config, ... }:
{
  _module.args.defaultUser = "paki";
  imports =
    [
      ../common/optional/vmify.nix

      ../common/global
      ../common/optional/nvim.nix

      ../../users/paki/user.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "SRV-BLOCKY";
    interfaces = {
      ens18.ipv4.addresses = [{
        address = "192.168.30.13";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.30.1";
    firewall = {
      allowedTCPPorts = [ 53 443 853 ];
      allowedUDPPorts = [ 53 443 853 ];
    };
  };
  services.resolved.enable = false;


  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;
      ports.tls = 853;
      ports.https = 443;
      upstreams.groups.default = [
        "https://one.one.one.one/dns-query"
      ];
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = [ "1.1.1.1" "1.0.0.1" ];
      };
      blocking = {
        blackLists = {
          ads = [
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
            "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
            "https://raw.githubusercontent.com/anudeepND/blacklist/master/facebook.txt"
            "https://adaway.org/hosts.txt"
            "https://v.firebog.net/hosts/AdguardDNS.txt"
            "https://v.firebog.net/hosts/Admiral.txt"
            "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
            "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
            "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
          ];
          tracking = [
            "https://v.firebog.net/hosts/Easyprivacy.txt"
            "https://v.firebog.net/hosts/Prigent-Ads.txt"
            "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
            "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
            "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
          ];
          malicious = [
            "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
            "https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt"
            "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
            "https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt"
            "https://v.firebog.net/hosts/RPiList-Malware.txt"
            "https://v.firebog.net/hosts/RPiList-Phishing.txt"
            "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
            "https://v.firebog.net/hosts/static/w3kbl.txt"
          ];
          crypto = [
            "https://raw.githubusercontent.com/anudeepND/blacklist/master/CoinMiner.txt"
            "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser"
            "https://v.firebog.net/hosts/Prigent-Crypto.txt"
          ];
        };
        whiteLists = {
          ads = [
            "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt"
          ];
        };
        clientGroupsBlock = {
          default = [ "ads" "tracking" "malicious" "crypto" ];
        };
      };
      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
    };
  };

  system.stateVersion = "23.11";
}
