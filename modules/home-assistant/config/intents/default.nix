{
  imports = [
    ./botty.nix
    ./climate.nix
    ./einkauf.nix
    ./garden.nix
    ./music.nix
    ./news.nix
    ./time.nix
    ./test_en.nix
    ./tv.nix
    ./weather.nix
  ];

  hass.voice.defaultLanguage = "de";
  hass.voice.extraConfig.de.skip_words = [ ];
}
