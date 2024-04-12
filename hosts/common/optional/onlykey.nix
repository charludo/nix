{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ onlykey onlykey-cli ];
  services.udev.extraRules = builtins.readFile (builtins.fetchurl {
    url = "https://raw.githubusercontent.com/trustcrypto/trustcrypto.github.io/pages/49-onlykey.rules";
    sha256 = "sha256:1pj9i4hp0d74073x1qqwigd0cyriamg65zmx2j98mi0k66qrhcxa";
  });
}
