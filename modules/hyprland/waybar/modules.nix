{
  config,
  pkgs,
  private-settings,
  ...
}:
let
  curl = "${pkgs.curl}/bin/curl";
  rofi = "${pkgs.rofi-wayland}/bin/rofi";
  librewolf = "${pkgs.librewolf}/bin/librewolf";
  thunderbird = "${pkgs.thunderbird}/bin/thunderbird";
  pavucontrol = "${pkgs.pavucontrol}/bin/pavucontrol";

  # These are created in the scripts folder
  playerctl = "waybar-playerctl";
  wireguard = "waybar-wireguard";
  reddit = "waybar-reddit";
  lemmy = "waybar-lemmy";
  mail = "waybar-mail";
  calendar = "waybar-calendar";
in
{
  clock = {
    format = "{:%a, %d.%m. %H:%M}";
    tooltip = true;
    tooltip-format = "<tt><big>{calendar}</big></tt>";
  };

  "custom/weather" = {
    exec = "${curl} \"wttr.in/${private-settings.locations.home}?format=%c%t\"";
    restart-interval = 600;
    on-click = "${config.home.sessionVariables.TERMINAL} --hold -e ${curl} wttr.in";
  };

  "custom/power" = {
    format = "󰐥";
    on-click = "${rofi} -show power-menu -modi power-menu:rofi-power-menu";
  };

  "custom/playerctl" = {
    format = "{}";
    return-type = "json";
    exec = "${playerctl}";
    restart-interval = 1;
    on-click = "${playerctl} toggle";
  };

  "custom/mail" = {
    exec = "${mail}";
    restart-interval = 300;
    on-click = "${thunderbird}";
  };

  "custom/calendar" = {
    exec = "${calendar}";
    restart-interval = 300;
    on-click = "${thunderbird} --calendar";
  };

  "custom/lemmy" = {
    exec = "${lemmy}";
    restart-interval = 1200;
    on-click = "${librewolf} --new-tab \"${private-settings.lemmyInstance}/inbox\"";
  };

  "custom/reddit" = {
    exec = "${reddit}";
    restart-interval = 1200;
    on-click = "${librewolf} --new-tab \"https://www.reddit.com/notifications/\"";
  };

  battery = {
    bat = "BAT0";
    interval = 60;
    states = {
      warning = 30;
      critical = 15;
    };
    format = "{capacity}% {icon} ";
    format-icons = [
      ""
      ""
      ""
      ""
      ""
    ];
    max-length = 25;
  };

  bluetooth = {
    interval = 10;
    format = "󰂱";
    format-disabled = "󰂲";
    format-connected = "󰂯 {device_alias}";
    tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
    tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
    tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
    tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
    on-click = "rfkill toggle bluetooth";
  };

  cpu = {
    interval = 10;
    format = "   {usage}%";
    max-length = 10;
  };

  "cpu#2" = {
    interval = 1;
    format = "{icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7}";
    format-icons = [
      "<span color='#69ff94'>▁</span>"
      "<span color='#2aa9ff'>▂</span>"
      "<span color='#f8f8f2'>▃</span>"
      "<span color='#f8f8f2'>▄</span>"
      "<span color='#ffffa5'>▅</span>"
      "<span color='#ffffa5'>▆</span>"
      "<span color='#ff9977'>▇</span>"
      "<span color='#dd532e'>█</span>"
    ];
  };

  "disk#home" = {
    interval = 30;
    format = "󱂵  {percentage_used}%";
    path = "/";
  };

  "disk#nas" = {
    interval = 30;
    format = "󰣳  {percentage_used}%";
    path = "/media/NAS/";
  };

  memory = {
    interval = 30;
    format = "  {}%";
    max-length = 10;
  };

  "network#wifi" = {
    interface = "wlp10s0";
    format = "{ifname}";
    format-wifi = "   {essid}";
    format-disconnected = "";
    tooltip-format = "{ifname} via {gwaddr} 󰊗";
    tooltip-format-wifi = "{essid} ({signalStrength}%) ";
    tooltip-format-ethernet = "{ifname} ";
    tooltip-format-disconnected = "Disconnected";
    max-length = 50;
    on-click = "nmtui";
  };

  "network#laptop" = {
    interface = "wlp2s0";
    format = "{ifname}";
    format-wifi = "   {essid}";
    format-disconnected = "";
    tooltip-format = "{ifname} via {gwaddr} 󰊗";
    tooltip-format-wifi = "{essid} ({signalStrength}%) ";
    tooltip-format-ethernet = "{ifname} ";
    tooltip-format-disconnected = "Disconnected";
    max-length = 50;
    on-click = "nmtui";
  };

  "network#eschaton" = {
    interface = "wlo1";
    format = "{ifname}";
    format-wifi = "   {essid}";
    format-disconnected = "";
    tooltip-format = "{ifname} via {gwaddr} 󰊗";
    tooltip-format-wifi = "{essid} ({signalStrength}%) ";
    tooltip-format-ethernet = "{ifname} ";
    tooltip-format-disconnected = "Disconnected";
    max-length = 50;
    on-click = "nmtui";
  };

  "network#mallorca" = {
    interface = "wlo1";
    format = "{ifname}";
    format-wifi = "   {essid}";
    format-disconnected = "";
    tooltip-format = "{ifname} via {gwaddr} 󰊗";
    tooltip-format-wifi = "{essid} ({signalStrength}%) ";
    tooltip-format-ethernet = "{ifname} ";
    tooltip-format-disconnected = "Disconnected";
    max-length = 50;
    on-click = "nmtui";
  };

  "network#lan" = {
    interface = "eno1";
    format = "󰌗   {ipaddr}/{cidr}";
    format-disconnected = "󰲛   {ifname}";
    tooltip-format = "   {ifname}";
    tooltip-format-disconnected = "Disconnected";
    max-length = 50;
  };

  tray = {
    icon-size = 21;
    spacing = 10;
  };

  "custom/wireguard" = {
    exec = "${wireguard}";
    on-click = "pkexec ${wireguard} --switch";
    restart-interval = 5;
  };

  "pulseaudio/slider" = {
    min = 0;
    max = 100;
    orientation = "horizontal";
    on-click-right = "${pavucontrol}";
  };

  pulseaudio = {
    format = "{volume}% {icon} {format_source}";
    format-muted = " {format_source}";
    format-source = "{volume}% ";
    format-source-muted = "";
    format-icons = {
      headphone = "";
      hands-free = "";
      headset = "";
      phone = "";
      portable = "";
      car = "";
      default = [
        ""
        ""
        ""
      ];
    };
    on-click = "${pavucontrol}";
  };

  temperature = {
    thermal-zone = "hwon4";
    format = "  {temperatureC}°C";
  };
}
