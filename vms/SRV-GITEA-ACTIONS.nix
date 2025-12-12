{ secrets, ... }:
{
  vm = {
    id = 2213;
    name = "SRV-GITEA-ACTIONS";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "16G";
  };

  gitea-runners = {
    enable = true;
    defaultTokenFile.secret = secrets.gitea-actions-registration-token;
    runners = {
      nix-runner-1 = {
        makeNixRunner = true;
        labels = [ "nix:docker://gitea-runner-nix" ];
      };
      nix-runner-2 = {
        makeNixRunner = true;
        labels = [ "nix:docker://gitea-runner-nix" ];
      };
      general-runner = {
        labels = [
          "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
          "python:docker://cimg/python"
          "rust:docker://rust"
        ];
      };
    };
  };
}
