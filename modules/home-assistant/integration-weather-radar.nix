{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass.weatherRadar;

  # Where the card's DWD endpoint points by default, and the exact string the
  # upstream sources contain (radar-player.ts declares it as a module-level
  # const with no config option, so it can only be reached by patching).
  upstreamBaseUrl = "https://maps.dwd.de";
  wmsPath = "/geoserver/dwd/wms";

  redirected = cfg.wmsBaseUrl != upstreamBaseUrl;

  # Home Assistant registers Lovelace modules as
  #   /local/nixos-lovelace-modules/<pname>.js?<version>
  # and serves them with a month-long max-age. The version is therefore the only
  # cache buster clients ever see, so a content change that leaves it alone is
  # invisible to every browser that already holds the file -- for up to 31 days,
  # through hard reloads, since the card is imported dynamically at runtime.
  #
  # Patching the endpoint changes the content but not the upstream version, so
  # fold the endpoint into the version to keep the two in step.
  endpointSuffix = builtins.substring 0 8 (builtins.hashString "sha256" cfg.wmsBaseUrl);

  package = pkgs.home-assistant-custom-lovelace-modules.weather-radar-card.overrideAttrs (old: {
    # stdenv warns when `version` is overridden without `src`, on the assumption
    # that the intent was to build a different upstream release. Here the intent
    # is the opposite: same source, relabelled so the cache buster moves. This is
    # stdenv's documented opt-out and is stripped before it reaches the builder.
    __intentionallyOverridingVersion = true;
    version = old.version + lib.optionalString redirected "-${endpointSuffix}";

    # Appended rather than replaced: the overlay already rewrites the HACS asset
    # paths, and that fix is independent of which endpoint is in use.
    postPatch =
      (old.postPatch or "")
      + lib.optionalString redirected ''
        grep -rlF "${upstreamBaseUrl}${wmsPath}" src \
          | xargs sed -i "s|${upstreamBaseUrl}${wmsPath}|${cfg.wmsBaseUrl}${wmsPath}|g"
      '';
  });
in
{
  options.hass.weatherRadar = {
    enable = lib.mkEnableOption "the weather-radar-card";

    wmsBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = upstreamBaseUrl;
      example = "https://map-cache.paki.place";
      description = ''
        Scheme and host the card fetches DWD radar tiles from, without a path.

        Point this at a {option}`services.dwd-proxy` instance to get caching.
        Note that the card is browser-side JavaScript, so this URL is resolved
        by each viewing device rather than by Home Assistant: it has to be
        reachable from phones and laptops, not just from the server. That rules
        out `localhost`, and — because a page served over HTTPS may not pull
        subresources over plain HTTP — it effectively rules out a bare LAN
        address too unless Home Assistant itself is served over HTTP.

        Only the WMS endpoint is redirected. The wind overlay uses a WCS
        endpoint on the same host, which the proxy does not accelerate, so it is
        left pointing upstream.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant.customLovelaceModules = [ package ];
  };
}
