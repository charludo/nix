{ config, pkgs, ... }:
pkgs.writers.writePython3Bin "waybar-mail" { libraries = [ ]; } # python
  ''
    import imaplib
    import configparser

    accounts = configparser.RawConfigParser()
    accounts.read("${config.age.secrets.waybar-mail.path}")
    strFormatted = ""


    def check_imap(imap_account):
        if imap_account["useSSL"] == "true":
            # pylint: disable=line-too-long
            client = imaplib.IMAP4_SSL(
              imap_account["host"], int(imap_account["port"]))
        else:
            client = imaplib.IMAP4(imap_account["host"], int(imap_account["port"]))
        client.login(imap_account["login"], imap_account["password"])
        if "folder" in imap_account:
            client.select(imap_account["folder"])
        else:
            client.select()
        return len(client.search(None, "UNSEEN")[1][0].split())


    has_mail = False
    for account in accounts:
        currentAccount = accounts[account]
        if account == "DEFAULT":
            continue
        if not currentAccount["icon"]:
            icon = accounts["DEFAULT"]["icon"]
        else:
            icon = currentAccount["icon"]
        unread = check_imap(currentAccount)
        if unread > 0:
            has_mail = True
            strFormatted += str(unread) + " " + icon + "     "
    if has_mail:
        print(strFormatted.strip() + " ")
    else:
        print()
  ''
