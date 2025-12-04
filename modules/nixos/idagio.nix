{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.idagio;
  UID = 9417;
  GID = 9417;
  idagio-web =
    pkgs.writers.writePython3Bin "idagio-web" { libraries = [ pkgs.python313Packages.flask ]; } # python
      ''
        from flask import Flask, request, render_template_string
        import os
        import threading


        app = Flask(__name__)


        def run_command(args):
            # pylint: disable=line-too-long
            cmd = "${lib.getExe cfg.package}"
            os.system(
                f"{cmd} {args}"
            )


        @app.route('/', methods=['GET', 'POST'])
        def index():
            message = ""
            if request.method == 'POST':
                input_value = request.form['idagio_url']
                url, _, _ = input_value.replace("/de/", "/").partition("?")
                config = "${cfg.configLocation}"
                threading.Thread(
                    target=run_command,
                    args=(f"-c {config} -u {url}",)
                ).start()
                message = f"{url} is now downloading."

            return render_template_string(''''
                <div style="
                  display: flex; justify-content: center; align-items: center;
                  height: 100vh; text-align: center;
                  flex-direction: column;
                ">
                    <form method="POST" style="display: inline-block;">
                        <label for="idagio_url">Idagio URL:</label>
                        <input type="text" id="idagio_url" name="idagio_url">
                        <input type="submit" value="Submit">
                    </form>
                    <p style="display: inline-block">%s</p>
                </div>
            '''' % message)


        if __name__ == '__main__':
            app.run(host='${cfg.host}', port=${builtins.toString cfg.port})
      '';
in
{
  options.services.idagio = {
    enable = mkEnableOption "idagio downloader";

    configLocation = mkOption {
      type = types.path;
      description = "Path to the idagio downloader config file.";
    };

    user = mkOption {
      type = types.str;
      default = "qbittorrent";
      description = "User account under which qBittorrent runs.";
    };

    group = mkOption {
      type = types.str;
      default = "qbittorrent";
      description = "Group under which qBittorrent runs.";
    };

    port = mkOption {
      type = types.port;
      default = 9417;
      description = "idagio downloader web port";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "idagio downloader host";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open services.idagio.port to the outside network.";
    };

    package = mkOption {
      type = types.package;
      description = "The idagio package to use.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd.services.idagio = {
      description = "idagio service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        ExecStart = "${lib.getExe idagio-web}";
      };
    };

    users.users = mkIf (cfg.user == "idagio") {
      idagio = {
        group = cfg.group;
        uid = UID;
      };
    };

    users.groups = mkIf (cfg.group == "idagio") {
      idagio = {
        gid = GID;
      };
    };
  };
}
