{
  imports = [
    ../../../charlotte/home/common/cli/bat.nix
    ../../../charlotte/home/common/cli/fzf.nix
  ];

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    matchBlocks = {
      "*" = {
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };
    };
  };
}
