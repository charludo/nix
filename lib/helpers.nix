{ lib, ... }:
rec {
  mkImports = dir: lib.filesystem.listFilesRecursive dir;
  mkImportsNoDefault = dir: lib.filter (f: baseNameOf f != "default.nix") (mkImports dir);

  toLowercaseKeys =
    attrs:
    lib.listToAttrs (
      lib.mapAttrsToList (key: value: {
        name = lib.toLower (builtins.head (builtins.match "^[^-]*-(.*)" key));
        inherit value;
      }) attrs
    );
  allVMSSHConfigs = toLowercaseKeys (
    builtins.mapAttrs (_: vm: { HostName = vm.networking.address; }) (
      lib.filterAttrs (
        name: _: lib.pathExists ../vms/keys/ssh_host_${name}_ed25519_key.pub
      ) lib.mkConfigs.vmSpecs
    )
  );

  allVMNames =
    path:
    map (f: lib.removeSuffix ".nix" f) (
      builtins.attrNames (
        builtins.readDir (
          builtins.filterSource (path: type: type != "directory" && baseNameOf path != ".nix") path
        )
      )
    );
}
