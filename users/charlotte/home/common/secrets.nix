{ secrets, ... }:
{
  age.secrets.netrc.rekeyFile = secrets.charlotte-netrc;
  age.secrets.charlotte-ssh.rekeyFile = secrets.charlotte-ssh;
}
