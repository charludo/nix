{ pkgs, ... }:
let
  lgtv =
    pkgs.writers.writePython3Bin "lgtv"
      {
        libraries = [ pkgs.python312Packages.flask ];
        doCheck = false;
      } # python
      ''
        from flask import Flask
        import os
        import time


        app = Flask(__name__)


        def run_command(args):
            os.system(
                f"${pkgs.python312Packages.aiopylgtv}/bin/aiopylgtvcommand 192.168.24.100 {args}"
            )


        @app.route('/picture/day', methods=['GET'])
        def day():
            run_command("set_current_picture_mode expert1")

        @app.route('/picture/night', methods=['GET'])
        def night():
            run_command("set_current_picture_mode filmMaker")

        @app.route('/picture/hdr', methods=['GET'])
        def hdr():
            run_command("set_current_picture_mode hdrFilmMaker")

        @app.route('/picture/dolby', methods=['GET'])
        def dolby():
            run_command("set_current_picture_mode hdrCinemaBright")

        @app.route('/picture/off', methods=['GET'])
        def off():
            run_command("turn_screen_off")

        @app.route('/picture/on', methods=['GET'])
        def on():
            run_command("turn_screen_on")

        @app.route('/sound/select', methods=['GET'])
        def sound():
            run_command("button EZSOUND")

        @app.route('/sound/up', methods=['GET'])
        def up_sound():
            run_command("button UP")
            time.sleep(0.2)
            run_command("button ENTER")

        @app.route('/sound/down', methods=['GET'])
        def down_sound():
            run_command("button DOWN")
            time.sleep(0.2)
            run_command("button ENTER")

        @app.route('/back', methods=['GET'])
        def back():
            run_command("button BACK")

        @app.route('/enter', methods=['GET'])
        def enter():
            run_command("button ENTER")

        if __name__ == '__main__':
            app.run(host='0.0.0.0', port='8080')
      '';
in
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2401;
    name = "SRV-HOME";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "2G";

    networking.openPorts.tcp = [ 80 ];
  };

  environment.systemPackages = [
    pkgs.python312Packages.aiopylgtv
    lgtv
  ];

  services.nginx = {
    enable = true;
    virtualHosts."_" = {
      locations."/" = {
        proxyPass = "http://localhost:8080";
      };
    };
  };

  systemd.services.lgtv = {
    description = "lgtv remote control";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "lgtv";
      Group = "lgtv";

      ExecStart = "${lgtv}/bin/lgtv";
    };
  };

  users.users = {
    lgtv = {
      isNormalUser = true;
      group = "lgtv";
      uid = 2134;
    };
  };

  users.groups = {
    lgtv = {
      gid = 2134;
    };
  };

  system.stateVersion = "23.11";
}
