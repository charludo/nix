{
  # Coords are vacuum-map-space rectangles. Re-harvest from the
  # interactive `vacuum_clean_zone` mode if the map ever rebuilds.
  # Each slug must match input_boolean.botty_<slug>_reinigen.
  hass.botty.zones = {
    sofa = {
      x1 = 23500;
      y1 = 25150;
      x2 = 26300;
      y2 = 29250;
    };
    kueche = {
      x1 = 19510;
      y1 = 25150;
      x2 = 23500;
      y2 = 27700;
    };
    wohnzimmer = {
      x1 = 19510;
      y1 = 25150;
      x2 = 26300;
      y2 = 31250;
    };
    buro = {
      x1 = 20250;
      y1 = 31300;
      x2 = 26250;
      y2 = 35100;
    };
  };
}
