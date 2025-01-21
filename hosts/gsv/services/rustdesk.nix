{ private-settings, ... }:
{
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    relayIP = private-settings.gsv.ip;
    extraSignalArgs = [
      "-k"
      "_"
    ];
  };
}
