{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixpkgs-bot;

  stateDirectory = "/var/lib/nixpkgs-bot";
in
{
  options.services.nixpkgs-bot = {
    enable = lib.mkEnableOption "nixpkgs-bot";

    releases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "24.11"
        "25.05"
      ];
      description = ''
        A list of NixOS release versions for which additional branch
        mappings should be generated.
        Each release will add staging, staging-next, release, and
        unstable branches to the configuration.
      '';
    };

    secrets.matrixTokenFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to a file containing the Matrix access token used for authenticating
        as the bot/account that publishes updates.

        One way to obtain the token is to run the following command:
        ```
        curl -X POST "https://<your_matrix_server>/_matrix/client/v3/login" \
          -H "Content-Type: application/json" \
          -d '{
                "type": "m.login.password",
                "user": "<username of the intended bot account>",
                "password": "<password of the bot account>"
              }'

        ```

        The response will contain an "access_token".
        Save this into the file passed to this option.
        The file should contain only the token on a single line.
      '';
    };

    secrets.githubTokenFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to a file containing a GitHub personal access token (PAT) used for
        authenticating GitHub API requests to interact with GitHub's GraphQL API
        without rate limiting.

        1. Visit https://github.com/settings/personal-access-tokens.
        2. Create a new fine-grained personal access token.
        3. Required scopes:
           - For read-only repo access: **"repo:public_repo"**
           - If you use a private repo: **"repo"**
        4. Generate the token and store it securely in a file.
           The file should contain only the token on a single line.
      '';
    };

    settings.server = lib.mkOption {
      type = lib.types.str;
      example = "https://matrix.example.com";
      description = ''
        The base URL of the server that provides the Matrix-compatible
        API. This is used by the service to publish and synchronize state.
      '';
    };

    settings.database = lib.mkOption {
      type = lib.types.str;
      default = "${stateDirectory}/state.sqlite";
      description = ''
        Path to the SQLite database file used to store internal state.
        The default stores the database inside the module's state directory.
      '';
    };

    settings.repo.localPath = lib.mkOption {
      type = lib.types.str;
      default = "${stateDirectory}/nixpkgs";
      description = ''
        Local path where the nixpkgs repository is stored or cloned.
      '';
    };

    settings.repo.owner = lib.mkOption {
      type = lib.types.str;
      default = "NixOS";
      description = ''
        GitHub owner of the repository to be tracked.
      '';
    };

    settings.repo.name = lib.mkOption {
      type = lib.types.str;
      default = "nixpkgs";
      description = ''
        Name of the GitHub repository to be tracked.
      '';
    };

    settings.branches = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default =
        let
          static = {
            staging = [ "staging-next" ];
            staging-next = [ "master" ];
            master = [
              "nixos-unstable-small"
              "nixpkgs-unstable"
            ];
            nixpkgs-unstable = [ ];
            nixos-unstable-small = [ "nixos-unstable" ];
            nixos-unstable = [ ];
          };

          perRelease = release: {
            "staging-${release}" = [ "staging-next-${release}" ];
            "staging-next-${release}" = [ "release-${release}" ];
            "release-${release}" = [ "nixos-${release}-small" ];
            "nixos-${release}-small" = [ "nixos-${release}" ];
            "nixos-${release}" = [ ];
          };
        in
        lib.zipAttrsWith (_: lib.flatten) ([ static ] ++ map perRelease cfg.releases);
      description = ''
        Mapping of Git branches and their parent branches.
        Used by the service to determine the branch inheritance structure.
        This is automatically extended based on the configured releases.
      '';
    };

    package = lib.mkPackageOption pkgs "nixpkgs-bot" { };

  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings.nixpkgs-bot."/var/lib/nixpkgs-bot".Z.mode = "0700";

    systemd.services.nixpkgs-bot = {
      wantedBy = [ "multi-user.target" ];
      description = "nixpkgs-bot";
      path = [
        pkgs.git
        pkgs.openssh
      ];
      serviceConfig = {
        LoadCredential = [
          "matrix_token:${cfg.secrets.matrixTokenFile}"
          "github_token:${cfg.secrets.githubTokenFile}"
        ];
        Restart = "always";
        RestartSec = "15s";
        WorkingDirectory = "/var/lib/nixpkgs-bot";
        ExecStartPre = lib.getExe (
          pkgs.writeShellScriptBin "nixpkgs-bot-git-pull" ''
            if [ ! -d "${cfg.settings.repo.localPath}/.git" ]; then
              git clone "https://github.com/${cfg.settings.repo.owner}/${cfg.settings.repo.name}.git" \
                "${cfg.settings.repo.localPath}"
            fi
          ''
        );
        ExecStart = "${lib.getExe cfg.package} ${builtins.toFile "config.yaml" (builtins.toJSON cfg.settings)}";
        TimeoutStartSec = 1800;
        DynamicUser = true;
        StateDirectory = baseNameOf stateDirectory;
      };
      unitConfig.StartLimitIntervalSec = "90s";
    };
  };
}
