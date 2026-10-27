# Remembrance

Central timers, reminders and alarms for Home Assistant. An engine with services, entities and
events: not bound to the satellite that set something, as many timers as you like, and (soon)
reminders and alarms straight from your CalDAV calendar. How you use it (voice intents, dashboard
buttons, automations) is up to you; Remembrance ships no sentences and no spoken texts.

Status: early. Timers work; calendar-backed reminders and alarms are next.

## Configuration

```yaml
remembrance:
  # Called once per ring round with the item as variables (plus `round`).
  ring_script: script.remembrance_ring
  ring:
    timer:
      interval: 20 # seconds between rounds
      limit: 120 # then dismissed as timed out
  snooze_delay: 600 # default for `remembrance.snooze`
  missed_grace: 300 # after a restart: ring late up to this, else `remembrance_missed`
  default_area: wohnzimmer # for items created without an area
```

## Services

Every service returns `{status, items, candidates?, reason?}` when called with a response.
`status` is `ok`, `ambiguous` (nothing was done; `candidates` lists the matches), `no_match` or
`invalid`. Called without a response, anything but `ok` raises an error.

Services acting on existing items share the target fields: `id` or `entity_id`, or a description
in any combination: `label` (fuzzy), `duration` (as set: "the 5-minute timer"), `remaining`
(roughly), `area` (only breaks ties); or `all: true`.

| Service | Fields |
|---|---|
| `timer_start` | `duration`, `label`, `area` |
| `timer_adjust` | target, `delta` (seconds, may be negative) or `set_remaining` |
| `timer_pause`, `timer_resume`, `timer_cancel` | target |
| `dismiss` | target; none: everything ringing (in `area`) |
| `snooze` | target, `delay`; none: what is ringing, else what rang last (in `area`) |
| `query` | target, `kind`, `state` |

## Entities and events

- `sensor.remembrance_timer_<id>` per timer: when it ends (timestamp), all fields as attributes.
- `binary_sensor.remembrance_ringing`: on while anything rings; the ringing items as attributes.
- Events: `remembrance_ringing` (per round), `remembrance_dismissed` (`reason`: `dismissed` or
  `timeout`), `remembrance_snoozed`, `remembrance_missed`, `remembrance_changed`.

## Development

`tests/` covers the core without Home Assistant, `tests_ha/` runs the services against a real
Home Assistant core (needs Home Assistant installed).
