{
  lib,
  pkgs,
  config,
  ...
}:
let
  e = config.hass.entities;
  sonos = e.media_player.living_room;
  allPlayer = e.media_player.alle;

  newsDir = "/var/lib/hass/www/news";

  haBaseUrl =
    let
      id = toString config.vm.id;
    in
    "http://192.168.${builtins.substring 0 2 id}.1${builtins.substring 2 2 id}:8123";

  feeds = {
    "tagesschau_100s.mp3" =
      "https://www.tagesschau.de/multimedia/sendung/tagesschau_in_100_sekunden/podcast-ts100-audio-100~podcast.xml";
    "wdr_aktuell.mp3" = "https://www1.wdr.de/mediathek/audio/wdr-aktuell-news/wdr-aktuell-152.podcast";
  };

  playLocal = filename: enqueue: {
    action = "media_player.play_media";
    target.entity_id = sonos;
    data = {
      media_content_id = "${haBaseUrl}/local/news/${filename}";
      media_content_type = "music";
      inherit enqueue;
    };
  };

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
    {
      action = "media_player.volume_set";
      target.entity_id = sonos;
      data.volume_level = 0.33;
      continue_on_error = true;
    }
    { delay.seconds = 1; }
  ];

  dailySummarySequence = prepare ++ [ (playLocal "zusammenfassung.mp3" "replace") ];
in
{
  systemd.services.fetch-news-podcasts = {
    description = "Download latest news podcast episodes for HA";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "hass";
      Group = "hass";
    };
    path = with pkgs; [
      curl
      gnugrep
      coreutils
      ffmpeg-headless
    ];
    script = ''
      set -u
      mkdir -p "${newsDir}"

      fetch_latest() {
        local feed="$1"
        local out="$2"
        local url
        url=$(curl -fsSL --max-time 15 "$feed" \
              | grep -oE 'https?://[^"]+\.mp3' \
              | head -1)
        if [ -z "$url" ]; then
          echo "No MP3 URL found in $feed" >&2
          return 1
        fi
        echo "Fetching $url -> $out"
        curl -fsSL --retry 3 --max-time 60 -o "$out.tmp" "$url" \
          && mv "$out.tmp" "$out"
      }

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (filename: feed: ''
          fetch_latest ${lib.escapeShellArg feed} ${lib.escapeShellArg "${newsDir}/${filename}"} || true
        '') feeds
      )}

      if [ -f "${newsDir}/tagesschau_100s.mp3" ] && [ -f "${newsDir}/wdr_aktuell.mp3" ]; then
        ffmpeg -y -loglevel error \
          -i "${newsDir}/tagesschau_100s.mp3" \
          -i "${newsDir}/wdr_aktuell.mp3" \
          -filter_complex "[0:a]volume=1.0[a0];[1:a]volume=1.15[a1];[a0][a1]concat=n=2:v=0:a=1[out]" \
          -map "[out]" -c:a libmp3lame -b:a 128k \
          "${newsDir}/zusammenfassung.tmp.mp3" \
          && mv "${newsDir}/zusammenfassung.tmp.mp3" "${newsDir}/zusammenfassung.mp3"
      fi
    '';
  };

  systemd.timers.fetch-news-podcasts = {
    description = "Periodically fetch news podcast episodes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "45min";
      Persistent = true;
    };
  };

  hass.voice.intents = {
    News_Tagesschau = {
      sentences = [
        "[Spiele|Spiel|Starte] [die] Tagesschau [in (hundert|100) Sekunden]"
      ];
      script = {
        action = prepare ++ [ (playLocal "tagesschau_100s.mp3" "replace") ];
        speech.text = "Von der Tagesschau.";
      };
    };

    News_WDRAktuell = {
      sentences = [
        "[Spiele|Spiel|Starte] WDR (Aktuell|aktuell)"
      ];
      script = {
        action = prepare ++ [ (playLocal "wdr_aktuell.mp3" "replace") ];
        speech.text = "Von WDR Aktuell.";
      };
    };

    News_TaeglicheZusammenfassung = {
      sentences = [
        "[Spiele|Spiel|Starte] [die|meine] (Nachrichten|tägliche Zusammenfassung)"
      ];
      script = {
        action = dailySummarySequence;
        speech.text = "Hier ist deine tägliche Zusammenfassung.";
      };
    };
  };

  hass.scripts.daily_summary = {
    alias = "Tägliche Zusammenfassung";
    icon = "mdi:newspaper-variant";
    sequence = dailySummarySequence;
    mode = "restart";
  };
}
