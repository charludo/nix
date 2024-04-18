{
  _module.args.defaultUser = "paki";
  imports =
    [
      ../common/optional/vmify.nix

      ../common/global
      ../common/optional/nvim.nix

      ../../users/paki/user.nix
    ];

  enableNas = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "SRV-PAPERLESS";
    interfaces = {
      ens18.ipv4.addresses = [{
        address = "192.168.20.37";
        prefixLength = 27;
      }];
    };
    defaultGateway = "192.168.20.34";
    firewall = {
      allowedTCPPorts = [ 5432 6379 8000 ];
      allowedUDPPorts = [ 5432 6379 8000 ];
    };
  };

  services.qemuGuest.enable = true;

  services.paperless = {
    enable = true;
    mediaDir = "";
    dataDir = "";
    consumptionDir = "";
    consumptionDirIsPublic = true;
    address = "paperless.paki.place";
    port = 8000;
    openMPThreadingWorkaround = true;
    settings = {
      PAPERLESS_CONSUMER_IGNORE_PATTERN = [
        ".DS_STORE/*"
        "desktop.ini"
      ];
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };
    };
  };

  system.stateVersion = "23.11";
}
