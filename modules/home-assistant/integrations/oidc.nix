{ pkgs, ... }:
{
  services.home-assistant.customComponents = [
    pkgs.ours.home-assistant.custom-components.auth_oidc
  ];

  services.home-assistant.config.auth_oidc = {
    client_id = "!secret oidc_client_id";
    client_secret = "!secret oidc_client_secret";
    discovery_url = "!secret oidc_discovery_url";
    display_name = "PocketID";

    features = {
      automatic_user_linking = false;
      automatic_person_creation = true;
    };
  };
}
