{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
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
        outputs.homeModules.common
        {
          imports = [
            inputs.agenix.homeManagerModules.default
            inputs.agenix-rekey.homeManagerModules.default
            inputs.nix-colors.homeManagerModules.colorScheme
            inputs.nixvim.homeManagerModules.nixvim
            inputs.plasma-manager.homeManagerModules.plasma-manager
          ];
        }
      ] ++ (builtins.attrValues outputs.homeModules);
    }
  ];

  nixos = hostname: enableHomeManager: extraModules: {
    name = hostname;
    value = lib.nixosSystem {
      modules =
        [
          outputs.nixosModules.common
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
          inputs.snow.nixosModules.default
        ]
        ++ (builtins.attrValues outputs.nixosModules)
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
              outputs.nixosModules.common
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
            ] ++ (builtins.attrValues outputs.nixosModules);
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
          outputs.homeModules.common
          inputs.agenix.homeManagerModules.default
          inputs.agenix-rekey.homeManagerModules.default
          inputs.nix-colors.homeManagerModules.colorScheme
          inputs.nixvim.homeManagerModules.nixvim
        ]
        ++ (builtins.attrValues outputs.homeModules)
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
