{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.bluetooth;
in
{
  options.bluetooth = {
    enable = lib.mkEnableOption "bluetooth config, incl. for keyboard";
  };

  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;

      # Drop once nixpkgs has bluez > 5.87.
      package = pkgs.bluez.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (pkgs.fetchpatch2 {
            name = "a2dp-fix-loading-of-remote-sep-from-cache.patch";
            url = "https://github.com/bluez/bluez/commit/b7d71e5067856b0daf2f1f73b3fc95483236610e.patch";
            hash = "sha256-tUWZEQ/AY1X6C5iqC8MEk/ZnryRU/1F+48JXRRS7VDk=";
          })
          (pkgs.fetchpatch2 {
            name = "audio-fix-stale-avdtp-connecting-state.patch";
            url = "https://github.com/bluez/bluez/commit/eda4262191ba00ab6912f54c86c2cdacc2f8b8d9.patch";
            hash = "sha256-XETLithpJ+XxZwpa0OAg+m4bB9swl39D7gzmnxqB95c=";
          })
          (pkgs.fetchpatch2 {
            name = "a2dp-fix-crash-on-null-stream-in-transport-cb.patch";
            url = "https://github.com/bluez/bluez/commit/0bed9886cff317d814f9b1f11c1461459f2b9a00.patch";
            hash = "sha256-KElh8HRttEWTGwpooezzJs5g0RhLt3eUO+AVj6QmpJM=";
          })
        ];
      });

      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
        };
        Policy = {
          AutoEnable = true;
          ReconnectAttempts = 7;
          ReconnectIntervals = "1,2,4,8,16,32,64";
        };
      };
    };

    services.blueman.enable = true;
    boot.kernelParams = [ "hid_apple.fnmode=2" ];
  };
}
