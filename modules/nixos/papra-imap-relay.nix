{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.services.papra-imap-relay;

  instanceOptions =
    _:
    {
      options = {
        enable = lib.mkEnableOption "this papra-imap-relay instance" // {
          default = true;
        };

        imap = {
          host = mkOption {
            type = types.str;
            description = "IMAP server, spoken to over implicit TLS.";
          };
          port = mkOption {
            type = types.port;
            default = 993;
            description = "IMAPS port.";
          };
          user = mkOption {
            type = types.str;
            description = "IMAP login.";
          };
          passwordFile = mkOption {
            type = types.path;
            description = "File containing the IMAP password.";
          };
          folder = mkOption {
            type = types.str;
            default = "INBOX";
            description = "Folder whose unseen mails are forwarded.";
          };
          doneFolder = mkOption {
            type = types.str;
            default = "Papra";
            description = ''
              Folder handled mails are moved to (created if missing).
              Empty to leave them in place, marked as seen.
            '';
          };
        };

        webhookUrl = mkOption {
          type = types.str;
          default = "http://127.0.0.1:${toString config.services.papra.environment.PORT}/api/intake-emails/ingest";
          defaultText = lib.literalExpression ''"http://127.0.0.1:''${toString config.services.papra.environment.PORT}/api/intake-emails/ingest"'';
          description = "Papra's intake email ingestion endpoint.";
        };

        webhookSecretFile = mkOption {
          type = types.path;
          description = ''
            File containing the same secret as Papra's `INTAKE_EMAILS_WEBHOOK_SECRET`:
            either only the secret, or an environment file with an
            `INTAKE_EMAILS_WEBHOOK_SECRET=` line, so Papra can use the same file.
          '';
        };

        intakeAddress = mkOption {
          type = types.str;
          example = "charlotte-1234@papra.internal";
          description = ''
            Intake email address, as shown in Papra's organization settings,
            that every forwarded mail is addressed to. It decides the
            organization the documents end up in.
          '';
        };

        senderOverride = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "relay@example.com";
          description = ''
            Sender reported to Papra instead of the mail's own. Papra drops
            mails whose sender is not an allowed origin of the intake address;
            with an override, only this one address has to be allowed there.
          '';
        };

        allowedSenders = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Only forward mails from these senders. Empty allows everyone.";
        };

        filenamePrefix = mkOption {
          type = types.str;
          default = "MAIL_";
          description = ''
            Prefix for the names of forwarded documents, so Papra tagging
            rules (`name` `starts with`) can recognise mail-ingested documents.
          '';
        };

        pollInterval = mkOption {
          type = types.ints.positive;
          default = 300;
          description = "Seconds between polls.";
        };
      };
    };
in
{
  options.services.papra-imap-relay = {
    package = lib.mkPackageOption pkgs.ours "papra-imap-relay" { };

    instances = mkOption {
      type = types.attrsOf (types.submodule instanceOptions);
      default = { };
      description = ''
        Relays that each poll one IMAP mailbox and forward the PDF
        attachments of new mails to one Papra intake email address.
      '';
    };
  };

  config.systemd.services = lib.mapAttrs' (
    name: instance:
    lib.nameValuePair "papra-imap-relay-${name}" {
      description = "Forward PDFs from ${instance.imap.user} to Papra";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "papra.service"
      ];

      environment = {
        IMAP_HOST = instance.imap.host;
        IMAP_PORT = toString instance.imap.port;
        IMAP_USER = instance.imap.user;
        IMAP_PASSWORD_FILE = "%d/imap-password";
        IMAP_FOLDER = instance.imap.folder;
        IMAP_DONE_FOLDER = instance.imap.doneFolder;
        WEBHOOK_URL = instance.webhookUrl;
        WEBHOOK_SECRET_FILE = "%d/webhook-secret";
        INTAKE_ADDRESS = instance.intakeAddress;
        SENDER_OVERRIDE = lib.optionalString (instance.senderOverride != null) instance.senderOverride;
        ALLOWED_SENDERS = lib.concatStringsSep "," instance.allowedSenders;
        FILENAME_PREFIX = instance.filenamePrefix;
        POLL_INTERVAL = toString instance.pollInterval;
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        LoadCredential = [
          "imap-password:${instance.imap.passwordFile}"
          "webhook-secret:${instance.webhookSecretFile}"
        ];
        Restart = "on-failure";
        RestartSec = "1min";
        # Exit code 78 means a bad login or config: stay down rather than
        # retry, so a wrong password cannot get the host banned by fail2ban.
        RestartPreventExitStatus = 78;

        DynamicUser = true;
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        UMask = "0077";
      };
    }
  ) (lib.filterAttrs (_: instance: instance.enable) cfg.instances);
}
