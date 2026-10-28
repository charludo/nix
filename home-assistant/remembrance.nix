{ lib, ... }:
let
  # Reminders and alarms come from the CalDAV calendar (Radicale on gsv).
  # Off until its login is in the HA secrets (`hass-secrets`):
  #   remembrance_caldav_url  the calendar's own URL
  #   remembrance_caldav_username, remembrance_caldav_password
  # Without it, the reminder and alarm intents answer that they aren't set up.
  withCalendar = false;
in
{
  hass.remembrance = {
    enable = true;
    settings = {
      ring_script = "script.remembrance_ring";
      # Seconds between rounds, and until it gives up.
      ring = {
        timer = {
          interval = 20;
          limit = 120;
        };
        # Said once; "noch mal" for more.
        reminder = {
          interval = 60;
          limit = 0;
        };
        # Louder every round (see the ring script), for up to ten minutes.
        alarm = {
          interval = 10;
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
