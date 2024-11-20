{ config, lib, pkgs, ... }:
let
  # These CONSTANTLY change and have different hashes depending on what server 
  # you connect to, so I'm putting a cached version on github. More work to update,
  # but whatever...
  configFiles = pkgs.stdenv.mkDerivation {
    name = "surfshark-config";
    src = pkgs.fetchurl {
      url = "https://github.com/charludo/surfshark-configs/raw/main/Surfshark_Config.zip";
      sha256 = "sha256-dIjNXy2UQ0nAVrp3guy2xDLu1gUvqYBXK9EnG7C3y68=";
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
  sops.secrets.openvpn = { sopsFile = ../secrets.sops.yaml; };
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  services.openvpn.servers = builtins.listToAttrs openVPNConfigs;
}
