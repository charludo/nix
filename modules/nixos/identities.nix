{ lib, ... }:

with lib;

{
  options.users.users = mkOption {
    type =
      with types;
      attrsOf (submodule {
        options.identities = mkOption {
          type =
            with lib.types;
            attrsOf (
              submodule (
                { config, ... }:
                {
                  options = {
                    serial = mkOption {
                      type = types.nullOr types.int;
                      default = null;
                      description = "The serial number of the Yubikey managing this identity";
                    };
                    privateKeyFile = mkOption {
                      type = types.path;
                      description = "The private key file associated with the identity";
                    };
                    publicKeyFile = mkOption {
                      type = types.path;
                      description = "The public key file associated with the identity";
                    };
                    publicKey = mkOption {
                      type = types.str;
                      default = "";
                      description = "The public key associated with this identity";
                    };
                    keyType = mkOption {
                      type = types.enum [
                        "ssh"
                        "age"
                      ];
                      default = "ssh";
                      description = "The type of this identity";
                    };
                  };
                  config = {
                    publicKey = mkIf (config.publicKeyFile != null) (builtins.readFile config.publicKeyFile);
                  };
                }
              )
            );
          default = { };
          description = "A set of identities";
        };
      });
  };
}
