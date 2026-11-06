{
  lib,
  buildHomeAssistantComponent,
  home-assistant,
  dejavu_fonts,
  dbus,
  nodejs,
  src,
}:
let
  manifest = lib.importJSON "${src}/custom_components/brother_ptouch/manifest.json";
  inherit (home-assistant) python3Packages;

  # Need the Home Assistant pytest plugin, which blocks real sockets: the core
  # tests (the bridge's HTTP server among them) run without it.
  haTests = [
    "tests/test_ha.py"
    "tests/test_bluetooth_ha.py"
    "tests/test_editor_api.py"
    "tests/test_frontend_contract.py"
  ];
in
buildHomeAssistantComponent {
  owner = "thatgoodpickle";
  domain = "brother_ptouch";
  inherit (manifest) version;
  inherit src;

  postPatch = ''
    # DejaVu is looked up at FHS paths (other weights next to it); else Pillow's bitmap font
    substituteInPlace custom_components/brother_ptouch/ptouch/render.py \
      --replace-fail '"/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",' \
                     '"${dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf",'
    # the asset tests look for it the same way, and skip without it
    substituteInPlace tests/test_assets.py \
      --replace-fail '"/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",' \
                     '"${dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf",'
    # nixpkgs' dbus-daemon expects its session config in /etc, missing in the sandbox
    substituteInPlace tests/fake_bluez.py \
      --replace-fail '"--session",' '"--config-file=${dbus}/share/dbus-1/session.conf",'
  '';

  dependencies = with python3Packages; [
    dbus-fast
    pillow
    python-barcode
    pyusb
    segno
  ];

  # frontend/dev is test and screenshot tooling, not part of the panel; the checks still need it.
  postInstall = ''
    rm -r $out/custom_components/brother_ptouch/frontend/dev
  '';

  doCheck = true;
  nativeCheckInputs =
    (with python3Packages; [
      (toPythonModule home-assistant)
      home-assistant-frontend
      pytest
      pytest-asyncio
      pytest-homeassistant-custom-component
    ])
    ++ [
      dbus # the BlueZ tests run a fake org.bluez on a private dbus-daemon
      nodejs
    ];

  checkPhase = ''
    runHook preCheck

    export HOME=$TMPDIR

    # test_icon_with_fake_and_missing_assets needs DejaVu at an FHS path.
    python -m pytest -q -p no:cacheprovider -p no:homeassistant tests \
      ${lib.concatMapStringsSep " " (t: "--ignore=${t}") haTests} \
      --deselect tests/test_design.py::test_icon_with_fake_and_missing_assets
    # test_bad_request_fails_alone is racy in the full suite, upstream as well (~1 in 4 runs).
    PYTHONPATH=.:$PYTHONPATH python -m pytest -q -p no:cacheprovider ${toString haTests} \
      --deselect tests/test_ha.py::test_bad_request_fails_alone

    for t in custom_components/brother_ptouch/frontend/dev/tests/test_*.mjs; do
      node "$t"
    done

    runHook postCheck
  '';

  meta = {
    description = "Brother P-touch label printer integration with a label editor panel";
    homepage = "https://github.com/thatgoodpickle/haos-labelprinter";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ charludo ];
  };
}
