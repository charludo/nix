{
  lib,
  nixvim,
}:
let

  languages =
    builtins.attrNames
      (lib.evalModules {
        modules = [
          ../../../modules/nixvim
          { config._module.check = false; }
        ];
      }).options.languages;
in
# nvim base package, no special language support
(import ./mkNixvim.nix { inherit lib nixvim; })

# nvim.${language} package for each language defined in the nixvim module
// lib.genAttrs languages (
  language:
  import ./mkNixvim.nix {
    inherit lib nixvim;
    languages = {
      ${language}.enable = true;
    };
  }
)

# nvim.common includes support for commonly used languages
// {
  common = (
    import ./mkNixvim.nix {
      inherit lib nixvim;
      languages = {
        go.enable = true;
        python.enable = true;
        rust.enable = true;
        webdev.enable = true;
      };
    }
  );
}

# nvim.full includes support for all languages defined in the nixvim module
# CAUTION: quite heavy due to the contained full texlive distribution
// {
  full = (
    import ./mkNixvim.nix {
      inherit lib nixvim;
      languages = builtins.listToAttrs (
        map (language: {
          name = language;
          value = {
            enable = true;
          };
        }) languages
      );
    }
  );
}
