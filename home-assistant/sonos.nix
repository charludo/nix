{
  services.home-assistant.extraComponents = [
    "sonos"
  ];

  services.home-assistant.config = {
    sonos.media_player.hosts = [
      "192.168.24.202" # Wohnzimmer
      "192.168.24.203" # Büro
    ];
  };
}
