"""Poll an IMAP mailbox and forward PDF attachments to Papra's intake email webhook.

Papra has no IMAP support; its intake emails expect a relay to POST each
mail to /api/intake-emails/ingest as multipart form data (the format of
@owlrelay/webhook): an `email` JSON field with from/to and one
`attachments[]` file per attachment, signed with an HMAC-SHA256 of the raw
body in the base64 `X-Signature` header.

Configuration is read from the environment, secrets from files (systemd
credentials).
"""

import base64
import email
import email.policy
import email.utils
import hashlib
import hmac
import imaplib
import json
import logging
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid

log = logging.getLogger("papra-imap-relay")

# sysexits EX_CONFIG: the unit is set up not to restart on it, so a wrong
# password does not hammer the mail server (and its fail2ban).
EXIT_CONFIG = 78


def env(name, default=None):
    value = os.environ.get(name, default)
    if value is None:
        log.error("missing required environment variable %s", name)
        sys.exit(EXIT_CONFIG)
    return value


def read_secret(name, env_key=None):
    """Read a secret file, either the bare secret or a `env_key=secret` environment file."""
    path = env(name)
    try:
        with open(path) as f:
            content = f.read().strip()
    except OSError as e:
        log.error("cannot read %s (%s): %s", name, path, e)
        sys.exit(EXIT_CONFIG)
    if env_key:
        for line in content.splitlines():
            key, sep, value = line.partition("=")
            if sep and key.strip() == env_key:
                return value.strip().strip("'\"")
    return content


def env_list(name):
    return [x.strip().lower() for x in os.environ.get(name, "").split(",") if x.strip()]


class Config:
    def __init__(self):
        self.imap_host = env("IMAP_HOST")
        self.imap_port = int(env("IMAP_PORT", "993"))
        self.imap_user = env("IMAP_USER")
        self.imap_password = read_secret("IMAP_PASSWORD_FILE")
        self.imap_folder = env("IMAP_FOLDER", "INBOX")
        # Folder to move handled mails to; empty keeps them, marked \Seen.
        self.done_folder = env("IMAP_DONE_FOLDER", "")
        self.webhook_url = env("WEBHOOK_URL")
        # Also accepts the environment file that sets Papra's own secret.
        self.webhook_secret = read_secret(
            "WEBHOOK_SECRET_FILE", "INTAKE_EMAILS_WEBHOOK_SECRET"
        ).encode()
        self.intake_address = env("INTAKE_ADDRESS")
        # Papra drops mails whose sender is not in the intake email's allowed
        # origins. Overriding it means only this one address needs allowing.
        self.sender_override = env("SENDER_OVERRIDE", "")
        self.allowed_senders = env_list("ALLOWED_SENDERS")
        self.filename_prefix = env("FILENAME_PREFIX", "")
        self.poll_interval = int(env("POLL_INTERVAL", "300"))


def pdf_attachments(msg):
    """Yield (filename, bytes) for every PDF part, including those of forwarded mails."""
    for part in msg.walk():
        if part.is_multipart():
            continue
        filename = part.get_filename()
        content_type = part.get_content_type()
        if content_type != "application/pdf" and not (
            filename and filename.lower().endswith(".pdf")
        ):
            continue
        payload = part.get_payload(decode=True)
        # Content types in mail are unreliable; trust the magic bytes.
        if not payload or payload.lstrip()[:5] != b"%PDF-":
            continue
        if not filename:
            filename = "attachment.pdf"
        elif not filename.lower().endswith(".pdf"):
            filename += ".pdf"
        yield filename, payload


def quote_header_value(value):
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "")
        .replace("\n", "")
    )


def multipart_body(email_json, files):
    boundary = uuid.uuid4().hex
    parts = [
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="email"\r\n\r\n',
        email_json.encode(),
        b"\r\n",
    ]
    for filename, content in files:
        parts += [
            f"--{boundary}\r\n".encode(),
            (
                'Content-Disposition: form-data; name="attachments[]"; '
                f'filename="{quote_header_value(filename)}"\r\n'
            ).encode(),
            b"Content-Type: application/pdf\r\n\r\n",
            content,
            b"\r\n",
        ]
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def post_to_papra(cfg, sender, files):
    email_json = json.dumps(
        {
            "from": {"address": sender},
            "to": [{"address": cfg.intake_address}],
            "originalTo": [],
        }
    )
    body, content_type = multipart_body(email_json, files)
    signature = base64.b64encode(
        hmac.new(cfg.webhook_secret, body, hashlib.sha256).digest()
    ).decode()
    request = urllib.request.Request(
        cfg.webhook_url,
        data=body,
        method="POST",
        headers={
            "Content-Type": content_type,
            "X-Signature": signature,
            "User-Agent": "papra-imap-relay",
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.status


def handle_message(cfg, raw):
    """Return True if the mail is done with (forwarded or nothing to forward)."""
    msg = email.message_from_bytes(raw, policy=email.policy.default)
    _, sender = email.utils.parseaddr(str(msg.get("From", "")))
    sender = sender.lower()
    subject = str(msg.get("Subject", ""))

    if cfg.allowed_senders and sender not in cfg.allowed_senders:
        log.info("skipping mail from %s (not an allowed sender): %s", sender, subject)
        return True

    files = [
        (cfg.filename_prefix + name, content) for name, content in pdf_attachments(msg)
    ]
    if not files:
        log.info("no PDF attachments in mail from %s: %s", sender, subject)
        return True

    try:
        status = post_to_papra(cfg, cfg.sender_override or sender, files)
    except urllib.error.HTTPError as e:
        log.error(
            "Papra rejected mail from %s (%s): HTTP %s %s",
            sender,
            subject,
            e.code,
            e.read()[:500],
        )
        return False
    except (urllib.error.URLError, OSError) as e:
        log.error("cannot reach Papra for mail from %s (%s): %s", sender, subject, e)
        return False

    log.info(
        "forwarded %d PDF(s) from %s (%s) to Papra: HTTP %s: %s",
        len(files),
        sender,
        subject,
        status,
        ", ".join(name for name, _ in files),
    )
    return True


def poll_once(cfg):
    context = ssl.create_default_context()
    with imaplib.IMAP4_SSL(
        cfg.imap_host, cfg.imap_port, ssl_context=context, timeout=60
    ) as imap:
        try:
            imap.login(cfg.imap_user, cfg.imap_password)
        except imaplib.IMAP4.error as e:
            log.error("IMAP login as %s failed, not retrying: %s", cfg.imap_user, e)
            sys.exit(EXIT_CONFIG)

        typ, _ = imap.select(cfg.imap_folder)
        if typ != "OK":
            log.error("cannot select IMAP folder %s", cfg.imap_folder)
            sys.exit(EXIT_CONFIG)

        if cfg.done_folder:
            imap.create(cfg.done_folder)  # fails harmlessly if it exists

        _, data = imap.uid("SEARCH", None, "UNSEEN")
        uids = data[0].split()
        for uid in uids:
            # PEEK keeps the mail unseen, so a failed forward is retried next poll.
            typ, fetched = imap.uid("FETCH", uid, "(BODY.PEEK[])")
            if typ != "OK" or not fetched or fetched[0] is None:
                log.error("cannot fetch mail %s", uid.decode())
                continue
            if not handle_message(cfg, fetched[0][1]):
                continue

            imap.uid("STORE", uid, "+FLAGS", "(\\Seen)")
            if cfg.done_folder:
                typ, _ = imap.uid("MOVE", uid, cfg.done_folder)
                if typ != "OK":
                    imap.uid("COPY", uid, cfg.done_folder)
                    imap.uid("STORE", uid, "+FLAGS", "(\\Deleted)")
                    imap.expunge()


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    cfg = Config()
    log.info(
        "polling %s@%s/%s every %ss, forwarding to %s as %s",
        cfg.imap_user,
        cfg.imap_host,
        cfg.imap_folder,
        cfg.poll_interval,
        cfg.webhook_url,
        cfg.intake_address,
    )
    backoff = cfg.poll_interval
    while True:
        try:
            poll_once(cfg)
            backoff = cfg.poll_interval
        except (TimeoutError, imaplib.IMAP4.error, OSError) as e:
            backoff = min(backoff * 2, 3600)
            log.error("IMAP error, retrying in %ss: %s", backoff, e)
        time.sleep(backoff)


if __name__ == "__main__":
    main()
