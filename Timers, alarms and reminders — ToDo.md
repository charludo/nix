# Timers, alarms and reminders — ToDo

Started Oct 27, 2026 · @Charlotte · last update Oct 28, 2026

## Where things stand

HA's built-in voice timers are bound to the satellite that set them, relative only, carry no message and can't be started from automations. HA has no reminders or alarms. None of the existing projects (see Sources) is mature enough for something this central. Plan: our own integration, published as a standalone HACS project like closest-intent.

**Today (`hass` branch)**

- Timers: three fixed helpers `timer.timer_1`–`3` (`home-assistant/timers.nix`), started by voice into the first free slot (`intents/timer.nix`), the starting area kept in `input_text.timer_N_area`. Expiry plays the timer sound plus TTS on that area's Sonos (`automations/timer.nix`).
- Sounds for `reminder` and `alarmclock` exist (`hass.voice.sounds`), but nothing uses them yet apart from the broadcast script.
- Fixed Oct 27 (not yet deployed): the timer announcement and the broadcast script still called `tts.piper`, which no longer exists. Both now use `hass.voice.ttsEntity` (`tts.pocket_tts`).

## Decisions

- **Self-made, standalone project `hass-remembrance`:** installable via HACS, configured in HA's UI. Our setup only consumes it. Lives in this repo while we iterate quickly; moves to its own repo next to `hass-closest-intent` once it settles.
- **Just an engine:** state, scheduling and an API (services, entities, events). How it's used (voice, UI, automations) is up to the caller; no sentences or response texts in the engine. Our voice intents and announcement texts are defined in Nix.
- **The calendar is the source of truth** for reminders and alarms: Radicale on gsv (`hosts/gsv/services/radicale.nix`). Voice and Thunderbird (or any client) edit the same entries, so no UI of our own for recurring things. Radicale keeps every iCalendar field as written and supports sync tokens.
- **Categories mark what the engine handles:** `HomeAssistant Reminder`, `HomeAssistant Alarm`, more kinds later. Untagged entries are never touched, so the entries can live in any calendar.
- **Location is the room:** free text (iCalendar has no select list), fuzzy-matched against HA's area names. Only read on tagged entries; no match or empty means the configured default, plus a warning in HA's log.
- **Rings only at the entry's own reminders (`VALARM`):** no automatic ring at the start time. On the dot only if a 0-minute reminder is set. Tagged entries without any reminder stay silent and get a log note.
- **Disabled alarms are disabled in the calendar too:** event status `CANCELLED` (Thunderbird's Status field), so it's visible and reversible there.
- **Other runtime state stays in the engine** (rung, snoozed until, dismissed), keyed by the entry's ID and occurrence. Nothing is written back for it, so no sync conflicts with Thunderbird.
- **Timers are not calendar entries:** they're too short-lived for a calendar sync. They live only in the engine, central rather than per satellite, with no limit on how many run in parallel.
- **Ringing goes through a script hook:** each ring round calls a configured script with the item's data; the engine decides when, the script how it sounds. A simple built-in fallback (sound plus a generic text on a configured media player) comes with publishing, for setups without a script.
- **Ambiguous targets do nothing:** the response lists the candidates, so the caller can ask back. Acting on a guess (extending the wrong timer) is worse than asking.

## Engine API

**Items:** timers, reminders and alarms, each with an ID, kind, label, area and state (`running`, `paused`, `scheduled`, `ringing`, `snoozed`). Every service can return data (`supports_response`).

**Target** (shared by all services acting on existing items):

- precise: `id` or `entity_id` (UI buttons);
- descriptive, any combination: `label` (fuzzy), `duration` (as set: "the 5-minute timer"), `remaining` (approximate), `time` (a reminder's or alarm's time of day), `area` (only breaks ties);
- everything: `all: true`.
- Ambiguous: nothing happens, the response contains `candidates`.

| Area | Service | Parameters | Response |
|---|---|---|---|
| Timers | `timer_start` | `duration`, `label`?, `area`? | the item |
| | `timer_adjust` | target, `delta` (+/−) or `set_remaining` (set the time left; `remaining` is a target field) | the item |
| | `timer_pause` / `timer_resume` | target | the item |
| | `timer_cancel` | target or `all` | cancelled items |
| Reminders | `reminder_create` | `summary`, `at` or `in`, `alerts` (offsets, default `[0]`), `area`? | the item (written to the calendar with category, location and reminders) |
| | `reminder_delete` | target | |
| Alarms | `alarm_create` | `time`, `days`/repeat rule?, `label`?, `area`? | the item (calendar event) |
| | `alarm_skip` | target, `date` (default: next occurrence) | the item; an exception date in the calendar ("Wecker morgen aus") |
| | `alarm_enable` / `alarm_disable` | target | the item; status `CANCELLED` in the calendar while disabled |
| | `alarm_delete` | target | |
| Ringing (all kinds) | `dismiss` | target, default: everything ringing (optionally only in `area`) | dismissed items |
| | `snooze` | target (default: whatever rang last, optionally in `area`), `delay`? (default from config) | the item with its new time |
| Queries | `query` | `kind`?, `state`?, target fields?, time window `from`/`to`? | items incl. time left, next ring time, next reminder |

**Entities**

- One sensor per running timer, showing when it ends (live countdown in the frontend), all fields as attributes. Created and removed with the timer.
- A calendar entity with the upcoming tagged entries.
- One switch per recurring alarm (enabled or not; mirrors the calendar status).
- Sensors: "next alarm" (timestamp) and "ringing" (on/off, the ringing items as attributes).

**Events:** `remembrance_ringing` (per ring round: item, round number, next reminder of the same occurrence, pending snooze), `remembrance_dismissed`, `remembrance_snoozed`, `remembrance_missed`, `remembrance_changed`.

**Config:** CalDAV connection and calendar, category names, ring script, repeat rhythm and time limit per kind, default snooze delay, default area.

## Engine behaviour

- **Sync:** poll the calendar every minute with a sync token; only changed entries come back. The engine's own writes take effect immediately.
- **Scheduling:** exact ring times locally, from the reminders including repeat rules and their exceptions.
- **Offline:** the last synced state is kept in HA's storage, so alarms still ring when Radicale or the internet is down.
- **Restarts:** re-schedule everything. Missed while HA was down: ring immediately if only minutes late, otherwise `remembrance_missed`.
- **Ringing:** repeats per the kind's rhythm until dismissed, snoozed or the time limit runs out.
- **Snooze without a target** means whatever rang last (in the given area, else anywhere). Prepares the later global "noch mal".

## Our setup (Nix)

**Ring script:** speaker per area via tts_relay's routes, the kind's sound, then TTS via `hass.voice.ttsEntity`. Alarms optionally with slowly rising volume. Generic HA announcement (`play_media` with `announce`), so tts_relay's ducking keeps working.

**Announcement texts** (built from the event data):

- Timer: "Der Nudel-Timer ist abgelaufen."
- Reminder: "Erinnerung: Zahnarzt in 30 Minuten."
- If another reminder of the same occurrence follows: "Ich erinnere dich 5 Minuten vorher noch mal." If that next one is at the start time: "… zum Beginn noch mal." No addition after the last one. Times relative to the event's start, as Thunderbird shows them.
- A pending snooze that comes before the next reminder is announced instead.

**Voice intents** (`hass.voice.intents`, calling the engine's services and building the replies from their responses):

| Kind | Sentences |
|---|---|
| Timers | "Nudel-Timer auf 8 Minuten", "Timer auf 5 Minuten", "5-Minuten-Timer um 1 Minute verlängern", "Pausiere den Timer", "Wie lange noch?", "Lösche den Nudel-Timer" |
| Reminders | "Erinnere mich Samstag um 13 Uhr an …", "… morgen früh an …", "… in 2 Stunden an …", "Was steht heute an?" |
| Alarms | "Weck mich morgen um 6:30", "Wecker werktags um 7", "Wecker für morgen aus" |
| Ringing | "Stopp", "Erinnere mich in 10 Minuten noch mal", "später noch mal", "morgen früh noch mal"; for alarms "Schlummern", "noch 5 Minuten" |

- The caller's area (`preferred_area_id`) goes into `area`, both for creating and as tie-breaker.
- Ambiguous: ask back with the candidates ("Den 5- oder den 10-Minuten-Timer?"). Needs a test that the satellite keeps the conversation open.
- Hyphens and compounds from speech-to-text ("5-Minuten-Timer", "Nudel-Timer") become spaces in closest-intent before matching, so sentences are written with spaces.
- **Date and time understanding** ("Samstag um 13 Uhr", "übermorgen Abend", "in 2 Stunden", "am 3. November") for `reminder_create`/`alarm_create`: where it lives (Jinja in Nix, or a helper the engine offers as a service) is still open. Check existing libraries for German first.

**Dashboard:** a "Wecker" view with the timer sensors (+1 min, pause, cancel via the services), next alarm, upcoming reminders.

## Steps

- [x] Deploy SRV-HOMEASSISTANT: `tts.piper` fix and the tts_relay duck fix.
- [x] Set up `hass-remembrance` in this repo (HACS layout, tests; YAML config first, config flow before publishing).
- [x] Engine core: items, targets, storage, scheduler, restart recovery, ringing via the script hook, events.
- [x] Timers: services, sensors; packaged and loaded in our HA.
- [x] Our side: ring script (`home-assistant/scripts/remembrance-ring.nix`) and timer intents (`intents/timer.nix`); the three fixed slots and their automation are gone, the dashboard banner shows one banner per timer (auto-entities). Live and tested by voice; HA's own timer intents are off (`hass.voice.disableBuiltinIntents`), as they caught what our sentences missed.
- [x] CalDAV sync (one calendar), categories, Location → area, reminders from `VALARM`, calendar entity (`calendar_items.py` pure, `caldav_source.py`, `calendar_manager.py`; tested against a local Radicale).
- [x] Reminders: `reminder_create`/`delete`, `snooze`, `dismiss`; intents (`intents/reminders.nix`) and announcement texts (ring script) in Nix.
- [x] Alarms: create, skip, enable/disable (status `CANCELLED`), switches, "next alarm"; intents (`intents/alarms.nix`), louder every round (ring script).
- [x] Dashboard view "Wecker" (`dashboards/home/view-wecker.nix`): timer quick start and controls; alarms and upcoming entries once the calendar is on.
- [x] Remove `timers.nix` and the old timer automation.
- [x] **Turn on the calendar:** add `remembrance_caldav_url` (the calendar's own URL), `remembrance_caldav_username` and `remembrance_caldav_password` to `hass-secrets`, set `withCalendar = true` in `home-assistant/remembrance.nix`, deploy.
- [ ] Try reminders and alarms by voice and on the Sonos (the texts are rendered and the matching simulated, not heard yet); check `parse_sentence` live first.
- [ ] Config flow and built-in ring fallback; move `hass-remembrance` to its own repo, publish via HACS.
- [x] RuntimeError: Detected that custom integration 'remembrance' calls async_write_ha_state from a thread other than the event loop, which may cause Home Assistant to crash or data to corrupt. (The "next alarm" sensor's minute tick was a plain lambda, which HA runs in a worker thread; it's the `@callback` itself now.)
- [x] closest_intent's self-check: 18 clashing intents, all alarms. Once and repeating alarms were the same sentence with different slot lists ("Weck mich <tag> um …" / "Weck mich <wiederholung> um …"), told apart only by the slot values. Now one slot list holds days and repeats, and one intent per kind (`Wecker`, `WeckerSanft`, `WeckerMitMusik`, `WeckerSanftMitMusik`) decides from the value; offline replica of the self-check: no clashes left.
- [ ] **Answering a question** ("Welchen Timer meinst du? …"): (1) closest_intent sets `continue_conversation` when the reply ends in "?" (HA's own agent never does; LLM agents get it from the chat log); check that LVA honours it. (2) On `ambiguous`, the intent keeps the pending action (service + data) for ~30 s, e.g. in an `input_text`; short answer intents ("Den Nudel Timer", "Den um 7 Uhr", "Die an den Zahnarzt") replay it with the chosen target. Also fixes: a bare "Den Nudel Timer" currently matches "Timer beenden" (score 71) and would delete a timer.
- [ ] **Timer names as one word** ("Nudeltimer", likely what speech-to-text writes): the unnamed `Timer` pattern wins, as aligning "timer" mid-word costs the named pattern a penalty, so the name is dropped when starting, querying or adjusting (deleting works by luck). Fix in closest_intent: a literal right after a slot may start mid-word (compounds). Check the satellite's activation log for the actual transcripts first.

## Notes

- **Sentences and closest_intent:** it expands each pattern into at most 16 variants (`expansion_cap`), so the shapes are generated in Nix, one pattern each (`lib.ha.remembrance`). Two slots side by side don't split; hence one slot for clock times ("13:30" arrives as "13 30", 1440 values) and one for day plus time of day ("morgen früh"). On equal scores the first pattern wins, so longer shapes come first. Number words come from our own list (`timer_zahl`), as HA's lists hold digits only.
- **Not understood (yet):** "halb sieben" and similar; dates like "am 3. November"; a timer name in the short form ("Nudel Timer auf 8 Minuten") or as one word ("Nudeltimer", see Steps).
- **Parse time:** sentences close to a time pattern take ~60–100 ms offline (the clock list in every alarm and reminder pattern); others stay at ~10 ms. The next thing to slim down if it gets noticeable live (e.g. fewer time shapes, or a cheaper clock slot in closest_intent).
- **Gently or at once:** "Weck mich …" (you're asleep) writes a line `Sanft` into the alarm's description, and the alarm gets louder every round, chime or music alike; "Stelle einen Wecker …" / "Wecker auf …" rings at one volume from the start. In Thunderbird: add or delete the `Sanft` line. The phrasing decides, not the time of day (a nap at 15:00 is still "Weck mich").
- **Waking up to music:** an alarm whose description has a line `Musik: <playlist>` (just `Musik`: the default, "500 random tracks") plays that playlist on the room's Music Assistant player instead of the chime, quietly and louder every round (ring script). No chime; with `Sanft` the music's own volume goes up every round (10 % to 40 %), otherwise it plays at 30 %. Snoozing pauses it (`remembrance_snooze_music`), the next ring starts it again; "Stopp" ends the alarm (no more ramping, no time limit) and lets the music play on at its volume, confirmed by "Wecker beendet" ducked over it; a second "Stopp" silences it. A music alarm replaces whatever is playing. Normal alarms, timers and reminders never touch the music's volume: their chime is an announcement that ducks it. By voice: "Weck mich (morgen) um 7 mit Musik", "… mit der Playlist <name>", "Weck mich werktags um 6:30 mit Musik", "Stelle einen Wecker auf 15 Uhr mit Musik"; or the line in Thunderbird's Description field. The engine only stores and passes on the description.
- **One "off" (`Stopp`, `intents/ringing.nix`):** "Stopp", "Ruhe", "Aus", "Wecker aus" and so on dismiss whatever rings and leave the music playing; with nothing ringing they silence the speakers (the former `StilleAlle`). Switching alarms off for good is "Wecker deaktivieren".
- **closest_intent:** before "und", a singular unit ("eine Minute und 30 Sekunden") against a plural-only pattern shifts its alignment into the number and loses it, hence `Minute[n]` there (only there: each optional doubles the candidates). Long TV sentences can score just over the threshold on short patterns ("Hess" as a device).

## Later

- Several calendars.
- "halb sieben", "Viertel nach", dates ("am 3. November").
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
