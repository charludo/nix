"""CLI: apply a JSON dict of tuning parameters to the ReSpeaker."""

import argparse
import json
import logging
import sys

from . import tuning


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config", help="path to JSON file with {name: value} pairs")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    log = logging.getLogger("respeaker-tuning-apply")

    with open(args.config) as f:
        params = json.load(f)

    if not params:
        log.info("no tuning parameters configured; nothing to do")
        return 0

    dev = tuning.find()
    if dev is None:
        log.error("ReSpeaker Mic Array v2.0 not found on USB")
        return 1

    try:
        for name, value in params.items():
            dev.write(name, value)
            log.info("set %s=%s", name, value)
    finally:
        dev.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
