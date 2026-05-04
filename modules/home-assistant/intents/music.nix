{ lib, config, ... }:
let
  e = config.hass.entities;
  player = e.media_player.alle;
in
{
  hass.voice.intents = {
    MusikAn = [
      "(Spiele|Spiel|Starte) [Musik|die Musik]"
      "Musik (an|abspielen|starten)"
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
    ];
    MusikShuffleAus = [
      "Shuffle (aus|ab|deaktivieren)"
      "Mischen (aus|ab|deaktivieren)"
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
    NeueMusik = [
      "(Spiele|Spiel) neue Musik"
      "(Spiele|Spiel) [die ]Playlist (neue Musik|Neue Tracks|Recently Added)"
    ];
  };

  hass.voice.intent_scripts = {
    MusikAn = {
      action = [
        {
          action = "media_player.media_play";
          target.entity_id = player;
        }
      ];
      speech.text = "Wird abgespielt.";
    };

    MusikPause = {
      action = [
        {
          action = "media_player.media_pause";
          target.entity_id = player;
        }
      ];
      speech.text = "Pausiert.";
    };

    MusikNaechster = {
      action = [
        {
          action = "media_player.media_next_track";
          target.entity_id = player;
        }
      ];
      speech.text = "Nächster Titel.";
    };

    MusikShuffleAn = {
      action = [
        {
          action = "media_player.shuffle_set";
          target.entity_id = player;
          data.shuffle = true;
        }
      ];
      speech.text = "Shuffle aktiviert.";
    };

    MusikShuffleAus = {
      action = [
        {
          action = "media_player.shuffle_set";
          target.entity_id = player;
          data.shuffle = false;
        }
      ];
      speech.text = "Shuffle deaktiviert.";
    };

    PlayerNeustart = {
      action = [ { action = e.script.sonos_reset; } ];
      speech.text = "Player wird neu gestartet.";
    };

    # Music Assistant doesn't ship a built-in "random album" picker, so we
    # search the library for a batch of albums and play a random one.
    ZufaelligesAlbum = {
      action = [
        {
          action = "music_assistant.search";
          data = {
            name = "";
            media_type = [ "album" ];
            limit = 50;
          };
          response_variable = "result";
        }
        {
          action = "music_assistant.play_media";
          target.entity_id = player;
          data = {
            media_id = "{{ (result.albums | random).uri }}";
            media_type = "album";
          };
        }
      ];
      speech.text = "Spiele ein zufälliges Album.";
    };

    # Recently-added playlist on Music Assistant. The playlist's display
    # name in MA must match `media_id` exactly; rename here if it doesn't.
    NeueMusik = {
      action = [
        {
          action = "music_assistant.play_media";
          target.entity_id = player;
          data = {
            media_id = "Recently Added Tracks";
            media_type = "playlist";
          };
        }
      ];
      speech.text = "Spiele neue Musik.";
    };
  };
}
