{
  private-settings,
  secrets,
  ...
}:
{
  fail2ban = {
    enable = true;
    doNotBan = [ private-settings.domains.vpn ];
    secrets = {
      cloudflareToken = secrets.gsv-fail2ban-cf-token;
      cloudflareZones = [
        {
          name = "blog";
          path = secrets.gsv-fail2ban-cf-zone;
        }
        {
          name = "personal";
          path = secrets.gsv-fail2ban-cf-zone-2;
        }
      ];
    };
  };
}
