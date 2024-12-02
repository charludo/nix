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
    description = "Builtin intent names to strip from the `home-assistant-intents` data package";
  };

  config = lib.mkIf (cfg != [ ]) {
    hass.package.pythonPackageOverrides = [
      (self: super: {
        home-assistant-intents = super.home-assistant-intents.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.jq ];
          postInstall =
            (old.postInstall or "")
            # bash
            + ''
              dataDir=$out/${self.python.sitePackages}/home_assistant_intents/data
              disabled='${builtins.toJSON cfg}'

              present=$(jq -s --argjson d "$disabled" \
                '[.[].intents | keys[]] | unique | map(select(IN($d[])))' \
                "$dataDir"/*.json)
              missing=$(jq -n --argjson d "$disabled" --argjson p "$present" '$d - $p')
              if [ "$(jq 'length' <<< "$missing")" -gt 0 ]; then
                echo "ERROR: hass.voice.disableBuiltinIntents lists intents that do not exist in any home_assistant_intents data file:" >&2
                jq -r '.[] | "  - " + .' <<< "$missing" >&2
                exit 1
              fi

              for f in "$dataDir"/*.json; do
                jq --argjson d "$disabled" \
                  '.intents |= with_entries(select(.key | IN($d[]) | not))' \
                  "$f" > "$f.tmp"
                mv "$f.tmp" "$f"
              done
            '';
        });
      })
    ];
  };
}
