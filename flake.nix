{
  description = "Pakihöhle <3";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snow = {
      url = "git+ssh://git@github.com/charludo/snow";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    authentik = {
      url = "github:nix-community/authentik-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.4.1";
    musnix.url = "github:musnix/musnix";
    conduwuit.url = "github:girlbossceo/conduwuit";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    personal-site.url = "git+ssh://git@github.com/charludo/personal-site";
    blog-site.url = "git+ssh://git@github.com/charludo/barely-website";
    eso-reshade.url = "git+ssh://git@github.com/charludo/eso-reshade";
    idagio.url = "git+ssh://git@github.com/charludo/IDAGIO-Downloader-Rust-ver";
  };

  outputs =
    {
      self,
      nixpkgs,
      agenix,
      agenix-rekey,
      home-manager,
      jovian,
      mailserver,
      musnix,
      nix-colors,
      nix-flatpak,
      nixos-generators,
      nixos-hardware,
      nixvim,
      plasma-manager,
      snow,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      mkLib = nixpkgs: nixpkgs.lib.extend (self: _: import ./lib { lib = self; } // home-manager.lib);
      lib = mkLib inputs.nixpkgs;

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      private-settings = import ./private-settings/settings.nix { inherit lib; };
      secrets = import ./private-settings/secrets.nix { inherit lib; };
    in
    {
      inherit lib;
      nixosModules.common = import ./modules/nixos;
      homeModules.common = import ./modules/home-manager;
      nixvimModules.common = import ./modules/nixvim;
      overlays = import ./overlays { inherit inputs; };

      nixosConfigurations =
        let
          homeModulesForOsConfig = [
            home-manager.nixosModules.home-manager
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
              home-manager.sharedModules =
                [
                  self.homeModules.common
                  {
                    imports = [
                      agenix.homeManagerModules.default
                      agenix-rekey.homeManagerModules.default
                      nix-colors.homeManagerModules.colorScheme
                      nixvim.homeManagerModules.nixvim
                      plasma-manager.homeManagerModules.plasma-manager
                    ];
                  }
                ]
                ++ (builtins.attrValues self.homeModules)
                ++ (builtins.attrValues self.nixvimModules);
            }
          ];

          mkOsConfig = hostname: enableHomeManager: extraModules: {
            name = hostname;
            value = lib.nixosSystem {
              modules =
                [
                  self.nixosModules.common
                  agenix.nixosModules.default
                  agenix-rekey.nixosModules.default
                  snow.nixosModules.default
                ]
                ++ (builtins.attrValues self.nixosModules)
                ++ [ ./hosts/${hostname} ]
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
        in
        lib.listToAttrs [
          (mkOsConfig "hub" true [ nixos-hardware.nixosModules.gigabyte-b550 ])
          (mkOsConfig "excession" true [
            nixos-hardware.nixosModules.gigabyte-b550
            nix-flatpak.nixosModules.nix-flatpak
          ])

          (mkOsConfig "drone" true [ musnix.nixosModules.default ])
          (mkOsConfig "eschaton" true [
            nixos-hardware.nixosModules.asus-battery
            nixos-hardware.nixosModules.common-pc-ssd
            nixos-hardware.nixosModules.common-cpu-intel
          ])
          (mkOsConfig "mallorca" true [ ])
          (mkOsConfig "steamdeck" true [
            nix-flatpak.nixosModules.nix-flatpak
            jovian.outputs.nixosModules.default
          ])

          (mkOsConfig "gsv" true [ mailserver.nixosModules.mailserver ])
        ]
        // builtins.listToAttrs (
          builtins.map
            (name: {
              inherit name;
              value = lib.nixosSystem {
                modules = [
                  self.nixosModules.common
                  agenix.nixosModules.default
                  agenix-rekey.nixosModules.default
                  snow.nixosModules.default

                  nixos-generators.nixosModules.all-formats
                  "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
                  "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"

                  ./vms/${name}.nix
                  ./modules/vms
                  ./hosts/common
                  ./users/paki/user.nix
                ] ++ (builtins.attrValues self.nixosModules);
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
                    builtins.map (lib.splitString ".") (builtins.attrNames (builtins.readDir ./vms))
                  )
                )
            )
        );

      homeConfigurations =
        let
          mkHomeConfig = username: hostname: extraModules: {
            name = "${username}@${hostname}";
            value = lib.homeManagerConfiguration {
              modules =
                [
                  self.homeModules.common
                  self.nixvimModules.common
                  agenix.homeManagerModules.default
                  agenix-rekey.homeManagerModules.default
                  nix-colors.homeManagerModules.colorScheme
                  nixvim.homeManagerModules.nixvim
                ]
                ++ (builtins.attrValues self.homeModules)
                ++ [ ./users/${username}/home/${hostname}.nix ]
                ++ extraModules;
              pkgs = nixpkgs.legacyPackages.${system};
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
        in
        lib.listToAttrs [
          (mkHomeConfig "charlotte" "hub" [ ])
          (mkHomeConfig "charlotte" "excession" [ ])

          (mkHomeConfig "charlotte" "drone" [ ])
          (mkHomeConfig "charlotte" "eschaton" [ ])
          (mkHomeConfig "charlotte" "mallorca" [ ])

          (mkHomeConfig "charlotte" "CL-ROU" [ ])
          (mkHomeConfig "marie" "CL-NIX-1" [ plasma-manager.homeManagerModules.plasma-manager ])
          (mkHomeConfig "marie" "CL-NIX-3" [ plasma-manager.homeManagerModules.plasma-manager ])
        ];

      devShells.${system} = {
        remux = (import ./shells/remux { inherit pkgs lib; });
        default = (import ./shells { inherit pkgs; });
      };

      formatter.${system} = pkgs.treefmt;

      agenix-rekey = agenix-rekey.configure {
        userFlake = self;
        nixosConfigurations = self.nixosConfigurations;
        homeConfigurations = self.homeConfigurations;
        collectHomeManagerConfigurations = true;
      };
    };
}
