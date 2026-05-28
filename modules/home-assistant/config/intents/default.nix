{
  imports = [
    ./botty.nix
    ./climate.nix
    ./einkauf.nix
    ./garden.nix
    ./music.nix
    ./news.nix
    ./test_en.nix
    ./time.nix
    ./timer.nix
    ./tv.nix
    ./ventilator.nix
    ./weather.nix
    ./x1c.nix
  ];

  hass.voice.defaultLanguage = "de";
  hass.voice.extraConfig.de.skip_words = [ ];
  hass.voice.disableBuiltinIntents = [
    "HassGetWeather"
    "HassClimateGetTemperature"
    "HassVacuumStart"
  ];
}
