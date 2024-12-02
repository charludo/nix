{ ... }:
{
  hass.automations = {
    set_theme_at_startup = {
      alias = "Set theme at startup";
      mode = "single";
      trigger = [
        {
          event = "start";
          trigger = "homeassistant";
        }
      ];
      action = [
        {
          action = "frontend.set_theme";
          data.name = "Rounded";
        }
      ];
    };
  };
}
