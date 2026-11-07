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
  specialArgs = {
    inherit
      inputs
      outputs
      lib
      private-settings
      secrets
      ;
  };
in
rec {
  homeModulesForOsConfig = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
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
      inherit specialArgs;
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

            "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"

            ../vms/${name}.nix
            ../modules/vms
            ../hosts/common
            ../users/paki/user.nix
          ]
          ++ (builtins.attrValues outputs.nixosModules);
          inherit specialArgs;
        };
      }) (lib.helpers.allVMNames vmPath)
    );

  vmSpecs = lib.genAttrs (lib.helpers.allVMNames ../vms) (
    name:
    (lib.evalModules {
      modules = [
        ../modules/vms
        ../vms/${name}.nix
        {
          _module.check = false;
          _module.args = { inherit pkgs; };
        }
      ];
      inherit specialArgs;
    }).config.vm
  );

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
      extraSpecialArgs = specialArgs;
    };
  };
}
