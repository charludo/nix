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
  age.secrets.charlotte-password.rekeyFile = secrets.charlotte-password;
  age.secrets.yubikey-sudo.rekeyFile = secrets.yubikey-sudo;
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
      charlotte.publicKeyFile = ./ssh.pub;

      diziet = {
        publicKeyFile = ./diziet_ssh.pub;
        privateKeyFile = config.age.secrets.yubikey-diziet-ssh.path;
        serial = private-settings.yubikeys.diziet.serial;
      };
      diziet_age = {
        publicKeyFile = ./diziet_age.pub;
        privateKeyFile = private-settings.yubikeys.diziet.identityFile;
        serial = private-settings.yubikeys.diziet.serial;
        keyType = "age";
      };

      perostek = {
        publicKeyFile = ./perostek_ssh.pub;
        privateKeyFile = config.age.secrets.yubikey-perostek-ssh.path;
        serial = private-settings.yubikeys.perostek.serial;
      };
      perostek_age = {
        publicKeyFile = ./perostek_age.pub;
        privateKeyFile = private-settings.yubikeys.perostek.identityFile;
        serial = private-settings.yubikeys.perostek.serial;
        keyType = "age";
      };

      zakalwe = {
        publicKeyFile = ./zakalwe_ssh.pub;
        privateKeyFile = config.age.secrets.yubikey-zakalwe-ssh.path;
        serial = private-settings.yubikeys.zakalwe.serial;
      };
      zakalwe_age = {
        publicKeyFile = ./zakalwe_age.pub;
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
    enable = true;
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
