{ stdenv }:
let
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
  google-fonts-quicksand = mkFontLoader {
    pname = "google-fonts-quicksand";
    url = "https://fonts.googleapis.com/css2?family=Quicksand:wght@500;600;700&display=swap";
  };
}
