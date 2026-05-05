"""Domain-wide constants."""

DOMAIN = "grocery_categorize"

CONF_TODO_ENTITY = "todo_entity"
CONF_SUPERMARKETS = "supermarkets"

DEFAULT_TODO_ENTITY = "todo.einkaufsliste"

# `hass.data[DOMAIN]` keys.
DATA_CLASSIFIER = "classifier"          # cached Classifier instance
DATA_CONFIG = "config"                  # parsed YAML config
DATA_RESULT = "result"                  # latest single-sensor render dict
DATA_LISTENERS = "listeners"            # list[callable] for the sensor

SERVICE_REFRESH = "refresh"

ATTR_SUPERMARKET = "supermarket"
ATTR_MARKDOWN = "markdown"
ATTR_GENERATED_AT = "generated_at"
