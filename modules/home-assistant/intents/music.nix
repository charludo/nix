{ lib, config, ... }:
let
  e = config.hass.entities;
  player = e.media_player.alle;

  playPlaylist = name: [{
    action = "music_assistant.play_media";
    target.entity_id = player;
    data = {
      media_id = name;
      media_type = "playlist";
    };
  }];
in
{
  hass.voice.intents = {
    MusikAn = [
      "(Spiele|Spiel|Starte) [Musik|die Musik]"
      "Musik (an|abspielen|starten)"
    ];
    MusikFortsetzen = [
      "Musik fortsetzen"
      "(Mache|Setze) Musik fort"
      "(Fortsetzen|Weiter abspielen|Weiterspielen)"
    ];
    MusikPause = [
      "(Pausiere|Stoppe|Anhalten) [die Musik]"
      "Musik (pausieren|anhalten|stoppen)"
      "Pause"
    ];
    MusikNaechster = [
      "(Nächster|Nächstes) (Titel|Song|Lied)"
      "Skip"
      "Weiter"
    ];
    MusikShuffleAn = [
      "Shuffle (an|ein|aktivieren)"
      "Mischen (an|ein|aktivieren)"
      "Zufallswiedergabe (an|ein|aktivieren)"
    ];
    MusikShuffleAus = [
      "Shuffle (aus|ab|deaktivieren)"
      "Mischen (aus|ab|deaktivieren)"
      "Zufallswiedergabe (aus|ab|deaktivieren)"
    ];
    PlayerNeustart = [
      "(Player|Spieler) (neu starten|neustarten|resetten)"
      "Restart Player"
    ];
    ZufaelligesAlbum = [
      "(Spiele|Spiel) [ein ]zufälliges Album"
      "Zufälliges Album"
      "Random Album"
    ];
    ZufaelligerKuenstler = [
      "(Spiele|Spiel) [einen ]zufälligen (Künstler|Artist)"
      "Zufälliger (Künstler|Artist)"
      "Random Artist"
    ];
    NeueMusik = [
      "(Spiele|Spiel) [die ]neue[n] (Musik|Tracks|Titel|Lieder)"
      "(Spiele|Spiel) [die ]Playlist (neue Musik|Neue Tracks|Recently Added)"
      "Recently Added"
    ];
    KuerzlichGespielt = [
      "(Spiele|Spiel) [die ]zuletzt (gehörten|gespielten) (Titel|Lieder|Tracks)"
      "Recently Played"
    ];
  };

  # Wildcard `{playlist}` for arbitrary user-created playlists. Requires
  # the custom_sentences route — `lists.playlist.wildcard` isn't accepted
  # by HA's `conversation:` schema.
  hass.voice.custom_sentences.music = {
    language = "de";
    intents.MusikPlaylist.data = [{
      sentences = [
        "(Spiele|Spiel|Starte) [die ]Playlist {playlist}"
        "Playlist {playlist}"
      ];
    }];
    lists.playlist.values = ["Bridgerton Pop" "NieR" "Philharmonix" "Sea Shanties"];
  };

  hass.voice.intent_scripts = {
    # MusikAn now starts a "shuffle everything" listening session via
    # Music Assistant's auto-generated 500-random playlist.
    MusikAn = {
      action = playPlaylist "500 random tracks (from library)";
      speech.text = "Spiele 500 zufällige Titel.";
    };

    MusikFortsetzen = {
      action = [{
        action = "media_player.media_play";
        target.entity_id = player;
      }];
      speech.text = "Wird fortgesetzt.";
    };

    MusikPause = {
      action = [{
        action = "media_player.media_pause";
        target.entity_id = player;
      }];
      speech.text = "Pausiert.";
    };

    MusikNaechster = {
      action = [{
        action = "media_player.media_next_track";
        target.entity_id = player;
      }];
      speech.text = "Nächster Titel.";
    };

    MusikShuffleAn = {
      action = [{
        action = "media_player.shuffle_set";
        target.entity_id = player;
        data.shuffle = true;
      }];
      speech.text = "Shuffle aktiviert.";
    };

    MusikShuffleAus = {
      action = [{
        action = "media_player.shuffle_set";
        target.entity_id = player;
        data.shuffle = false;
      }];
      speech.text = "Shuffle deaktiviert.";
    };

    PlayerNeustart = {
      action = [{ action = e.script.sonos_reset; }];
      speech.text = "Player wird neu gestartet.";
    };

    ZufaelligesAlbum = {
      action = playPlaylist "Random Album (from library)";
      speech.text = "Spiele ein zufälliges Album.";
    };

    ZufaelligerKuenstler = {
      action = playPlaylist "Random Artist (from library)";
      speech.text = "Spiele einen zufälligen Künstler.";
    };

    NeueMusik = {
      action = playPlaylist "Recently added tracks";
      speech.text = "Spiele neue Musik.";
    };

    KuerzlichGespielt = {
      action = playPlaylist "Recently played tracks";
      speech.text = "Spiele zuletzt gehörte Titel.";
    };

    MusikPlaylist = {
      action = [{
        action = "music_assistant.play_media";
        target.entity_id = player;
        data = {
          media_id = "{{ playlist }}";
          media_type = "playlist";
        };
      }];
      speech.text = "Spiele Playlist {{ playlist }}.";
    };
  };
}
