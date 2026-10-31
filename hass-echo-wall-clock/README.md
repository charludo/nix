# Echo Wall Clock

Use an Amazon Echo Wall Clock with Home Assistant instead of an Echo. Home Assistant takes the
Echo's place: it keeps the clock connected, sets its time, and puts timers, alarms and reminders on
its LED ring. No Amazon account, cloud or Echo involved.

The integration only knows the clock. What sets alerts on it (voice intents, automations, another
timer integration) is up to you, through the actions and events below.

Status: early. Pairing, time, and timers work on a real clock. How the clock shows alarms,
reminders, several timers at once and the notification indicator is still to be checked.

## Requirements

- **Classic Bluetooth, through BlueZ.** The clock isn't Bluetooth LE, so Home Assistant's own
  Bluetooth stack and ESPHome proxies can't reach it. The integration talks to BlueZ over the
  system D-Bus (HA OS and most installs have this) and needs a Python built with Bluetooth sockets.
- **An adapter within range of the clock.** Classic Bluetooth, a few metres through walls.
- **The clock away from its Echo.** Remove it in the Alexa app or switch the Echo off, or the two
  compete for it.

## Setup

Add the integration in the UI. A clock the adapter has already paired with is offered directly;
otherwise put the clock into pairing mode and Home Assistant looks for it for 20 seconds, pairs and
adds it. Nothing to type. With several powered adapters you choose one first.

Option: **Ring for** (default 10 minutes), how long a due alert is left ringing before it's
cancelled for you.

## How it works

While the clock misses its Echo it opens a Bluetooth link about once a minute and looks for a
Serial Port service on the other end. Home Assistant publishes one, and when the link comes up it
connects back, encrypted, to the clock's data channel, sends the time and every alert it should
show, and stays connected, sending the time again every half hour. If the clock goes away (new
batteries, out of range), it's brought up to date when it's back; alerts cancelled meanwhile are
deleted then. Alerts are stored, so a Home Assistant restart loses nothing.

The messages are the Alexa Gadgets Toolkit's, byte for byte what an Echo sends.

## Actions

All take an optional `device_id`, needed only with more than one clock. Those that set an alert
return it (`alert_id`, `kind`, `at`, `label`, `ringing`).

| Action | Fields | |
|---|---|---|
| `set_timer` | `duration`, `alert_id`?, `label`? | A timer on the LED ring. |
| `set_alarm` | `at`, `alert_id`?, `label`? | `at`: a date and time, or a time of day (the next one). |
| `set_reminder` | `at`, `alert_id`?, `label`? | |
| `update_alert` | `alert_id`, one of `at`, `duration`, `extend` | Moves it; `extend` may be negative. Into the past cancels it. |
| `cancel_alert` | `alert_id` | Also stops a ringing alert. |
| `cancel_all` | `kind`? | |
| `list_alerts` | `kind`? | Returns `connected` and the alerts, soonest first. |
| `sync_time` | | |

`alert_id` is yours to choose (up to 63 characters), so a caller can use its own IDs; setting an
existing one replaces it. Without one, a numeric ID is made up. `label` stays in Home Assistant:
the clock has no display for it.

## Entities and events

Per clock:

- `binary_sensor.*_connected`: whether the clock is connected now.
- `sensor.*_next_timer`, `*_next_alarm`, `*_next_reminder`: when the next one is due (or was, while
  it rings), with all of that kind in the `alerts` attribute.
- `switch.*_notification_indicator`: what an Echo does for a new notification.
- `button.*_sync_time`.

Events, with the alert's fields plus `device_id` and `address`:

- `echo_wall_clock_alert_due`: an alert is due; the clock rings by itself.
- `echo_wall_clock_alert_ended`: a due alert ended; `reason` is `cancelled`, `timeout`
  (rang for *Ring for*) or `expired` (ran out while Home Assistant was down).

## Development

- `tests/`: the protocol (checked against bytes a real Echo sent) and the clock's sessions, against
  a stand-in clock. No Home Assistant.
- `tests_ha/`: setup, actions, entities and events on a real Home Assistant core, with BlueZ
  simulated.

```
python -m pytest -o asyncio_mode=auto tests
cd tests_ha && python -m pytest -o asyncio_mode=auto .
```

Echo and Alexa are trademarks of Amazon. This project isn't affiliated with or endorsed by Amazon.
