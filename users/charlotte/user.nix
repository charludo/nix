{
  pkgs,
  lib,
  config,
  secrets,
  private-settings,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  age.secrets.charlotte-ssh.rekeyFile = secrets.charlotte-ssh;
  age.secrets.charlotte-password.rekeyFile = secrets.charlotte-password;
  age.secrets.yubikey-diziet-ssh.rekeyFile = secrets.yubikey-diziet-ssh;
  age.secrets.yubikey-perostek-ssh.rekeyFile = secrets.yubikey-perostek-ssh;
  age.secrets.yubikey-zakalwe-ssh.rekeyFile = secrets.yubikey-zakalwe-ssh;

  users.users.charlotte = {
    isNormalUser = true;
    shell = pkgs.fish;

    uid = 1000;
    group = "charlotte";
    extraGroups =
      [
        "wheel"
        "video"
        "audio"
        "networkmanager"
        "nas"
      ]
      ++ ifTheyExist [
        "docker"
        "git"
      ];

    identities = {
      charlotte = {
        publicKeyFile = ./keys/ssh.pub;
        privateKeyFile = config.age.secrets.charlotte-ssh.path;
      };

      diziet = {
        publicKeyFile = ./keys/diziet_ssh.pub;
        privateKeyFile = config.age.secrets.yubikey-diziet-ssh.path;
        serial = private-settings.yubikeys.diziet.serial;
      };
      diziet_age = {
        publicKeyFile = ./keys/diziet_age.pub;
        privateKeyFile = private-settings.yubikeys.diziet.identityFile;
        serial = private-settings.yubikeys.diziet.serial;
        keyType = "age";
      };

      perostek = {
        publicKeyFile = ./keys/perostek_ssh.pub;
        privateKeyFile = config.age.secrets.yubikey-perostek-ssh.path;
        serial = private-settings.yubikeys.perostek.serial;
      };
      perostek_age = {
        publicKeyFile = ./keys/perostek_age.pub;
        privateKeyFile = private-settings.yubikeys.perostek.identityFile;
        serial = private-settings.yubikeys.perostek.serial;
        keyType = "age";
      };

      zakalwe = {
        publicKeyFile = ./keys/zakalwe_ssh.pub;
        privateKeyFile = config.age.secrets.yubikey-zakalwe-ssh.path;
        serial = private-settings.yubikeys.zakalwe.serial;
      };
      zakalwe_age = {
        publicKeyFile = ./keys/zakalwe_age.pub;
        privateKeyFile = private-settings.yubikeys.zakalwe.identityFile;
        serial = private-settings.yubikeys.zakalwe.serial;
        keyType = "age";
      };
    };

    openssh.authorizedKeys.keys = lib.map (id: id.publicKey) (
      lib.attrValues (
        lib.filterAttrs (_: id: id.keyType == "ssh") config.users.users.charlotte.identities
      )
    );

    hashedPasswordFile = config.age.secrets.charlotte-password.path;

    packages = with pkgs; [
      home-manager
      git
    ];
  };

  yubikey = {
    enable = lib.mkDefault true;
    identities = config.users.users.charlotte.identities;
    sshDir = "${config.users.users.charlotte.home}/.ssh";
    sudoAuthFile = config.age.secrets.yubikey-sudo.path;
  };

  users.groups.charlotte.gid = 1000;

  security.sudo.extraRules = [
    {
      users = [ "charlotte" ];
      commands = [
        {
          command = "ALL";
          options = [ "SETENV" ];
        }
      ];
    }
  ];

  home-manager.users.charlotte = import ./home/${config.networking.hostName}.nix;
  environment.shells = with pkgs; [
    fish
    bash
  ];
}
