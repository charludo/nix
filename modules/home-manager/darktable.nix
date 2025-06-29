{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.darktable;
in
{
  options.desktop.darktable.enable = lib.mkEnableOption "enable Darktable";
  options.desktop.darktable.dbLocation = lib.mkOption {
    type = lib.types.str;
    description = "where to save the Darktable DB";
    default = "${config.xdg.userDirs.pictures}/.darktable/library.db";
  };
  options.desktop.darktable.configLocation = lib.mkOption {
    type = lib.types.str;
    description = "where to save Darktable files";
    default = "${config.home.homeDirectory}/.config/darktable";
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
      home.packages = with pkgs; [
        darktable
        exiftool
      ];

      xdg.desktopEntries."org.darktable.darktable" = {
        name = "Darktable";
        type = "Application";
        comment = "Organize and develop images from digital cameras";
        terminal = false;
        exec = "darktable --configdir \"${cfg.configLocation}\" --library \"${cfg.dbLocation}\" %U";
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

      home.file."${cfg.configLocation}/darktablerc" = {
        force = true;
        text = ''
          lua/script_manager/filmsim/fujifilm_auto_settings=TRUE
          lua/script_manager/filmsim/FilmSimPanel=TRUE
          accel/assign_instance=false
          accel/enable_fallbacks=false
          accel/hide_notice=false
          accel/load_defaults=true
          accel/prefer_enabled=false
          accel/prefer_expanded=false
          accel/prefer_focused=true
          accel/prefer_unmasked=false
          accel/select_order=last instance
          accel/show_tab_in_prefs=true
          accel/slider_precision=0
          allow_lab_output=false
          ask_before_copy=true
          ask_before_delete=true
          ask_before_discard=true
          ask_before_move=true
          ask_before_remove=true
          ask_before_rmdir=false
          autosave_interval=10
          backthumbs_inactivity=5,000000
          backthumbs_initialize=false
          backthumbs_mipsize=never
          bauhaus/scale=1,400000
          bauhaus/zoom_step=true
          brush_smoothing=medium
          cache_color_managed=true
          cache_disk_backend=true
          cache_disk_backend_full=false
          channel_display=false color
          clplatform_amdacceleratedparallelprocessing=true
          clplatform_apple=false
          clplatform_intelropenclhdgraphics=true
          clplatform_nvidiacuda=true
          clplatform_openclon12=false
          clplatform_other=false
          clplatform_rusticl=false
          codepaths/openmp_simd=false
          compress_xmp_tags=only large entries
          context_help/url=https://docs.darktable.org/usermanual/
          context_help/use_default_url=true
          darkroom/modules/channelmixerrgb/colorchecker=0
          darkroom/modules/channelmixerrgb/optimization=0
          darkroom/modules/channelmixerrgb/safety=0,500000
          darkroom/modules/exposure/lightness=50,000000
          darkroom/mouse/middle_button_cycle_zoom_to_200_percent=true
          darkroom/ui/activate_expand=false
          darkroom/ui/auto_module_name_update=true
          darkroom/ui/develop_mask=false
          darkroom/ui/hide_header_buttons=always
          darkroom/ui/iso12464_border=4,000000
          darkroom/ui/iso12464_ratio=0,400000
          darkroom/ui/loading_screen=true
          darkroom/ui/overexposed/colorscheme=1
          darkroom/ui/overexposed/lower=-12.689999580383301
          darkroom/ui/overexposed/mode=0
          darkroom/ui/overexposed/upper=99.989997863769531
          darkroom/ui/overlay_color=
          darkroom/ui/overlay_contrast=0,500000
          darkroom/ui/rawoverexposed/colorscheme=0
          darkroom/ui/rawoverexposed/mode=0
          darkroom/ui/rawoverexposed/threshold=1
          darkroom/ui/rename_new_instance=false
          darkroom/ui/scale_precise_step_multiplier=0,100000
          darkroom/ui/scale_rough_step_multiplier=10,000000
          darkroom/ui/scale_step_multiplier=1,000000
          darkroom/ui/scroll_to_module=true
          darkroom/ui/scrollbars=false
          darkroom/ui/show_mask_indicator=true
          darkroom/ui/sidebar_scroll_default=true
          darkroom/ui/single_module=true
          darkroom/ui/single_module_group_only=true
          darkroom/ui/transition_duration=250
          darkroom/undo/merge_same_secs=10,000000
          darkroom/undo/review_secs=2,000000
          database=library.db
          database/create_snapshot=once a week
          database/keep_snapshots=10
          database/maintenance_freepage_ratio=25
          database_cache_quality=89
          guides/lighttable/1/global/show=
          libraw_extensions=
          lighttable/ui/1/bottom_visible=TRUE
          lighttable/ui/1/header_visible=TRUE
          lighttable/ui/1/left_visible=TRUE
          lighttable/ui/1/panel_collaps_state=
          lighttable/ui/1/panels_collapse_controls=TRUE
          lighttable/ui/1/right_visible=TRUE
          lighttable/ui/1/toolbar_bottom_visible=TRUE
          lighttable/ui/1/toolbar_top_visible=TRUE
          lighttable/ui/expose_statuses=false
          lighttable/ui/milliseconds=false
          lighttable/ui/preview/bottom_visible=true
          lighttable/ui/preview/header_visible=false
          lighttable/ui/preview/left_visible=false
          lighttable/ui/preview/panel_collaps_state=1
          lighttable/ui/preview/panels_collapse_controls=false
          lighttable/ui/preview/right_visible=false
          lighttable/ui/preview/toolbar_bottom_visible=false
          lighttable/ui/preview/toolbar_top_visible=false
          lighttable/ui/scroll_to_module=false
          lighttable/ui/scrollbars=true
          lighttable/ui/single_module=false
          lua/_scripts_install/debug=FALSE
          lua/_scripts_install/dont_show=FALSE
          lua/_scripts_install/initialized=
          lua/_scripts_install/remind=
          masks_scroll_down_increases=false
          max_panel_height=400
          metadata/resolution=300
          min_panel_height=64
          modules/default_presets_first=true
          omit_tag_hierarchy=false
          opencl=FALSE
          opencl_checksum=
          opencl_device_priority=*/!0,*/*/*/!0,*
          opencl_library=
          opencl_mandatory_timeout=400
          opencl_scheduling_profile=default
          opencl_tune_headroom=false
          panel_scrollbars_always_visible=true
          performance_configuration_version_completed=16
          pixelpipe_synchronization_timeout=200
          plugins/capture/camera/live_view_fps=15
          plugins/capture/mode=0
          plugins/capture/storage/basedirectory=$(PICTURES_FOLDER)/darktable
          plugins/capture/storage/namepattern=$(YEAR)$(MONTH)$(DAY)_$(SEQUENCE).$(FILE_EXTENSION)
          plugins/capture/storage/subpath=$(YEAR)$(MONTH)$(DAY)_$(JOBCODE)
          plugins/collect/descending=true
          plugins/collect/filmroll_sort=import time
          plugins/collection/colors_filter=80000000
          plugins/collection/descending=false
          plugins/collection/film_id=1
          plugins/collection/filter_flags=3
          plugins/collection/query_flags=3
          plugins/collection/rating=1
          plugins/collection/rating_comparator=3
          plugins/collection/sort=0
          plugins/collection/text_filter=
          plugins/darkroom/active=
          plugins/darkroom/ashift/autocrop_value=1
          plugins/darkroom/ashift/expand_values=false
          plugins/darkroom/ashift/near_delta=20,000000
          plugins/darkroom/ashift/near_delta_draw=5,000000
          plugins/darkroom/atrous/aspect_percent=56
          plugins/darkroom/atrous/gui_channel=0
          plugins/darkroom/basecurve/auto_apply_percamera_presets=false
          plugins/darkroom/basecurve/visible=true
          plugins/darkroom/bilat/visible=true
          plugins/darkroom/channelmixerrgb/expand_picker_mapping=
          plugins/darkroom/channelmixerrgb/expand_values=
          plugins/darkroom/channelmixerrgb/gui_page=0
          plugins/darkroom/clipping/guide=0
          plugins/darkroom/clipping/ratio_d=0
          plugins/darkroom/clipping/ratio_n=0
          plugins/darkroom/clipping/visible=true
          plugins/darkroom/colorbalance/controls=
          plugins/darkroom/colorbalance/layout=list
          plugins/darkroom/colorbalance/visible=true
          plugins/darkroom/colorbalancergb/aspect_percent=56
          plugins/darkroom/colorbalancergb/checker/size=8
          plugins/darkroom/colorbalancergb/checker1/blue=1
          plugins/darkroom/colorbalancergb/checker1/green=1
          plugins/darkroom/colorbalancergb/checker1/red=1
          plugins/darkroom/colorbalancergb/checker2/blue=0.18000000715255737
          plugins/darkroom/colorbalancergb/checker2/green=0.18000000715255737
          plugins/darkroom/colorbalancergb/checker2/red=0.18000000715255737
          plugins/darkroom/colorin/visible=true
          plugins/darkroom/colorpicker/windowheight=200
          plugins/darkroom/colorzones/aspect_percent=56
          plugins/darkroom/colorzones/bg_sat_factor=0,500000
          plugins/darkroom/colorzones/gui_channel=0
          plugins/darkroom/crop/expand_margins=false
          plugins/darkroom/crop/visible=true
          plugins/darkroom/demosaic/fdc_xover_iso=1600
          plugins/darkroom/demosaic/visible=true
          plugins/darkroom/denoiseprofile/aspect_percent=56
          plugins/darkroom/denoiseprofile/show_compute_variance_mode=false
          plugins/darkroom/denoiseprofile/visible=true
          plugins/darkroom/duplicate/windowheight=400
          plugins/darkroom/export/visible=true
          plugins/darkroom/exposure/mapping=
          plugins/darkroom/exposure/visible=true
          plugins/darkroom/filmicrgb/aspect_percent=56
          plugins/darkroom/flip/visible=true
          plugins/darkroom/groups=2
          plugins/darkroom/hazeremoval/visible=true
          plugins/darkroom/hide_default_presets=false
          plugins/darkroom/highlights/visible=true
          plugins/darkroom/histogram/aspect_percent=56
          plugins/darkroom/histogram/histogram=logarithmic
          plugins/darkroom/histogram/mode=histogram
          plugins/darkroom/histogram/orient=horizontal
          plugins/darkroom/histogram/panel_position=right
          plugins/darkroom/histogram/show_blue=true
          plugins/darkroom/histogram/show_green=true
          plugins/darkroom/histogram/show_red=true
          plugins/darkroom/histogram/vectorscope=u*v*
          plugins/darkroom/histogram/vectorscope/angle=270
          plugins/darkroom/histogram/vectorscope/harmony/dim=0,700000
          plugins/darkroom/histogram/vectorscope/harmony_rotation=0
          plugins/darkroom/histogram/vectorscope/harmony_type=none
          plugins/darkroom/histogram/vectorscope/harmony_width=normal
          plugins/darkroom/histogram/vectorscope/scale=logarithmic
          plugins/darkroom/histogram/waveform=overlaid
          plugins/darkroom/history/windowheight=1000
          plugins/darkroom/image_infos_pattern=$(EXIF_EXPOSURE) • f/$(EXIF_APERTURE) • $(EXIF_FOCAL_LENGTH) mm • $(EXIF_ISO) ISO
          plugins/darkroom/image_infos_position=bottom
          plugins/darkroom/lens/expand_fine_tune=
          plugins/darkroom/lens/expand_vignette=
          plugins/darkroom/lens/visible=true
          plugins/darkroom/levels/aspect_percent=56
          plugins/darkroom/lowlight/aspect_percent=56
          plugins/darkroom/lut3d/def_path=${cfg.configLocation}/luts/
          plugins/darkroom/masks/brush/border=0,050000
          plugins/darkroom/masks/brush/density=1,000000
          plugins/darkroom/masks/brush/hardness=0,660000
          plugins/darkroom/masks/circle/border=0,050000
          plugins/darkroom/masks/circle/size=0,050000
          plugins/darkroom/masks/ellipse/border=0,050000
          plugins/darkroom/masks/ellipse/flags=0
          plugins/darkroom/masks/ellipse/radius_a=0,050000
          plugins/darkroom/masks/ellipse/radius_b=0,035350
          plugins/darkroom/masks/ellipse/rotation=90,000000
          plugins/darkroom/masks/expand_properties=
          plugins/darkroom/masks/gradient/compression=0,500000
          plugins/darkroom/masks/gradient/rotation=0,000000
          plugins/darkroom/masks/gradient/steepness=0,000000
          plugins/darkroom/masks/heightview=300
          plugins/darkroom/masks/opacity=1,000000
          plugins/darkroom/masks/path/border=0,050000
          plugins/darkroom/modulegroups_basics_sections_labels=true
          plugins/darkroom/modulegroups_preset=
          plugins/darkroom/navigation/aspect_percent=56
          plugins/darkroom/rawdenoise/aspect_percent=56
          plugins/darkroom/rawdenoise/gui_channel=0
          plugins/darkroom/rawprepare/allow_editing_crop=false
          plugins/darkroom/retouch/default_algo=2
          plugins/darkroom/rgblevels/aspect_percent=56
          plugins/darkroom/rgblevels/visible=true
          plugins/darkroom/sharpen/visible=true
          plugins/darkroom/show_guides_in_ui=true
          plugins/darkroom/show_warnings=true
          plugins/darkroom/sigmoid/expand_primaries=
          plugins/darkroom/sigmoid/expand_values=
          plugins/darkroom/snapshots/windowheight=200
          plugins/darkroom/spots/brush_border=0,050000
          plugins/darkroom/spots/brush_density=1,000000
          plugins/darkroom/spots/brush_hardness=0,660000
          plugins/darkroom/spots/circle_border=0,020000
          plugins/darkroom/spots/circle_size=0,020000
          plugins/darkroom/spots/ellipse_border=0,020000
          plugins/darkroom/spots/ellipse_flags=0
          plugins/darkroom/spots/ellipse_radius_a=0,020000
          plugins/darkroom/spots/ellipse_radius_b=0,014140
          plugins/darkroom/spots/ellipse_rotation=90,000000
          plugins/darkroom/spots/path_border=0,050000
          plugins/darkroom/tagging/visible=true
          plugins/darkroom/temperature/button_bar=true
          plugins/darkroom/temperature/colored_sliders=no color
          plugins/darkroom/temperature/expand_coefficients=false
          plugins/darkroom/temperature/visible=true
          plugins/darkroom/toneequal/gui_page=0
          plugins/darkroom/toneequal/visible=true
          plugins/darkroom/ui/border_size=10
          plugins/darkroom/watermark/color_blue=
          plugins/darkroom/watermark/color_green=
          plugins/darkroom/watermark/color_red=
          plugins/darkroom/watermark/font=
          plugins/darkroom/watermark/text=
          plugins/darkroom/workflow=scene-referred (filmic)
          plugins/imageio/format/avif/bpp=8
          plugins/imageio/format/avif/color_mode=false
          plugins/imageio/format/avif/compression_type=1
          plugins/imageio/format/avif/quality=90
          plugins/imageio/format/avif/tiling=true
          plugins/imageio/format/exr/bpp=32
          plugins/imageio/format/exr/compression=4
          plugins/imageio/format/j2k/preset=
          plugins/imageio/format/j2k/quality=95
          plugins/imageio/format/jpeg/quality=95
          plugins/imageio/format/jpeg/subsample=
          plugins/imageio/format/jxl/bpp=8
          plugins/imageio/format/jxl/effort=7
          plugins/imageio/format/jxl/original=false
          plugins/imageio/format/jxl/pixel_type=false
          plugins/imageio/format/jxl/quality=95
          plugins/imageio/format/jxl/tier=0
          plugins/imageio/format/pdf/border=0 mm
          plugins/imageio/format/pdf/bpp=8
          plugins/imageio/format/pdf/compression=1
          plugins/imageio/format/pdf/dpi=300,000000
          plugins/imageio/format/pdf/icc=
          plugins/imageio/format/pdf/mode=
          plugins/imageio/format/pdf/orientation=
          plugins/imageio/format/pdf/pages=
          plugins/imageio/format/pdf/rotate=
          plugins/imageio/format/pdf/size=a4
          plugins/imageio/format/pdf/title=
          plugins/imageio/format/png/bpp=8
          plugins/imageio/format/png/compression=5
          plugins/imageio/format/tiff/bpp=8
          plugins/imageio/format/tiff/compress=2
          plugins/imageio/format/tiff/compresslevel=6
          plugins/imageio/format/tiff/pixelformat=false
          plugins/imageio/format/tiff/shortfile=false
          plugins/imageio/format/webp/comp_type=0
          plugins/imageio/format/webp/hint=0
          plugins/imageio/format/webp/quality=95
          plugins/imageio/format/xcf/bpp=32
          plugins/imageio/storage/disk/file_directory=$(FILE_FOLDER)/darktable_exported/$(FILE_NAME)
          plugins/imageio/storage/disk/overwrite=
          plugins/imageio/storage/email/client=
          plugins/imageio/storage/export/piwigo/server=
          plugins/imageio/storage/gallery/file_directory=$(HOME)/darktable_gallery/img_$(SEQUENCE)
          plugins/imageio/storage/gallery/title=darktable gallery
          plugins/imageio/storage/gphoto/id=642055548087-n01fgvugnbns7a9jq8jfucjsn5l1t6so.apps.googleusercontent.com
          plugins/imageio/storage/gphoto/secret=o29QcbsDWS5cauRqdmGdF3sP
          plugins/imageio/storage/latex/file_directory=
          plugins/imageio/storage/latex/title=
          plugins/lighttable/1/collect_visible=TRUE
          plugins/lighttable/1/copy_history_visible=TRUE
          plugins/lighttable/1/export_visible=TRUE
          plugins/lighttable/1/filmstrip_visible=FALSE
          plugins/lighttable/1/filtering_visible=TRUE
          plugins/lighttable/1/geotagging_visible=TRUE
          plugins/lighttable/1/image_visible=TRUE
          plugins/lighttable/1/import_visible=TRUE
          plugins/lighttable/1/lua_scripts_installer_visible=TRUE
          plugins/lighttable/1/metadata_view_visible=TRUE
          plugins/lighttable/1/metadata_visible=TRUE
          plugins/lighttable/1/recentcollect_visible=FALSE
          plugins/lighttable/1/select_visible=TRUE
          plugins/lighttable/1/styles_visible=TRUE
          plugins/lighttable/1/tagging_visible=TRUE
          plugins/lighttable/1/timeline_visible=TRUE
          plugins/lighttable/audio_player=aplay
          plugins/lighttable/base_layout=1
          plugins/lighttable/collect/expanded=FALSE
          plugins/lighttable/collect/history0=
          plugins/lighttable/collect/history1=
          plugins/lighttable/collect/history2=
          plugins/lighttable/collect/history3=
          plugins/lighttable/collect/history4=
          plugins/lighttable/collect/history5=
          plugins/lighttable/collect/history6=
          plugins/lighttable/collect/history7=
          plugins/lighttable/collect/history8=
          plugins/lighttable/collect/history9=
          plugins/lighttable/collect/history_hide=false
          plugins/lighttable/collect/history_max=10
          plugins/lighttable/collect/history_pos0=1
          plugins/lighttable/collect/item0=0
          plugins/lighttable/collect/item1=0
          plugins/lighttable/collect/item2=0
          plugins/lighttable/collect/item3=0
          plugins/lighttable/collect/item4=0
          plugins/lighttable/collect/item5=0
          plugins/lighttable/collect/item6=0
          plugins/lighttable/collect/item7=0
          plugins/lighttable/collect/item8=0
          plugins/lighttable/collect/item9=0
          plugins/lighttable/collect/mode0=0
          plugins/lighttable/collect/mode1=0
          plugins/lighttable/collect/mode2=0
          plugins/lighttable/collect/mode3=0
          plugins/lighttable/collect/mode4=0
          plugins/lighttable/collect/mode5=0
          plugins/lighttable/collect/mode6=0
          plugins/lighttable/collect/mode7=0
          plugins/lighttable/collect/mode8=0
          plugins/lighttable/collect/mode9=0
          plugins/lighttable/collect/mode99999=
          plugins/lighttable/collect/num_rules=1
          plugins/lighttable/collect/single-click=false
          plugins/lighttable/collect/string0=%
          plugins/lighttable/collect/string1=
          plugins/lighttable/collect/string2=
          plugins/lighttable/collect/string3=
          plugins/lighttable/collect/string4=
          plugins/lighttable/collect/string5=
          plugins/lighttable/collect/string6=
          plugins/lighttable/collect/string7=
          plugins/lighttable/collect/string8=
          plugins/lighttable/collect/string9=
          plugins/lighttable/collect/windowheight=500
          plugins/lighttable/copy_history/expanded=FALSE
          plugins/lighttable/copy_history/pastemode=0
          plugins/lighttable/copy_metadata/colors=
          plugins/lighttable/copy_metadata/geotags=
          plugins/lighttable/copy_metadata/metadata=
          plugins/lighttable/copy_metadata/pastemode=
          plugins/lighttable/copy_metadata/rating=
          plugins/lighttable/copy_metadata/tags=
          plugins/lighttable/culling_last_id=-1
          plugins/lighttable/culling_num_images=2
          plugins/lighttable/culling_zoom_mode=0
          plugins/lighttable/draw_group_borders=true
          plugins/lighttable/export/ask_before_export_overwrite=true
          plugins/lighttable/export/dimensions_type=0
          plugins/lighttable/export/expanded=FALSE
          plugins/lighttable/export/export_masks=FALSE
          plugins/lighttable/export/force_lcms2=false
          plugins/lighttable/export/format_name=jpeg
          plugins/lighttable/export/height=0
          plugins/lighttable/export/high_quality_processing=false
          plugins/lighttable/export/iccintent=-1
          plugins/lighttable/export/iccprofile=
          plugins/lighttable/export/icctype=-1
          plugins/lighttable/export/pixel_interpolator=lanczos3
          plugins/lighttable/export/pixel_interpolator_warp=bicubic
          plugins/lighttable/export/print_dpi=300
          plugins/lighttable/export/resizing_factor=
          plugins/lighttable/export/storage_name=disk
          plugins/lighttable/export/style=
          plugins/lighttable/export/style_append=
          plugins/lighttable/export/upscale=
          plugins/lighttable/export/width=0
          plugins/lighttable/extended_pattern=$(FILE_NAME).$(FILE_EXTENSION)$(NL)$(EXIF_EXPOSURE) • f/$(EXIF_APERTURE) • $(EXIF_FOCAL_LENGTH)mm • $(EXIF_ISO) ISO $(SIDECAR_TXT)
          plugins/lighttable/filtering/expanded=FALSE
          plugins/lighttable/filtering/history_max=10
          plugins/lighttable/filtering/item0=32
          plugins/lighttable/filtering/item1=18
          plugins/lighttable/filtering/item2=33
          plugins/lighttable/filtering/lastsort=
          plugins/lighttable/filtering/lastsortorder=
          plugins/lighttable/filtering/mode0=0
          plugins/lighttable/filtering/mode1=0
          plugins/lighttable/filtering/mode2=0
          plugins/lighttable/filtering/num_rules=3
          plugins/lighttable/filtering/num_sort=1
          plugins/lighttable/filtering/off0=0
          plugins/lighttable/filtering/off1=0
          plugins/lighttable/filtering/off2=0
          plugins/lighttable/filtering/sort0=0
          plugins/lighttable/filtering/sort_history_max=10
          plugins/lighttable/filtering/sortorder0=
          plugins/lighttable/filtering/string0=%
          plugins/lighttable/filtering/string1=
          plugins/lighttable/filtering/string2=%%
          plugins/lighttable/filtering/top0=1
          plugins/lighttable/filtering/top1=1
          plugins/lighttable/filtering/top2=1
          plugins/lighttable/geotagging/expanded=FALSE
          plugins/lighttable/geotagging/heighttracklist=50
          plugins/lighttable/geotagging/tz=UTC
          plugins/lighttable/hide_default_presets=false
          plugins/lighttable/image/expanded=FALSE
          plugins/lighttable/images_in_row=5
          plugins/lighttable/import/expanded=FALSE
          plugins/lighttable/layout=1
          plugins/lighttable/live_view/overlay_imgid=
          plugins/lighttable/live_view/overlay_mode=
          plugins/lighttable/live_view/splitline=
          plugins/lighttable/lua_scripts_installer/expanded=FALSE
          plugins/lighttable/metadata/creator_flag=4
          plugins/lighttable/metadata/creator_text_height=1
          plugins/lighttable/metadata/description_flag=4
          plugins/lighttable/metadata/description_text_height=1
          plugins/lighttable/metadata/expanded=FALSE
          plugins/lighttable/metadata/image id_flag=4
          plugins/lighttable/metadata/notes_flag=4
          plugins/lighttable/metadata/notes_text_height=1
          plugins/lighttable/metadata/publisher_flag=4
          plugins/lighttable/metadata/publisher_text_height=1
          plugins/lighttable/metadata/rights_flag=4
          plugins/lighttable/metadata/rights_text_height=1
          plugins/lighttable/metadata/title_flag=4
          plugins/lighttable/metadata/title_text_height=1
          plugins/lighttable/metadata/version name_flag=5
          plugins/lighttable/metadata/version name_text_height=1
          plugins/lighttable/metadata_view/expanded=FALSE
          plugins/lighttable/metadata_view/pretty_location=true
          plugins/lighttable/metadata_view/visible=
          plugins/lighttable/metadata_view/windowheight=1000
          plugins/lighttable/overlay_timeout=3
          plugins/lighttable/overlays/0/0=0
          plugins/lighttable/overlays/0/1=1
          plugins/lighttable/overlays/0/2=4
          plugins/lighttable/overlays/1/0=0
          plugins/lighttable/overlays/1/1=1
          plugins/lighttable/overlays/1/2=1
          plugins/lighttable/overlays/2/0=0
          plugins/lighttable/overlays/2/1=1
          plugins/lighttable/overlays/2/2=4
          plugins/lighttable/overlays/culling/0=6
          plugins/lighttable/overlays/culling/1=6
          plugins/lighttable/preset/ask_before_delete_preset=true
          plugins/lighttable/preview/max_in_memory_images=4
          plugins/lighttable/recentcollect/expanded=FALSE
          plugins/lighttable/recentcollect/hide=true
          plugins/lighttable/recentcollect/line0=
          plugins/lighttable/recentcollect/line1=
          plugins/lighttable/recentcollect/line2=
          plugins/lighttable/recentcollect/line3=
          plugins/lighttable/recentcollect/line4=
          plugins/lighttable/recentcollect/line5=
          plugins/lighttable/recentcollect/line6=
          plugins/lighttable/recentcollect/line7=
          plugins/lighttable/recentcollect/line8=
          plugins/lighttable/recentcollect/line9=
          plugins/lighttable/recentcollect/max_items=10
          plugins/lighttable/recentcollect/num_items=0
          plugins/lighttable/recentcollect/windowheight=1000
          plugins/lighttable/select/expanded=FALSE
          plugins/lighttable/style/applymode=
          plugins/lighttable/style/ask_before_delete_style=true
          plugins/lighttable/style/windowheight=400
          plugins/lighttable/styles/expanded=FALSE
          plugins/lighttable/tagging/ask_before_delete_tag=true
          plugins/lighttable/tagging/case_sensitivity=insensitive
          plugins/lighttable/tagging/confidence=50
          plugins/lighttable/tagging/dttags=false
          plugins/lighttable/tagging/expanded=FALSE
          plugins/lighttable/tagging/heightattachedwindow=100
          plugins/lighttable/tagging/heightdictionarywindow=200
          plugins/lighttable/tagging/hidehierarchy=false
          plugins/lighttable/tagging/listsortedbycount=false
          plugins/lighttable/tagging/nb_recent_tags=20
          plugins/lighttable/tagging/no_uncategorized=false
          plugins/lighttable/tagging/nosuggestion=false
          plugins/lighttable/tagging/recent_tags=
          plugins/lighttable/tagging/treeview=false
          plugins/lighttable/thumbnail_hq_min_level=720p
          plugins/lighttable/thumbnail_raw_min_level=never
          plugins/lighttable/thumbnail_sizes=120|400
          plugins/lighttable/thumbnail_tooltip_pattern=<b>$(FILE_NAME).$(FILE_EXTENSION)</b>$(NL)$(EXIF.DATE.REGIONAL) $(EXIF.TIME.REGIONAL)$(NL)$(EXIF_EXPOSURE) • f/$(EXIF_APERTURE) • $(EXIF_FOCAL_LENGTH) mm • $(EXIF_ISO) ISO
          plugins/lighttable/timeline/last_zoom=0
          plugins/lighttable/tooltips/0/0=true
          plugins/lighttable/tooltips/0/1=true
          plugins/lighttable/tooltips/0/2=false
          plugins/lighttable/tooltips/1/0=TRUE
          plugins/lighttable/tooltips/1/1=TRUE
          plugins/lighttable/tooltips/1/2=true
          plugins/lighttable/tooltips/2/0=true
          plugins/lighttable/tooltips/2/1=true
          plugins/lighttable/tooltips/2/2=false
          plugins/lighttable/tooltips/culling/0=false
          plugins/lighttable/tooltips/culling/1=false
          plugins/map/epsilon_factor=25
          plugins/map/filter_images_drawn=false
          plugins/map/geotagging_search_url=https://nominatim.openstreetmap.org/search?q=%s&format=xml&limit=%d&polygon_text=1
          plugins/map/images_thumbnail=thumbnail
          plugins/map/locationshape=
          plugins/map/map_source=OpenStreetMap I
          plugins/map/max_images_drawn=100
          plugins/map/max_outline_nodes=10000
          plugins/map/min_images_per_group=1
          plugins/map/show_map_osd=true
          plugins/map/show_outline=true
          plugins/map/showalllocations=FALSE
          plugins/midi/devices=
          plugins/print/print/black_point_compensation=TRUE
          plugins/print/print/bottom_margin=17,000000
          plugins/print/print/grid_size=10,000000
          plugins/print/print/iccintent=
          plugins/print/print/iccprofile=
          plugins/print/print/icctype=-1
          plugins/print/print/left_margin=17,000000
          plugins/print/print/lock_borders=
          plugins/print/print/medium=Plain paper
          plugins/print/print/paper=A4
          plugins/print/print/printer=Drucker
          plugins/print/print/right_margin=17,000000
          plugins/print/print/style=
          plugins/print/print/style_append=
          plugins/print/print/top_margin=17,000000
          plugins/print/print/unit=mm
          plugins/print/printer/iccintent=
          plugins/print/printer/iccprofile=
          plugins/print/printer/icctype=-1
          plugins/pwstorage/pwstorage_backend=none
          plugins/session/jobcode=capture job
          pressure_sensitivity=off
          preview_downsampling=to 1/2
          rating_one_double_tap=false
          resource_default=512 8 128 700
          resource_large=700 16 128 900
          resource_small=128 4 64 400
          resource_unrestricted=16384 1024 128 900
          resourcelevel=large
          run_crawler_on_start=false
          screen_dpi_overwrite=-1,000000
          second_window/iso_12646=
          second_window/last_visible=FALSE
          send_to_trash=true
          session/base_directory_pattern=$(PICTURES_FOLDER)/Darktable
          session/filename_pattern=$(YEAR)$(MONTH)$(DAY)_$(SEQUENCE).$(FILE_EXTENSION)
          session/sub_directory_pattern=$(YEAR)$(MONTH)$(DAY)_$(JOBCODE)
          session/use_filename=false
          show_folder_levels=1
          slideshow/ui/panel_collaps_state=1
          slideshow/ui/panels_collapse_controls=false
          slideshow_delay=5
          storage/piwigo/conflict=0
          storage/piwigo/last_album=
          storage/piwigo/overwrite=0
          themes/usercss=true
          ui/detect_mono_exif=false
          ui/hide_tooltips=
          ui/performance=false
          ui/show_focus_peaking=FALSE
          ui/style/preview_size=250
          ui_last/color/display2_filename=
          ui_last/color/display2_intent=0
          ui_last/color/display2_type=19
          ui_last/color/display_filename=
          ui_last/color/display_intent=0
          ui_last/color/display_type=8
          ui_last/color/histogram_filename=
          ui_last/color/histogram_type=1
          ui_last/color/mode=0
          ui_last/color/softproof_filename=
          ui_last/color/softproof_intent=0
          ui_last/color/softproof_type=1
          ui_last/colorpicker_display_samples=false
          ui_last/colorpicker_large=false
          ui_last/colorpicker_mode=mean
          ui_last/colorpicker_model=RGB
          ui_last/colorpicker_restrict_histogram=false
          ui_last/display_profile_source=all
          ui_last/expander_histogram=-1
          ui_last/expander_history=-1
          ui_last/expander_import=false
          ui_last/expander_metadata=0
          ui_last/expander_navigation=-1
          ui_last/expander_snapshots=-1
          ui_last/fullscreen=FALSE
          ui_last/grouping=false
          ui_last/ignore_exif_rating=false
          ui_last/import_apply_metadata=false
          ui_last/import_datetime_override=
          ui_last/import_dialog_height=600
          ui_last/import_dialog_paned_places_pos=150
          ui_last/import_dialog_paned_pos=0
          ui_last/import_dialog_show_home=true
          ui_last/import_dialog_show_mounted=true
          ui_last/import_dialog_show_pictures=true
          ui_last/import_dialog_width=800
          ui_last/import_ignore_nonraws=false
          ui_last/import_initial_rating=1
          ui_last/import_jobcode=no_name
          ui_last/import_keep_open=false
          ui_last/import_last_creator=
          ui_last/import_last_description=
          ui_last/import_last_directory=
          ui_last/import_last_folder_descending=false
          ui_last/import_last_image id=
          ui_last/import_last_notes=
          ui_last/import_last_publisher=
          ui_last/import_last_rights=
          ui_last/import_last_root=
          ui_last/import_last_tags=
          ui_last/import_last_tags_imported=true
          ui_last/import_last_title=
          ui_last/import_last_version name=
          ui_last/import_recursive=false
          ui_last/import_select_new=true
          ui_last/maximized=TRUE
          ui_last/modulegroups_dialog_height=700
          ui_last/modulegroups_dialog_width=1100
          ui_last/no_april1st=true
          ui_last/panel_bottom=0
          ui_last/panel_left=-1
          ui_last/panel_right=-1
          ui_last/panel_top=0
          ui_last/preferences_dialog_height=700
          ui_last/preferences_dialog_width=1100
          ui_last/session_expander_import=false
          ui_last/shortcuts_dialog_height=700
          ui_last/shortcuts_dialog_width=1100
          ui_last/styles_create_duplicate=
          ui_last/theme=darktable
          ui_last/view=0
          ui_last/window_h=1354
          ui_last/window_w=2516
          ui_last/window_x=2582
          ui_last/window_y=22
          use_system_font=TRUE
          write_sidecar_files=never
        '';
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
