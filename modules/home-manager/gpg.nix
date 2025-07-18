{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gpg;
in
{
  options.gpg.enable = lib.mkEnableOption "custom gpg";

  config = lib.mkIf cfg.enable {
    programs.gpg = {
      enable = true;

      scdaemonSettings = {
        disable-ccid = true;
      };

      settings = {
        personal-cipher-preferences = "AES256 AES192 AES";
        personal-digest-preferences = "SHA512 SHA384 SHA256";
        personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
        default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
        cert-digest-algo = "SHA512";
        s2k-digest-algo = "SHA512";
        s2k-cipher-algo = "AES256";
        charset = "utf-8";
        fixed-list-mode = true;
        no-comments = true;
        no-emit-version = true;
        keyid-format = "0xlong";
        list-options = "show-uid-validity";
        verify-options = "show-uid-validity";
        with-fingerprint = true;
        require-cross-certification = true;
        no-symkey-cache = true;
        use-agent = true;
        throw-keyids = true;
      };
    };

    services.gpg-agent = {
      enable = true;

      defaultCacheTtl = 60;
      maxCacheTtl = 120;
      pinentry.package = pkgs.pinentry-rofi;
      extraConfig = ''
        ttyname $GPG_TTY
      '';
    };
  };
}
