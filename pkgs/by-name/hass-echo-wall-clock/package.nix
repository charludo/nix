{
  lib,
  buildHomeAssistantComponent,
  home-assistant,
  runCommand,
  ruff,
}:
let
  # Developed in this repo for now; moves to its own repo once it settles.
  src = lib.fileset.toSource {
    root = ../../../hass-echo-wall-clock;
    fileset = lib.fileset.difference ../../../hass-echo-wall-clock (
      lib.fileset.fileFilter (f: f.hasExt "pyc") ../../../hass-echo-wall-clock
    );
  };

  # From Home Assistant's own package set, so they match what it runs with.
  dependencies = with home-assistant.python3Packages; [ dbus-fast ];

  # Home Assistant itself as a library, for the tests against a real core.
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
    runCommand "hass-echo-wall-clock-${name}" { nativeBuildInputs = [ testPython ]; } ''
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
  domain = "echo_wall_clock";
  version = "0.1.0";
  inherit src dependencies;

  passthru.tests = {
    # The protocol and the clock's sessions, no Home Assistant.
    unit = runTests "unit" "python -m pytest -q -p no:cacheprovider -o asyncio_mode=auto tests";
    # Setup, actions, entities and events on a real core, BlueZ simulated.
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
    description = "Echo Wall Clock timers, alarms and reminders in Home Assistant, without an Echo";
    license = lib.licenses.agpl3Only;
  };
}
