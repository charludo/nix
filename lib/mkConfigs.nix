{
  lib,
  pkgsFor,
  inputs,
  outputs,
  ...
}:
let
  private-settings = import ../private-settings/settings.nix { inherit lib; };
  secrets = import ../private-settings/secrets.nix { inherit lib; };
  pkgs = pkgsFor."x86_64-linux";
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
          pkgs
          private-settings
          secrets
          ;
      };
      home-manager.sharedModules = [
        inputs.agenix.homeManagerModules.default
        inputs.agenix-rekey.homeManagerModules.default
        inputs.nix-colors.homeManagerModules.colorScheme
        inputs.nixvim.homeModules.nixvim
        inputs.plasma-manager.homeModules.plasma-manager
      ]
      ++ (builtins.attrValues outputs.homeModules);
    }
  ];

  nixos = hostname: enableHomeManager: extraModules: {
    name = hostname;
    value = lib.nixosSystem {
      modules = [
        outputs.nixosModules.common
        inputs.agenix.nixosModules.default
        inputs.agenix-rekey.nixosModules.default
        inputs.snow.nixosModules.default

        # Ensures we use pkgs.ours as well here
        { nixpkgs.pkgs = pkgs; }
      ]
      ++ (builtins.attrValues outputs.nixosModules)
      ++ [ ../hosts/${hostname} ]
      ++ lib.optionals enableHomeManager homeModulesForOsConfig
      ++ extraModules;
      specialArgs = {
        inherit
          inputs
          outputs
          lib
          private-settings
          secrets
          ;
      };
    };
  };

  vms =
    vmPath:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = lib.nixosSystem {
          modules = [
            outputs.nixosModules.common
            inputs.agenix.nixosModules.default
            inputs.agenix-rekey.nixosModules.default
            inputs.snow.nixosModules.default
            inputs.home-manager.nixosModules.home-manager

            # Ensures we use pkgs.ours as well here
            { nixpkgs.pkgs = pkgs; }

            inputs.nixos-generators.nixosModules.all-formats
            "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
            "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"

            ../vms/${name}.nix
            ../modules/vms
            ../hosts/common
            ../users/paki/user.nix
          ]
          ++ (builtins.attrValues outputs.nixosModules);
          specialArgs = {
            inherit
              inputs
              outputs
              lib
              private-settings
              secrets
              ;
          };
        };
      }) (lib.helpers.allVMNames vmPath)
    );

  satellite = hostname: {
    name = hostname;
    value = lib.nixosSystem {
      modules = [
        outputs.nixosModules.common
        inputs.agenix.nixosModules.default
        inputs.agenix-rekey.nixosModules.default
        inputs.snow.nixosModules.default

        # Ensures we use pkgs.ours as well here, and for the correct architecture
        { nixpkgs.pkgs = pkgsFor."aarch64-linux"; }
        { networking.hostName = hostname; }

        "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

        ../hosts/common
        ../users/paki/user.nix
      ]
      ++ (builtins.attrValues outputs.nixosModules)
      ++ [ ../home-assistant/satellite ];
      specialArgs = {
        inherit
          inputs
          outputs
          lib
          private-settings
          secrets
          ;
      };
    };
  };

  home = username: hostname: extraModules: {
    name = "${username}@${hostname}";
    value = lib.homeManagerConfiguration {
      modules = [
        outputs.homeModules.common
        inputs.agenix.homeManagerModules.default
        inputs.agenix-rekey.homeManagerModules.default
        inputs.nix-colors.homeManagerModules.colorScheme
        inputs.nixvim.homeModules.nixvim
      ]
      ++ (builtins.attrValues outputs.homeModules)
      ++ [ ../users/${username}/home/${hostname}.nix ]
      ++ extraModules;
      inherit pkgs;
      extraSpecialArgs = {
        inherit
          inputs
          outputs
          lib
          private-settings
          secrets
          ;
      };
    };
  };
}
