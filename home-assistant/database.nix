{

  services.home-assistant = {
    extraPackages = python3Packages: [ python3Packages.psycopg2 ];
    config.recorder.db_url = "postgresql://@/hass";
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "hass" ];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
      }
    ];
  };
}
