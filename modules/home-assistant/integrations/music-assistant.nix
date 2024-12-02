{ pkgs, ... }:
let
  panelJs = pkgs.writeText "music-assistant-panel.js" ''
    class MusicAssistantPanel extends HTMLElement {
      set panel(panel) {
        if (this._ready) return;
        this._ready = true;
        Object.assign(this.style, { display: "block", position: "relative", height: "100%" });
        const iframe = document.createElement("iframe");
        iframe.src = panel.config.url;
        Object.assign(iframe.style, { position: "absolute", top: 0, left: 0, width: "100%", height: "100%", border: "none" });
        this.appendChild(iframe);
      }
    }
    customElements.define("music-assistant-panel", MusicAssistantPanel);
  '';
in
{
  services.home-assistant.extraComponents = [
    "music_assistant"
  ];

  systemd.tmpfiles.rules = [
    "d  /var/lib/hass/www                  0755 hass hass -"
    "L+ /var/lib/hass/www/music-assistant-panel.js - - - - ${panelJs}"
  ];

  services.home-assistant.config.panel_custom = [
    {
      name = "music-assistant-panel";
      url_path = "music-assistant";
      sidebar_title = "Music Assistant";
      sidebar_icon = "mdi:music";
      module_url = "/local/music-assistant-panel.js";
      config.url = "http://192.168.24.103:8095";
    }
  ];
}
