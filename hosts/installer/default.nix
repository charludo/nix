{ pkgs, ... }:
{
  imports =
    [
      ../common/optional/vmify.nix

      ../common/global/locale.nix
      ../common/global/nix.nix
      ../common/global/openssh.nix
      ../common/optional/nvim.nix
    ];


  environment.systemPackages = [ pkgs.git ];

  system.stateVersion = "23.11";
}
