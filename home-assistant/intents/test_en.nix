{ lib, ... }:
{
  # English translations of all German intents, for testing the matcher.
  # Mirrors botty, climate, einkauf, garden, music, news, time, tv, weather
  # — sentences + speech responses only, no actions executed. Every
  # entry's `language` is set to "en" via the wrapping mapAttrs so we
  # don't repeat the same one line on every intent.
  hass.voice.intents = lib.mapAttrs (_: i: i // { language = "en"; }) {
    # ----- botty (vacuum) -----
    ENBottyStart = {
      sentences = [
        "(start|begin) [the ]cleaning"
        "start cleaning"
        "(start|begin) vacuuming"
        "vacuum"
        "botty (go|clean|vacuum)"
      ];
      script.speech.text = "Cleaning started.";
    };

    ENBottyEnde = {
      sentences = [
        "(stop|end) [the ]cleaning"
        "(stop|end) vacuuming"
        "botty (go home|return|stop|to the base)"
        "send [the ]vacuum home"
      ];
      script.speech.text = "Cleaning ended.";
    };

    ENBottyWohnzimmer = {
      sentences = [
        "(vacuum|clean) [the ]living room"
        "botty [to the] living room"
        "living room (clean|vacuum)"
      ];
      script.speech.text = "Cleaning the living room.";
    };

    ENBottyBuero = {
      sentences = [
        "(vacuum|clean) [the ](office|study)"
        "botty [to the] (office|study)"
        "(office|study) (clean|vacuum)"
      ];
      script.speech.text = "Cleaning the office.";
    };

    ENBottyKueche = {
      sentences = [
        "(vacuum|clean) [the ]kitchen"
        "botty [to the] kitchen"
        "kitchen (clean|vacuum)"
      ];
      script.speech.text = "Cleaning the kitchen.";
    };

    ENBottySofa = {
      sentences = [
        "(vacuum|clean) (under|in front of) the (sofa|couch|tv|television)"
        "[botty] (vacuum|clean) [the ](sofa|couch|tv|television)"
      ];
      script.speech.text = "Cleaning the sofa.";
    };

    # ----- climate -----
    ENTemperatur = {
      sentences = [
        "how (warm|hot) is it in [the ]{area}"
        "what (is the |'s the )(temperature|humidity) in [the ]{area}"
        "how humid is it in [the ]{area}"
        "what (is|'s) the climate in [the ]{area}"
      ];
      lists.area.values = [
        "living room"
        "kitchen"
        "bedroom"
        "office"
        "bathroom"
        "hallway"
      ];
      script.speech.text = "It's currently 21.5 degrees with 48 percent humidity in the {{ area }}.";
    };

    # ----- einkauf (shopping / todo list) -----
    ENEinkaufAdd = {
      sentences = [
        "(add|put|throw) {item} (on|to) [the |my ]shopping list"
        "{item} (on|to) the shopping list"
        "shopping list {item}"
      ];
      lists.item.wildcard = true;
      script.speech.text = ''"{{ item }}" added.'';
    };

    ENToDoAdd = {
      sentences = [
        "(add|put|throw) {item} (on|to) [the |my ](todo|to-do|to do) list"
        "{item} (on|to) the (todo|to-do) list"
        "(todo|to-do) list {item}"
      ];
      lists.item.wildcard = true;
      script.speech.text = ''"{{ item }}" added.'';
    };

    # ----- garden (water pump) -----
    ENPumpeAn = {
      sentences = [
        "(activate|turn on|switch on) [the ][water ]pump"
        "[water ]pump on"
      ];
      script.speech.text = "Water pump activated.";
    };

    ENPumpeAus = {
      sentences = [
        "(deactivate|turn off|switch off) [the ][water ]pump"
        "[water ]pump off"
      ];
      script.speech.text = "Water pump deactivated.";
    };

    # ----- music -----
    ENMusikAn = {
      sentences = [
        "(play|start) [some |the ]music"
        "music (on|please|start)"
      ];
      script.speech.text = "Playing 500 random tracks.";
    };

    ENMusikFortsetzen = {
      sentences = [
        "(resume|continue) [the ]music"
        "(resume|continue) playback"
        "(keep|continue) playing"
      ];
      script.speech.text = "Resuming.";
    };

    ENMusikPause = {
      sentences = [
        "(pause|stop|halt) [the ]music"
        "(pause|stop) playback"
        "pause"
      ];
      script.speech.text = "Paused.";
    };

    ENMusikNaechster = {
      sentences = [
        "next (track|song)"
        "skip [this] (track|song)"
        "skip"
      ];
      script.speech.text = "Next track.";
    };

    ENMusikShuffleAn = {
      sentences = [
        "(turn on|enable|activate) shuffle"
        "shuffle (on|enable)"
        "(enable|turn on) random playback"
      ];
      script.speech.text = "Shuffle enabled.";
    };

    ENMusikShuffleAus = {
      sentences = [
        "(turn off|disable|deactivate) shuffle"
        "shuffle (off|disable)"
        "(disable|turn off) random playback"
      ];
      script.speech.text = "Shuffle disabled.";
    };

    ENMusikPlayerNeustart = {
      sentences = [
        "(restart|reset) [the ](player|sonos)"
        "restart player"
      ];
      script.speech.text = "Restarting the player.";
    };

    ENMusikZufaelligesAlbum = {
      sentences = [
        "play [a ]random album"
        "random album"
      ];
      script.speech.text = "Playing a random album.";
    };

    ENMusikZufaelligerKuenstler = {
      sentences = [
        "play [a ]random (artist|musician)"
        "random artist"
      ];
      script.speech.text = "Playing a random artist.";
    };

    ENMusikNeueMusik = {
      sentences = [
        "play [the ](new|newest|latest) (music|tracks|songs)"
        "play [the ]playlist (new music|recently added)"
        "recently added"
      ];
      script.speech.text = "Playing new music.";
    };

    ENMusikKuerzlichGespielt = {
      sentences = [
        "play [the ]recently (played|heard) (tracks|songs)"
        "recently played"
        "play the same songs again"
      ];
      script.speech.text = "Playing recently heard tracks.";
    };

    ENMusikPlaylist = {
      sentences = [
        "(play|start) [the ]playlist {playlist}"
        "playlist {playlist}"
      ];
      lists.playlist.values = [
        "Bridgerton Pop"
        "NieR"
        "Philharmonix"
        "Sea Shanties"
      ];
      script.speech.text = "Playing playlist {{ playlist }}.";
    };

    # ----- news -----
    ENNewsTagesschau = {
      sentences = [
        "(play|start) [the ]tagesschau"
        "(play|start) tagesschau in (one hundred|100) seconds"
        "tagesschau"
      ];
      script.speech.text = "From the Tagesschau.";
    };

    ENNewsWDRAktuell = {
      sentences = [
        "(play|start) WDR (current|aktuell)"
        "WDR[ news| aktuell]"
      ];
      script.speech.text = "From WDR Aktuell.";
    };

    ENNewsTaeglicheZusammenfassung = {
      sentences = [
        "(play|start) [the |my ](news|daily (summary|briefing|digest))"
        "news"
        "daily (summary|briefing|digest)"
      ];
      script.speech.text = "Here is your daily summary.";
    };

    # ----- time -----
    ENZeitUhrzeit = {
      sentences = [
        "what (time is it|'s the time)"
        "tell me the time"
        "current time"
        "time"
      ];
      script.speech.text = "It is {{ now().strftime('%H:%M') }}.";
    };

    ENZeitDatum = {
      sentences = [
        "what (date is it|'s the date|'s today's date)"
        "what is today's date"
        "date"
      ];
      script.speech.text = ''
        Today is {{ ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][now().weekday()] }}, the {{ now().day }}th of {{ ['January','February','March','April','May','June','July','August','September','October','November','December'][now().month - 1] }} {{ now().year }}.
      '';
    };

    ENZeitWochentag = {
      sentences = [
        "what (day|weekday) is it [today]"
        "what day of the week is it"
        "[week]day"
      ];
      script.speech.text = ''
        Today is {{ ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][now().weekday()] }}.
      '';
    };

    # ----- tv -----
    ENTVHell = {
      sentences = [
        "(make|set) the (tv|television|picture|screen) bright[er]"
        "[tv ]day mode"
      ];
      script.speech.text = "Picture is now bright.";
    };

    ENTVDunkel = {
      sentences = [
        "(make|set) the (tv|television|picture|screen) (dark|darker|dimmer)"
        "[tv ]night mode"
      ];
      script.speech.text = "Picture is now dark.";
    };

    ENTVAus = {
      sentences = [
        "(turn|switch) off [the ](tv|television)"
        "(tv|television) (off|turn off)"
      ];
      script.speech.text = "Television turned off.";
    };

    ENTVStumm = {
      sentences = [
        "mute [the ](tv|television)"
        "(tv|television) (mute|silence)"
        "(make|set) [the ](tv|television) (silent|quiet)"
      ];
      script.speech.text = "Television muted.";
    };

    # ----- weather -----
    ENWetterHeute = {
      sentences = [
        "(what's|what is|how's|how is) the weather (today|right now|currently|outside)"
        "how (warm|hot|cold) is it (outside|right now|currently)"
      ];
      script.speech.text = "It is currently 18.4 degrees outside, feels like 17.";
    };

    ENWetterMorgen = {
      sentences = [
        "(what's|what is|how's|how is) the weather tomorrow [morning|afternoon|evening]"
        "how (warm|hot) will it be tomorrow"
      ];
      script.speech.text = "Tomorrow will be 21.0 degrees with a low of 12.5 degrees. Precipitation: 0.0 millimeters.";
    };

    ENWetterWoche = {
      sentences = [
        "(what's|what is|how's|how is) the weather (this week|the next few days|next week)"
        "weather forecast [for the next few days]"
      ];
      script.speech.text = "Monday: 12.0 to 21.0 degrees. Tuesday: 13.0 to 22.0 degrees. Wednesday: 14.0 to 20.0 degrees.";
    };

    ENWetterStunde = {
      sentences = [
        "(what's|what will|how will|how's) the weather [be ]at {timer_hours:hours} (o'clock|)"
        "how (warm|hot) will it be at {timer_hours:hours} (o'clock|)"
      ];
      script.speech.text = "At {{ timer_hours }} o'clock it will be 19.5 degrees, partly cloudy, 0 millimeters precipitation with 10 percent probability.";
    };

    ENWetterWindAktuell = {
      sentences = [
        "how windy is it [today|right now|currently]"
        "how (strong|hard) is the wind [blowing]"
      ];
      script.speech.text = "The wind is currently blowing at 14.2 kilometers per hour, with gusts up to 28.0.";
    };

    ENWetterWindHeuteNacht = {
      sentences = [
        "how windy will it be (tonight|at night|this evening)"
      ];
      script.speech.text = "Tonight around 9 kilometers per hour.";
    };

    ENWetterTemperaturMaxHeute = {
      sentences = [
        "how (warm|hot) will it (get|be) today [still]"
        "what (is|'s) the (high|maximum|highest) temperature today"
      ];
      script.speech.text = "Today will reach up to 22.5 degrees with a low of 11.0.";
    };

    ENWetterRegenHeute = {
      sentences = [
        "(is|will) it (raining|rain) (today|later today)"
        "will it rain today"
        "is there [any ]rain today"
      ];
      script.speech.text = "No rain is expected today.";
    };

    ENWetterRegenStunde = {
      sentences = [
        "(is|will) it (raining|rain) at {timer_hours:hours} (o'clock|)"
        "is there [any ]rain at {timer_hours:hours} (o'clock|)"
      ];
      script.speech.text = "At {{ timer_hours }} o'clock: 0 millimeters of rain with 10 percent probability.";
    };
  };
}
