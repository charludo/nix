{
  lib,
  fetchFromGitHub,
  php,
}:

php.buildComposerProject2 (finalAttrs: {
  pname = "cabbage";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "katyarrow";
    repo = "cabbage.gay";
    rev = "a163d6b36e36d3e88cbc1099d9c4889f3760fccd";
    hash = "sha256-YCW06YfmVVsVrpYqXfK2xNB8cWhkpCmaPRs3KZ3mUjc=";
  };

  patches = [
    ./redirect-runtime-dirs.patch
    ./header-uses-app-name.patch
  ];

  vendorHash = "sha256-w5ARJYvMF3VpqXoTLPAaoIGF4zKruzc5ZfKTpkK61Cg=";

  composerNoDev = true;
  composerNoPlugins = false;
  composerStrictValidation = false;

  postInstall = ''
    chmod -R u+w $out/share
    mv $out/share/php/cabbage $out/cabbage-tmp
    mv $out/cabbage-tmp/{app,bootstrap,config,database,lang,public,resources,routes,storage,vendor,artisan,composer.json,composer.lock} $out/
    mv $out/cabbage-tmp/.env.example $out/env-upstream
    rm -rf $out/cabbage-tmp $out/share
  '';

  passthru = {
    inherit php;
  };

  meta = {
    description = "cabbage.gay — encrypted scheduling poll service (Laravel)";
    homepage = "https://github.com/katyarrow/cabbage.gay";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ charludo ];
    platforms = lib.platforms.linux;
  };
})
