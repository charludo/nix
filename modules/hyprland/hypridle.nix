{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "pidof hyprlock || hyprlock";
        ignore_dbus_inhibit = false;
        lock_cmd = "hyprlock";
      };
    };
  };
}
