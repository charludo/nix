{
  config,
  lib,
  pkgs,
  ...
}:
let
  lifecycle =
    pkgs.writers.writePython3Bin "pinchflat-lifecycle"
      { libraries = [ pkgs.python3Packages.mutagen ]; } # python
      ''
        import json
        import sys

        import mutagen

        PROFILES = {
            "Anime Music": {
                "album": "Anime",
                "albumartist": "Various Artists",
            },
            "Japanisch": {
                "album": "Japanisch",
                "albumartist": "Various Artists",
            },
        }


        def main():
            if len(sys.argv) < 3 or sys.argv[1] != "media_downloaded":
                return

            item = json.loads(sys.argv[2])
            path = item.get("media_filepath")
            tags = PROFILES.get(item["source"]["media_profile"]["name"])
            if tags is None or not path:
                return

            audio = mutagen.File(path, easy=True)
            if audio is None:
                sys.exit(f"cannot tag {path}: unsupported file type")

            changed = False
            for tag, value in tags.items():
                if audio.get(tag) != [value]:
                    print(f"{path}: {tag}: {audio.get(tag)} -> [{value!r}]")
                    audio[tag] = value
                    changed = True
            if changed:
                audio.save()


        main()
      '';
in
{
  vm = {
    id = 2216;
    name = "SRV-PINCHFLAT";

    hardware.cores = 2;
    hardware.memory = 8192;
    hardware.storage = "16G";

    certsFor = [
      {
        name = "pinchflat";
        inherit (config.services.pinchflat) port;
        defaultProxySettings = false;
      }
    ];
  };

  services.pinchflat = {
    enable = true;
    selfhosted = true;
    mediaDir = config.nas.location;
  };

  systemd.services.pinchflat = {
    after = [ "media-NAS.mount" ];
    partOf = [ "media-NAS.mount" ];
    serviceConfig.ExecStartPre = [
      "${lib.getExe' pkgs.coreutils "install"} -D -m 0755 ${lib.getExe lifecycle} /var/lib/pinchflat/extras/user-scripts/lifecycle"
    ];
  };

  nas.enable = true;
  nas.extraUsers = [ config.services.pinchflat.user ];

  nas.backup.enable = true;
  rsync."pinchflat" = {
    tasks = [
      {
        from = "/var/lib/pinchflat";
        to = "${config.nas.backup.stateLocation}/pinchflat";
        chown = "pinchflat:pinchflat";
      }
    ];
  };
}
