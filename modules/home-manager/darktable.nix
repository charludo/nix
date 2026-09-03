{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.darktable;

  allSettings = cfg.settings // cfg.staticSettings;
  confFlags = lib.concatMapStringsSep " " (
    k: "--conf ${lib.escapeShellArg "${k}=${allSettings.${k}}"}"
  ) (builtins.attrNames allSettings);

  darktable = pkgs.symlinkJoin {
    name = "darktable-${pkgs.darktable.version}-configured";
    paths = [ pkgs.darktable ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/darktable \
        --add-flags ${lib.escapeShellArg confFlags}
    '';
    meta = pkgs.darktable.meta // {
      mainProgram = "darktable";
    };
  };

  darktableUiKeys = pkgs.stdenvNoCC.mkDerivation {
    name = "darktable-ui-keys";
    src = pkgs.darktable.src;
    nativeBuildInputs = [ pkgs.gawk ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      awk '
        /<dtconfig[ >]/ { has = ($0 ~ /prefs="|dialog="/) ? 1 : 0 }
        /<name>/ {
          k = $0
          sub(/.*<name>/, "", k)
          sub(/<\/name>.*/, "", k)
          if (has) print k
        }
      ' data/darktableconfig.xml.in | sort -u > $out
    '';
  };

  nixSettings = pkgs.writeText "darktable-nix-settings" (
    lib.concatMapStringsSep "" (k: "${k}=${cfg.settings.${k}}\n") (builtins.attrNames cfg.settings)
  );

  staticKeys = pkgs.writeText "darktable-static-keys" (
    lib.concatMapStringsSep "" (k: "${k}\n") (builtins.attrNames cfg.staticSettings)
  );

  configDiff = pkgs.writeShellApplication {
    name = "darktable-config-diff";
    runtimeInputs = [ pkgs.gawk ];
    text = ''
      live_rc=${lib.escapeShellArg "${cfg.configLocation}/darktablerc"}
      ui_keys=${darktableUiKeys}
      defaults=${lib.escapeShellArg "${pkgs.darktable}/share/darktable/darktablerc"}
      nixset=${nixSettings}
      statickeys=${staticKeys}

      full=0
      case "''${1:-}" in
        --full) full=1 ;;
        "") ;;
        *) printf 'usage: %s [--full]\n' "''${0##*/}" >&2; exit 2 ;;
      esac

      if [ ! -e "$live_rc" ]; then
        printf 'No darktablerc yet at %s\n' "$live_rc"
        exit 1
      fi

      awk -v ui_keys="$ui_keys" -v home="$HOME" -v cfgloc=${lib.escapeShellArg cfg.configLocation} \
          -v nixset="$nixset" -v statickeys="$statickeys" -v full="$full" '
        BEGIN {
          while ((getline k < ui_keys) > 0) ui[k] = 1
          while ((getline k < statickeys) > 0) static[k] = 1
          while ((getline line < nixset) > 0) {
            i = index(line, "=")
            nix[substr(line, 1, i - 1)] = substr(line, i + 1)
          }
        }
        FNR == NR {
          i = index($0, "=")
          d = substr($0, i + 1)
          gsub(/\$\(home\)/, home, d)
          def[substr($0, 1, i - 1)] = d
          next
        }
        {
          i = index($0, "=")
          k = substr($0, 1, i - 1)
          v = substr($0, i + 1)
          if (!(k in ui) || (k in static) || tolower(v) == tolower(def[k])) next
          if (!full && (k in nix) && tolower(v) == tolower(nix[k])) next
          out[k] = v
        }
        END {
          if (full) for (k in nix) if (!(k in out) && !(k in static)) out[k] = nix[k]
          for (k in out) {
            v = out[k]
            if ((k in nix) && tolower(nix[k]) == tolower(v)) v = nix[k]
            if (index(v, cfgloc) == 1) v = "''${cfg.configLocation}" substr(v, length(cfgloc) + 1)
            printf "  \"%s\" = \"%s\";\n", k, v
          }
        }
      ' "$defaults" "$live_rc" | sort
    '';
  };

in
{
  options.desktop.darktable.enable = lib.mkEnableOption "Darktable";
  options.desktop.darktable.dbLocation = lib.mkOption {
    type = lib.types.str;
    description = "where to save the Darktable DB";
    default = "${config.xdg.userDirs.pictures}/.darktable/library.db";
    defaultText = lib.literalExpression "\${config.xdg.userDirs.pictures}/.darktable/library.db";
  };
  options.desktop.darktable.configLocation = lib.mkOption {
    type = lib.types.str;
    description = "where to save Darktable files";
    default = "${config.home.homeDirectory}/.config/darktable";
    defaultText = lib.literalExpression "\${config.home.homeDirectory}/.config/darktable";
  };

  options.desktop.darktable.settings = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    description = ''
      Darktable settings to override with `--config`.
      Run `darktable-config-diff [--full]` after changing UI settings to regenerate.
    '';
    default = { };
  };

  options.desktop.darktable.staticSettings = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    description = ''
      Settings whose values nix computes, e.g.store paths, and which should never come from UI config.
    '';
    default = { };
  };

  config =
    let
      additionalFiles = pkgs.stdenv.mkDerivation rec {
        name = "additional-files";
        src = pkgs.fetchgit {
          url = "https://github.com/darktable-org/lua-scripts";
          rev = "abfa8e9878746511ffebfd6493cb7f45866428cd";
          sha256 = "sha256-lzO1S1F6lE2HTCs5srvb8lvlnC6A8BqZ6deO/m7gpp0=";
        };
        srcFilmSimulation = pkgs.fetchgit {
          url = "https://github.com/bastibe/Darktable-Film-Simulation-Panel";
          rev = "57be3f7f208b9efc496f288ad5667d74dace5d36";
          sha256 = "sha256-OHObydq3dXW/uFa4UoBDMvWXf0GRf852SubR5Tb3NUI=";
        };
        srcFujiAutoSettings = pkgs.fetchgit {
          url = "https://github.com/bastibe/Fujifilm-Auto-Settings-for-Darktable";
          rev = "79a458ce9bc28c870091c978b829aaed8dbdb45a";
          sha256 = "sha256-vscZzEnwOr0amUV9BwFEzRO6XHGKeqndh8so2+iG7nU=";
        };
        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out/stylesToImport
          mkdir -p $out/icons
          mkdir -p $out/luts
          mkdir -p $out/lua/filmsim

          cp -r "${src}/." "$out/lua"

          cp -rf "${srcFujiAutoSettings}/fujifilm_auto_settings.lua" "$out/lua/filmsim/fujifilm_auto_settings.lua"
          cp -rf "${srcFujiAutoSettings}/Fuji XTrans V8/." "$out/luts/Fuji XTrans V8"
          cp -rf "${srcFujiAutoSettings}/styles/." "$out/stylesToImport"

          cp -rf "${srcFilmSimulation}/lua/contrib/FilmSimPanel.lua" "$out/lua/filmsim/FilmSimPanel.lua"
          cp -rf "${srcFilmSimulation}/icons/." "$out/icons"
          cp -rf "${srcFilmSimulation}/styles/." "$out/stylesToImport"
          cp -rf "${srcFilmSimulation}/user.css" "$out/user.css"

          echo "require \"tools/script_manager\"" >> $out/luarc
        '';
      };
    in
    lib.mkIf cfg.enable {
      home.packages = [
        darktable
        configDiff
        pkgs.exiftool
        pkgs.hugin
      ];

      xdg.desktopEntries."org.darktable.darktable" = {
        name = "Darktable";
        type = "Application";
        comment = "Organize and develop images from digital cameras";
        terminal = false;
        exec = "${lib.getExe darktable} --configdir \"${cfg.configLocation}\" --library \"${cfg.dbLocation}\" %U";
        startupNotify = true;
        categories = [
          "Graphics"
          "Photography"
        ];
        icon = "darktable";
        mimeType = [
          "application/x-darktable"
          "image/x-dcraw"
          "image/x-adobe-dng"
          "image/x-canon-cr2"
          "image/x-canon-crw"
          "image/x-fuji-raf"
          "image/x-kodak-dcr"
          "image/x-kodak-kdc"
          "image/x-minolta-mrw"
          "image/x-nikon-nef"
          "image/x-nikon-nrw"
          "image/x-olympus-orf"
          "image/x-panasonic-rw"
          "image/x-panasonic-rw2"
          "image/x-pentax-pef"
          "image/x-sony-arw"
          "image/x-sony-sr2"
          "image/x-sony-srf"
          "image/vnd.radiance"
          "image/avif"
          "image/x-canon-cr3"
          "image/x-exr"
          "image/aces"
          "image/qoi"
          "image/fits"
        ];
      };

      desktop.darktable.staticSettings = {
        "lua/executable_paths/hugin" = lib.getExe' pkgs.hugin "hugin";
        "lua/executable_paths/hugin_executor" = lib.getExe' pkgs.hugin "hugin_executor";
        "lua/executable_paths/pto_gen" = lib.getExe' pkgs.hugin "pto_gen";
      };

      desktop.darktable.settings = {
        "bauhaus/scale" = "1,400000";
        "clplatform_amdacceleratedparallelprocessing" = "true";
        "clplatform_rusticl" = "false";
        "darkroom/ui/develop_mask" = "false";
        "darkroom/ui/overexposed/mode" = "0";
        "darkroom/ui/sidebar_scroll_default" = "true";
        "lua/script_manager/contrib/hugin" = "TRUE";
        "lua/script_manager/filmsim/FilmSimPanel" = "TRUE";
        "lua/script_manager/filmsim/fujifilm_auto_settings" = "TRUE";
        "lua/script_manager/tools/executable_manager" = "TRUE";
        "opencl" = "FALSE";
        "opencl_mandatory_timeout" = "400";
        "plugins/capture/storage/namepattern" = "$(YEAR)$(MONTH)$(DAY)_$(SEQUENCE).$(FILE_EXTENSION)";
        "plugins/capture/storage/subpath" = "$(YEAR)$(MONTH)$(DAY)_$(JOBCODE)";
        "plugins/collect/descending" = "true";
        "plugins/darkroom/atrous/gui_channel" = "0";
        "plugins/darkroom/colorbalancergb/checker1/blue" = "1";
        "plugins/darkroom/colorbalancergb/checker1/green" = "1";
        "plugins/darkroom/colorbalancergb/checker1/red" = "1";
        "plugins/darkroom/colorbalancergb/checker2/blue" = "0.18000000715255737";
        "plugins/darkroom/colorbalancergb/checker2/green" = "0.18000000715255737";
        "plugins/darkroom/colorbalancergb/checker2/red" = "0.18000000715255737";
        "plugins/darkroom/colorbalancergb/checker/size" = "8";
        "plugins/darkroom/colorzones/gui_channel" = "0";
        "plugins/darkroom/histogram/mode" = "histogram";
        "plugins/darkroom/image_infos_pattern" =
          "$(EXIF_EXPOSURE) • f/$(EXIF_APERTURE) • $(EXIF_FOCAL_LENGTH) mm • $(EXIF_ISO) ISO";
        "plugins/darkroom/lut3d/def_path" = "${cfg.configLocation}/luts";
        "plugins/darkroom/rawdenoise/gui_channel" = "0";
        "plugins/imageio/storage/disk/file_directory" =
          "$(FILE_FOLDER)/Output/IMG_$(EXIF_YEAR)$(EXIF_MONTH)$(EXIF_DAY)_$(EXIF_HOUR)$(EXIF_MINUTE)$(EXIF_SECOND)";
        "plugins/lighttable/collect/history_hide" = "false";
        "plugins/lighttable/export/export_masks" = "FALSE";
        "plugins/lighttable/extended_pattern" =
          "$(FILE_NAME).$(FILE_EXTENSION)$(NL)$(EXIF_EXPOSURE) • f/$(EXIF_APERTURE) • $(EXIF_FOCAL_LENGTH)mm • $(EXIF_ISO) ISO $(SIDECAR_TXT)";
        "plugins/lighttable/metadata/creator_flag" = "4";
        "plugins/lighttable/metadata/description_flag" = "4";
        "plugins/lighttable/metadata/image id_flag" = "4";
        "plugins/lighttable/metadata/notes_flag" = "4";
        "plugins/lighttable/metadata/publisher_flag" = "4";
        "plugins/lighttable/metadata/rights_flag" = "4";
        "plugins/lighttable/metadata/title_flag" = "4";
        "plugins/lighttable/metadata/version name_flag" = "5";
        "plugins/lighttable/recentcollect/hide" = "true";
        "plugins/lighttable/thumbnail_tooltip_pattern" =
          "<b>$(FILE_NAME).$(FILE_EXTENSION)</b>$(NL)$(EXIF.DATE.REGIONAL) $(EXIF.TIME.REGIONAL)$(NL)$(EXIF_EXPOSURE) • f/$(EXIF_APERTURE) • $(EXIF_FOCAL_LENGTH) mm • $(EXIF_ISO) ISO";
        "plugins/map/map_source" = "OpenStreetMap I";
        "plugins/map/showalllocations" = "FALSE";
        "plugins/print/printer/icctype" = "-1";
        "plugins/print/print/icctype" = "-1";
        "plugins/print/print/medium" = "Plain paper";
        "plugins/print/print/paper" = "A4";
        "plugins/print/print/printer" = "Drucker";
        "plugins/pwstorage/pwstorage_backend" = "none";
        "resource_default" = "512 8 128 700";
        "resource_large" = "700 16 128 900";
        "resourcelevel" = "large";
        "resource_small" = "128 4 64 400";
        "resource_unrestricted" = "16384 1024 128 900";
        "storage/piwigo/conflict" = "0";
        "themes/usercss" = "true";
        "ui_last/theme" = "darktable";
        "ui/performance" = "false";
        "ui/show_focus_peaking" = "FALSE";
        "ui/show_welcome_screen" = "false";
        "use_system_font" = "TRUE";
        "write_sidecar_files" = "never";
      };

      home.file."${cfg.configLocation}/user.css".source = "${additionalFiles}/user.css";
      home.file."${cfg.configLocation}/luarc".source = "${additionalFiles}/luarc";
      home.file."${cfg.configLocation}/lua".source = "${additionalFiles}/lua";
      home.file."${cfg.configLocation}/luts" = {
        source = "${additionalFiles}/luts";
        recursive = true;

      };
      home.file."${cfg.configLocation}/icons" = {
        source = "${additionalFiles}/icons";
        recursive = true;
      };
      home.file."${cfg.configLocation}/stylesToImport" = {
        source = "${additionalFiles}/stylesToImport";
        recursive = true;
      };

      home.file."${cfg.configLocation}/shortcutsrc" = {
        force = true;
        text = ''
          Left=disabled;views/darkroom/move/horizontal;down
          Right=disabled;views/darkroom/move/horizontal;up
          None=iop/filmicrgb/contrast;*1000
          None=iop/colorbalancergb/contrast;*0,1
          None;left=fallbacks/utility module
          None;left;double=fallbacks/utility module;reset
          None;right=fallbacks/utility module;presets
          None;left=fallbacks/processing module;enable
          None;left;long=fallbacks/processing module;focus
          None;left;double=fallbacks/processing module;reset
          None;right=fallbacks/processing module;presets
          None;right;double=fallbacks/processing module;instance
          None;shift=fallbacks/value;*10
          None;ctrl=fallbacks/value;*0,1
          None;shift;ctrl=fallbacks/value;*10
          None;horizontal=fallbacks/value;*0,1
          None;vertical=fallbacks/value;*10
          None;left;double=fallbacks/value;reset
          None;vertical;left;double=fallbacks/value;top
          None;ctrl=fallbacks/toggle;ctrl-toggle
          None;right=fallbacks/toggle;right-toggle
          None;long=fallbacks/toggle;right-toggle
          None;scroll=fallbacks/dropdown;*-1
          None;vertical=fallbacks/dropdown;*-1
          None;left=fallbacks/dropdown;button
          None;ctrl;left=fallbacks/dropdown;button;ctrl-toggle
          None;left;double=fallbacks/dropdown;reset
          None;shift;ctrl=fallbacks/slider;force;*10
          None;left=fallbacks/slider;button
          None;ctrl;left=fallbacks/slider;button;ctrl-toggle
          None;vertical;right=fallbacks/slider;zoom
          None;ctrl=fallbacks/button;ctrl-activate
          None;right=fallbacks/button;right-activate
          None;long=fallbacks/button;right-activate
          None;shift=fallbacks/contrast equalizer;reset
          None;ctrl=fallbacks/contrast equalizer;bottom
          None;shift=fallbacks/move;select
          space=views/slideshow/start and stop
          space=views/lighttable/select toggle image
          comma;shift=views/lighttable/toggle culling zoom mode
          minus=views/slideshow/speed up
          minus;ctrl=views/lighttable/zoom out
          minus;alt=views/lighttable/zoom min
          equal;shift=views/slideshow/slow down
          equal;shift;ctrl=views/lighttable/zoom in
          equal;shift;alt=views/lighttable/zoom max
          bracketleft=lib/timeline/start selection
          bracketright=lib/timeline/stop selection
          a;ctrl=lib/select/select all
          a;shift;ctrl=lib/select/select none
          c;ctrl=lib/copy_history/copy
          c;shift;ctrl=lib/copy_history/selective copy
          d;ctrl=lib/image/duplicate
          d;shift;ctrl=lib/image/duplicate virgin
          f=views/lighttable/preview;toggle
          g;ctrl=lib/image/group
          g;shift;ctrl=lib/image/ungroup
          h;shift;ctrl=views/tethering/hide histogram
          i=views/lighttable/show infos
          i;ctrl=lib/select/invert selection
          i;shift;ctrl=lib/import/copy & import
          k;ctrl=lib/collect/history
          k;shift;ctrl=lib/collect/jump back to previous collection
          p;ctrl=lib/print_settings/print
          s;shift=lib/map_settings/thumbnail display
          s;ctrl=lib/map_settings/filtered images
          v=lib/live_view/toggle live view
          v;ctrl=lib/copy_history/paste
          v;shift;ctrl=lib/copy_history/selective paste
          w=lib/live_view/zoom live view
          w=views/lighttable/preview
          w;ctrl=views/lighttable/preview;focus detection
          x=views/lighttable/toggle culling mode
          x;ctrl=views/lighttable/toggle culling dynamic mode
          y;ctrl=views/map/redo
          y;ctrl=views/lighttable/redo
          z;ctrl=views/map/undo
          z;ctrl=views/lighttable/undo
          Return=views/lighttable/select single image
          Escape=views/slideshow/exit slideshow
          Escape=views/lighttable/exit current layout
          Escape;alt=views/lighttable/move/leave;next
          Home=views/lighttable/move/whole;previous
          Left=views/slideshow/step back
          Left=views/lighttable/move/horizontal;previous
          Up=views/slideshow/slow down
          Up=views/lighttable/move/vertical;next
          Right=views/slideshow/step forward
          Right=views/lighttable/move/horizontal;next
          Down=views/slideshow/speed up
          Down=views/lighttable/move/vertical;previous
          Page_Up=views/lighttable/move/page;next
          Page_Down=views/lighttable/move/page;previous
          End=views/lighttable/move/whole;next
          KP_Add=views/slideshow/slow down
          KP_Subtract=views/slideshow/speed up
          F1;shift=lib/filtering/rules/color label;red
          F2;shift=lib/filtering/rules/color label;yellow
          F3;shift=lib/filtering/rules/color label;green
          F4;shift=lib/filtering/rules/color label;blue
          F5;shift=lib/filtering/rules/color label;purple
          Delete=lib/image/remove
          space=views/darkroom/image forward
          comma;shift=views/darkroom/decrease brush opacity
          minus;ctrl=views/darkroom/zoom out
          period;shift=views/darkroom/increase brush opacity
          0=views/thumbtable/rating
          1=views/thumbtable/rating;one
          1;alt=views/darkroom/zoom close-up
          2=views/thumbtable/rating;two
          2;alt=views/darkroom/zoom;item:fill
          3=views/thumbtable/rating;three
          3;alt=views/darkroom/zoom;item:fit
          4=views/thumbtable/rating;four
          5=views/thumbtable/rating;five
          equal;shift;ctrl=views/darkroom/zoom in
          bracketleft=iop/flip/rotate 90 degrees CCW
          bracketleft;shift=views/darkroom/decrease brush hardness
          bracketright=iop/flip/rotate 90 degrees CW
          bracketright;shift=views/darkroom/increase brush hardness
          a=views/darkroom/force pan-zoom-rotate with mouse
          a;ctrl=views/thumbtable/select all
          a;shift;ctrl=views/thumbtable/select none
          b=global/panels/collapsing controls
          b;ctrl=views/darkroom/color assessment
          b;shift;ctrl=global/panels/bottom
          b;alt=views/darkroom/color assessment second preview
          c=iop/crop
          c;ctrl=views/thumbtable/copy history
          c;shift;ctrl=views/thumbtable/copy history parts
          d=global/switch views/darkroom
          d;ctrl=views/thumbtable/duplicate image
          d;shift;ctrl=views/thumbtable/duplicate image virgin
          d;scroll=iop/colorbalancergb/saturation/mid-tones
          e;ctrl=lib/export/export
          e;scroll=iop/exposure/exposure
          f;ctrl=global/panels/filmstrip and timeline
          f;shift;ctrl=global/toggle focus peaking
          g=views/darkroom/guide lines/toggle
          g;ctrl=views/darkroom/gamut check
          h=global/show accels window
          h;ctrl=global/panels/header
          h;shift;ctrl=views/darkroom/histogram/hide histogram
          i;ctrl=views/thumbtable/invert selection
          i;shift;ctrl;alt=global/reinitialise input devices
          j;ctrl=lib/metadata_view/jump to film roll
          l=global/switch views/lighttable
          l;shift;ctrl=global/panels/left
          m=global/switch views/map
          n;shift;ctrl=views/darkroom/hide navigation thumbnail
          o=views/darkroom/overexposed/toggle
          o;shift=views/darkroom/raw overexposed/toggle
          o;ctrl=views/darkroom/cycle overlay colors
          p=global/switch views/print
          q;ctrl=global/quit
          q;scroll=iop/colorbalancergb/contrast
          r=views/thumbtable/rating;reject
          r;shift;ctrl=global/panels/right
          r;scroll=iop/ashift/rotation
          s=global/switch views/slideshow
          s;ctrl=views/darkroom/softproof
          t=global/switch views/tethering
          t;shift=global/toggle tooltip visibility
          t;ctrl=lib/tagging/tag
          t;shift;ctrl=global/panels/top
          t;alt=lib/tagging/redo last tag
          v;ctrl=views/thumbtable/paste history
          v;shift;ctrl=views/thumbtable/paste history parts
          v;scroll=iop/colorbalancergb/global vibrance
          w=views/darkroom/full preview
          w;shift;scroll=iop/filmicrgb/white relative exposure
          y;ctrl=views/darkroom/redo
          z;ctrl=views/darkroom/undo
          z;scroll=iop/channelmixerrgb/temperature
          BackSpace=views/darkroom/image back
          Tab=global/panels/all
          Left=views/darkroom/image back
          Up=views/darkroom/move/vertical;up
          Right=views/darkroom/image forward
          Down=views/darkroom/move/vertical;down
          F1=views/thumbtable/color label;red
          F2=views/thumbtable/color label;yellow
          F3=views/thumbtable/color label;green
          F4=views/thumbtable/color label;blue
          F5=views/thumbtable/color label;purple
          F11=global/fullscreen
        '';
      };

      home.file."${cfg.configLocation}/customPreset.dtpreset".text = # xml
        ''
          <?xml version="1.0" encoding="UTF-8"?>
          <darktable_preset version="1.0">
          	<preset>
          		<name>workflow: custom</name>
          		<description></description>
          		<operation>modulegroups</operation>
          		<op_params>gz02eJxdUdF1wzAIXCUbpBlJlk4W78nCRdjty2OkLtCVOkWxnaSv/hI64LiDm739fH3fzAyfM/dFcH0GltCYOmbhTBVW0boNVINaL0FmNIsltIY60SdExuGqmGZI0K07cmWJLIKoxO06CqUDHEINLWJrGCv777LSIBtkPmiiuGU+CikuAh9HKy4vUWeGyE0ldHUXmWVycY+ZZlF4ttALZbVcad4deF2lsagNoVM0U27A+xLqawEWVHh5Wi3hDsHEq1ec7FqinJcOp9xYdiozT8RFVmxBxYra98SB+eJSoT+b3robOmzZeWnH/+7t3SZuHIvwBHPSlcJ5FTvXYV0RS6Poki2GB7gL/n/Rwjq7F1e431agvMTyvK7zIeeN7vHYwJIg3UYJaQmK1NIWU7OVxgZVP48TsdAdvxtNA+8=</op_params>
          		<op_version>1</op_version>
          		<enabled>1</enabled>
          		<autoapply>1</autoapply>
          		<model>%</model>
          		<maker>%</maker>
          		<lens>%</lens>
          		<iso_min>0,000000</iso_min>
          		<iso_max>340282346638528859811704183484516925440,000000</iso_max>
          		<exposure_min>0,000000</exposure_min>
          		<exposure_max>340282346638528859811704183484516925440,000000</exposure_max>
          		<aperture_min>0,000000</aperture_min>
          		<aperture_max>340282346638528859811704183484516925440,000000</aperture_max>
          		<focal_length_min>0</focal_length_min>
          		<focal_length_max>1000</focal_length_max>
          		<blendop_params></blendop_params>
          		<blendop_version>0</blendop_version>
          		<multi_priority>0</multi_priority>
          		<multi_name>(null)</multi_name>
          		<multi_name_hand_edited>0</multi_name_hand_edited>
          		<filter>0</filter>
          		<def>0</def>
          		<format>0</format>
          	</preset>
          </darktable_preset>
        '';
    };
}
