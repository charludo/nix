{ config, pkgs, ... }:
{
  imports = [ ./scripts ];
  # Note: Only basic setup and styling is handled here.
  # Custom modules are created in ./modules.nix.
  # The actual bars are configured in the host-specific files.
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    package = pkgs.waybar.overrideAttrs (oa: {
      mesonFlag = (oa.mesonFlag or [ ]) ++ [ "-Dexperimental=true" ];
    });
    style =
      let
        inherit (config.colorScheme) palette;
      in
      # css
      ''
        @define-color progress  alpha(#${palette.base0E}, 0.1);
        window {
          background-color: transparent;
        }

        label {
          color: @text;
        }

        .modules-left {
          margin-left: 16px;
        }
        .modules-right {
          margin-right: 16px;
        }

        #workspaces,
        #clock,
        #custom-weather,
        #battery,
        #bluetooth,
        #cpu,
        #disk,
        #memory,
        #network,
        #pulseaudio-slider,
        #temperature,
        #custom-power,
        #tray,
        #custom-wireguard,
        #custom-playerctl,
        #custom-mail,
        #custom-lemmy,
        #custom-reddit,
        #custom-updates {
          margin: 0px 4px;
          padding: 0px 12px;
          border-radius: 64px;
          background-color: alpha(#${palette.base0E}, 0.05);
        }

        #custom-playerctl {
          background-size: 100% 100%;
          background-repeat: no-repeat;
          background-position: center;
        }

        #pulseaudio-slider {
          min-width: 100px;
        }

        #workspaces button.persistent {
            color: alpha(#${palette.base05}, 0.7);
        }
        #workspaces button.empty {
          opacity: 0.7;
        }
        #workspaces button.active {
          color: #${palette.base09};
        }

        /* Is this an ugly hack? Yes! Does it Work? Also yes! */
        .progress-1 {
          background-image: linear-gradient(to right, @progress 1%, transparent 1%);
        }
        .progress-2 {
          background-image: linear-gradient(to right, @progress 2%, transparent 2%);
        }
        .progress-3 {
          background-image: linear-gradient(to right, @progress 3%, transparent 3%);
        }
        .progress-4 {
          background-image: linear-gradient(to right, @progress 4%, transparent 4%);
        }
        .progress-5 {
          background-image: linear-gradient(to right, @progress 5%, transparent 5%);
        }
        .progress-6 {
          background-image: linear-gradient(to right, @progress 6%, transparent 6%);
        }
        .progress-7 {
          background-image: linear-gradient(to right, @progress 7%, transparent 7%);
        }
        .progress-8 {
          background-image: linear-gradient(to right, @progress 8%, transparent 8%);
        }
        .progress-9 {
          background-image: linear-gradient(to right, @progress 9%, transparent 9%);
        }
        .progress-10 {
          background-image: linear-gradient(to right, @progress 10%, transparent 10%);
        }
        .progress-11 {
          background-image: linear-gradient(to right, @progress 11%, transparent 11%);
        }
        .progress-12 {
          background-image: linear-gradient(to right, @progress 12%, transparent 12%);
        }
        .progress-13 {
          background-image: linear-gradient(to right, @progress 13%, transparent 13%);
        }
        .progress-14 {
          background-image: linear-gradient(to right, @progress 14%, transparent 14%);
        }
        .progress-15 {
          background-image: linear-gradient(to right, @progress 15%, transparent 15%);
        }
        .progress-16 {
          background-image: linear-gradient(to right, @progress 16%, transparent 16%);
        }
        .progress-17 {
          background-image: linear-gradient(to right, @progress 17%, transparent 17%);
        }
        .progress-18 {
          background-image: linear-gradient(to right, @progress 18%, transparent 18%);
        }
        .progress-19 {
          background-image: linear-gradient(to right, @progress 19%, transparent 19%);
        }
        .progress-20 {
          background-image: linear-gradient(to right, @progress 20%, transparent 20%);
        }
        .progress-21 {
          background-image: linear-gradient(to right, @progress 21%, transparent 21%);
        }
        .progress-22 {
          background-image: linear-gradient(to right, @progress 22%, transparent 22%);
        }
        .progress-23 {
          background-image: linear-gradient(to right, @progress 23%, transparent 23%);
        }
        .progress-24 {
          background-image: linear-gradient(to right, @progress 24%, transparent 24%);
        }
        .progress-25 {
          background-image: linear-gradient(to right, @progress 25%, transparent 25%);
        }
        .progress-26 {
          background-image: linear-gradient(to right, @progress 26%, transparent 26%);
        }
        .progress-27 {
          background-image: linear-gradient(to right, @progress 27%, transparent 27%);
        }
        .progress-28 {
          background-image: linear-gradient(to right, @progress 28%, transparent 28%);
        }
        .progress-29 {
          background-image: linear-gradient(to right, @progress 29%, transparent 29%);
        }
        .progress-30 {
          background-image: linear-gradient(to right, @progress 30%, transparent 30%);
        }
        .progress-31 {
          background-image: linear-gradient(to right, @progress 31%, transparent 31%);
        }
        .progress-32 {
          background-image: linear-gradient(to right, @progress 32%, transparent 32%);
        }
        .progress-33 {
          background-image: linear-gradient(to right, @progress 33%, transparent 33%);
        }
        .progress-34 {
          background-image: linear-gradient(to right, @progress 34%, transparent 34%);
        }
        .progress-35 {
          background-image: linear-gradient(to right, @progress 35%, transparent 35%);
        }
        .progress-36 {
          background-image: linear-gradient(to right, @progress 36%, transparent 36%);
        }
        .progress-37 {
          background-image: linear-gradient(to right, @progress 37%, transparent 37%);
        }
        .progress-38 {
          background-image: linear-gradient(to right, @progress 38%, transparent 38%);
        }
        .progress-39 {
          background-image: linear-gradient(to right, @progress 39%, transparent 39%);
        }
        .progress-40 {
          background-image: linear-gradient(to right, @progress 40%, transparent 40%);
        }
        .progress-41 {
          background-image: linear-gradient(to right, @progress 41%, transparent 41%);
        }
        .progress-42 {
          background-image: linear-gradient(to right, @progress 42%, transparent 42%);
        }
        .progress-43 {
          background-image: linear-gradient(to right, @progress 43%, transparent 43%);
        }
        .progress-44 {
          background-image: linear-gradient(to right, @progress 44%, transparent 44%);
        }
        .progress-45 {
          background-image: linear-gradient(to right, @progress 45%, transparent 45%);
        }
        .progress-46 {
          background-image: linear-gradient(to right, @progress 46%, transparent 46%);
        }
        .progress-47 {
          background-image: linear-gradient(to right, @progress 47%, transparent 47%);
        }
        .progress-48 {
          background-image: linear-gradient(to right, @progress 48%, transparent 48%);
        }
        .progress-49 {
          background-image: linear-gradient(to right, @progress 49%, transparent 49%);
        }
        .progress-50 {
          background-image: linear-gradient(to right, @progress 50%, transparent 50%);
        }
        .progress-51 {
          background-image: linear-gradient(to right, @progress 51%, transparent 51%);
        }
        .progress-52 {
          background-image: linear-gradient(to right, @progress 52%, transparent 52%);
        }
        .progress-53 {
          background-image: linear-gradient(to right, @progress 53%, transparent 53%);
        }
        .progress-54 {
          background-image: linear-gradient(to right, @progress 54%, transparent 54%);
        }
        .progress-55 {
          background-image: linear-gradient(to right, @progress 55%, transparent 55%);
        }
        .progress-56 {
          background-image: linear-gradient(to right, @progress 56%, transparent 56%);
        }
        .progress-57 {
          background-image: linear-gradient(to right, @progress 57%, transparent 57%);
        }
        .progress-58 {
          background-image: linear-gradient(to right, @progress 58%, transparent 58%);
        }
        .progress-59 {
          background-image: linear-gradient(to right, @progress 59%, transparent 59%);
        }
        .progress-60 {
          background-image: linear-gradient(to right, @progress 60%, transparent 60%);
        }
        .progress-61 {
          background-image: linear-gradient(to right, @progress 61%, transparent 61%);
        }
        .progress-62 {
          background-image: linear-gradient(to right, @progress 62%, transparent 62%);
        }
        .progress-63 {
          background-image: linear-gradient(to right, @progress 63%, transparent 63%);
        }
        .progress-64 {
          background-image: linear-gradient(to right, @progress 64%, transparent 64%);
        }
        .progress-65 {
          background-image: linear-gradient(to right, @progress 65%, transparent 65%);
        }
        .progress-66 {
          background-image: linear-gradient(to right, @progress 66%, transparent 66%);
        }
        .progress-67 {
          background-image: linear-gradient(to right, @progress 67%, transparent 67%);
        }
        .progress-68 {
          background-image: linear-gradient(to right, @progress 68%, transparent 68%);
        }
        .progress-69 {
          background-image: linear-gradient(to right, @progress 69%, transparent 69%);
        }
        .progress-70 {
          background-image: linear-gradient(to right, @progress 70%, transparent 70%);
        }
        .progress-71 {
          background-image: linear-gradient(to right, @progress 71%, transparent 71%);
        }
        .progress-72 {
          background-image: linear-gradient(to right, @progress 72%, transparent 72%);
        }
        .progress-73 {
          background-image: linear-gradient(to right, @progress 73%, transparent 73%);
        }
        .progress-74 {
          background-image: linear-gradient(to right, @progress 74%, transparent 74%);
        }
        .progress-75 {
          background-image: linear-gradient(to right, @progress 75%, transparent 75%);
        }
        .progress-76 {
          background-image: linear-gradient(to right, @progress 76%, transparent 76%);
        }
        .progress-77 {
          background-image: linear-gradient(to right, @progress 77%, transparent 77%);
        }
        .progress-78 {
          background-image: linear-gradient(to right, @progress 78%, transparent 78%);
        }
        .progress-79 {
          background-image: linear-gradient(to right, @progress 79%, transparent 79%);
        }
        .progress-80 {
          background-image: linear-gradient(to right, @progress 80%, transparent 80%);
        }
        .progress-81 {
          background-image: linear-gradient(to right, @progress 81%, transparent 81%);
        }
        .progress-82 {
          background-image: linear-gradient(to right, @progress 82%, transparent 82%);
        }
        .progress-83 {
          background-image: linear-gradient(to right, @progress 83%, transparent 83%);
        }
        .progress-84 {
          background-image: linear-gradient(to right, @progress 84%, transparent 84%);
        }
        .progress-85 {
          background-image: linear-gradient(to right, @progress 85%, transparent 85%);
        }
        .progress-86 {
          background-image: linear-gradient(to right, @progress 86%, transparent 86%);
        }
        .progress-87 {
          background-image: linear-gradient(to right, @progress 87%, transparent 87%);
        }
        .progress-88 {
          background-image: linear-gradient(to right, @progress 88%, transparent 88%);
        }
        .progress-89 {
          background-image: linear-gradient(to right, @progress 89%, transparent 89%);
        }
        .progress-90 {
          background-image: linear-gradient(to right, @progress 90%, transparent 90%);
        }
        .progress-91 {
          background-image: linear-gradient(to right, @progress 91%, transparent 91%);
        }
        .progress-92 {
          background-image: linear-gradient(to right, @progress 92%, transparent 92%);
        }
        .progress-93 {
          background-image: linear-gradient(to right, @progress 93%, transparent 93%);
        }
        .progress-94 {
          background-image: linear-gradient(to right, @progress 94%, transparent 94%);
        }
        .progress-95 {
          background-image: linear-gradient(to right, @progress 95%, transparent 95%);
        }
        .progress-96 {
          background-image: linear-gradient(to right, @progress 96%, transparent 96%);
        }
        .progress-97 {
          background-image: linear-gradient(to right, @progress 97%, transparent 97%);
        }
        .progress-98 {
          background-image: linear-gradient(to right, @progress 98%, transparent 98%);
        }
        .progress-99 {
          background-image: linear-gradient(to right, @progress 99%, transparent 99%);
        }
        .progress-100 {
          background-image: linear-gradient(to right, @progress 100%, transparent 100%);
        }
      '';
  };
}
