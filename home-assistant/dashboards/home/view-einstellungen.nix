{ lib, e }:
let
  ha = lib.ha;
in
{
  type = "sections";
  max_columns = 1;
  path = "einstellungen";
  icon = "mdi:cog";
  header.card = ha.mkTitleCard "Ansichten";
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
            (ha.mkToggleGreen {
              entity = e.input_boolean.settings_garten_anzucht;
              name = "Anzucht";
            })
            (ha.mkToggleBlue {
              entity = e.input_boolean.settings_garten_bewasserung;
              name = "Bewässerung";
            })
            (ha.mkToggleYellow {
              entity = e.input_boolean.settings_garten_heizung;
              name = "Heizung";
            })
          ];
        }
      ];
    }
  ];
}
