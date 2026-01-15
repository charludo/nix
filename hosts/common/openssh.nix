{
  outputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.networking) hostName;
  hosts = outputs.nixosConfigurations;
  pubKey = host: ../${host}/ssh_host_ed25519_key.pub;
in
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      StreamLocalBindUnlink = "yes";
    };

    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  programs.ssh = {
    knownHosts = lib.filterAttrs (_: v: v.publicKeyFile != null) (
      builtins.mapAttrs (name: _: {
        publicKeyFile = if builtins.pathExists (pubKey name) then (pubKey name) else null;
        extraHostNames = (lib.optional (name == hostName) "localhost");
      }) hosts
    );
  };

  security.pam = {
    sshAgentAuth = {
      enable = true;
      authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
    };

    services.sudo.rules.auth.rssh = {
      order = config.rules.auth.ssh_agent_order - 1;
      control = "sufficient";
      modulePath = "${pkgs.pam_rssh}/lib/libpam_rssh.so";
      settings.authorized_key_command = pkgs.writeShellScript "get-authorized-keys" ''
        cat "/etc/ssh/authorized_keys.d/$1"
      '';
    };
  };
}
