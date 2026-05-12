{
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  age.secrets.gsv-cabbage.rekeyFile = secrets.gsv-cabbage;

  services.cabbage = {
    enable = true;
    package = pkgs.ours.cabbage;
    hostname = "cabbage.${private-settings.domains.blog}";
    appName = "cabbage.meet";
    environmentFile = config.age.secrets.gsv-cabbage.path;

    nginx = {
      forceSSL = true;
      enableACME = true;
    };

    adminNotificationEmail = "cabbage@mail.${private-settings.domains.blog}";
  };
}
