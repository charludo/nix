{
  config,
  lib,
  pkgs,
  private-settings,
  outputs,
  ...
}:

with lib;
let
  cfg = config.blocky;
in
{
  options.blocky = {
    enable = lib.mkEnableOption "blocky DNS blocker";
    addEntriesForVMs = lib.mkEnableOption "add custom DNS entries for VM services";
  };

  config = mkIf cfg.enable {
    services.resolved.enable = lib.mkForce false;
    services.blocky = {
      enable = true;
      settings = {
        ports.dns = 53;
        upstreams.groups.default = [
          private-settings.upstreamDNS.url
        ];
        bootstrapDns = {
          upstream = private-settings.upstreamDNS.url;
          ips = private-settings.upstreamDNS.ips;
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
              "https://raw.githubusercontent.com/d3ward/toolz/master/src/d3host.txt"
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
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
            allowed = [
              (pkgs.writeText "custom-whitelist.txt" ''
                *.awin1.com
              '')
            ];
          };
          clientGroupsBlock = {
            default = [
              "ads"
              "tracking"
              "malicious"
              "crypto"
            ];
          };
        };
        customDNS.mapping = lib.mkIf cfg.addEntriesForVMs (
          builtins.listToAttrs (
            lib.lists.flatten (
              builtins.map (
                vm:
                builtins.map (entry: {
                  name = "${entry.name}.${private-settings.domains.ad}";
                  value = outputs.nixosConfigurations.${vm}.config.vm.networking.address;
                }) outputs.nixosConfigurations.${vm}.config.vm.certsFor
              ) (lib.helpers.allVMNames ../../vms)
            )
          )
        );
      };
    };
  };
}
