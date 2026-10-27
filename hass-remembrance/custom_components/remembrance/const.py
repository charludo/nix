"""Constants shared by the integration's modules."""

DOMAIN = "remembrance"
STORAGE_KEY = DOMAIN
STORAGE_VERSION = 1

KIND_TIMER = "timer"

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
CONF_DEFAULT_AREA = "default_area"

DEFAULT_INTERVAL = 20.0
DEFAULT_LIMIT = 120.0
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
