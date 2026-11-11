{
  config,
  lib,
  pkgs,
  private-settings,
  secrets,
  ...
}:
let
  backupDirDaily = "${config.nas.backup.stateLocation}/paperless/daily/";
  backupDirMonthly = "${config.nas.backup.stateLocation}/paperless/monthly/";

  restore-paperless = pkgs.writeShellApplication {
    name = "restore-paperless";
    text = ''
      sudo -u paperless /run/current-system/sw/bin/paperless-manage document_importer "${backupDirDaily}"
    '';
  };

  papraStateDir = "/var/lib/papra";
  papraDatabase = "${papraStateDir}/db.sqlite";
  papraDatabaseSnapshot = "${papraStateDir}/backup/db.sqlite";
  papraBackupDir = "${config.nas.backup.stateLocation}/papra";
  # Holds one folder per organization, named after its id (`org_…`, see the organization's URL).
  papraIngestionDir = "${config.nas.location}/Papra";

  restore-papra = pkgs.writeShellApplication {
    name = "restore-papra";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      systemctl stop papra.service
      rsync-restore-papra
      install -o papra -g papra -m 0600 "${papraDatabaseSnapshot}" "${papraDatabase}"
      rm -f "${papraDatabase}-wal" "${papraDatabase}-shm"
      systemctl start papra.service
    '';
  };
in
{
  vm = {
    id = 2203;
    name = "SRV-PAPERLESS";

    hardware.cores = 4;
    # Only applies to new images; on the existing VM: `qm set 2203 --memory 12288`.
    # Ollama (~4 GB with gemma3:4b) and Docling (~3 GB) need the extra room.
    hardware.memory = 12288;
    hardware.storage = "32G";

    networking.openPorts.tcp = [
      8000
      config.services.papra.environment.PORT
    ];
    networking.openPorts.udp = [ 8000 ];
  };

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [
    config.services.paperless.user
    config.services.papra.user
  ];

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    port = 8000;
    dataDir = "/var/lib/paperless";
    consumptionDir = "${config.nas.location}/Scanner/";
    consumptionDirIsPublic = true;
    openMPThreadingWorkaround = true;
    settings = {
      PAPERLESS_URL = private-settings.domains.paperless;
      PAPERLESS_DBENGINE = "postgresql";
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };
      PAPERLESS_ENABLE_ALLAUTH = true;
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
    };
    environmentFile = config.age.secrets.paperless-openid.path;
  };
  age.secrets.paperless-openid.rekeyFile = secrets.paperless-openid;

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "paperless" ];
    ensureUsers = [
      {
        name = "paperless";
        ensureDBOwnership = true;
      }
    ];
    authentication = ''
      #type database  DBuser  auth-method
      local all       all     trust
    '';
  };

  # Papra, on trial next to Paperless. The organization(s) and their intake
  # email addresses are created in the web UI; see the relay below.
  services.papra = {
    enable = true;
    environment = {
      APP_BASE_URL = private-settings.domains.papra;
      TRUSTED_ORIGINS = private-settings.domains.papra;
      DATABASE_URL = "file:${papraDatabase}";

      # Login via Pocket ID only; AUTH_PROVIDERS_CUSTOMS lives in the secret.
      AUTH_IS_REGISTRATION_ENABLED = true;
      AUTH_PROVIDERS_EMAIL_IS_ENABLED = false;
      AUTH_FIRST_USER_AS_ADMIN = true;

      DOCUMENT_STORAGE_ENCRYPTION_IS_ENABLED = true;

      DOCUMENTS_OCR_LANGUAGES = "deu,eng";
      # Papra gives Docling a hard 30 s per document; slower ones (long scans
      # on this CPU) fall back to the built-in extraction with Tesseract.
      CONTENT_EXTRACTION_STRATEGY = "docling,internal";
      DOCLING_BASE_URL = "http://127.0.0.1:${toString config.services.docling-serve.port}";

      INGESTION_FOLDER_IS_ENABLED = true;
      INGESTION_FOLDER_ROOT_PATH = papraIngestionDir;
      # inotify does not see changes on the CIFS share
      INGESTION_FOLDER_WATCHER_USE_POLLING = true;
      INGESTION_FOLDER_WATCHER_POLLING_INTERVAL_MS = 10000;
      INGESTION_FOLDER_WATCHER_FILE_STABILITY_THRESHOLD_MS = 10000;
      INGESTION_FOLDER_POST_PROCESSING_STRATEGY = "move";

      # Addresses are only identifiers here: mail arrives via the IMAP relay,
      # which addresses each forwarded mail to the configured intake address.
      INTAKE_EMAILS_IS_ENABLED = true;
      INTAKE_EMAILS_DRIVER = "catch-all";
      INTAKE_EMAILS_CATCH_ALL_DOMAIN = "papra.internal";

      AI_IS_ENABLED = true;
      AUTO_TAGGING_ENABLED = true;
      AUTO_TAGGING_MODEL = "ollama://${lib.head config.services.ollama.loadModels}";
      AUTO_TAGGING_DEFAULT_MAX_TAGS = 3;
      OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}/v1";
    };
    environmentFiles = [
      # AUTH_SECRET, DOCUMENT_STORAGE_DOCUMENT_KEY_ENCRYPTION_KEYS, AUTH_PROVIDERS_CUSTOMS
      config.age.secrets.papra-env.path
      # INTAKE_EMAILS_WEBHOOK_SECRET
      config.age.secrets.papra-intake.path
    ];
  };
  age.secrets.papra-env.rekeyFile = secrets.papra-env;
  age.secrets.papra-intake.rekeyFile = secrets.papra-intake;

  # The module manages the ingestion root as a local directory, which the CIFS
  # mount neither needs nor allows (no chown).
  systemd.tmpfiles.settings."10-papra".${papraIngestionDir} = lib.mkForce { };
  systemd.services.papra = {
    unitConfig.RequiresMountsFor = [ papraIngestionDir ];
    after = [
      "docling-serve.service"
      "ollama.service"
    ];
  };

  services.papra-imap-relay.instances.charlotte = {
    imap = {
      host = "mail.${private-settings.domains.personal}";
      # TODO: placeholder, the mailbox does not exist yet.
      user = "papra@${private-settings.domains.personal}";
      passwordFile = config.age.secrets.papra-imap-password.path;
    };
    webhookSecretFile = config.age.secrets.papra-intake.path;
    # TODO: placeholder, copy the address from the organization's settings → Intake emails.
    intakeAddress = "charlotte@papra.internal";
    # So this is the only address to allow on the intake email in Papra.
    senderOverride = "papra@${private-settings.domains.personal}";
    filenamePrefix = "MAIL_";
  };
  age.secrets.papra-imap-password.rekeyFile = secrets.papra-imap-password;

  services.docling-serve = {
    enable = true;
    environment = {
      DOCLING_SERVE_ENABLE_UI = "False";
      # Papra stops waiting after 30 s; do not keep converting for nobody.
      DOCLING_SERVE_MAX_SYNC_WAIT = "30";
      DOCLING_SERVE_MAX_DOCUMENT_TIMEOUT = "45";
      DOCLING_SERVE_ENG_LOC_NUM_WORKERS = "1";
    };
  };

  # CPU only: the GPU host's iGPU is passed through to SRV-JELLYFIN and the NPU
  # is used by SRV-VOICE. Tagging a document takes minutes, which is fine.
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    loadModels = [ "gemma3:4b" ];
    environmentVariables = {
      # Papra sends whole documents; the default 4k window silently cuts them.
      OLLAMA_CONTEXT_LENGTH = "8192";
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      # Free the RAM between documents.
      OLLAMA_KEEP_ALIVE = "5m";
    };
  };

  # Background work: keep Paperless and the web UIs responsive.
  systemd.services.ollama.serviceConfig = {
    Nice = 15;
    CPUWeight = 20;
  };
  systemd.services.docling-serve.serviceConfig = {
    Nice = 10;
    CPUWeight = 50;
  };

  # Papra keeps its state in SQLite; back up a consistent snapshot, not the live file.
  rsync."papra" = {
    tasks = [
      {
        from = papraStateDir;
        to = papraBackupDir;
        extraFlags = "--exclude=/db.sqlite --exclude=/db.sqlite-wal --exclude=/db.sqlite-shm";
      }
    ];
  };
  systemd.services."rsync-task-papra".preStart = ''
    install -d -o papra -g papra -m 0700 "$(dirname "${papraDatabaseSnapshot}")"
    rm -f "${papraDatabaseSnapshot}"
    ${lib.getExe pkgs.sqlite} "${papraDatabase}" ".backup '${papraDatabaseSnapshot}'"
  '';

  environment.systemPackages = [
    restore-paperless
    restore-papra
  ];

  systemd = {
    timers."paperless-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "paperless-backup-daily.service";
      };
    };
    timers."paperless-backup-monthly" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        Unit = "paperless-backup-monthly.service";
      };
    };

    services."paperless-backup-daily" = {
      script = ''
        /run/current-system/sw/bin/paperless-manage document_exporter "${backupDirDaily}" -p -d
        /run/current-system/sw/bin/paperless-manage document_create_classifier
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
    services."paperless-backup-monthly" = {
      script = ''
        /run/current-system/sw/bin/paperless-manage document_exporter "${backupDirMonthly}" -z
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };
}
