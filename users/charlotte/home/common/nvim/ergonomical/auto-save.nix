{
  programs.nixvim.plugins.auto-save = {
    enable = true;
    debounceDelay = 250;
    triggerEvents = [ "InsertLeave" ];
  };
}
