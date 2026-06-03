{ config, lib, ... }:
let
  e = config.hass.entities;
  player = e.media_player.alle;

  playMA = mediaType: mediaId: {
    action = "music_assistant.play_media";
    target.entity_id = player;
    data = {
      media_id = mediaId;
      media_type = mediaType;
    };
  };
  playPlaylist = name: [ (playMA "playlist" name) ];

  silent = lib.ha.voice.silentAction;
  ack = lib.ha.voice.acknowledgeAction;

  # area_slug → media_player target for the satellite the command was
  # spoken on. Same shape as volume.nix's areaToTarget: walk the
  # tts_relay routes, drop ones whose media_player has no declared
  # area, and key the survivors by area slug. Used by `unmuteSatellite`
  # to flip is_volume_muted off on the right speaker before playback.
  mediaPlayers = config.hass.devices.media_players;
  areaToTarget = lib.listToAttrs (
    lib.filter (p: p != null) (
      map (
        r:
        let
          slug = lib.removePrefix "media_player." r.target;
          area = mediaPlayers.${slug}.area or null;
        in
        if area == null then null else lib.nameValuePair (lib.ha.mkSlug area) r.target
      ) (config.hass.ttsRelay or [ ])
    )
  );

  # Prepended to every music intent's action sequence: a satellite
  # whose preferred_area_id we can't resolve to a media_player target
  # is left alone (chat path, non-routed satellite, etc.). Otherwise
  # the satellite's local Sonos gets unmuted so the upcoming playback
  # is audible — anyone earlier could have left it muted (button
  # long-press, prior Lautsprecher*Aus intent, …).
  unmuteSatellite = [
    { variables.area_to_target = areaToTarget; }
    {
      "if" = [
        {
          condition = "template";
          value_template = ''{{ area_to_target.get(preferred_area_id | default("")) is not none }}'';
        }
      ];
      "then" = [
        {
          action = "media_player.volume_mute";
          target.entity_id = "{{ area_to_target[preferred_area_id] }}";
          data.is_volume_muted = false;
        }
      ];
    }
  ];
in
{
  hass.voice.intents = {
    MusikAn = silent {
      sentences = [
        "(Spiele|Spiel|Starte) [etwas|ein bisschen|irgendwelche|zufällige] Musik"
        "Musik (an|abspielen|starten)"
      ];
      script = {
        action = unmuteSatellite ++ playPlaylist "500 random tracks (from library)";
        speech.text = "Spiele 500 zufällige Titel.";
      };
    };

    MusikFortsetzen = silent {
      sentences = [
        "Musik (fortsetzen|weiter)"
        "(Mache|Setze) Musik fort"
        "(Fortsetzen|Weiter abspielen|Weiterspielen|Spiel weiter)"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "media_player.media_play";
            target.entity_id = player;
          }
        ];
        speech.text = "Wird fortgesetzt.";
      };
    };

    MusikPause = silent {
      sentences = [
        "(Pausiere|Stoppe) die Musik"
        "Musik (pausieren|anhalten|stoppen|aus)"
        "Pause"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "media_player.media_pause";
            target.entity_id = player;
          }
        ];
        speech.text = "Pausiert.";
      };
    };

    MusikNaechster = silent {
      sentences = [
        "(Nächster|Nächstes) (Titel|Song|Lied)"
        "Skip"
        "Weiter"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "media_player.media_next_track";
            target.entity_id = player;
          }
        ];
        speech.text = "Nächster Titel.";
      };
    };

    MusikShuffleAn = ack {
      sentences = [
        "(Shuffle|Mischen|Zufallswiedergabe) [an|ein|aktivieren]"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "media_player.shuffle_set";
            target.entity_id = player;
            data.shuffle = true;
          }
        ];
        speech.text = "Shuffle aktiviert.";
      };
    };

    MusikShuffleAus = ack {
      sentences = [
        "(Shuffle|Mischen|Zufallswiedergabe) (aus|deaktivieren)"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "media_player.shuffle_set";
            target.entity_id = player;
            data.shuffle = false;
          }
        ];
        speech.text = "Shuffle deaktiviert.";
      };
    };

    MusikLoopAn = ack {
      sentences = [
        "(Wiederholung|Wiederholen) [an|ein|aktivieren]"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "media_player.repeat_set";
            target.entity_id = player;
            data.repeat = "all";
          }
        ];
        speech.text = "Wiederholen aktiviert.";
      };
    };

    MusikLoopAus = ack {
      sentences = [
        "(Wiederholung|Wiederholen) (aus|deaktivieren)"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "media_player.repeat_set";
            target.entity_id = player;
            data.repeat = "off";
          }
        ];
        speech.text = "Wiederholen deaktiviert.";
      };
    };

    MusikPlayerNeustart = {
      sentences = [
        "(Player|Spieler|Sonos) (neu starten|neustarten|resetten)"
      ];
      script = {
        action = unmuteSatellite ++ [ { action = e.script.sonos_reset; } ];
        speech.text = "Player wird neu gestartet.";
      };
    };

    MusikZufaelligesAlbum = silent {
      sentences = [
        "[Spiele|Spiel] [ein] (zufälliges Album|Zufallsalbum)"
      ];
      script = {
        action = unmuteSatellite ++ playPlaylist "Random Album (from library)";
        speech.text = "Spiele ein zufälliges Album.";
      };
    };

    MusikZufaelligerKuenstler = silent {
      sentences = [
        "(Spiele|Spiel) [einen] (zufälligen|zufälliger) (Künstler|Artist)"
      ];
      script = {
        action = unmuteSatellite ++ playPlaylist "Random Artist (from library)";
        speech.text = "Spiele einen zufälligen Künstler.";
      };
    };

    MusikNeueMusik = silent {
      sentences = [
        "(Spiele|Spiel) ([die] neue[sten|n]|kürzlich hinzugefügte) (Musik|Tracks|Titel|Lieder)"
      ];
      script = {
        action = unmuteSatellite ++ playPlaylist "Recently added tracks";
        speech.text = "Spiele kürzlich hinzugefügte Musik.";
      };
    };

    MusikKuerzlichGespielt = silent {
      sentences = [
        "(Spiele|Spiel) [die ]zuletzt (gehörten|gespielten) (Titel|Lieder|Tracks)"
        "Spiel (die|den) selben Song[s] nochmal"
      ];
      script = {
        action = unmuteSatellite ++ playPlaylist "Recently played tracks";
        speech.text = "Spiele zuletzt gehörte Titel.";
      };
    };

    MusikPlaylist = {
      sentences = [
        "(Spiele|Spiel|Starte) die Playlist {mass_playlist}"
      ];
      script = {
        action = unmuteSatellite ++ [ (playMA "playlist" "{{ mass_playlist }}") ];
        speech.text = "Spiele die Playlist {{ mass_playlist }}.";
      };
    };

    MusikAlbum = {
      sentences = [
        "(Spiele|Spiel|Starte) das Album {mass_album}"
      ];
      script = {
        action = unmuteSatellite ++ [ (playMA "album" "{{ mass_album }}") ];
        speech.text = "Spiele das Album {{ mass_album }}.";
      };
    };

    MusikGenre = {
      sentences = [
        "(Spiele|Spiel|Starte) {mass_genre} (Musik|Lieder)"
        "(Spiele|Spiel|Starte) [die ]Musikrichtung {mass_genre}"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data.media_id = "{{ mass_genre }}";
          }
        ];
        speech.text = "Spiele {{mass_genre}} Musik.";
      };
    };

    MusikKuenstler = {
      sentences = [
        "(Spiele|Spiel) (was|etwas|Musik|etwas Musik) von {mass_artist}"
      ];
      script = {
        action = unmuteSatellite ++ [ (playMA "artist" "{{ mass_artist }}") ];
        speech.text = "Spiele Musik von {{ mass_artist }}.";
      };
    };

    MusikSong = silent {
      sentences = [
        "(Spiele|Spiel|Starte) (das|den) (Lied|Stück|Song) {mass_track}"
      ];
      script = {
        action = unmuteSatellite ++ [ (playMA "track" "{{ mass_track }}") ];
        speech.text = "Spiele {{ mass_track }}.";
      };
    };

    MusikSongVonKuenstler = silent {
      sentences = [
        "(Spiele|Spiel|Starte) [das|den] [Lied|Stück|Song] {mass_track} von {mass_artist}"
      ];
      script = {
        action = unmuteSatellite ++ [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data = {
              media_id = "{{ mass_track }}";
              media_type = "track";
              artist = "{{ mass_artist }}";
            };
          }
        ];
        speech.text = "Spiele {{ mass_track }} von {{ mass_artist }}.";
      };
    };
  };
}
