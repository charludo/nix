{
  description = "Pakihöhle <3";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.4.1";

    mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    musnix = {
      url = "github:musnix/musnix";
    };
    conduwuit = {
      url = "github:girlbossceo/conduwuit";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    private-settings.url = "git+ssh://git@github.com/charludo/nix-private";
    personal-site.url = "git+ssh://git@github.com/charludo/personal-site";
    blog-site.url = "git+ssh://git@github.com/charludo/barely-website";
    eso-reshade.url = "git+ssh://git@github.com/charludo/eso-reshade";
    idagio.url = "git+ssh://git@github.com/charludo/IDAGIO-Downloader-Rust-ver";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      jovian,
      private-settings,
      musnix,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib // home-manager.lib;

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      private-settings-module = {
        config = {
          _module.args.private-settings = private-settings;
          _module.args.secrets = private-settings.secrets;
        };
      };
    in
    {
      inherit lib;
      nixosModules =
        (import ./modules/nixos)
        // jovian.outputs.nixosModules
        // musnix.nixosModules
        // private-settings-module;
      homeModules = (import ./modules/home-manager) // private-settings-module;
      overlays = import ./overlays { inherit inputs outputs; };

      # Available through 'nixos-rebuild --flake .#hostname'
      nixosConfigurations =
        {
          # Desktop
          hub = lib.nixosSystem {
            modules = [ ./hosts/hub ];
            specialArgs = { inherit inputs outputs; };
          };

          # Laptop
          drone = lib.nixosSystem {
            modules = [ ./hosts/drone ];
            specialArgs = { inherit inputs outputs; };
          };

          # Laptop Mallorca
          mallorca = lib.nixosSystem {
            modules = [ ./hosts/mallorca ];
            specialArgs = { inherit inputs outputs; };
          };

          # Gaming
          excession = lib.nixosSystem {
            modules = [ ./hosts/excession ];
            specialArgs = { inherit inputs outputs; };
          };

          # Gaming Mk II
          steamdeck = lib.nixosSystem {
            modules = [ ./hosts/steamdeck ];
            specialArgs = { inherit inputs outputs; };
          };

          # nixos-rebuild switch --flake ".#gsv" --target-host gsv
          gsv = lib.nixosSystem {
            modules = [ ./hosts/gsv ];
            specialArgs = { inherit inputs outputs; };
          };
        }
        //
        # VMs
        builtins.listToAttrs (
          builtins.map
            (name: {
              inherit name;
              value = lib.nixosSystem {
                modules = [ ./vms/${name}.nix ];
                specialArgs = { inherit inputs outputs; };
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

      # Available through 'home-manager --flake .#username@hostname'
      homeConfigurations = {
        "charlotte@hub" = lib.homeManagerConfiguration {
          modules = [ ./users/charlotte/home/hub.nix ];
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs outputs; };
        };

        "charlotte@drone" = lib.homeManagerConfiguration {
          modules = [ ./users/charlotte/home/drone.nix ];
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs outputs; };
        };

        "charlotte@excession" = lib.homeManagerConfiguration {
          modules = [ ./users/charlotte/home/excession.nix ];
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs outputs; };
        };

        "charlotte@mallorca" = lib.homeManagerConfiguration {
          modules = [ ./users/charlotte/home/mallorca.nix ];
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs outputs; };
        };
      };

      # Available through 'nix develop ".#shellname"'
      devShells.${system} = {
        keyctl = (import ./shells/keyctl { inherit pkgs; });
        vmctl = (import ./shells/vmctl { inherit pkgs; });
        remux = (import ./shells/remux { inherit pkgs lib; });
        default = (import ./shells { inherit pkgs; });
      };

      formatter.${system} = pkgs.treefmt;
    };
}
