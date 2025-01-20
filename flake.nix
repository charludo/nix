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

    musnix = { url = "github:musnix/musnix"; };
    conduwuit = { url = "github:girlbossceo/conduwuit"; };

    private-settings.url = "git+ssh://git@github.com/charludo/nix-private";
    personal-site.url = "git+ssh://git@github.com/charludo/personal-site";
    blog-site.url = "git+ssh://git@github.com/charludo/barely-website";
    eso-reshade.url = "git+ssh://git@github.com/charludo/eso-reshade";
    idagio.url = "git+ssh://git@github.com/charludo/IDAGIO-Downloader-Rust-ver";
  };

  outputs = { self, nixpkgs, home-manager, nixos-generators, jovian, private-settings, ... } @ inputs:
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
      nixosModules = (import ./modules/nixos) // jovian.outputs.nixosModules // private-settings-module;
      homeModules = (import ./modules/home-manager) // private-settings-module;
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

        # ---
        # VMs
        # ---

        # Graphical Remote
        CL-NIX-1 = lib.nixosSystem {
          modules = [ ./vms/CL-NIX-1.nix ];
          specialArgs = { inherit inputs outputs; };
        };
        CL-NIX-3 = lib.nixosSystem {
          modules = [ ./vms/CL-NIX-3.nix ];
          specialArgs = { inherit inputs outputs; };
        };
        CL-ROU = lib.nixosSystem {
          modules = [ ./vms/CL-ROU.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Adblocking
        SRV-BLOCKY = lib.nixosSystem {
          modules = [ ./vms/SRV-BLOCKY.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Paperless-NGX
        SRV-PAPERLESS = lib.nixosSystem {
          modules = [ ./vms/SRV-PAPERLESS.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Immich
        SRV-IMMICH = lib.nixosSystem {
          modules = [ ./vms/SRV-IMMICH.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Stirling PDF
        SRV-PDF = lib.nixosSystem {
          modules = [ ./vms/SRV-PDF.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # WasteBin (Rust PasteBin)
        SRV-WASTEBIN = lib.nixosSystem {
          modules = [ ./vms/SRV-WASTEBIN.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Cloud Backup
        SRV-CLOUDSYNC = lib.nixosSystem {
          modules = [ ./vms/SRV-CLOUDSYNC.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Forgejo Git server
        SRV-GIT = lib.nixosSystem {
          modules = [ ./vms/SRV-GIT.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Jellyfin Media Server
        SRV-JELLYFIN = lib.nixosSystem {
          modules = [ ./vms/SRV-JELLYFIN.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Audiobook Server
        SRV-AUDIOBOOKSHELF = lib.nixosSystem {
          modules = [ ./vms/SRV-AUDIOBOOKSHELF.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Kavita Reading Server
        SRV-KAVITA = lib.nixosSystem {
          modules = [ ./vms/SRV-KAVITA.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Mangas
        SRV-SUWAYOMI = lib.nixosSystem {
          modules = [ ./vms/SRV-SUWAYOMI.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Helper for downloading Linux ISOs
        SRV-TORRENTER = lib.nixosSystem {
          modules = [ ./vms/SRV-TORRENTER.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Matrix Server
        SRV-MATRIX = lib.nixosSystem {
          modules = [ ./vms/SRV-MATRIX.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Stateless Home automations
        SRV-HOME = lib.nixosSystem {
          modules = [ ./vms/SRV-HOME.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Vikunja Server
        SRV-VIKUNJA = lib.nixosSystem {
          modules = [ ./vms/SRV-VIKUNJA.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Vaultwarden
        SRV-VAULTWARDEN = lib.nixosSystem {
          modules = [ ./vms/SRV-VAULTWARDEN.nix ];
          specialArgs = { inherit inputs outputs; };
        };

        # Minecraft internal
        SRV-MINECRAFT = lib.nixosSystem {
          modules = [ ./vms/SRV-MINECRAFT.nix ];
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
    };
}
