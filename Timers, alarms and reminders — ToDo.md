# Timers, alarms and reminders — ToDo

Started Oct 27, 2026 · @Charlotte · last update Oct 27, 2026

## Where things stand

HA's built-in voice timers are bound to the satellite that set them, relative only, carry no message and can't be started from automations. HA has no reminders or alarms. None of the existing projects (see Sources) is mature enough for something this central. Plan: our own integration, published as a standalone HACS project like closest-intent.

**Today (`hass` branch)**

- Timers: three fixed helpers `timer.timer_1`–`3` (`home-assistant/timers.nix`), started by voice into the first free slot (`intents/timer.nix`), the starting area kept in `input_text.timer_N_area`. Expiry plays the timer sound plus TTS on that area's Sonos (`automations/timer.nix`).
- Sounds for `reminder` and `alarmclock` exist (`hass.voice.sounds`), but nothing uses them yet apart from the broadcast script.
- Fixed Oct 27 (not yet deployed): the timer announcement and the broadcast script still called `tts.piper`, which no longer exists. Both now use `hass.voice.ttsEntity` (`tts.pocket_tts`).

## Decisions

- **Self-made, standalone project `hass-remembrance`:** installable via HACS, configured in HA's UI. Our setup only consumes it. Lives in this repo while we iterate quickly; moves to its own repo next to `hass-closest-intent` once it settles.
- **The calendar is the source of truth** for reminders and alarms: Radicale on gsv (`hosts/gsv/services/radicale.nix`). Voice and Thunderbird (or any client) edit the same entries, so no UI of our own for recurring things. Radicale keeps every iCalendar field as written and supports sync tokens.
- **Categories mark what the integration handles:** `HomeAssistant Reminder`, `HomeAssistant Alarm`, more kinds later. Untagged entries are never touched, so the entries can live in any calendar.
- **Location is the room:** free text (iCalendar has no select list), fuzzy-matched against the configured room names. Only read on tagged entries; no match or empty means the configured default, plus a warning in HA's log.
- **Rings only at the entry's own reminders (`VALARM`):** no automatic ring at the start time. On the dot only if a 0-minute reminder is set. Tagged entries without any reminder stay silent and get a log note.
- **Runtime state stays in the integration** (announced, snoozed until, acknowledged), keyed by the entry's ID and occurrence. Nothing is written back for it, so no sync conflicts with Thunderbird.
- **Timers are not calendar entries:** they're too short-lived for a calendar sync. They live only in the integration, central rather than per satellite, with no limit on how many run in parallel.

## Concept

**Sync and ringing**

- Poll the calendar every minute with a sync token; only changed entries come back.
- Schedule exact ring times locally from the reminders, including repeat rules and their exceptions.
- Keep the last synced state in HA's storage, so alarms still ring when Radicale or the internet is down.
- After a restart, re-schedule. Anything missed while HA was down rings immediately if it's only minutes late, otherwise it's marked missed.
- The integration's own writes (voice) take effect immediately, without waiting for the next poll.

**Playback**

- Room from the Location field, mapped to a media player in the config. Generic HA announcement (`play_media` with `announce`), so tts_relay's ducking keeps working here.
- The kind's sound, then TTS. Alarms optionally with slowly rising volume, repeating until stopped or a time limit runs out.

**Announcement text**

- Reminder: "Erinnerung: Zahnarzt in 30 Minuten."
- If another reminder of the same occurrence follows: "Ich erinnere dich 5 Minuten vorher noch mal." If that next one is at the start time: "… zum Beginn noch mal." No addition after the last one.
- The time is relative to the event's start, as Thunderbird shows it.
- A pending repeat ("noch mal", below) that comes before the next reminder is announced instead.

**Voice**

| Kind | Sentences |
|---|---|
| Timers | "Nudel-Timer auf 8 Minuten", "Timer auf 5 Minuten", "5-Minuten-Timer um 1 Minute verlängern", "Pausiere den Timer", "Wie lange noch?", "Lösche den Nudel-Timer" |
| Reminders | "Erinnere mich Samstag um 13 Uhr an …", "… morgen früh an …", "… in 2 Stunden an …", "Was steht heute an?" |
| Alarms | "Weck mich morgen um 6:30", "Wecker werktags um 7", "Wecker für morgen aus" |
| Repeat | "Erinnere mich in 10 Minuten noch mal", "später noch mal", "morgen früh noch mal"; for alarms "Schlummern", "noch 5 Minuten" |

- **Created by voice:** a calendar entry with the category set and the room it was spoken in as Location. Reminders get a 0-minute reminder automatically. "Wecker für morgen aus" excludes that one occurrence from the repeat.
- **Which timer is meant:** the label ("Nudel"), the original length ("5-Minuten-Timer"), the closest time left, the room it was started in, or the only one running. Still ambiguous: ask back ("Den 5- oder den 10-Minuten-Timer?"). Needs a test that the satellite keeps the conversation open.
- **Which reminder "noch mal" means:** the last one that rang in this room within the past few minutes, otherwise the last one anywhere. The repeat is runtime state; the calendar entry stays unchanged. It plays in the room you asked from.
- **Date and time understanding** ("Samstag um 13 Uhr", "übermorgen Abend", "in 2 Stunden", "am 3. November") in its own module with unit tests. Check existing libraries for German first.

**HA side**

- Timers: one entity per running timer showing when it ends (live countdown in the frontend), plus services for +1 min, pause and cancel.
- Reminders and alarms: a calendar entity for display, one on/off switch per recurring alarm.
- A "Wecker" view in our dashboard (Nix).
- Services for everything, so automations and other setups can use it.
- Sentence files for German and English included.

## Steps

- [ ] Deploy SRV-HOMEASSISTANT: `tts.piper` fix and the tts_relay duck fix.
- [ ] Set up `hass-remembrance` in this repo (HACS layout, config flow, tests).
- [ ] Engine: entries, local scheduler, storage, restart recovery, playback per room.
- [ ] Timers on the engine, by voice and in the UI; replace the three fixed slots.
- [ ] CalDAV sync (one calendar), categories, Location fuzzy match, reminders from `VALARM`.
- [ ] Reminders by voice, incl. the date/time module and the "noch mal" repeat.
- [ ] Announcement text with the next-reminder line.
- [ ] Alarms: recurring, snooze, rising volume, "Wecker für morgen aus".
- [ ] Dashboard view.
- [ ] Switch our setup over, remove `timers.nix` and the old timer automation.
- [ ] Move `hass-remembrance` to its own repo, publish via HACS.

## Later

- Several calendars.
- Fuzzy-matching details for Location (thresholds, aliases).
- Tasks (`VTODO`) with a "done" tick, at least for one-off items; recurring tasks behave inconsistently across clients.
- **Global "noch mal":** one slot for the last repeatable thing, whether alarm, reminder or what was just said. To prepare for it, every announcement registers itself as repeatable through a small common interface, rather than the reminder code tracking "the last one" itself. The TTS relay can join later.
- Phone push with "Erledigt" and "Später" buttons.
- Gentle wake-up: lights ramping up before the alarm (like Wake Alarm).

## Sources

| Project | What it does | Status (Oct 2026) | Fit |
|---|---|---|---|
| [Household Voice](https://github.com/kidhasmoxy/household-voice) | Shared timers that survive restarts, alarms, voice editing, asks back when ambiguous | v0.3 pre-release, 0 stars | Closest in idea; tied to Music Assistant, no sign of German. Ideas borrowed: asking back, ringing that stops after a limit, restart recovery |
| [HA Alarm Clock](https://github.com/nirnachmani/HA-Alarm-Clock) | Central alarms and reminders on media players, repeats, snooze, cards | 5 stars, "likely contains a lot of bugs", Sonos untested | No timers |
| [Voice Alarms (hass_alarm)](https://github.com/Gamer92000/hass_alarm) | Alarms and reminders, German, sentences or LLM, panel | 0 stars, 14 commits | Rings on the satellite itself, ours has no usable speaker |
| [HA-Assist-Alarms](https://github.com/nathothan/ha-assist-alarms) | Voice alarms and reminders | | Per satellite by design |
| [Wake Alarm](https://community.home-assistant.io/t/wake-alarm-sunrise-alarms-with-multi-room-music-notifications-and-a-card-beta/1010263), [Smart Wake](https://community.home-assistant.io/t/custom-integration-smart-wake-the-intelligent-alarm-clock-for-home-assistant/1029213) | Sunrise wake-up | Beta | Inspiration for the wake-up |

- [Voice PE Remote Timer](https://community.home-assistant.io/t/voice-pe-remote-timer/967020): the built-in timers' limits.
- [Voice reminders with the time worked out in Jinja](https://community.home-assistant.io/t/voice-reminders-for-assist-with-the-time-worked-out-in-jinja-rather-than-by-an-llm/1021075): deterministic time parsing without an LLM.
