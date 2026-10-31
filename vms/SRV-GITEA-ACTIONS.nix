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
    runners = {
      nix-runner-1 = {
        tokenFile.secret = secrets.gitea-runner-token-nix-runner-1;
        makeNixRunner = true;
        uuid = "60f806c2-4db0-47c8-a9ce-7640a78faf2c";
        labels = [ "nix:docker://gitea-runner-nix" ];
      };
      nix-runner-2 = {
        tokenFile.secret = secrets.gitea-runner-token-nix-runner-2;
        makeNixRunner = true;
        uuid = "cb93ce60-dd00-422d-99d3-ab94a13661cb";
        labels = [ "nix:docker://gitea-runner-nix" ];
      };
      general-runner = {
        tokenFile.secret = secrets.gitea-runner-token-general-runner;
        uuid = "069c0927-8990-4d01-bd42-ae612edb15e0";
        labels = [
          "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
          "python:docker://cimg/python"
          "rust:docker://rust"
        ];
      };
    };
  };
}
