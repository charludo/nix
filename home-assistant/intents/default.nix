{
  imports = [
    ./alarm.nix
    ./botty.nix
    ./climate.nix
    ./devices.nix
    ./einkauf.nix
    ./music.nix
    ./news.nix
    ./volume.nix
    ./test_en.nix
    ./time.nix
    ./timer.nix
    ./tv.nix
    ./weather.nix
    ./x1c.nix
  ];

  hass.voice.defaultLanguage = "de";
  hass.voice.extraConfig.de.skip_words = [ ];
  hass.voice.disableBuiltinIntents = [
    "HassGetWeather"
    "HassClimateGetTemperature"
    "HassVacuumStart"
    "HassTurnOn"
    "HassTurnOff"
    "HassGetState"
  ];
}
