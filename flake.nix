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

    mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    private-settings.url = "git+ssh://git@github.com/charludo/nix-private";
  };

  outputs = { self, nixpkgs, home-manager, nixos-generators, ... } @ inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib // home-manager.lib;

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      inherit lib;
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;
      overlays = import ./overlays { inherit inputs outputs; };

      # Available through 'nixos-rebuild --flake .#hostname'
      nixosConfigurations = {
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

        # Gaming
        excession = lib.nixosSystem {
          modules = [ ./hosts/excession ];
          specialArgs = { inherit inputs outputs; };
        };

        # nixos-rebuild switch --flake ".#gsv" --target-host gsv
        gsv = lib.nixosSystem {
          modules = [ ./hosts/gsv ];
          specialArgs = { inherit inputs outputs; };
        };

        # Adblocking
        SRV-BLOCKY = lib.nixosSystem {
          modules = [ ./hosts/SRV-BLOCKY ];
          specialArgs = { inherit inputs outputs; };
        };

        # Paperless-NGX
        SRV-PAPERLESS = lib.nixosSystem {
          modules = [ ./hosts/SRV-PAPERLESS ];
          specialArgs = { inherit inputs outputs; };
        };

        # Stirling PDF
        SRV-PDF = lib.nixosSystem {
          modules = [ ./hosts/SRV-PDF ];
          specialArgs = { inherit inputs outputs; };
        };

        # WasteBin (Rust PasteBin)
        SRV-WASTEBIN = lib.nixosSystem {
          modules = [ ./hosts/SRV-WASTEBIN ];
          specialArgs = { inherit inputs outputs; };
        };

        # Graphical Remote
        CL-NIX-3 = lib.nixosSystem {
          modules = [ ./hosts/CL-NIX-3 ];
          specialArgs = { inherit inputs outputs; };
        };

        # Cloud Backup
        SRV-CLOUDSYNC = lib.nixosSystem {
          modules = [ ./hosts/SRV-CLOUDSYNC ];
          specialArgs = { inherit inputs outputs; };
        };

        # Installer (used with nixos-generators install-iso)
        installer = lib.nixosSystem {
          modules = [ ./hosts/installer ];
          specialArgs = { inherit inputs outputs; };
        };
      };

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
      };

      # Available through 'nix develop ".#shellname"'
      devShells.${system} = {
        keyctl = (import ./shells/keyctl { inherit pkgs; });
      };
    };
}
