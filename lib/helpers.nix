{ lib, outputs, ... }:
rec {
  mkImports = dir: lib.filesystem.listFilesRecursive dir;
  mkImportsNoDefault = dir: lib.filter (f: baseNameOf f != "default.nix") (mkImports dir);

  toLowercaseKeys =
    attrs:
    lib.listToAttrs (
      lib.mapAttrsToList (key: value: {
        name = lib.toLower (builtins.head (builtins.match "^[^-]*-(.*)" key));
        value = value;
      }) attrs
    );
  allVMSSHConfigs = toLowercaseKeys (
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

  allVMNames =
    path:
    builtins.map (f: lib.removeSuffix ".nix" f) (
      builtins.attrNames (
        builtins.readDir (
          builtins.filterSource (path: type: type != "directory" && baseNameOf path != ".nix") path
        )
      )
    );
}
