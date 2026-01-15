# large parts of this have been copied from:
# https://git.clan.lol/clan/clan-infra/src/branch/main/modules/web01/gitea/actions-runner.nix
{
  inputs,
  config,
  lib,
  pkgs,
  private-settings,
  ...
}:
let
  cfg = config.gitea-runners;
in
{
  options.gitea-runners = {
    enable = lib.mkEnableOption "Gitea/Forgejo action runner(s)";
    defaultUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "The default base URL of the Gitea/Forgejo instance when no runner-specific URL is set";
      default = "https://git.${private-settings.domains.home}";
      defaultText = "(populated from git submodule)";
    };
    defaultTokenFile.secret = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = "The default token file used when no runner-specific token file one is set";
      default = null;
    };
    emptyPassword = lib.mkOption {
      type = lib.types.str;
      description = "(Empty) password for the unpriveleged user";
      default = private-settings.git.empty-password;
      defaultText = "(populated from git submodule)";
    };
    runners = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule ({
          options = {
            makeNixRunner = lib.mkEnableOption "necessary settings to make the runner use the host's nix store";
            url = lib.mkOption {
              type = nullOr str;
              description = "The base URL of the Gitea/Forgejo instance";
              default = null;
            };
            tokenFile.secret = lib.mkOption {
              type = nullOr path;
              description = "The token file used to register at the Gitea/Forgejo instance";
              default = null;
            };
            labels = lib.mkOption {
              type = listOf str;
              description = "Labels used to map jobs to runners";
            };
            settings = lib.mkOption {
              type = anything;
              description = "Configuration for `act_runner daemon`";
              default = { };
            };
          };
        }));
      default = { };
      description = "an arbitrary number of gitea-actions-runner instances";
    };
  };

  config = lib.mkIf cfg.enable {
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
        containersConf.settings.containers.dns_servers = config.networking.nameservers;
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
          emptypassword='${cfg.emptyPassword}'
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
    }
    // lib.mapAttrs' (name: _: {
      name = "gitea-runner-${builtins.replaceStrings [ "-" ] [ "\\x2d" ] name}";
      value = {
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
    }) cfg.runners;

    age.secrets = {
      "gitea-runner-token-default".rekeyFile = cfg.defaultTokenFile.secret;
    }
    // (lib.concatMapAttrs (name: runner: {
      "gitea-runner-token-${name}".rekeyFile = runner.tokenFile.secret;
    }) (lib.filterAttrs (_: r: r.tokenFile.secret != null) cfg.runners));

    services.gitea-actions-runner =
      let
        storeDeps = pkgs.runCommand "store-deps" { } ''
          mkdir -p $out/bin
          for dir in ${
            toString [
              pkgs.coreutils
              pkgs.findutils
              pkgs.gnugrep
              pkgs.gnused
              pkgs.gawk
              pkgs.git
              pkgs.nix
              pkgs.bash
              pkgs.jq
              pkgs.nodejs
              pkgs.gnutar
              pkgs.gzip
              pkgs.lftp
              pkgs.openssh

              pkgs.nixfmt
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
      {
        package = pkgs.forgejo-runner;
        instances = (
          builtins.mapAttrs (name: runner: {
            inherit name;
            inherit (runner) labels;

            enable = true;

            url = if (!isNull runner.url) then runner.url else cfg.defaultUrl;
            tokenFile =
              config.age.secrets."gitea-runner-token-${name}".path
                or config.age.secrets.gitea-runner-token-default.path;
            settings = lib.mkMerge [
              runner.settings
              (lib.mkIf runner.makeNixRunner {
                container.options = "-e NIX_BUILD_SHELL=/bin/bash -e NIX_PATH=nixpkgs=${inputs.nixpkgs.outPath} -e PAGER=cat -e PATH=/bin -e SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt -v /nix:/nix -v ${storeDeps}/bin:/bin -v ${storeDeps}/etc/ssl:/etc/ssl --user nixuser";
                container.network = "host";
                container.valid_volumes = [
                  "/nix"
                  "${storeDeps}/bin"
                  "${storeDeps}/etc/ssl"
                ];
              })
            ];
          }) cfg.runners
        );
      };
  };
}
