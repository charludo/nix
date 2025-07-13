{ lib, ... }:

with lib;

{
  options.users.users = mkOption {
    description = "extension of users.users";
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
                      description = "the serial number of the Yubikey managing this identity";
                    };
                    privateKeyFile = mkOption {
                      type = types.path;
                      description = "the private key file associated with the identity";
                    };
                    publicKeyFile = mkOption {
                      type = types.path;
                      description = "the public key file associated with the identity";
                    };
                    publicKey = mkOption {
                      type = types.str;
                      default = "";
                      description = "the public key associated with this identity";
                    };
                    keyType = mkOption {
                      type = types.enum [
                        "ssh"
                        "age"
                      ];
                      default = "ssh";
                      description = "the type of this identity";
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
