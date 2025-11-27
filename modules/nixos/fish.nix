{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.fish;
in
{
  options.fish = {
    enable = lib.mkEnableOption "fish shell and make user default";
  };

  config = mkIf cfg.enable {
    programs.fish.enable = true;
    programs.fish.promptInit = # fish
      ''
        if not functions -q tide
          function fish_prompt
            set -l last_status $status
            set -l stat
            if test $last_status -ne 0
              set stat (set_color red)"[$last_status]"(set_color normal)
            end

            set -l endprompt
            if [ (whoami) = "root" ]
              echo -n (set_color red)
              set endprompt (set_color red)'# '(set_color normal)
            else 
              echo -n (set_color green)
              set endprompt (set_color green)'$ '(set_color normal)
            end

            string join ''' -- '[' (whoami) '@' (hostname) ':' (prompt_pwd) ']' $stat $endprompt
          end
        end
      '';
    users.defaultUserShell = pkgs.fish;
  };
}
