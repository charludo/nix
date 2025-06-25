{
  description = "Pakihöhle <3";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    snow.url = "git+ssh://git@github.com/charludo/snow";
    snow.inputs.nixpkgs.follows = "nixpkgs";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";
    jovian.inputs.nixpkgs.follows = "nixpkgs";

    mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
    mailserver.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix-rekey.url = "github:oddlama/agenix-rekey";
    agenix-rekey.inputs.nixpkgs.follows = "nixpkgs";

    authentik.url = "github:nix-community/authentik-nix";
    authentik.inputs.nixpkgs.follows = "nixpkgs";

    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";

    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";

    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

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
    { self, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;
      system = "x86_64-linux";

      pkgs = nixpkgs.legacyPackages.${system};
      lib = import ./lib { inherit pkgs inputs outputs; };
      packages = pkgs.callPackage ./pkgs { inherit inputs lib; };
    in
    {
      inherit lib;
      overlays = import ./overlays { inherit inputs; };

      nixosConfigurations =
        builtins.listToAttrs [
          (lib.mkConfigs.nixos "hub" true [ inputs.nixos-hardware.nixosModules.gigabyte-b550 ])
          (lib.mkConfigs.nixos "excession" true [
            inputs.nixos-hardware.nixosModules.gigabyte-b550
            inputs.nix-flatpak.nixosModules.nix-flatpak
          ])

          (lib.mkConfigs.nixos "drone" true [ inputs.musnix.nixosModules.default ])
          (lib.mkConfigs.nixos "eschaton" true [
            inputs.nixos-hardware.nixosModules.asus-battery
            inputs.nixos-hardware.nixosModules.common-pc-ssd
            inputs.nixos-hardware.nixosModules.common-cpu-intel
          ])
          (lib.mkConfigs.nixos "mallorca" true [ ])
          (lib.mkConfigs.nixos "steamdeck" true [
            inputs.nix-flatpak.nixosModules.nix-flatpak
            inputs.jovian.outputs.nixosModules.default
          ])

          (lib.mkConfigs.nixos "gsv" true [ inputs.mailserver.nixosModules.mailserver ])
        ]
        // lib.mkConfigs.vms ./vms;

      homeConfigurations = builtins.listToAttrs [
        (lib.mkConfigs.home "charlotte" "hub" [ ])
        (lib.mkConfigs.home "charlotte" "excession" [ ])

        (lib.mkConfigs.home "charlotte" "drone" [ ])
        (lib.mkConfigs.home "charlotte" "eschaton" [ ])
        (lib.mkConfigs.home "charlotte" "mallorca" [ ])

        (lib.mkConfigs.home "charlotte" "CL-ROU" [ ])
        (lib.mkConfigs.home "marie" "CL-NIX-1" [ inputs.plasma-manager.homeManagerModules.plasma-manager ])
        (lib.mkConfigs.home "marie" "CL-NIX-3" [ inputs.plasma-manager.homeManagerModules.plasma-manager ])
      ];

      packages.${system} = packages;

      devShells.${system} = {
        default = pkgs.callPackage ./shells { };
        remux = pkgs.callPackage ./shells/remux.nix { inherit (packages) remux; };
      };

      formatter.${system} = pkgs.treefmt;

      nixvimModules.common = import ./modules/nixvim;
      nixosModules.common = import ./modules/nixos;
      homeModules.common = import ./modules/home-manager;

      agenix-rekey = inputs.agenix-rekey.configure {
        userFlake = self;
        nixosConfigurations = self.nixosConfigurations;
        homeConfigurations = self.homeConfigurations;
        collectHomeManagerConfigurations = true;
      };
    };
}
