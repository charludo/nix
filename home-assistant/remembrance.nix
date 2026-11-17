{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.hass.voice) sounds;
  # Timers and alarms ring their chime with 3 s of quiet in between: a
  # round every chime + 3 s.
  every = sound: lib.ha.soundDurationMs pkgs sound / 1000.0 + 3;
  # Reminders and alarms come from the CalDAV calendar (Radicale on gsv).
  # Off until its login is in the HA secrets (`hass-secrets`):
  #   remembrance_caldav_url  the calendar's own URL
  #   remembrance_caldav_username, remembrance_caldav_password
  # Without it, the reminder and alarm intents answer that they aren't set up.
  withCalendar = true;
in
{
  hass.remembrance = {
    enable = true;
    # Reads times and durations in sentences (`create_from_text`).
    duckling.enable = true;
    settings = {
      ring_script = "script.remembrance_ring";
      # Seconds between rounds, and until it gives up.
      ring = {
        timer = {
          interval = every sounds.timer;
          limit = 120;
        };
        # One round, said twice by the ring script; "stopp" within the
        # 30 s skips the repeat, "noch mal" afterwards rings it again.
        reminder = {
          interval = 60;
          limit = 30;
        };
        # "Sanft" ones get louder with time (see the ring script); up to ten
        # minutes.
        alarm = {
          interval = every sounds.alarmclock;
          limit = 600;
        };
      };
      snooze_delay = 600;
    }
    // lib.optionalAttrs withCalendar {
      calendar = {
        url = "!secret remembrance_caldav_url";
        username = "!secret remembrance_caldav_username";
        password = "!secret remembrance_caldav_password";
      };
    };
  };
}
