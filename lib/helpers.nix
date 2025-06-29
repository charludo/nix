{ lib, outputs, ... }:
rec {
  mkImports = dir: lib.filesystem.listFilesRecursive dir;
  mkImportsNoDefault = dir: lib.filter (f: baseNameOf f != "default.nix") (mkImports dir);

  toLowercaseKeys =
    attrs:
    lib.listToAttrs (
      lib.mapAttrsToList (key: value: {
        name = lib.toLower (lib.replaceStrings [ "SRV-" ] [ "" ] key);
        value = value;
      }) attrs
    );
  allVMs = toLowercaseKeys (
    lib.filterAttrs (_: v: v.hostname != null) (
      builtins.mapAttrs (name: _: {
        hostname =
          if lib.pathExists ../vms/keys/ssh_host_${name}_ed25519_key.pub then
            let
              interfaces = outputs.nixosConfigurations.${name}.config.networking.interfaces;
              iface = lib.findFirst (i: interfaces ? ${i}) null [
                "ens18"
                "enp6s18"
              ];
            in
            if iface != null then (builtins.head interfaces.${iface}.ipv4.addresses).address else null
          else
            null;
      }) outputs.nixosConfigurations
    )
  );
}
