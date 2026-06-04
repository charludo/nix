{ lib, e }:
let
  ha = lib.ha;
  alle = e.media_player.alle;

  # Variant of mkServiceButton with the Sonos visual defaults (white
  # foreground, 88px tall, left-aligned). Used by every transport
  # control on this view that isn't a stand-alone preset.
  mkSonosBtn =
    args:
    ha.mkServiceButton (
      {
        height = 88;
        align = "start";
        padding = "13px 0px 16px 20px";
        fg = "var(--white)";
        haptic = "medium";
      }
      // args
    );

  # Track-step button (next/previous) — full-width media_player call,
  # entity_id pinned to the `alle` speaker group.
  mkStepBtn =
    {
      name,
      icon,
      service,
    }:
    mkSonosBtn {
      inherit name icon;
      service = name;
      tapAction = {
        action = "perform-action";
        haptic = "medium";
        perform_action = service;
        data.entity_id = alle;
      };
      height = 184;
      padding = "108px 0px 16px 20px";
    };

  # Seek button (10s back/forward) — 84px tall, calls the seek script.
  mkSeekBtn =
    {
      name,
      icon,
      seek,
    }:
    mkSonosBtn {
      inherit name icon;
      service = e.script.media_seek;
      serviceData = {
        seek_amount = seek;
        media_player = alle;
      };
      height = 84;
      padding = "8px 0px 16px 20px";
    };

  # Two-state media_player attribute toggle: tap calls `service` with
  # `attribute = attrValue`, and the button recolors yellow when
  # `activeWhen` evaluates true. Default `attrValue` flips a boolean
  # attribute, and `activeWhen` checks for `=== true` — override
  # either for multi-mode attributes (e.g. repeat: off/all cycle).
  mkAttrToggle =
    {
      attribute,
      offName,
      offIcon,
      onName,
      onIcon,
      service,
      attrValue ? "[[[ return !entity.attributes.${attribute}; ]]]",
      activeWhen ? "[[[ return entity.attributes.${attribute} === true; ]]]",
    }:
    mkSonosBtn {
      name = offName;
      icon = offIcon;
      entity = alle;
      inherit service;
      serviceData = {
        entity_id = alle;
        ${attribute} = attrValue;
      };
      state = [
        (ha.mkStateStyleFull {
          value = activeWhen;
          name = onName;
          icon = onIcon;
          bg = "var(--yellow)";
          nameColor = "var(--black)";
          iconColor = "var(--black)";
        })
      ];
    };
in
{
  type = "sections";
  max_columns = 1;
  icon = "mdi:music-note";
  path = "";
  header.card = ha.mkBadgeTitleCard {
    name = "Sonos";
    badgeCard = ha.mkHeaderBadge {
      entity = alle;
      name = ''[[[ return states["${alle}"].state.charAt(0).toUpperCase() + states["${alle}"].state.slice(1); ]]]'';
    };
  };
  sections = [
    {
      type = "grid";
      cards = [

        (ha.mkSonosAlbumArt alle)

        # Play/Pause + speaker toggles
        (ha.mkHStack [
          (ha.mkButtonGreen {
            name = "Abspielen";
            icon = "mdi:play";
            entity = e.media_player.office;
            service = e.script.sonos_play_pause;
            height = 184;
            align = "start";
            padding = "108px 0px 16px 20px";
            state = [
              (ha.mkStateStyleFull {
                value = "[[[ return entity?.state === 'playing'; ]]]";
                name = "Pausieren";
                icon = "mdi:pause";
                bg = "var(--yellow)";
              })
            ];
          })
          (ha.mkVStack [
            (ha.mkSpeakerToggle {
              name = "Wohnzimmer";
              entity = e.media_player.living_room;
              service = e.script.sonos_wohnzimmer_toggle;
            })
            (ha.mkSpeakerToggle {
              name = "Büro";
              entity = e.media_player.office;
              service = e.script.sonos_buro_toggle;
            })
          ])
        ])

        # Previous / Next / Shuffle+Loop
        (ha.mkHStack [
          (mkStepBtn {
            name = "Voriger";
            icon = "mdi:skip-previous";
            service = "media_player.media_previous_track";
          })
          (mkStepBtn {
            name = "Nächster";
            icon = "mdi:skip-next";
            service = "media_player.media_next_track";
          })
          (ha.mkVStack [
            (mkAttrToggle {
              attribute = "shuffle";
              offName = "Shuffle aus";
              offIcon = "mdi:shuffle-disabled";
              onName = "Shuffle an";
              onIcon = "mdi:shuffle";
              service = "media_player.shuffle_set";
            })
            (mkAttrToggle {
              attribute = "repeat";
              offName = "Loop aus";
              offIcon = "mdi:repeat-off";
              onName = "Loop an";
              onIcon = "mdi:repeat";
              service = "media_player.repeat_set";
              attrValue = ''
                [[[
                  const modes = ['off', 'all'];
                  const current = entity.attributes.repeat ?? 'off';
                  return modes[(modes.indexOf(current) + 1) % modes.length];
                ]]]
              '';
              activeWhen = ''[[[ return entity.attributes.repeat === "all"; ]]]'';
            })
          ])
        ])

        # Volume sliders: full-volume on the left, per-room on the
        # right with seek buttons stacked above each.
        (ha.mkHStack [
          (ha.mkVolumeSliderCard {
            name = "";
            entity = alle;
            height = 400;
          })
          (ha.mkVStack [
            (mkSeekBtn {
              name = "Zurück";
              icon = "mdi:rewind-10";
              seek = -10;
            })
            (ha.mkVolumeSliderCard {
              name = "Wohnzimmer";
              entity = e.media_player.living_room;
              height = 276;
            })
          ])
          (ha.mkVStack [
            (mkSeekBtn {
              name = "Vorwärts";
              icon = "mdi:fast-forward-10";
              seek = 10;
            })
            (ha.mkVolumeSliderCard {
              name = "Büro";
              entity = e.media_player.office;
              height = 276;
            })
          ])
        ])

        # Player reset — red when the speaker group reports "off".
        (mkSonosBtn {
          name = "Player neu starten";
          icon = "mdi:restart";
          entity = alle;
          service = e.script.sonos_reset;
          align = "center";
          padding = "13px 0px 16px 20px";
          haptic = "light";
          state = [
            (ha.mkStateStyleFull {
              value = ''[[[ return entity.state === "off"; ]]]'';
              name = "Player ist aus";
              icon = "mdi:restart-alert";
              bg = "var(--red)";
              nameColor = "var(--black)";
              iconColor = "var(--black)";
            })
          ];
        })

      ];
    }
  ];
}
