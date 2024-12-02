{ ... }:
{
  hass.automations = {
    lg_picture_mode = {
      alias = "LG Picture Mode";
      mode = "single";
      trigger = [
        {
          platform = "webhook";
          allowed_methods = [
            "POST"
            "PUT"
          ];
          local_only = true;
          webhook_id = "-kLWFUupoQJU-drBnLJa4OSFp";
        }
      ];
      action = [
        {
          service = "shell_command.set_light_mode_sdr";
          data = { };
        }
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
          data.name = "Rounded Dark";
        }
      ];
    };
  };
}
