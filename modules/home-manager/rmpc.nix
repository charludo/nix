{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.colorScheme) palette;
  cfg = config.cli.rmpc;
in
{
  options.cli.rmpc.enable = lib.mkEnableOption "rmpc MPD client";
  options.cli.rmpc.musicLocation = lib.mkOption {
    type = lib.types.str;
    default = "/media/NAS/Musik";
    description = "where mpd looks for music";
  };
  options.cli.rmpc.stateLocation = lib.mkOption {
    type = lib.types.str;
    default = "$XDG_DATA_HOME/mpd";
    description = "where mpd saves its state";
  };
  options.programs.rmpc.theme = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Write the theme file. Remember to set `theme: Some(\"nix\"),` in your config!";
  };

  config = lib.mkIf cfg.enable {
    programs.rmpc = {
      enable = true;
      config =
        # ron
        ''
          (
            address: "${config.services.mpd.network.listenAddress}:${builtins.toString config.services.mpd.network.port}",
            lyrics_dir: Some("${cfg.musicLocation}"),
            scrolloff: 8,
            wrap_navigation: true,
            select_current_song_on_change: true,
            artists: (
              album_display_mode: NameOnly,
              album_sort_by: Name,
            ),
            album_art: (
              method: Block,
              horizontal_align: Center,
            ),
            browser_song_sort: [Disc, Track, Title, Artist],
            show_playlists_in_browser: None,
            theme: Some("nix"),
            tabs: (
              [
                (
                  name: "Queue",
                  pane: Split(
                    direction: Horizontal,
                    panes: [
                      (
                        size: "100%",
                        pane: Pane(Queue),
                      ),
                      (
                        size: "46",
                        pane: Split(
                          direction: Vertical,
                          panes: [
                            (
                              size: "16",
                              pane: Pane(AlbumArt),
                              align: Right,
                            ),
                            (
                              size: "100%",
                              pane: Pane(Lyrics),
                            ),
                            (
                              size: "4",
                              pane: Pane(Cava),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                (
                  name: "Albums",
                  pane: Pane(Albums),
                ),
                (
                  name: "Artists",
                  pane: Pane(AlbumArtists),
                ),
                (
                  name: "Playlists",
                  pane: Pane(Playlists),
                ),
                (
                  name: "Search",
                  pane: Pane(Search),
                ),
              ],
            ),
            cava: (
              framerate: 60,
              autosens: true,
              sensitivity: 100,
              lower_cutoff_freq: Some(50),
              higher_cutoff_freq: Some(10000),
              input: (
                method: Fifo,
                source: "/tmp/mpd.fifo",
                sample_rate: Some(44100),
                channels: Some(2),
                sample_bits: Some(16),
              ),
              smoothing: (
                noise_reduction: 77,
                monstercat: false,
                waves: false,
              ),
              eq: []
            ),
          )
        '';
      theme =
        #ron
        ''
          #![enable(implicit_some)]
          #![enable(unwrap_newtypes)]
          #![enable(unwrap_variant_newtypes)]
          (
            default_album_art_path: None,
            show_song_table_header: true,
            draw_borders: true,
            browser_column_widths: [20, 38, 42],
            background_color: None,
            text_color: None,
            header_background_color: None,
            modal_background_color: None,
            progress_bar: (
              symbols: ["", "", ""],
              track_style: (fg: "#${palette.base02}"),
              elapsed_style: (fg: "#${palette.base0D}"),
              thumb_style: (fg: "#${palette.base0D}", bg: "#${palette.base00}"),
            ),
            tab_bar: (
              enabled: true,
              active_style: (fg: "#${palette.base00}", bg: "#${palette.base0D}", modifiers: "Bold"),
              inactive_style: (),
            ),
            highlighted_item_style: (fg: "#${palette.base0D}", modifiers: "Bold"),
            current_item_style: (fg: "#${palette.base00}", bg: "#${palette.base0D}", modifiers: "Bold"),
            borders_style: (fg: "#${palette.base0D}"),
            highlight_border_style: (fg: "#${palette.base0D}"),
            symbols: (
              song: "",
              dir: "󱍙",
              playlist: "󰎆",
              marker: " ",
              ellipsis: "...",
              song_style: None,
              dir_style: None,
              playlist_style: None,
            ),
            scrollbar: (
              symbols: ["│", "█", "│", "│"],
              track_style: (),
              ends_style: (),
              thumb_style: (fg: "#${palette.base0D}"),
            ),
            song_table_format: [
              (
                prop: (kind: Property(Artist),
                  default: (kind: Text("Unknown"))
                ),
                width: "20%",
              ),
              (
                prop: (kind: Property(Title),
                  default: (kind: Text("Unknown"))
                ),
                width: "35%",
              ),
              (
                prop: (kind: Property(Album), style: (fg: "#${palette.base07}"),
                  default: (kind: Text("Unknown Album"), style: (fg: "#${palette.base07}"))
                ),
                width: "30%",
              ),
              (
                prop: (kind: Property(Duration),
                  default: (kind: Text("-"))
                ),
                width: "15%",
                alignment: Right,
              ),
            ],
            browser_song_format: [
              (
                kind: Group([
                 (kind: Property(Track)),
                  (kind: Text(" ")),
                ])
              ),
              (
                kind: Group([
                  (kind: Property(Artist)),
                  (kind: Text(" - ")),
                  (kind: Property(Title)),
                ]),
                default: (kind: Property(Filename))
              ),
            ],
            layout: Split(
              direction: Vertical,
              panes: [
                (size: "3", pane: Pane(Tabs)),
                (
                  size: "3",
                  pane: Split(
                    direction: Horizontal,
                    panes: [
                      (
                        size: "100%",
                        pane: Split(
                          direction: Vertical,
                          panes: [
                            (
                              size: "4",
                              borders: "NONE",
                              pane: Pane(Header),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                (
                  size: "100%",
                  pane: Split(
                    direction: Horizontal,
                    panes: [
                      (
                        size: "100%",
                        borders: "NONE",
                        pane: Pane(TabContent),
                      ),
                    ],
                  ),
                ),
                (
                  size: "1",
                  borders: "NONE",
                  pane: Pane(ProgressBar),
                ),
              ],
            ),
            header: (
              rows: [
                (
                  left: [
                    (
                      kind: Property(
                        Status(
                          StateV2(
                            paused_label: " Paused",
                            playing_label: " Playing",
                            stopped_label: " Stopped",
                          ),
                        ),
                      ),
                      style: (modifiers: "Bold"),
                    ),
                  ],
                  center: [
                    (
                      kind: Property(Widget(ScanStatus)),
                    ),
                    (
                      kind: Property(Song(Title)),
                      style: (modifiers: "Bold"),
                      default: (
                        kind: Text("No Song"),
                        style: (modifiers: "Bold"),
                      ),
                    ),
                  ],
                  right: [
                    (
                      kind: Property(Widget(Volume)),
                      style: (fg: "#${palette.base0D}"),
                    ),
                  ],
                ),
                (
                  left: [
                    (
                      kind: Text("[ "),
                      style: (
                        fg: "#${palette.base05}",
                        modifiers: "Bold",
                      ),
                    ),
                    (
                      kind: Property(Status(Elapsed)),
                      style: (fg: "#${palette.base07}"),
                    ),
                    (
                      kind: Text(" / "),
                      style: (
                        fg: "#${palette.base05}",
                        modifiers: "Bold",
                      ),
                    ),
                    (
                      kind: Property(Status(Duration)),
                      style: (fg: "#${palette.base07}"),
                    ),
                    (
                      kind: Text(" | "),
                      style: (fg: "#${palette.base05}"),
                    ),
                    (
                      kind: Property(Status(Bitrate)),
                      style: (fg: "#${palette.base07}"),
                    ),
                    (
                      kind: Text(" kbps "),
                      style: (fg: "#${palette.base05}"),
                    ),
                    (
                      kind: Text("]"),
                      style: (
                        fg: "#${palette.base05}",
                        modifiers: "Bold",
                      ),
                    ),
                  ],
                  center: [
                    (
                      kind: Property(Song(Artist)),
                      style: (
                        fg: "#${palette.base0C}",
                        modifiers: "Bold",
                      ),
                      default: (
                        kind: Text("Unknown Artist"),
                        style: (
                          fg: "#${palette.base0C}",
                          modifiers: "Bold",
                        ),
                      ),
                    ),
                    (kind: Text(" - ")),
                    (
                      kind: Property(Song(Album)),
                      style: (fg: "#${palette.base05}"),
                      default: (
                        kind: Text("Unknown Album"),
                        style: (
                          fg: "#${palette.base05}",
                          modifiers: "Bold",
                        ),
                      ),
                    ),
                  ],
                  right: [
                    (
                      kind: Text("["),
                      style: (fg: "#${palette.base05}"),
                    ),
                    (
                      kind: Property(
                        Status(
                          RepeatV2(
                            on_label: "    ",
                            off_label: "    ",
                            on_style: (
                              fg: "#${palette.base07}",
                              modifiers: "Bold",
                            ),
                            off_style: (
                              fg: "#${palette.base03}",
                              modifiers: "Bold",
                            ),
                          ),
                        ),
                      ),
                    ),
                    (
                      kind: Property(
                        Status(
                          RandomV2(
                            on_label: "    ",
                            off_label: "    ",
                            on_style: (
                              fg: "#${palette.base07}",
                              modifiers: "Bold",
                            ),
                            off_style: (
                              fg: "#${palette.base03}",
                              modifiers: "Bold",
                            ),
                          ),
                        ),
                      ),
                    ),
                    (
                      kind: Property(
                        Status(
                          ConsumeV2(
                            on_label: "  󰮯  ",
                            off_label: "  󰮯  ",
                            oneshot_label: " 󰮯 󰇊 ",
                            on_style: (
                              fg: "#${palette.base07}",
                              modifiers: "Bold",
                            ),
                            off_style: (
                              fg: "#${palette.base03}",
                              modifiers: "Bold",
                            ),
                          ),
                        ),
                      ),
                    ),
                    (
                      kind: Property(
                        Status(
                          SingleV2(
                            on_label: " 󰎤  ",
                            off_label: " 󰎦  ",
                            oneshot_label: " 󰇊  ",
                            off_oneshot_label: " 󱅊  ",
                            on_style: (
                              fg: "#${palette.base07}",
                              modifiers: "Bold",
                            ),
                            off_style: (
                              fg: "#${palette.base03}",
                              modifiers: "Bold",
                            ),
                          ),
                        ),
                      ),
                    ),
                    (
                      kind: Text(" ]"),
                      style: (fg: "#${palette.base05}"),
                    ),
                  ],
                ),
              ],
            ),
          )
        '';
    };
    xdg.configFile = {
      "rmpc/themes/nix.ron".text = config.programs.rmpc.theme;
    };

    # show images even in alacritty, but do not animate using hyprland
    home.packages = with pkgs; [
      ueberzugpp
      lrcget
      cava
    ];
    wayland.windowManager.hyprland.settings.windowrule = [
      "no_focus 1, match:class ^(ueberzugpp_).*"
      "no_anim 1, match:class ^(ueberzugpp_).*"
      "workspace special:magic silent, match:class ^(ueberzugpp_).*"
      "workspace special:magic silent, match:title ^(rmpc).*"
    ];

    # use same music player widget as for jellyfin
    services.mpdris2 = {
      enable = true;
      multimediaKeys = true;
    };

    services.mpd = {
      enable = true;
      musicDirectory = cfg.musicLocation;

      extraConfig = ''
        audio_output {
          type "pipewire"
          name "PipeWire Sound Server"
        }

        auto_update "yes"

        audio_output {
          type   "fifo"
          name   "cava"
          path   "/tmp/mpd.fifo"
          format "44100:16:2"
        }
      '';
    };
  };
}
