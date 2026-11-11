{
  stdenv,
  fetchFromGitHub,
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
in
{
  # Python dependencies (vacuum-map-parser-*) come from nixpkgs; see home-assistant/xiaomi.nix.
  xiaomi_cloud_map_extractor = mkComponent {
    pname = "xiaomi_cloud_map_extractor";
    version = "3.0.0-alpha-24";
    owner = "PiotrMachowski";
    repo = "Home-Assistant-custom-components-Xiaomi-Cloud-Map-Extractor";
    rev = "v3.0.0-alpha-24";
    sha256 = "sha256-F+rD8Uz9GAEWUfYxo8XTvpG/ds4raWe+8k5b0PlDzSk=";
  };
}
