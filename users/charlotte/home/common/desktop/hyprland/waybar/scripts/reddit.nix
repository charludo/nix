{ config, pkgs, ... }:
pkgs.writeShellApplication {
  name = "waybar-reddit";
  runtimeInputs = [
    pkgs.toybox
    pkgs.curl
    pkgs.jq
  ];
  text = ''
    set +o pipefail
    URL="https://www.reddit.com/message/unread/.json?feed=$(cat ${
      config.sops.secrets."reddit/token".path
    })&user=$(cat ${config.sops.secrets."reddit/username".path})"
    USERAGENT="polybar-scripts/notification-reddit:v1.0 u/$(cat ${
      config.sops.secrets."reddit/username".path
    })"
    notifications=$(curl -sf --user-agent "$USERAGENT" "$URL" | jq '.["data"]["children"] | length')

    if [ -n "$notifications" ] && [ "$notifications" -gt 0 ]; then
        echo "   $notifications"
    else
        echo ""
    fi  
  '';
}
