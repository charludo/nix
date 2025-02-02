{ private-settings, secrets, ... }:
let
  inherit (private-settings) contact monitAdminPassword;
in
{
  services.smartd.enable = true;
  monitConfig = {
    enable = true;

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

  # activate telegram notifications
  age.secrets.telegram-bot.rekeyFile = secrets.monit-telegram-bot;
}
