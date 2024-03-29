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

    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprlock.url = "github:hyprwm/hyprlock";
    hyprpaper.url = "github:hyprwm/hyprpaper";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    private-email.url = "git+ssh://git@github.com/charludo/email";
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs:
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
        # Laptop
        drone = lib.nixosSystem {
          modules = [ ./hosts/drone ];
          specialArgs = { inherit inputs outputs; };
        };
      };

      # Available through 'home-manager --flake .#username@hostname'
      homeConfigurations = {
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
