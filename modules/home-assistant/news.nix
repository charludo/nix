{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hass.news;

  sortedFeedNames = map (entry: entry.name) (
    lib.sort (a: b: a.order < b.order) (
      lib.mapAttrsToList (name: feed: {
        inherit name;
        inherit (feed) order;
      }) cfg.feeds
    )
  );
in
{
  options.hass.news = {
    feeds = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Podcast RSS feed URL. The fetcher takes the first `.mp3` link it finds";
            };
            volumeAdjust = lib.mkOption {
              type = lib.types.number;
              default = 0.0;
              description = "Relative volume gain applied via ffmpeg after download";
            };
            order = lib.mkOption {
              type = lib.types.int;
              description = "Position in the stitched daily summary";
            };
          };
        }
      );
      default = { };
      description = "News podcast feeds to fetch and stitch into a daily summary";
    };

    directory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hass/www/news";
      description = "Disk location for downloaded episodes and the stitched summary.";
    };

    summaryName = lib.mkOption {
      type = lib.types.str;
      default = "zusammenfassung";
      description = "Filename stem for the stitched summary, without suffix";
    };

    fetchInterval = lib.mkOption {
      type = lib.types.str;
      default = "45min";
      description = "systemd `OnUnitActiveSec` for the fetch timer";
    };

    fetchBootDelay = lib.mkOption {
      type = lib.types.str;
      default = "2min";
      description = "systemd `OnBootSec` for the fetch timer";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      description = "HA host URL the playing Sonos can reach";
    };

    fallbackTarget = lib.mkOption {
      type = lib.types.str;
      description = "`media_player` entity_id used as the default playback target";
    };

    filenames = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Per-feed filenames, relative to `directory`, plus a `summary` key";
    };

    feedOrder = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Feed names sorted by their declared `order`";
    };

    actions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
      readOnly = true;
      description = "Per-feed \"play me\" action sequence";
    };
  };

  config = lib.mkIf (cfg.feeds != { }) {
    hass.news.filenames = lib.mapAttrs (name: _: "${name}.mp3") cfg.feeds // {
      summary = "${cfg.summaryName}.mp3";
    };

    hass.news.feedOrder = sortedFeedNames;

    hass.news.actions =
      let
        mkPlay = filename: [
          {
            action = "media_player.play_media";
            target.entity_id = ''{{ area_to_target.get(preferred_area_id | default("")) or "${cfg.fallbackTarget}" }}'';
            data = {
              media_content_id = "${cfg.baseUrl}/local/news/${filename}";
              media_content_type = "music";
              enqueue = "replace";
            };
          }
        ];
      in
      lib.mapAttrs (name: _: mkPlay "${name}.mp3") cfg.feeds
      // {
        summary = mkPlay "${cfg.summaryName}.mp3";
      };

    systemd.services.fetch-news-podcasts = {
      description = "Download + stitch news podcasts for HA";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hass";
        Group = "hass";
      };
      path = with pkgs; [
        curl
        gnugrep
        coreutils
        ffmpeg-headless
      ];
      script = ''
        set -u
        mkdir -p ${lib.escapeShellArg cfg.directory}

        fetch_raw() {
          local feed="$1"; local out="$2"
          local url
          url=$(curl -fsSL --max-time 15 "$feed" | grep -oE 'https?://[^"]+\.mp3' | head -1)
          [ -n "$url" ] || { echo "No MP3 URL found in $feed" >&2; return 1; }
          echo "Fetching $url -> $out"
          curl -fsSL --retry 3 --max-time 60 -o "$out.tmp.mp3" "$url" && mv "$out.tmp.mp3" "$out"
        }

        fetch_adjusted() {
          local feed="$1"; local out="$2"; local mult="$3"
          local url
          url=$(curl -fsSL --max-time 15 "$feed" | grep -oE 'https?://[^"]+\.mp3' | head -1)
          [ -n "$url" ] || { echo "No MP3 URL found in $feed" >&2; return 1; }
          echo "Fetching $url -> $out (volume × $mult)"
          curl -fsSL --retry 3 --max-time 60 -o "$out.dl" "$url" \
            && ffmpeg -y -loglevel error -i "$out.dl" \
                 -filter:a "volume=$mult" -c:a libmp3lame -b:a 128k "$out.tmp.mp3" \
            && mv "$out.tmp.mp3" "$out" \
            && rm -f "$out.dl"
        }

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: feed:
            let
              out = lib.escapeShellArg "${cfg.directory}/${name}.mp3";
              url = lib.escapeShellArg feed.url;
            in
            if feed.volumeAdjust == 0 then
              "fetch_raw ${url} ${out} || true"
            else
              "fetch_adjusted ${url} ${out} ${toString (1.0 + feed.volumeAdjust)} || true"
          ) cfg.feeds
        )}

        ${lib.optionalString (lib.length sortedFeedNames > 1) (
          let
            files = map (n: "${cfg.directory}/${n}.mp3") sortedFeedNames;
            inputs = lib.concatMapStringsSep " " (f: "-i ${lib.escapeShellArg f}") files;
            filter =
              lib.concatStrings (lib.imap0 (i: _: "[${toString i}:a]") files)
              + "concat=n=${toString (builtins.length files)}:v=0:a=1[out]";
            summary = "${cfg.directory}/${cfg.summaryName}.mp3";
            checks = lib.concatStringsSep " && " (map (f: "[ -f ${lib.escapeShellArg f} ]") files);
          in
          ''
            if ${checks}; then
              ffmpeg -y -loglevel error \
                ${inputs} \
                -filter_complex "${filter}" \
                -map "[out]" -c:a libmp3lame -b:a 128k \
                ${lib.escapeShellArg "${summary}.tmp.mp3"} \
                && mv ${lib.escapeShellArg "${summary}.tmp.mp3"} ${lib.escapeShellArg summary}
            fi
          ''
        )}
      '';
    };

    systemd.timers.fetch-news-podcasts = {
      description = "Periodically fetch news podcast episodes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.fetchBootDelay;
        OnUnitActiveSec = cfg.fetchInterval;
        Persistent = true;
      };
    };
  };
}
