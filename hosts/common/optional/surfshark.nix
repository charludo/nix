{ config, pkgs, ... }:
let
  configFiles = pkgs.stdenv.mkDerivation {
    name = "surfshark-config";
    src = pkgs.fetchurl {
      url = "https://my.surfshark.com/vpn/api/v1/server/configurations";
      sha256 = "sha256-U5mq+BQa7nclLsz0D/3cUE4AGgmPtf9gnb0KLaUPoV4=";
    };
    phases = [ "installPhase" ];
    buildInputs = [ pkgs.unzip pkgs.rename ];
    installPhase = ''
      unzip $src 
      find . -type f ! -name '*_udp.ovpn' -delete
      find . -type f -exec sed -i "s+auth-user-pass+auth-user-pass \"${config.sops.secrets.openvpn.path}\"+" {} +
      rename 's/prod.surfshark.com_udp.//' *
      mkdir -p $out
      mv * $out
    '';
  };

  getConfig = filePath: {
    name = "${builtins.substring 0 (builtins.stringLength filePath - 5) filePath}";
    value = { config = '' config ${configFiles}/${filePath} ''; autoStart = false; updateResolvConf = true; };
  };
  openVPNConfigs = map getConfig (builtins.attrNames (builtins.readDir configFiles));
in
{
  sops.secrets.openvpn = { };
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  services.openvpn.servers = builtins.listToAttrs openVPNConfigs;
}
