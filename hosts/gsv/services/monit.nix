{ inputs, ... }:
let
  inherit (inputs.private-settings) contact monitAdminPassword;
in
{
  imports = [ ../../common/optional/monit.nix ];

  services.smartd.enable = true;
  monitConfig = {
    alertAddress = contact.monitoring;
    adminPassword = monitAdminPassword;
    adminInterface.enable = true;

    sshd.enable = true;
    smartd.enable = true;
    zfs.enable = true;

    postfix.enable = true;
    dovecot.enable = true;
    rspamd.enable = true;
  };
}
