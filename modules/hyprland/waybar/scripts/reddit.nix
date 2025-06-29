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
    # shellcheck disable=SC2086
    URL="https://www.reddit.com/message/unread/.json?feed=$(cat ${config.age.secrets.reddit-token.path})&user=$(cat ${config.age.secrets.reddit-username.path})"
    # shellcheck disable=SC2086
    USERAGENT="polybar-scripts/notification-reddit:v1.0 u/$(cat ${config.age.secrets.reddit-username.path})"
    notifications=$(curl -sf --user-agent "$USERAGENT" "$URL" | jq '.["data"]["children"] | length')

    if [ -n "$notifications" ] && [ "$notifications" -gt 0 ]; then
        echo "   $notifications"
    else
        echo ""
    fi  
  '';
}
