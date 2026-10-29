"""Constants shared by the integration's modules."""

DOMAIN = "remembrance"
STORAGE_KEY = DOMAIN
STORAGE_VERSION = 1

KIND_TIMER = "timer"
KIND_REMINDER = "reminder"
KIND_ALARM = "alarm"
KINDS = [KIND_TIMER, KIND_REMINDER, KIND_ALARM]

EVENT_RINGING = f"{DOMAIN}_ringing"
EVENT_DISMISSED = f"{DOMAIN}_dismissed"
EVENT_SNOOZED = f"{DOMAIN}_snoozed"
EVENT_MISSED = f"{DOMAIN}_missed"
EVENT_CHANGED = f"{DOMAIN}_changed"

# Dispatcher signal: the set of items or one of them changed.
SIGNAL_UPDATED = f"{DOMAIN}_updated"

CONF_RING_SCRIPT = "ring_script"
CONF_RING = "ring"
CONF_INTERVAL = "interval"
CONF_LIMIT = "limit"
CONF_SNOOZE_DELAY = "snooze_delay"
CONF_MISSED_GRACE = "missed_grace"
CONF_CALENDAR = "calendar"
CONF_URL = "url"
CONF_USERNAME = "username"
CONF_PASSWORD = "password"
CONF_POLL_INTERVAL = "poll_interval"
CONF_REMINDER_CATEGORY = "reminder_category"
CONF_ALARM_CATEGORY = "alarm_category"
# Duckling's HTTP server, for the services that take a sentence.
CONF_DUCKLING_URL = "duckling_url"

# Ring rhythm per kind: seconds between rounds, and until it times out.
DEFAULT_RING = {
    KIND_TIMER: (20.0, 120.0),
    KIND_REMINDER: (60.0, 0.0),
    KIND_ALARM: (30.0, 600.0),
}
DEFAULT_POLL_INTERVAL = 60.0
DEFAULT_REMINDER_CATEGORY = "HomeAssistant Reminder"
DEFAULT_ALARM_CATEGORY = "HomeAssistant Alarm"
DEFAULT_SNOOZE_DELAY = 600.0
# Overdue by at most this after a restart: ring late instead of reporting missed.
DEFAULT_MISSED_GRACE = 300.0
# "Snooze" without a target also reaches items dismissed this recently.
RECENT_WINDOW = 900.0

# Response status of every service.
STATUS_OK = "ok"
STATUS_AMBIGUOUS = "ambiguous"
STATUS_NO_MATCH = "no_match"
STATUS_INVALID = "invalid"
