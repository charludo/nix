{ lib, config, ... }:
let
  e = config.hass.entities;
  sonos = e.media_player.office;
  allPlayer = e.media_player.alle;

  # Sonos UPnP can briefly time out on rapid state changes (stop → play
  # against a still-syncing group), so the prep steps tolerate failure
  # and we give the speaker a beat before kicking off playback.
  prepare = [
    {
      action = "media_player.media_stop";
      target.entity_id = allPlayer;
      continue_on_error = true;
    }
    {
      action = "media_player.volume_mute";
      target.entity_id = sonos;
      data.is_volume_muted = false;
      continue_on_error = true;
    }
    { delay.seconds = 2; }
  ];

  # Two REST sensors poll each podcast's RSS every 5 min and pluck the
  # latest episode's MP3 URL via regex. Cleaner than command_line+curl:
  # no shell, no extra processes, native HA template.
  podcastFeed = name: url: {
    inherit name;
    platform = "rest";
    resource = url;
    value_template = ''
      {% set m = value | regex_findall('https?://[^"\s]+\.mp3') %}
      {{ m[0] if m else "" }}
    '';
    scan_interval = 300;
  };

  playUrl = mediaIdTemplate: enqueue: {
    action = "media_player.play_media";
    target.entity_id = sonos;
    data = {
      media_content_id = mediaIdTemplate;
      media_content_type = "music";
      inherit enqueue;
    };
  };

  tagesschauUrl = "{{ states('sensor.tagesschau_100s_mp3') }}";
  wdrUrl = "{{ states('sensor.wdr_aktuell_mp3') }}";
in
{
  hass.voice.intents = {
    Tagesschau = [
      "(Spiele|Spiel|Starte) [die ]Tagesschau"
      "(Spiele|Spiel) Tagesschau in (hundert|100) Sekunden"
      "Tagesschau"
    ];
    WDR_Aktuell = [
      "(Spiele|Spiel|Starte) WDR (Aktuell|aktuell)"
      "WDR (Aktuell|aktuell)"
      "WDR Nachrichten"
    ];
    Nachrichten = [
      "(Spiele|Spiel|Starte) [die ]Nachrichten"
      "Nachrichten"
      "Tägliche Zusammenfassung"
    ];
  };

  hass.voice.intent_scripts = {
    Tagesschau = {
      action = prepare ++ [ (playUrl tagesschauUrl "play") ];
      speech.text = "Spiele Tagesschau.";
    };
    WDR_Aktuell = {
      action = prepare ++ [ (playUrl wdrUrl "play") ];
      speech.text = "Spiele WDR Aktuell.";
    };
    # Sonos queues the second item; plays them back-to-back without us
    # having to detect end-of-track. `enqueue: play` clears + starts;
    # `enqueue: add` appends.
    Nachrichten = {
      action = prepare ++ [
        (playUrl tagesschauUrl "play")
        (playUrl wdrUrl "add")
      ];
      speech.text = "Spiele Nachrichten.";
    };
  };

  services.home-assistant.config = {
    sensor = [
      (podcastFeed "tagesschau_100s_mp3" "https://www.tagesschau.de/multimedia/sendung/tagesschau_in_100_sekunden/podcast-ts100-audio-100~podcast.xml")

      (podcastFeed "wdr_aktuell_mp3" "https://www1.wdr.de/mediathek/audio/wdr-aktuell-news/wdr-aktuell-152.podcast")
    ];
  };
}
