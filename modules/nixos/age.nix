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
  userPath = ../../users/${config.home.username}/keys/ssh.pub;
in
{
  options.age = {
    enable = lib.mkEnableOption "age secrets management";
  };

  config = lib.mkIf cfg.enable {
    age.rekey = {
      hostPubkey = lib.mkDefault (
        if (lib.hasAttr "networking" config) then
          (
            if lib.pathExists hostPath then
              hostPath
            else
              (
                if lib.pathExists vmPath then
                  vmPath
                else
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN8hb7uYM6Nwlshdc9n7YmnDSyXkOK2CqbizvA1Gr4rO dummy"
              )
          )
        else
          userPath
      );

      masterIdentities = [
        {
          identity = private-settings.yubikeys.zakalwe.identityFile;
          pubkey = ../../users/charlotte/keys/zakalwe_age.pub;
        }
        {
          identity = private-settings.yubikeys.perostek.identityFile;
          pubkey = ../../users/charlotte/keys/perostek_age.pub;
        }
        {
          identity = private-settings.yubikeys.diziet.identityFile;
          pubkey = ../../users/charlotte/keys/diziet_age.pub;
        }
        {
          identity = "/home/charlotte/.ssh/id_ed25519";
          pubkey = ../../users/charlotte/keys/ssh.pub;
        }
        {
          identity = "/home/marie/.ssh/id_ed25519";
          pubkey = ../../users/marie/keys/ssh.pub;
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
