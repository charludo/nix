{ stdenv, fetchurl }:
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
  swipe-card = mkCard {
    pname = "swipe-card";
    version = "5.0.0";
    url = "https://raw.githubusercontent.com/bramkragten/swipe-card/v5.0.0/dist/swipe-card.js";
    sha256 = "0caf1pkscl12pxdyr0acmxb6d1ia1b3z2khdnik7zk06g8h4cgy1";
  };

  lg-remote-control = mkCard {
    pname = "lg-remote-control";
    version = "2.0.4";
    url = "https://github.com/madmicio/LG-WebOS-Remote-Control/releases/download/2.0.4/lg-remote-control.js";
    sha256 = "1j7b0j7a5wp27z0vrlby8dngcz385h2icqpn3xdr7nam6gckxfzd";
  };

  my-slider-v2 = mkCard {
    pname = "my-slider-v2";
    version = "1.0.6";
    url = "https://github.com/AnthonMS/my-cards/releases/download/v1.0.6/my-slider-v2.js";
    sha256 = "1widw930kvgh3bbkqwnr5m3v33yq56hljlv8q7hnnrnk1bcq7cs5";
  };

  xiaomi-vacuum-map-card = mkCard {
    pname = "xiaomi-vacuum-map-card";
    version = "2.3.2";
    url = "https://github.com/PiotrMachowski/lovelace-xiaomi-vacuum-map-card/releases/download/v2.3.2/xiaomi-vacuum-map-card.js";
    sha256 = "1q4asrbv9vgrbs96gf1kqm0bxd2qa7llvblrzqaj2vi0s4vl5ddb";
  };

  layout-card = mkCard {
    pname = "layout-card";
    version = "2.4.5";
    url = "https://raw.githubusercontent.com/thomasloven/lovelace-layout-card/b67162283d36e44390f3eba04254668aac3cc752/layout-card.js";
    sha256 = "sha256-qn7S8BC3RTaHsCpU3FNyuwyYRRJEwapA6F1vfHFggZE=";
  };

  weather-radar-card = mkCard {
    pname = "weather-radar-card";
    version = "3.6.0";
    url = "https://github.com/Makin-Things/weather-radar-card/releases/download/v3.6.0/weather-radar-card.js";
    sha256 = "sha256-Pvwb7sKBG5fWOUmMv+8qKZ/wLCy0HvI0mkgVh1MLD3w=";
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
