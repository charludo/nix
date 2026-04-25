{
  config,
  lib,
  private-settings,
  ...
}:
let
  cfg = config.vm;
in
{
  options.vm.unsupervisedUpdates = lib.mkEnableOption "unsupervised nightly updates of this VM";

  config = {
    system.autoUpgrade = {
      enable = cfg.unsupervisedUpdates || builtins.elem "stateless" config.snow.tags;

      flake = "git+https://${private-settings.flakeRepo}?submodules=1#${config.vm.name}";
      upgrade = false;

      dates = "03:00";
      randomizedDelaySec = "2h";
      fixedRandomDelay = true;
      persistent = false;

      allowReboot = true;
      rebootWindow = {
        lower = "03:00";
        upper = "05:00";
      };
    };
  };
}
