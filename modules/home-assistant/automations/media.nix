{ ... }:
{
  hass.automations = {
    lg_picture_mode_day = {
      alias = "LG Picture Mode: Day at sunrise";
      mode = "single";
      trigger = [
        {
          platform = "sun";
          event = "sunrise";
        }
      ];
      action = [
        { action = "rest_command.lgtv_picture_day"; }
      ];
    };

    lg_picture_mode_night = {
      alias = "LG Picture Mode: Night at sunset";
      mode = "single";
      trigger = [
        {
          platform = "sun";
          event = "sunset";
        }
      ];
      action = [
        { action = "rest_command.lgtv_picture_night"; }
      ];
    };

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
