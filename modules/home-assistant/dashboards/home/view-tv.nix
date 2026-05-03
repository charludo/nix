{ lib, e }:
let
  ha = lib.ha;

  smallHeight = 88;
  enterHeight = 184;

  mkBtn =
    {
      name,
      icon,
      service,
      height ? smallHeight,
      bg ? "var(--contrast2)",
      iconColor ? "var(--contrast20)",
      nameColor ? "var(--contrast20)",
      haptic ? "light",
    }:
    {
      type = "custom:button-card";
      inherit name icon;
      tap_action = {
        inherit haptic;
        action = "perform-action";
        perform_action = service;
      };
      styles =
        (ha.mkStyles {
          icon = {
            width = "24px";
            color = iconColor;
          };
          img_cell = {
            "justify-content" = "center";
            "margin-top" = "0px";
          };
          name = {
            "justify-self" = "center";
            "font-size" = "14px";
            "margin-top" = "0px";
            color = nameColor;
          };
          card = {
            height = "${toString height}px";
            "border-radius" = "24px";
            padding = "16px";
            "background-color" = bg;
          };
        })
        // {
          grid = ha.mkStyleProp { "grid-template-areas" = ''"i" "n"''; };
        };
    };

in
{
  type = "sections";
  max_columns = 2;
  path = "tv";
  icon = "mdi:remote-tv";
  header = {
    card = ha.mkTitleCard "Fernbedienung";
  };
  sections = [
    {
      type = "grid";
      cards = [
        # Picture modes — top row: Tag + Nacht (each half-width via 2-child hstack)
        (ha.mkHStack [
          (mkBtn {
            name = "Tag";
            icon = "mdi:weather-sunny";
            service = "rest_command.lgtv_picture_day";
            bg = "var(--yellow)";
            iconColor = "var(--black)";
            nameColor = "var(--black)";
            haptic = "medium";
          })
          (mkBtn {
            name = "Nacht";
            icon = "mdi:weather-night";
            service = "rest_command.lgtv_picture_night";
            bg = "var(--blue)";
            iconColor = "var(--black)";
            nameColor = "var(--black)";
            haptic = "medium";
          })
        ])

        # Picture modes — bottom row: Dolby, HDR, An, Aus (4-child hstack = quarter each)
        (ha.mkHStack [
          (mkBtn {
            name = "Dolby";
            icon = "mdi:dolby";
            service = "rest_command.lgtv_picture_dolby";
          })
          (mkBtn {
            name = "HDR";
            icon = "mdi:hdr";
            service = "rest_command.lgtv_picture_hdr";
          })
          (mkBtn {
            name = "An";
            icon = "mdi:television";
            service = "rest_command.lgtv_picture_on";
            bg = "var(--green)";
            iconColor = "var(--black)";
            nameColor = "var(--black)";
          })
          (mkBtn {
            name = "Aus";
            icon = "mdi:television-off";
            service = "rest_command.lgtv_picture_off";
            bg = "var(--red)";
            iconColor = "var(--contrast1)";
            nameColor = "var(--contrast1)";
          })
        ])

        # Navigation: [VStack(Hoch, Runter, Zurück)]
        # Right column: top row [SoundSelect | Settings], then Enter (2-row tall)
        (ha.mkHStack [
          (ha.mkVStack [
            (mkBtn {
              name = "Hoch";
              icon = "mdi:arrow-up";
              service = "rest_command.lgtv_up";
            })
            (mkBtn {
              name = "Runter";
              icon = "mdi:arrow-down";
              service = "rest_command.lgtv_down";
            })
            (mkBtn {
              name = "Zurück";
              icon = "mdi:arrow-left";
              service = "rest_command.lgtv_back";
            })
          ])
          (ha.mkVStack [
            (ha.mkHStack [
              (mkBtn {
                name = "Ton";
                icon = "mdi:music-note";
                service = "rest_command.lgtv_sound_select";
              })
              (mkBtn {
                name = "Menü";
                icon = "mdi:cog-outline";
                service = "rest_command.lgtv_settings";
              })
            ])
            (mkBtn {
              name = "Enter";
              icon = "mdi:arrow-right";
              service = "rest_command.lgtv_enter";
              height = enterHeight;
              bg = "var(--green)";
              iconColor = "var(--black)";
              nameColor = "var(--black)";
            })
          ])
        ])
      ];
    }

    # Side-by-side LG WebOS remote (custom:lg-remote-control card).
    {
      type = "grid";
      cards = [
        {
          type = "custom:lg-remote-control";
          entity = e.media_player.lg_c4;
          colors = {
            buttons = "#3d3846";
            border = "#000000";
          };
          color_buttons = true;
        }
      ];
    }
  ];
}
