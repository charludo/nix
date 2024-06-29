{ inputs, ... }:
let
  inherit (inputs.private-settings) gsv;
in
{
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    relayIP = gsv.ip;
  };
}
