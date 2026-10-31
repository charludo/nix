"""Constants for the Echo Wall Clock integration."""

from datetime import timedelta

DOMAIN = "echo_wall_clock"

CONF_ADDRESS = "address"
CONF_ADAPTER = "adapter"
CONF_RING_FOR = "ring_for"

# How long a due alert is left ringing before it's cancelled for you.
DEFAULT_RING_FOR = 600

# Kinds, as the services and entities name them; the wire uses upper case.
KIND_TIMER = "timer"
KIND_ALARM = "alarm"
KIND_REMINDER = "reminder"
KINDS = (KIND_TIMER, KIND_ALARM, KIND_REMINDER)

ATTR_ALERT_ID = "alert_id"
ATTR_ALERTS = "alerts"
ATTR_AT = "at"
ATTR_DEVICE_ID = "device_id"
ATTR_DURATION = "duration"
ATTR_EXTEND = "extend"
ATTR_KIND = "kind"
ATTR_LABEL = "label"

EVENT_ALERT_DUE = f"{DOMAIN}_alert_due"
EVENT_ALERT_ENDED = f"{DOMAIN}_alert_ended"

# Safety net next to the BlueZ signal: look at the link state this often.
POLL_INTERVAL = timedelta(seconds=30)
# Seconds to look for clocks in pairing mode.
SCAN_SECONDS = 20

STORAGE_VERSION = 1
