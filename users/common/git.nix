{
  programs.git = {
    enable = true;
    ignores = [
      "Session.vim"
      "main.shada"
      ".envrc"
      ".direnv"
      ".venv"
      ".dmypy.json"
    ];
    extraConfig = {
      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = true;
      };
      push = {
        autoSetupRemote = true;
      };
    };
  };
}
