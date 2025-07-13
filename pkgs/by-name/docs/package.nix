{
  lib,
  nixosOptionsDoc,
  mdbook,
  stdenv,
  ...
}:
let
  mkOptions =
    module: extraConfig:
    lib.evalModules {
      modules = [
        module
        ({ config._module.check = false; } // extraConfig)
      ];
    };

  mkCleaned =
    options:
    builtins.removeAttrs options [
      "_module"
      "_freeformOptions"
      "warnings"
      "assertions"
      "content"
    ];

  mkOptionsDoc =
    options: lib.mapAttrs (_: v: nixosOptionsDoc { options = v; }) (mkCleaned options.options);

  mkSummary =
    section: options:
    lib.concatStringsSep "\n" (
      builtins.map (n: "  - [${n}](options/${section}/${n}.md)") (builtins.attrNames options)
    );

  options = {
    "NixOS" = mkOptionsDoc (
      mkOptions ../../../modules/nixos {
        options.users.users = lib.mkOption { description = "Refer to nixpkgs' users.users module."; };
      }
    );
    "HomeManager" = mkOptionsDoc (mkOptions ../../../modules/home-manager { });
    "NixVim" = mkOptionsDoc (mkOptions ../../../modules/nixvim { });
    "VMs" = mkOptionsDoc (mkOptions ../../../modules/vms { });
  };

  nestedSummaries = lib.concatStringsSep "\n" (
    builtins.attrValues (
      builtins.mapAttrs (n: v: "- [${n}](options/${n}.md)\n" + (mkSummary n v)) options
    )
  );
in
stdenv.mkDerivation {
  buildInputs = [ mdbook ];
  src = ./.;
  name = "docs";
  buildPhase =
    ''
      mkdir -p $out
    ''
    + lib.concatStringsSep "\n" (
      builtins.attrValues (
        lib.mapAttrs (
          p: pv:
          ''
            mkdir -p options/${p}
            touch options/${p}.md
          ''
          + (lib.concatStringsSep "\n" (
            builtins.attrValues (
              lib.mapAttrs (
                n: v:
                # bash
                ''
                  cat ${v.optionsCommonMark} >> "options/${p}/${n}.md"
                '') pv
            )
          ))
        ) options
      )
    )
    + ''
      substituteInPlace ./SUMMARY.md \
        --replace-fail "@OPTIONS@" "${nestedSummaries}"

      mdbook build
      cp -r ./book/* $out
    '';
}
