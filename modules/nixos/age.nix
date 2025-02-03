{
  lib,
  config,
  private-settings,
  ...
}:
let
  cfg = config.age;

  hostPath = ../../hosts/${config.networking.hostName}/ssh_host_ed25519_key.pub;
  vmPath = ../../vms/keys/ssh_host_${config.networking.hostName}_ed25519_key.pub;
  userPath = ../../users/${config.home.username}/ssh.pub;
in
{
  options.age = {
    enable = lib.mkEnableOption "enable age secrets management";
  };

  config = lib.mkIf cfg.enable {
    age.rekey = {
      hostPubkey = lib.mkDefault (
        if (lib.hasAttr "networking" config) then
          (if lib.pathExists hostPath then hostPath else vmPath)
        else
          userPath
      );

      masterIdentities = [
        {
          identity = private-settings.yubikeys.zakalwe.identityFile;
          pubkey = ../../users/charlotte/zakalwe_age.pub;
        }
        {
          identity = private-settings.yubikeys.perostek.identityFile;
          pubkey = ../../users/charlotte/perostek_age.pub;
        }
        {
          identity = private-settings.yubikeys.diziet.identityFile;
          pubkey = ../../users/charlotte/diziet_age.pub;
        }
        {
          identity = "/home/charlotte/.ssh/id_ed25519";
          pubkey = ../../users/charlotte/ssh.pub;
        }
        {
          identity = "/home/marie/.ssh/id_ed25519";
          pubkey = ../../users/marie/ssh.pub;
        }
      ];
      storageMode = "local";
      localStorageDir =
        ../../.
        + "/private-settings/secrets/rekeyed/${
          if (lib.hasAttr "networking" config) then
            config.networking.hostName
          else
            "${config.home.username}-${config.home.hostname}"
        }";
    };
  };
}
