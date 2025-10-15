# This has in large parts been copied from: https://github.com/EmergentMind/nix-config/blob/dev/modules/common/yubikey.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.yubikey;

  yubikey-up =
    let
      applicableKeys = filterAttrs (_: id: id.serial != null && id.keyType == "ssh") cfg.identities;
      yubikeyPublics = concatStringsSep " " (
        mapAttrsToList (
          _: id: "[${builtins.toString id.publicKeyFile}]=\"${builtins.toString id.serial}\""
        ) applicableKeys
      );
      yubikeyPrivates = concatStringsSep " " (
        mapAttrsToList (
          _: id: "[${builtins.toString id.privateKeyFile}]=\"${builtins.toString id.serial}\""
        ) applicableKeys
      );
    in
    pkgs.writeShellApplication {
      name = "yubikey-up";
      runtimeInputs = builtins.attrValues { inherit (pkgs) gawk yubikey-manager; };
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        serial=$(ykman list | awk '{print $NF}')
        # If it got unplugged before we ran, just don't bother
        if [ -z "$serial" ]; then
          exit 0
        fi

        declare -A publics=(${yubikeyPublics})
        declare -A privates=(${yubikeyPrivates})

        public_file=""
        for key in "''${!publics[@]}"; do
          if [[ $serial == "''${publics[$key]}" ]]; then
            public_file="$key"
          fi
        done

        private_file=""
        for key in "''${!privates[@]}"; do
          if [[ $serial == "''${privates[$key]}" ]]; then
            private_file="$key"
          fi
        done

        if [ -z "$public_file" ] || [ -z "$private_file" ]; then
          echo WARNING: Unidentified yubikey with serial "$serial" . Won\'t link an SSH key.
          exit 0
        fi

        cp "$private_file" "${cfg.sshDir}/id_yubikey"
        cp "$public_file" "${cfg.sshDir}/id_yubikey.pub"

        chmod 600 "${cfg.sshDir}/id_yubikey"
        chown "$(stat -c "%U:%G" ${cfg.sshDir})" "${cfg.sshDir}/id_yubikey"
        chown "$(stat -c "%U:%G" ${cfg.sshDir})" "${cfg.sshDir}/id_yubikey.pub"
      '';
    };
  yubikey-down = pkgs.writeShellApplication {
    name = "yubikey-down";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      rm "${cfg.sshDir}/id_yubikey"
      rm "${cfg.sshDir}/id_yubikey.pub"
    '';
  };
in
{
  options.yubikey = {
    enable = mkEnableOption "yubikey-based services and authentication";

    identities = mkOption {
      type = lib.types.anything;
      description = ''
        A set of identities. See user.users.<name>.identities
      '';
    };

    sshDir = mkOption {
      type = types.str;
      description = ''
        Directory where ssh identities get linked
      '';
    };

    sudoAuthFile = mkOption {
      type = types.path;
      default = "~/.config/Yubico/u2f_keys";
      description = ''
        File for the pam.u2f module's authfile setting.
      '';
    };

    lockOnRemove = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to lock the device if the Yubikey is removed
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = ''
      # Link/unlink ssh key on yubikey add/remove
      SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="1050", RUN+="${lib.getBin yubikey-up}/bin/yubikey-up"
      # NOTE: Yubikey 4 has a ID_VENDOR_ID on remove, but not Yubikey 5 BIO, whereas both have a HID_NAME.
      # Yubikey 5 HID_NAME uses "YubiKey" whereas Yubikey 4 uses "Yubikey", so matching on "Yubi" works for both
      SUBSYSTEM=="hid", ACTION=="remove", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${lib.getBin yubikey-down}/bin/yubikey-down"
    ''
    + optionalString cfg.lockOnRemove ''
      SUBSYSTEM=="hid",\
       ACTION=="remove",\
       ENV{HID_NAME}=="Yubico YubiKey FIDO",\
       RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"

    '';

    environment.systemPackages =
      with pkgs;
      [
        yubioath-flutter
        yubikey-manager
        pam_u2f
        age-plugin-yubikey
      ]
      ++ [
        yubikey-up
        yubikey-down
      ];

    # Restart pcscd every 30mins to prevent "please insert card ..."
    services.pcscd.enable = true;
    # systemd.services.pcscd.serviceConfig = {
    # Restart = "always";
    # RuntimeMaxSec = "1800s";
    # };
    systemd.services."restart-pcscd" = {
      description = "Restart pcscd service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart pcscd.service";
      };
    };

    systemd.timers."restart-pcscd" = {
      description = "Timer to restart pcscd every 30 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30min";
        OnUnitActiveSec = "30min";
        Unit = "restart-pcscd.service";
      };
    };

    services.udev.packages = [ pkgs.yubikey-personalization ];
    services.yubikey-agent.enable = true;

    hardware.gpgSmartcards.enable = true;

    security.pam = {
      sshAgentAuth.enable = true;
      u2f = {
        enable = true;
        settings = {
          cue = true;
          origin = "pam://yubi";
          authfile = cfg.sudoAuthFile;
        };
      };
      services = {
        login.u2fAuth = true;
        sudo = {
          u2fAuth = true;
          sshAgentAuth = true;
        };
        hyprlock.u2fAuth = true;
        polkit-1.u2fAuth = true;
      };
    };
  };
}
