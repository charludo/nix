{ secrets, ... }:
{
  gitea-runners = {
    enable = true;
    defaultTokenFile.secret = secrets.gitea-actions-registration-token;
    runners = {
      ci-buildbot = {
        makeNixRunner = true;
        labels = [ "buildbot:docker://gitea-runner-nix" ];
        settings = {
          container.cpus = "6";
          container.memory = "48G";
          container.memory_swap = "0";
        };
      };
    };
  };
}
