{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.postgresql-collation;
  pg = config.services.postgresql;
in
{
  options.postgresql-collation = {
    enable =
      mkEnableOption "reindexing databases whose collation version changed after a glibc update"
      // {
        default = pg.enable;
        defaultText = literalExpression "config.services.postgresql.enable";
      };
  };

  config = mkIf cfg.enable {
    systemd.services.postgresql-collation-refresh = {
      description = "Reindex PostgreSQL databases with a stale collation version";

      wantedBy = [ "postgresql.target" ];
      requires = [ "postgresql.service" ];
      after = [
        "postgresql.service"
        "postgresql-setup.service"
      ];

      serviceConfig = {
        User = "postgres";
        Group = "postgres";
        Type = "oneshot";
        RemainAfterExit = true;
      };

      path = [ pg.finalPackage ];
      environment.PGPORT = toString pg.settings.port;

      script = ''
        in_recovery=$(psql -XtA -d postgres -c "select pg_is_in_recovery()")
        if [[ $in_recovery == t ]]; then
          echo "Skipping because PostgreSQL is in recovery"
          exit 0
        fi

        failed=0
        databases=$(psql -XtA -d postgres -c "select datname from pg_database where datallowconn")
        mapfile -t databases <<<"$databases"
        for db in "''${databases[@]}"; do
          stale=$(psql -XtA -d postgres -v db="$db" <<<"select datcollversion <> pg_database_collation_actual_version(oid) from pg_database where datname = :'db'")
          [[ $stale == t ]] || continue

          echo "$db: collation version changed, reindexing"
          if ! psql -X -v ON_ERROR_STOP=1 -d "$db" -v db="$db" <<<'
            REINDEX DATABASE :"db";
            ALTER DATABASE :"db" REFRESH COLLATION VERSION;
          '; then
            echo "$db: reindex failed, collation version left stale" >&2
            failed=1
          fi
        done
        exit $failed
      '';
    };
  };
}
