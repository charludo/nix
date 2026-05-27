{
  stdenv,
  fetchFromGitHub,
  hass-closest-intent-src,
}:
let
  mkComponent =
    {
      pname,
      version,
      owner,
      repo,
      rev,
      sha256,
      domain ? pname,
      componentPath ? "custom_components/${domain}",
    }:
    stdenv.mkDerivation {
      inherit pname version;
      src = fetchFromGitHub {
        inherit
          owner
          repo
          rev
          sha256
          ;
      };
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/custom_components
        cp -r ${componentPath} $out/custom_components/${domain}
      '';
      passthru = {
        inherit domain;
        isHomeAssistantComponent = true;
      };
    };

  # Same shape as `mkComponent` but takes a local source tree instead of
  # fetching from GitHub. Used while a component is still in-tree; swap to
  # `mkComponent` once the component lives in its own repo.
  mkLocalComponent =
    {
      pname,
      version,
      src,
      domain ? pname,
      componentPath ? "custom_components/${domain}",
    }:
    stdenv.mkDerivation {
      inherit pname version src;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/custom_components
        cp -r ${componentPath} $out/custom_components/${domain}
      '';
      passthru = {
        inherit domain;
        isHomeAssistantComponent = true;
      };
    };
in
{
  # Sourced from the `hass-closest-intent` flake input (a local path while the
  # repo isn't published). Swap to `mkComponent` with fetchFromGitHub once it
  # lives upstream.
  closest_intent = mkLocalComponent {
    pname = "closest_intent";
    version = "0.1.0";
    src = hass-closest-intent-src;
  };

  grocery_categorize = mkLocalComponent {
    pname = "grocery_categorize";
    version = "0.1.0";
    src = ../../../../hass-grocery-categorize;
  };

  auth_oidc = mkComponent {
    pname = "auth_oidc";
    version = "1.0.2";
    owner = "christiaangoossens";
    repo = "hass-oidc-auth";
    rev = "v1.0.2";
    sha256 = "sha256-ZYJD0PVh2E07cdY1a7uxSxdooAMz78HwJpwr4uWofZM=";
  };

  bambu_lab = mkComponent {
    pname = "bambu_lab";
    version = "2.2.22";
    owner = "greghesp";
    repo = "ha-bambulab";
    rev = "v2.2.22";
    sha256 = "sha256-JRJ+tfllDuMrtz+5VQL2l5nkhJQXRoNvsvFnrReSZHE=";
  };

  xiaomi_cloud_map_extractor = mkComponent {
    pname = "xiaomi_cloud_map_extractor";
    version = "3.0.0-alpha-24";
    owner = "PiotrMachowski";
    repo = "Home-Assistant-custom-components-Xiaomi-Cloud-Map-Extractor";
    rev = "v3.0.0-alpha-24";
    sha256 = "sha256-F+rD8Uz9GAEWUfYxo8XTvpG/ds4raWe+8k5b0PlDzSk=";
  };

  xiaomi_miio_fan = mkComponent {
    pname = "xiaomi_miio_fan";
    version = "2025.7.0.1";
    owner = "syssi";
    repo = "xiaomi_fan";
    rev = "2025.7.0.1";
    sha256 = "sha256-+w0OxUn7wKYb+RmG0QowaxP1wBL5Re50t77XQ8iWDzQ=";
    domain = "xiaomi_miio_fan";
    componentPath = "custom_components/xiaomi_miio_fan";
  };

  # Vacuum map parser Python packages are dependencies of xiaomi_cloud_map_extractor.
  # Built lazily so they always use the exact python3Packages from home-assistant.python,
  # which may carry overrides that differ from pkgs.python3Packages.
  mkVacuumParsers =
    python3Packages:
    let
      py = python3Packages;

      mkVacuumParser =
        {
          pname,
          version,
          owner,
          hash,
          tag ? "v${version}",
          postPatch ? ''substituteInPlace pyproject.toml --replace "0.0.0" "${version}"'',
        }:
        py.buildPythonPackage {
          inherit pname version postPatch;
          pyproject = true;
          src = fetchFromGitHub {
            inherit owner hash tag;
            repo = "Python-package-${pname}";
          };
          nativeBuildInputs = [ py.poetry-core ];
          dependencies = [
            py.pillow
            py.pycryptodome
            py.vacuum-map-parser-base
          ];
          doCheck = false;
        };
    in
    {
      vacuum-map-parser-dreame = mkVacuumParser {
        pname = "vacuum-map-parser-dreame";
        version = "0.1.3";
        owner = "PiotrMachowski";
        hash = "sha256-7ZuyRK5KKlul+VycH6lQFRJVKCT4AUFXjeY+t4sHqtk=";
      };

      vacuum-map-parser-viomi = mkVacuumParser {
        pname = "vacuum-map-parser-viomi";
        version = "0.1.3";
        owner = "PiotrMachowski";
        hash = "sha256-ritPucFznZvqgvCmp2RJ6SoGJko6LHL74ecSDhu7JG0=";
      };

      vacuum-map-parser-roidmi = mkVacuumParser {
        pname = "vacuum-map-parser-roidmi";
        version = "0.1.3";
        owner = "PiotrMachowski";
        hash = "sha256-E4DCvDQRrdueGnKbY3D+Oh/hvr8hcW5FZF3Of0Vbvs4=";
      };

      vacuum-map-parser-ijai = mkVacuumParser {
        pname = "vacuum-map-parser-ijai";
        version = "0.1.1";
        owner = "maksp86";
        hash = "sha256-SF5v4QlOHV4JSZgawW6XW08wQWXPCeP1oXwlKrHhkKs=";
      };

      vacuum-map-parser-xiaomi = mkVacuumParser {
        pname = "vacuum-map-parser-xiaomi";
        version = "0.1.4";
        owner = "aronkahrs-us";
        tag = "0.1.4";
        hash = "sha256-ZZvmi7l7/hn8/xcccAA0lEE1F7Eic247lREvffQ34SA=";
        postPatch = "";
      };
    };
}
