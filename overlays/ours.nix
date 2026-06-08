{ outputs }:
final: _: {
  ours = outputs.packages.${final.stdenv.hostPlatform.system};
  inherit (outputs) lib;
}
