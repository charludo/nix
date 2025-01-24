{
  inputs,
  pkgs,
  config,
  secrets,
  private-settings,
  ...
}:
let
  storeDeps = pkgs.runCommand "store-deps" { } ''
    mkdir -p $out/bin
    for dir in ${
      toString [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gawk
        pkgs.git
        pkgs.nix
        pkgs.bash
        pkgs.jq
        pkgs.nodejs
        pkgs.gnutar
        pkgs.gzip

        pkgs.nixfmt-rfc-style
        pkgs.deadnix
        pkgs.ruff
      ]
    }; do
      for bin in "$dir"/bin/*; do
        ln -s "$bin" "$out/bin/$(basename "$bin")"
      done
    done

    # Add SSL CA certs
    mkdir -p $out/etc/ssl/certs
    cp -a "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" $out/etc/ssl/certs/ca-bundle.crt
  '';
in
# large parts of this have been copied from:
# https://git.clan.lol/clan/clan-infra/src/branch/main/modules/web01/gitea/actions-runner.nix
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2213;
    name = "SRV-GITEA-ACTIONS";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "16G";
  };

  users.users.nixuser = {
    group = "nixuser";
    description = "Used for running nix ci jobs";
    home = "/var/empty";
    isSystemUser = true;
  };
  users.groups.nixuser = { };

  virtualisation = {
    podman.enable = true;
    containers = {
      containersConf.settings.containers.dns_servers = [ "1.1.1.1" ];
      storage.settings = {
        storage.graphroot = "/var/lib/containers/storage";
        storage.runroot = "/run/containers/storage";
      };
    };
  };
  systemd.services = {
    gitea-runner-nix-image = {
      wantedBy = [ "multi-user.target" ];
      after = [ "podman.service" ];
      requires = [ "podman.service" ];
      path = [
        config.virtualisation.podman.package
        pkgs.gnutar
        pkgs.shadow
        pkgs.getent
      ];
      # we also include etc here because the cleanup job also wants the nixuser to be present
      script = ''
        set -eux -o pipefail
        mkdir -p etc/nix

        # Create an unpriveleged user that we can use also without the run-as-user.sh script
        touch etc/passwd etc/group
        groupid=$(cut -d: -f3 < <(getent group nixuser))
        userid=$(cut -d: -f3 < <(getent passwd nixuser))
        groupadd --prefix $(pwd) --gid "$groupid" nixuser
        emptypassword='${private-settings.git.empty-password}'
        useradd --prefix $(pwd) -p "$emptypassword" -m -d /tmp -u "$userid" -g "$groupid" -G nixuser nixuser

        cat <<NIX_CONFIG > etc/nix/nix.conf
        accept-flake-config = true
        experimental-features = nix-command flakes
        NIX_CONFIG

        cat <<NSSWITCH > etc/nsswitch.conf
        passwd:    files mymachines systemd
        group:     files mymachines systemd
        shadow:    files

        hosts:     files mymachines dns myhostname
        networks:  files

        ethers:    files
        services:  files
        protocols: files
        rpc:       files
        NSSWITCH

        # list the content as it will be imported into the container
        tar -cv . | tar -tvf -
        tar -cv . | podman import - gitea-runner-nix
      '';
      serviceConfig = {
        RuntimeDirectory = "gitea-runner-nix-image";
        WorkingDirectory = "/run/gitea-runner-nix-image";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    gitea-runner-nix = {
      after = [ "gitea-runner-nix-image.service" ];
      requires = [ "gitea-runner-nix-image.service" ];

      serviceConfig = {
        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        DeviceAllow = "";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        UMask = "0066";
        ProtectProc = "invisible";
        SystemCallFilter = [
          "~@clock"
          "~@cpu-emulation"
          "~@module"
          "~@mount"
          "~@obsolete"
          "~@raw-io"
          "~@reboot"
          "~@swap"
          "~@privileged"
          "~capset"
          "~setdomainname"
          "~sethostname"
        ];
        SupplementaryGroups = [ "podman" ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        PrivateNetwork = false;
        MemoryDenyWriteExecute = false;
        ProcSubset = "all";
        LockPersonality = true;
        DynamicUser = true;
      };
    };
  };

  sops.secrets.registration-token = {
    sopsFile = secrets.gitea-actions;
  };
  services.gitea-actions-runner = {
    package = pkgs.forgejo-actions-runner;
    instances = {
      nix-runner = {
        enable = true;
        name = "nix-runner";
        url = "https://git.${private-settings.domains.home}";
        tokenFile = config.sops.secrets.registration-token.path;
        labels = [ "nix:docker://gitea-runner-nix" ];
        settings = {
          container.options = "-e NIX_BUILD_SHELL=/bin/bash -e NIX_PATH=nixpkgs=${inputs.nixpkgs.outPath} -e PAGER=cat -e PATH=/bin -e SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt -v /nix:/nix -v ${storeDeps}/bin:/bin -v ${storeDeps}/etc/ssl:/etc/ssl --user nixuser";
          container.network = "host";
          container.valid_volumes = [
            "/nix"
            "${storeDeps}/bin"
            "${storeDeps}/etc/ssl"
          ];
        };
      };
      general-runner = {
        enable = true;
        name = "general-runner";
        url = "https://git.${private-settings.domains.home}";
        tokenFile = config.sops.secrets.registration-token.path;
        labels = [
          "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
          "python:docker://cimg/python"
          "rust:docker://cimg/rust"
        ];
      };
    };
  };

  system.stateVersion = "23.11";
}
