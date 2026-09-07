{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  python3,
  pkg-config,
  autoPatchelfHook,
  makeWrapper,
  stdenv,
}:

buildNpmPackage (finalAttrs: {
  pname = "trek";
  version = "4.2.1";

  src = fetchFromGitHub {
    owner = "liketrek";
    repo = "TREK";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qIuJOAzqYNIH9JdKe/YkInh+qQjOJigcZQD4/6r66AM=";
  };

  npmDepsHash = "sha256-2iTyYCgOycMoBkUs0PwBNihscvF9EjNvVF3uwtWSqME=";

  inherit nodejs;

  nativeBuildInputs = [
    # better-sqlite3 is compiled from source, see npm_config_build_from_source
    python3
    pkg-config
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  env = {
    npm_config_build_from_source = "true";
  };
  autoPatchelfIgnoreMissingDeps = true;
  dontCheckForBrokenSymlinks = true;

  buildPhase = ''
    runHook preBuild

    for tree in client server shared; do
      if [ -d "$tree/node_modules" ]; then
        patchShebangs "$tree/node_modules"
      fi
    done

    npm run build --workspace=shared
    npm run build --workspace=server
    npm run build --workspace=client

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app=$out/share/trek
    mkdir -p $app/server

    npm ci --workspace=server --omit=dev

    rm -rf node_modules/@trek/client
    rm -rf node_modules/sharp node_modules/@img
    rm -rf node_modules/@napi-rs/canvas-linux-x64-musl

    cp -a node_modules $app/node_modules
    cp package.json $app/

    mkdir -p $app/shared
    cp -a shared/dist $app/shared/dist
    cp shared/package.json $app/shared/

    cp -a server/dist server/assets $app/server/
    cp server/package.json server/tsconfig.json $app/server/

    mkdir -p $app/server/scripts
    cp server/scripts/migrate-encryption.ts $app/server/scripts/
    cp server/reset-admin.js $app/server/

    cp -a client/dist $app/server/public
    cp -a client/public/fonts $app/server/public/fonts

    cp -a wiki $app/wiki

    ln -s ../../data $app/server/data
    ln -s ../../uploads $app/server/uploads

    makeWrapper ${lib.getExe nodejs} $out/bin/trek \
      --add-flags "--require tsconfig-paths/register" \
      --add-flags "dist/index.js"

    runHook postInstall
  '';

  dontStrip = true;

  meta = {
    description = "Self-hosted collaborative travel and trip planner";
    longDescription = "A self-hosted travel/trip planner with real-time collaboration, interactive maps, PWA support, SSO, budgets, packing lists, and more.";
    homepage = "https://liketrek.com";
    downloadPage = "https://github.com/liketrek/TREK";
    changelog = "https://github.com/liketrek/TREK/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "trek";
    maintainers = with lib.maintainers; [ charludo ];
    platforms = lib.platforms.linux;
  };
})
