{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  nixosModules.common = import ../modules/nixos;
  homeModules.common = import ../modules/home-manager;

  private-settings = import ../private-settings/settings.nix { inherit lib; };
  secrets = import ../private-settings/secrets.nix { inherit lib; };
in
rec {
  homeModulesForOsConfig = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.extraSpecialArgs = {
        inherit
          inputs
          outputs
          lib
          private-settings
          secrets
          ;
      };
      home-manager.sharedModules = [
        homeModules.common
        {
          imports = [
            inputs.agenix.homeManagerModules.default
            inputs.agenix-rekey.homeManagerModules.default
            inputs.nix-colors.homeManagerModules.colorScheme
            inputs.nixvim.homeManagerModules.nixvim
            inputs.plasma-manager.homeManagerModules.plasma-manager
          ];
        }
      ] ++ (builtins.attrValues homeModules);
    }
  ];

  nixos = hostname: enableHomeManager: extraModules: {
    name = hostname;
    value = lib.nixosSystem {
      modules =
        [
          nixosModules.common
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
          inputs.snow.nixosModules.default
        ]
        ++ (builtins.attrValues nixosModules)
        ++ [ ../hosts/${hostname} ]
        ++ lib.optionals enableHomeManager homeModulesForOsConfig
        ++ extraModules;
      specialArgs = {
        inherit
          lib
          inputs
          outputs
          private-settings
          secrets
          ;
      };
    };
  };

  vms =
    vmPath:
    builtins.listToAttrs (
      builtins.map
        (name: {
          inherit name;
          value = lib.nixosSystem {
            modules = [
              nixosModules.common
              inputs.agenix.nixosModules.default
              inputs.agenix-rekey.nixosModules.default
              inputs.snow.nixosModules.default

              inputs.nixos-generators.nixosModules.all-formats
              "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
              "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"

              ../vms/${name}.nix
              ../modules/vms
              ../hosts/common
              ../users/paki/user.nix
            ] ++ (builtins.attrValues nixosModules);
            specialArgs = {
              inherit
                lib
                inputs
                outputs
                private-settings
                secrets
                ;
            };
          };
        })
        (
          builtins.filter (name: builtins.substring 0 3 name == "SRV" || builtins.substring 0 2 name == "CL")
            (
              builtins.map builtins.head (
                builtins.map (lib.splitString ".") (builtins.attrNames (builtins.readDir vmPath))
              )
            )
        )
    );

  home = username: hostname: extraModules: {
    name = "${username}@${hostname}";
    value = lib.homeManagerConfiguration {
      modules =
        [
          homeModules.common
          inputs.agenix.homeManagerModules.default
          inputs.agenix-rekey.homeManagerModules.default
          inputs.nix-colors.homeManagerModules.colorScheme
          inputs.nixvim.homeManagerModules.nixvim
        ]
        ++ (builtins.attrValues homeModules)
        ++ [ ../users/${username}/home/${hostname}.nix ]
        ++ extraModules;
      inherit pkgs;
      extraSpecialArgs = {
        inherit
          lib
          inputs
          outputs
          private-settings
          secrets
          ;
      };
    };
  };
}
