{
  config,
  pkgs,
  private-settings,
  ...
}:
pkgs.writeShellApplication {
  name = "waybar-lemmy";
  runtimeInputs = [
    pkgs.toybox
    pkgs.curl
    pkgs.jq
  ];
  text = ''
    set +o pipefail
    set +o errexit
    set +o nounset
    instance="${private-settings.lemmyInstance}"
    username="$(cat ${config.sops.secrets."lemmy/username".path})"
    password="$(cat ${config.sops.secrets."lemmy/password".path})"

    API="api/v3"
    set +H

    login() {
        end_point="user/login"
        json_data="{\"username_or_email\":\"$username\",\"password\":\"$password\"}"

        url="$instance/$API/$end_point"

        curl -s -m 3 -H "Content-Type: application/json" -d "$json_data" "$url"
    }

    get_unread_replies() {
        end_point="user/replies"
        www_data="unread_only=true"

        url="$instance/$API/$end_point?$www_data"

        curl -s -m 3 "$url" --cookie "jwt=$jwt" | jq -r '.replies | length'
    }

    jwt=$(login | jq -r .jwt)
    notifications=$(get_unread_replies)

    if [ -n "$notifications" ] && [ "$notifications" -gt 0 ]; then
        echo "   $notifications"
    else
        echo ""
    fi  
  '';
}
