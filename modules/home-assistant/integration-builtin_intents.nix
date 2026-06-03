{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass.voice.disableBuiltinIntents;
in
{
  options.hass.voice.disableBuiltinIntents = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [
      "HassGetWeather"
      "HassClimateGetTemperature"
    ];
    description = ''
      Builtin intent names to strip from the ``home-assistant-intents``
      data package, removing them from Hassil's recognition pool across
      every language. Use this when ``closest_intent`` forwards a
      canonical sentence that Hassil would otherwise re-match against a
      builtin pattern, picking the builtin over the intended custom
      intent. The build fails if a listed name doesn't appear in any
      language's intent data — typo guard against silently no-op-ing.
    '';
  };

  config = lib.mkIf (cfg != [ ]) {
    services.home-assistant.package = pkgs.home-assistant.override {
      packageOverrides = self: super: {
        home-assistant-intents = super.home-assistant-intents.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.jq ];
          postInstall = (old.postInstall or "") + ''
            dataDir=$out/${self.python.sitePackages}/home_assistant_intents/data
            disabled=(${lib.concatMapStringsSep " " lib.escapeShellArg cfg})

            declare -A seen
            for intent in "''${disabled[@]}"; do
              seen[$intent]=0
            done

            for f in "$dataDir"/*.json; do
              for intent in "''${disabled[@]}"; do
                if jq -e --arg k "$intent" '.intents | has($k)' "$f" >/dev/null; then
                  seen[$intent]=1
                  jq --arg k "$intent" 'del(.intents[$k])' "$f" > "$f.tmp"
                  mv "$f.tmp" "$f"
                fi
              done
            done

            missing=()
            for intent in "''${disabled[@]}"; do
              if [ "''${seen[$intent]}" = "0" ]; then
                missing+=("$intent")
              fi
            done
            if [ ''${#missing[@]} -gt 0 ]; then
              echo "ERROR: hass.voice.disableBuiltinIntents lists intents that do not exist in any home_assistant_intents data file:" >&2
              printf '  - %s\n' "''${missing[@]}" >&2
              exit 1
            fi
          '';
        });
      };
    };
  };
}
