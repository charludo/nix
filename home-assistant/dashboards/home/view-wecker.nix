{ lib, withCalendar }:
# Timers, alarms and reminders (remembrance). Alarms and reminders only with
# the calendar set up; edit them there or by voice.
let
  ha = lib.ha;
  cards = import ./remembrance-cards.nix { inherit lib; };
  nextAlarm = "sensor.remembrance_next_alarm";
in
{
  type = "sections";
  max_columns = 1;
  path = "wecker";
  icon = "mdi:alarm";
  header.card =
    if withCalendar then
      ha.mkBadgeTitleCard {
        name = "Wecker";
        badgeCard = ha.mkHeaderBadge {
          entity = nextAlarm;
          name = ''[[[ const s = states["${nextAlarm}"]; if (!s || !s.attributes.next_ring) return "Kein Wecker"; return new Date(s.state).toLocaleString("de-DE", { weekday: "short", hour: "2-digit", minute: "2-digit" }); ]]]'';
        };
      }
    else
      ha.mkTitleCard "Timer";
  sections = [
    {
      type = "grid";
      cards = ha.mkButtonGrid 4 cards.timerQuickStart ++ [ cards.timerControls ];
    }
  ]
  ++ lib.optionals withCalendar [
    {
      type = "grid";
      cards = [
        cards.alarmSwitches
        cards.upcoming
      ];
    }
  ];
}
