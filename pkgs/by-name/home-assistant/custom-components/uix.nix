{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  nix-update-script,
}:

buildHomeAssistantComponent (finalAttrs: {
  owner = "Lint-Free-Technology";
  domain = "uix";
  version = "8.3.1";

  src = fetchFromGitHub {
    owner = "Lint-Free-Technology";
    repo = "uix";
    tag = "v${finalAttrs.version}";
    hash = "sha256-X6Jp9XeAzh1fGVleQGM/OYbuW6eDFxVUDxwp2m7qY/k=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    name = "uix-${finalAttrs.version}-npm-deps";
    hash = "sha256-FpMqvOgHGuBQMloc/bd7Z/KqELZLNPwatBHjgX/8oY0=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  # drop the prebuilt bundles checked into the repo, so the build regenerates them
  postPatch = ''
    rm custom_components/uix/*.js custom_components/uix/*.js.gz
  '';

  # `npm run build` also stamps package.json's version into manifest.json and
  # gzips the bundles, which Home Assistant's static file handler serves
  buildPhase = ''
    runHook preBuild

    npm run build

    runHook postBuild
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "UI eXtension for Home Assistant, the successor of card-mod";
    homepage = "https://github.com/Lint-Free-Technology/uix";
    changelog = "https://github.com/Lint-Free-Technology/uix/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ charludo ];
  };
})
