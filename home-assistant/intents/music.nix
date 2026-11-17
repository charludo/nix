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
  unmute = lib.ha.voice.unmuteSatellite { inherit config; };
in
{
  hass.voice.intents = {
    MusikAn = silent (unmute {
      sentences = [
        "(Spiele|Spiel|Starte) [etwas|ein bisschen|irgendwelche|zufällige] Musik"
        "Musik [an|abspielen|starten]"
      ];
      script = {
        action = playPlaylist "500 random tracks (from library)";
        speech.text = "Spiele 500 zufällige Titel.";
      };
    });

    MusikFortsetzen = silent (unmute {
      sentences = [
        "Musik (fortsetzen|weiter)"
        "(Mache|Setze) Musik fort"
        "(Fortsetzen|Weiter abspielen|Weiterspielen|Spiel weiter)"
        "Wiedergabe (fortsetzen|weiter)"
        "Setze [die] Wiedergabe fort"
      ];
      script = {
        action = [
          {
            action = "media_player.media_play";
            target.entity_id = player;
          }
        ];
        speech.text = "Wird fortgesetzt.";
      };
    });

    MusikPause = silent (unmute {
      sentences = [
        "(Pausiere|Stoppe) die Musik"
        "Musik (pausieren|anhalten|stoppen|aus)"
        "Pause"
      ];
      script = {
        action = [
          {
            action = "media_player.media_pause";
            target.entity_id = player;
          }
        ];
        speech.text = "Pausiert.";
      };
    });

    MusikNaechster = silent (unmute {
      sentences = [
        "(Nächster|Nächstes) (Titel|Song|Lied)"
        "Skip"
        "Weiter"
      ];
      script = {
        action = [
          {
            action = "media_player.media_next_track";
            target.entity_id = player;
          }
        ];
        speech.text = "Nächster Titel.";
      };
    });

    MusikShuffleAn = ack (unmute {
      sentences = [
        "(Shuffle|Mischen|Zufallswiedergabe) [an|ein|aktivieren]"
      ];
      script = {
        action = [
          {
            action = "media_player.shuffle_set";
            target.entity_id = player;
            data.shuffle = true;
          }
        ];
        speech.text = "Shuffle aktiviert.";
      };
    });

    MusikShuffleAus = ack (unmute {
      sentences = [
        "(Shuffle|Mischen|Zufallswiedergabe) (aus|deaktivieren)"
      ];
      script = {
        action = [
          {
            action = "media_player.shuffle_set";
            target.entity_id = player;
            data.shuffle = false;
          }
        ];
        speech.text = "Shuffle deaktiviert.";
      };
    });

    MusikLoopAn = ack (unmute {
      sentences = [
        "(Wiederholung|Wiederholen) [an|ein|aktivieren]"
      ];
      script = {
        action = [
          {
            action = "media_player.repeat_set";
            target.entity_id = player;
            data.repeat = "all";
          }
        ];
        speech.text = "Wiederholen aktiviert.";
      };
    });

    MusikLoopAus = ack (unmute {
      sentences = [
        "(Wiederholung|Wiederholen) (aus|deaktivieren)"
      ];
      script = {
        action = [
          {
            action = "media_player.repeat_set";
            target.entity_id = player;
            data.repeat = "off";
          }
        ];
        speech.text = "Wiederholen deaktiviert.";
      };
    });

    MusikPlayerNeustart = unmute {
      sentences = [
        "(Player|Spieler|Sonos) (neu starten|neustarten|resetten)"
      ];
      script = {
        action = [ { action = e.script.sonos_reset; } ];
        speech.text = "Player wird neu gestartet.";
      };
    };

    MusikZufaelligesAlbum = silent (unmute {
      sentences = [
        "[Spiele|Spiel] [ein] (zufälliges Album|Zufallsalbum)"
      ];
      script = {
        action = playPlaylist "Random Album (from library)";
        speech.text = "Spiele ein zufälliges Album.";
      };
    });

    MusikZufaelligerKuenstler = silent (unmute {
      sentences = [
        "(Spiele|Spiel) [einen] (zufälligen|zufälliger) (Künstler|Artist)"
      ];
      script = {
        action = playPlaylist "Random Artist (from library)";
        speech.text = "Spiele einen zufälligen Künstler.";
      };
    });

    MusikNeueMusik = silent (unmute {
      sentences = [
        # Split: closest_intent expands a pattern into at most 16 forms.
        "Spiele die neue[sten|n] (Musik|Tracks|Titel|Lieder)"
        "Spiele neue[sten|n] (Musik|Tracks|Titel|Lieder)"
        "Spiel die neue[sten|n] (Musik|Tracks|Titel|Lieder)"
        "Spiel neue[sten|n] (Musik|Tracks|Titel|Lieder)"
        "(Spiele|Spiel) kürzlich hinzugefügte (Musik|Tracks|Titel|Lieder)"
      ];
      script = {
        action = playPlaylist "Recently added tracks";
        speech.text = "Spiele kürzlich hinzugefügte Musik.";
      };
    });

    MusikKuerzlichGespielt = silent (unmute {
      sentences = [
        # Split: closest_intent expands a pattern into at most 16 forms.
        "Spiele [die ]zuletzt (gehörten|gespielten) (Titel|Lieder|Tracks)"
        "Spiel [die ]zuletzt (gehörten|gespielten) (Titel|Lieder|Tracks)"
        "Spiel (die|den) selben Song[s] nochmal"
      ];
      script = {
        action = playPlaylist "Recently played tracks";
        speech.text = "Spiele zuletzt gehörte Titel.";
      };
    });

    MusikPlaylist = unmute {
      sentences = [
        "(Spiele|Spiel|Starte) die Playlist {mass_playlist}"
      ];
      script = {
        action = [ (playMA "playlist" "{{ mass_playlist }}") ];
        speech.text = "Spiele die Playlist {{ mass_playlist }}.";
      };
    };

    MusikAlbum = unmute {
      sentences = [
        "(Spiele|Spiel|Starte) das Album {mass_album}"
      ];
      script = {
        action = [ (playMA "album" "{{ mass_album }}") ];
        speech.text = "Spiele das Album {{ mass_album }}.";
      };
    };

    MusikGenre = unmute {
      sentences = [
        "(Spiele|Spiel|Starte) {mass_genre} (Musik|Lieder)"
        "(Spiele|Spiel|Starte) [die ]Musikrichtung {mass_genre}"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data.media_id = "{{ mass_genre }}";
          }
        ];
        speech.text = "Spiele {{mass_genre}} Musik.";
      };
    };

    MusikKuenstler = unmute {
      sentences = [
        "(Spiele|Spiel) (was|etwas|Musik|etwas Musik) von {mass_artist}"
        "Musik von {mass_artist}"
      ];
      script = {
        action = [ (playMA "artist" "{{ mass_artist }}") ];
        speech.text = "Spiele Musik von {{ mass_artist }}.";
      };
    };

    MusikSong = silent (unmute {
      sentences = [
        # Split: closest_intent expands a pattern into at most 16 forms.
        "Spiele (das|den) (Lied|Stück|Song) {mass_track}"
        "Spiel (das|den) (Lied|Stück|Song) {mass_track}"
        "Starte (das|den) (Lied|Stück|Song) {mass_track}"
      ];
      script = {
        action = [ (playMA "track" "{{ mass_track }}") ];
        speech.text = "Spiele {{ mass_track }}.";
      };
    });

    # Music Assistant only exposes title/artist/album on the player (no
    # composer or year), so what's said depends on the kind of media: a
    # podcast is named by its show, a track by artist and album. The album
    # artist is added only when it differs, which is what carries the
    # orchestra/ensemble on classical and compilation releases.
    MusikWasIstDas = {
      sentences = [
        "Was ist das"
        "Was (läuft|spielt) [da|hier|gerade|jetzt]"
        # Split: closest_intent expands each pattern into at most 16 forms,
        # and as one pattern "Was für ein Titel ist das" was cut off.
        "Was [für ein|ein] (Lied|Song|Titel|Stück) ist das"
        # Split: closest_intent expands a pattern into at most 16 forms.
        "Was [für ein|ein] (Lied|Song|Titel|Stück) läuft"
        "Was für ein (Lied|Song|Titel|Stück) läuft (da|hier|gerade|jetzt)"
        "Was ein (Lied|Song|Titel|Stück) läuft (da|hier|gerade|jetzt)"
        "Was (Lied|Song|Titel|Stück) läuft (da|hier|gerade|jetzt)"
        # Split: closest_intent expands a pattern into at most 16 forms.
        "Welche[s] (Lied|Song|Titel|Stück|Album) ist das"
        "Welche(r|n) (Lied|Song|Titel|Stück|Album) ist das"
      ];
      script.speech.text = ''
        {%- set p = '${player}' -%}
        {%- set t = state_attr(p, 'media_title') -%}
        {%- if is_state(p, ['off', 'idle', 'standby', 'unavailable', 'unknown']) or not t -%}
          Es läuft gerade nichts.
        {%- else -%}
          {%- set artist = state_attr(p, 'media_artist') -%}
          {%- set album = state_attr(p, 'media_album_name') -%}
          {%- set album_artist = state_attr(p, 'media_album_artist') -%}
          {%- set kind = state_attr(p, 'media_content_type') | default("", true) | string -%}
          {%- if 'podcast' in kind -%}
            {{ t }}{{ (', aus dem Podcast ' ~ album) if album else "" }}.
          {%- elif 'audiobook' in kind -%}
            {{ ('Das Hörbuch ' ~ album ~ ', ') if album and album != t else "" }}{{ t }}{{ (' von ' ~ artist) if artist else "" }}.
          {%- else -%}
            {{ t }}{{ (' von ' ~ artist) if artist else "" }}{{ (', vom Album ' ~ album) if album and album != t else "" }}{{ (' von ' ~ album_artist) if album_artist and album_artist != artist else "" }}.
          {%- endif -%}
        {%- endif -%}
      '';
    };

    MusikSongVonKuenstler = silent (unmute {
      sentences = [
        # One per verb: closest_intent expands a pattern into at most 16
        # forms, and as one pattern the "Starte" forms were cut off.
        "Spiele [das|den] [Lied|Stück|Song] {mass_track} von {mass_artist}"
        "Spiel [das|den] [Lied|Stück|Song] {mass_track} von {mass_artist}"
        "Starte [das|den] [Lied|Stück|Song] {mass_track} von {mass_artist}"
      ];
      script = {
        action = [
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
    });
  };
}
