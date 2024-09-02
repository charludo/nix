{ pkgs, ... }:
{
  services.pcscd.enable = true;
  environment.systemPackages = [ pkgs.eid-mw ];
}
