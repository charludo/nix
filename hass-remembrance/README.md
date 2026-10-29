# Remembrance

Central timers, reminders and alarms for Home Assistant. An engine with services, entities and
events: not bound to the satellite that set something, as many timers as you like, and
reminders and alarms straight from your CalDAV calendar. How you use it (voice intents, dashboard
buttons, automations) is up to you; Remembrance ships no sentences and no spoken texts.

Status: early. Timers, plus reminders and alarms from one CalDAV calendar.

## Calendar

Reminders and alarms live in your calendar; any client (Thunderbird, phone) can edit them.

- An entry is handled when it carries the category `HomeAssistant Reminder` or `HomeAssistant Alarm` (configurable). Everything else is left alone.
- It rings at its own reminders (VALARMs) only; on the dot only with a 0-minute reminder. Repeats,
  exceptions and moved occurrences are honoured.
- Further categories name the rooms it rings in: an area's name, alias or id, ignoring case.
  Several rooms ring at once; with none, it rings everywhere. Other categories are ignored.
- The Location field is passed on with the item, like the description.
- A disabled alarm has the status `CANCELLED` (Thunderbird's Status field).
- The Description field is passed on with the item, uninterpreted: what it means is up to your
  ring script (e.g. a playlist to wake up to).
- The last synced state is cached, so rings still happen while the server is unreachable.

## Configuration

```yaml
remembrance:
  # Called once per ring round with the item as variables (plus `round`); its
  # `areas` are where it rings, none: everywhere.
  ring_script: script.remembrance_ring
  ring: # per kind: seconds between rounds, and until it times out (0: one round)
    timer: { interval: 20, limit: 120 }
    reminder: { interval: 60, limit: 0 }
    alarm: { interval: 30, limit: 600 }
  snooze_delay: 600 # default for `remembrance.snooze`
  missed_grace: 300 # after a restart: ring late up to this, else `remembrance_missed`
  calendar: # optional; without it only timers
    url: https://dav.example.org/user/calendar/ # the calendar's own URL
    username: user
    password: !secret caldav_password
    poll_interval: 60
  # optional; Duckling's HTTP server, for the services that take a sentence
  duckling_url: http://127.0.0.1:8000
```

## Services

Every service returns `{status, items, candidates?, reason?}` when called with a response.
`status` is `ok`, `ambiguous` (nothing was done; `candidates` lists the matches), `no_match` or
`invalid`. Called without a response, anything but `ok` raises an error. Empty or zero fields
count as not given.

Services acting on existing items share the target fields: `id` or `entity_id`, or a description
in any combination: `label` (fuzzy), `duration` (a timer as set: "the 5-minute timer"),
`remaining` (roughly), `time` (a reminder's or alarm's time of day), `area` (only breaks ties;
items without areas are in every area); or
`all: true`.

| Service                                         | Fields                                                                                         |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `timer_start`                                   | `duration`, `label`, `area`                                                                    |
| `timer_adjust`                                  | target, `delta` (seconds, may be negative) or `set_remaining`                                  |
| `timer_pause`, `timer_resume`, `timer_cancel`   | target                                                                                         |
| `reminder_create`                               | `summary`, `at` or `in`, `alerts` (seconds before, default `[0]`), `area`, `description`       |
| `reminder_delete`                               | target                                                                                         |
| `alarm_create`                                  | `time`, `days` (e.g. `werktags`, `montags`, `daily`) or `date`, `label`, `area`, `description` |
| `alarm_skip`                                    | target, `date` (default: the next occurrence); a one-off alarm is deleted                      |
| `alarm_enable`, `alarm_disable`, `alarm_delete` | target                                                                                         |
| `dismiss`                                       | target; none: everything ringing (in `area`)                                                   |
| `snooze`                                        | target, `delay`; none: what is ringing, else what rang last (in `area`)                        |
| `query`                                         | target, `kind`, `state`, `from`/`to` (one item per occurrence in that window)                  |
| `create_from_text`                              | `text`, `kind`, `language`, `area` (see below)                                                 |
| `parse`                                         | `text`, `kind`, `language`: only what it would create                                          |

### From sentences

`create_from_text` takes a whole sentence ("Weck mich werktags um halb sieben mit Musik", "5
Minuten Timer ab jetzt") and creates what it says through `timer_start`, `reminder_create` or
`alarm_create`; its response also has `parsed`, what was understood. `kind` is optional: without
it, the sentence says. `parse` returns only `parsed`. A sentence that doesn't say enough is
`invalid` with a `reason`: `unknown kind`, `no duration`, `no time`, `vague time` ("morgen
früh"), `no summary`.

[Duckling](https://github.com/facebook/duckling) reads the times and durations; a parser per
language (`parsers/`; so far `de`, default Home Assistant's language) adds the rest: which kind,
repeats ("werktags", "montags", "jeden Tag"), a timer's label ("Nudeltimer"), a reminder's text,
and for alarms the description lines `Sanft` (gently: "sanft", "Weck mich") and `Musik` /
`Musik: <playlist>` ("mit Musik", "mit der Playlist …"). Alarms take a clock time as said ("um
7": 7:00), reminders the next time it comes (at 14:00, "um 7" is 19:00); a reminder on a day
without a time starts at 9.

## Entities and events

- `sensor.remembrance_timer_<id>` per timer: when it ends (timestamp), all fields as attributes.
- `binary_sensor.remembrance_ringing`: on while anything rings; the ringing items as attributes.
- With a calendar: `calendar.remembrance` (the tagged entries), a switch per repeating alarm, and
  `sensor.remembrance_next_alarm`.
- Events: `remembrance_ringing` (per round; reminders with `offset` and `next_offset`, seconds
  before the start), `remembrance_dismissed` (`reason`: `dismissed` or `timeout`),
  `remembrance_snoozed`, `remembrance_missed`, `remembrance_changed`.

## Development

`tests/` covers the pure modules without Home Assistant, `tests_ha/` runs the services against a
real Home Assistant core and a throwaway Radicale (needs Home Assistant, caldav and radicale
installed).
