{ lib }:
let
  ha = lib.ha;
in
{
  type = "sections";
  max_columns = 1;
  path = "einstellungen";
  icon = "mdi:cog";
  header = {
    card = ha.mkTitleCard "Ansichten";
  };
  sections = [
    {
      type = "grid";
      cards = [
        {
          square = false;
          type = "grid";
          columns = 3;
          title = "Garten";
          cards = [
            (ha.mkToggleCard {
              entity = "input_boolean.settings_garten_anzucht";
              name = "Anzucht";
              onColor = "var(--green)";
            })
            (ha.mkToggleCard {
              entity = "input_boolean.settings_garten_bewasserung";
              name = "Bewässerung";
              onColor = "var(--blue)";
            })
            (ha.mkToggleCard {
              entity = "input_boolean.settings_garten_heizung";
              name = "Heizung";
              onColor = "var(--yellow)";
            })
          ];
        }

      ];
    }
  ];
}
