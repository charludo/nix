{ outputs }:
final: _: {
  ours = outputs.packages.${final.stdenv.hostPlatform.system};
  lib = outputs.lib;
}
