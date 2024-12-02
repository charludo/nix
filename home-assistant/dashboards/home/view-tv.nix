{ lib, e }:
let
  ha = lib.ha;
in
{
  type = "sections";
  max_columns = 2;
  path = "tv";
  icon = "mdi:remote-tv";
  header.card = ha.mkTitleCard "Fernbedienung";
  sections = [
    {
      type = "grid";
      cards = [
        (ha.mkHStack [
          (ha.mkButtonYellow {
            name = "Tag";
            icon = "mdi:weather-sunny";
            service = "rest_command.lgtv_picture_day";
          })
          (ha.mkButtonBlue {
            name = "Nacht";
            icon = "mdi:weather-night";
            service = "rest_command.lgtv_picture_night";
          })
        ])

        (ha.mkHStack [
          (ha.mkServiceButton {
            name = "Dolby";
            icon = "mdi:dolby";
            service = "rest_command.lgtv_picture_dolby";
          })
          (ha.mkServiceButton {
            name = "HDR";
            icon = "mdi:hdr";
            service = "rest_command.lgtv_picture_hdr";
          })
          (ha.mkButtonGreen {
            name = "An";
            icon = "mdi:television";
            service = "rest_command.lgtv_picture_on";
          })
          (ha.mkButtonRed {
            name = "Aus";
            icon = "mdi:television-off";
            service = "rest_command.lgtv_picture_off";
          })
        ])

        # Navigation pad: [Hoch/Runter/Zurück] | [[Ton, Menü] / Enter(tall)]
        (ha.mkHStack [
          (ha.mkVStack [
            (ha.mkServiceButton {
              name = "Hoch";
              icon = "mdi:arrow-up";
              service = "rest_command.lgtv_up";
            })
            (ha.mkServiceButton {
              name = "Runter";
              icon = "mdi:arrow-down";
              service = "rest_command.lgtv_down";
            })
            (ha.mkServiceButton {
              name = "Zurück";
              icon = "mdi:arrow-left";
              service = "rest_command.lgtv_back";
            })
          ])
          (ha.mkVStack [
            (ha.mkHStack [
              (ha.mkServiceButton {
                name = "Ton";
                icon = "mdi:music-note";
                service = "rest_command.lgtv_sound_select";
              })
              (ha.mkServiceButton {
                name = "Menü";
                icon = "mdi:cog-outline";
                service = "rest_command.lgtv_settings";
              })
            ])
            (ha.mkButtonGreen {
              name = "Enter";
              icon = "mdi:arrow-right";
              service = "rest_command.lgtv_enter";
              height = 184;
            })
          ])
        ])
      ];
    }

    {
      type = "grid";
      cards = [
        {
          type = "custom:lg-remote-control";
          entity = e.media_player.lg_c4;
          colors = {
            buttons = "var(--contrast5)";
            border = "var(--black)";
          };
          color_buttons = true;
        }
      ];
    }
  ];
}
