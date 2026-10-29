{
  lib,
  buildHomeAssistantComponent,
  home-assistant,
  duckling,
  radicale,
  runCommand,
  ruff,
}:
let
  # Developed in this repo for now; moves to its own repo once it settles.
  src = lib.fileset.toSource {
    root = ../../../hass-remembrance;
    fileset = lib.fileset.difference ../../../hass-remembrance (
      lib.fileset.fileFilter (f: f.hasExt "pyc") ../../../hass-remembrance
    );
  };

  # From Home Assistant's own package set, so they match what it runs with.
  dependencies = with home-assistant.python3Packages; [
    caldav
    icalendar
    recurring-ical-events
  ];

  # Home Assistant itself as a library, for the tests against a real core;
  # Radicale as the CalDAV server they talk to, Duckling to read sentences.
  testPython = home-assistant.python3Packages.python.withPackages (
    ps:
    [
      (ps.toPythonModule home-assistant)
      ps.pytest
      ps.pytest-asyncio
    ]
    ++ dependencies
  );

  runTests =
    name: command:
    runCommand "hass-remembrance-${name}"
      {
        nativeBuildInputs = [
          testPython
          radicale
          duckling
        ];
      }
      ''
        cp -r ${src} work
        chmod -R u+w work
        cd work
        export HOME=$TMPDIR
        ${command}
        touch $out
      '';
in
buildHomeAssistantComponent {
  owner = "charludo";
  domain = "remembrance";
  version = "0.1.0";
  inherit src dependencies;

  passthru.tests = {
    # The pure core, no Home Assistant.
    unit = runTests "unit" "python -m pytest -q -p no:cacheprovider tests";
    # Services, entities and events on a real Home Assistant core.
    ha = runTests "ha" ''
      cd tests_ha
      python -m pytest -q -p no:cacheprovider -o asyncio_mode=auto -o filterwarnings= .
    '';
    lint = runTests "lint" ''
      ${lib.getExe ruff} check .
      ${lib.getExe ruff} format --check .
    '';
  };

  meta = {
    description = "Central timers, reminders and alarms for Home Assistant";
    license = lib.licenses.agpl3Only;
  };
}
