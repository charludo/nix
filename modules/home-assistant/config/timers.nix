{
  # Pool of generic timers picked by the voice intent (first idle one wins).
  # Add more entries here if you tend to run several timers concurrently.
  hass.timers = {
    timer_1 = {
      name = "Timer 1";
      icon = "mdi:timer-sand";
    };
    timer_2 = {
      name = "Timer 2";
      icon = "mdi:timer-sand";
    };
    timer_3 = {
      name = "Timer 3";
      icon = "mdi:timer-sand";
    };
  };
}
