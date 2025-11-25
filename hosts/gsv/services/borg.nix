{ secrets, ... }:
{
  borg.gsv = {
    paths = [
      "/var/vmail"
      "/var/lib/radicale"
    ];
    secrets.password = secrets.borg-password-gsv;
    secrets.sshKey = secrets.borg-ssh;
  };
}
