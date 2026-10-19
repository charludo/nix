{
  stdenv,
  fetchurl,
  callPackage,
}:
let
  mkCard =
    {
      pname,
      version,
      url,
      sha256,
    }:
    stdenv.mkDerivation {
      inherit pname version;
      src = fetchurl { inherit url sha256; };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out
        cp $src $out/${pname}.js
      '';
    };

  mkFontLoader =
    { pname, url }:
    stdenv.mkDerivation {
      inherit pname;
      version = "1";
      dontUnpack = true;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out
        cat > $out/${pname}.js << 'EOF'
        Object.assign(document.head.appendChild(document.createElement("link")), {
          rel: "stylesheet",
          href: "${url}"
        });
        EOF
      '';
    };
in
{
  simple-swipe-card = callPackage ./simple-swipe-card.nix { };

  my-slider-v2 = mkCard {
    pname = "my-slider-v2";
    version = "1.0.6";
    url = "https://github.com/AnthonMS/my-cards/releases/download/v1.0.6/my-slider-v2.js";
    sha256 = "1widw930kvgh3bbkqwnr5m3v33yq56hljlv8q7hnnrnk1bcq7cs5";
  };

  layout-card = mkCard {
    pname = "layout-card";
    version = "2.4.5";
    url = "https://raw.githubusercontent.com/thomasloven/lovelace-layout-card/b67162283d36e44390f3eba04254668aac3cc752/layout-card.js";
    sha256 = "sha256-qn7S8BC3RTaHsCpU3FNyuwyYRRJEwapA6F1vfHFggZE=";
  };

  config-template-card = mkCard {
    pname = "config-template-card";
    version = "1.3.6";
    url = "https://github.com/iantrich/config-template-card/releases/download/1.3.6/config-template-card.js";
    sha256 = "0bkclpgd9frm30fp95ay891ffsjhz7qygqid8fd0x4hh19z3rvpc";
  };

  windrose-card = mkCard {
    pname = "windrose-card";
    version = "2.4.1";
    url = "https://github.com/aukedejong/lovelace-windrose-card/releases/download/v2.4.1/windrose-card.js";
    sha256 = "14fkjm8asqzvw1fhcm3qn22m9v3gcpj9bmbccfy58139pj2is3jr";
  };

  google-fonts-quicksand = mkFontLoader {
    pname = "google-fonts-quicksand";
    url = "https://fonts.googleapis.com/css2?family=Quicksand:wght@500;600;700&display=swap";
  };
}
