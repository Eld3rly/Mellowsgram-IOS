#!/usr/bin/env python3
"""Generate a local Mellowsgram build configuration from environment values.

The generated JSON belongs in build-input/ and is intentionally ignored by git.
APPLE_TEAM_ID may be omitted for a completely unsigned local device build; when
present, it is used to generate valid application-identifier entitlements.
"""

import argparse
import json
import os
from pathlib import Path
import re
import sys


API_ID_PATTERN = re.compile(r"[1-9][0-9]{0,9}\Z")
API_HASH_PATTERN = re.compile(r"[0-9a-fA-F]{32}\Z")
TEAM_ID_PATTERN = re.compile(r"[A-Z0-9]{10}\Z")
BUNDLE_ID_PATTERN = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\Z")


def build_configuration(environment, require_team_id=False):
    values = {
        "api_id": environment.get("TELEGRAM_API_ID", "").strip(),
        "api_hash": environment.get("TELEGRAM_API_HASH", "").strip(),
        "team_id": environment.get("APPLE_TEAM_ID", "").strip().upper(),
        "bundle_id": environment.get("APP_BUNDLE_ID", "com.mellowsgram.ios").strip(),
        "url_scheme": environment.get("APP_URL_SCHEME", "mellowsgram").strip(),
    }

    missing = []
    for key in ("api_id", "api_hash"):
        if not values[key]:
            missing.append("TELEGRAM_" + key.upper())
    if require_team_id and not values["team_id"]:
        missing.append("APPLE_TEAM_ID")
    if missing:
        raise ValueError("Missing configuration values: " + ", ".join(missing))

    if not API_ID_PATTERN.fullmatch(values["api_id"]):
        raise ValueError("Invalid TELEGRAM_API_ID format")
    if int(values["api_id"]) > 2147483647:
        raise ValueError("TELEGRAM_API_ID exceeds Int32")
    if not API_HASH_PATTERN.fullmatch(values["api_hash"]):
        raise ValueError("Invalid TELEGRAM_API_HASH format")
    if not BUNDLE_ID_PATTERN.fullmatch(values["bundle_id"]):
        raise ValueError("Invalid APP_BUNDLE_ID format")
    if values["team_id"] and not TEAM_ID_PATTERN.fullmatch(values["team_id"]):
        raise ValueError("Invalid APPLE_TEAM_ID format")
    if not values["url_scheme"] or not re.fullmatch(r"[A-Za-z][A-Za-z0-9+.-]*", values["url_scheme"]):
        raise ValueError("Invalid APP_URL_SCHEME format")

    return {
        "bundle_id": values["bundle_id"],
        "api_id": values["api_id"],
        "api_hash": values["api_hash"],
        "team_id": values["team_id"],
        "is_internal_build": "true",
        "is_appstore_build": "false",
        "appstore_id": "0",
        "app_specific_url_scheme": values["url_scheme"],
        "premium_iap_product_id": "",
        "enable_siri": False,
        "enable_icloud": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Ignored JSON path under build-input/")
    parser.add_argument("--api-id")
    parser.add_argument("--api-hash")
    parser.add_argument("--team-id")
    parser.add_argument("--bundle-id")
    parser.add_argument("--url-scheme")
    parser.add_argument(
        "--require-team-id",
        action="store_true",
        help="Fail unless APPLE_TEAM_ID is set; use this for a pre-entitled IPA.",
    )
    args = parser.parse_args()

    environment = dict(os.environ)
    overrides = {
        "TELEGRAM_API_ID": args.api_id,
        "TELEGRAM_API_HASH": args.api_hash,
        "APPLE_TEAM_ID": args.team_id,
        "APP_BUNDLE_ID": args.bundle_id,
        "APP_URL_SCHEME": args.url_scheme,
    }
    for key, value in overrides.items():
        if value is not None:
            environment[key] = value

    try:
        configuration = build_configuration(environment, require_team_id=args.require_team_id)
    except ValueError as error:
        print("Mellowsgram configuration error: {}".format(error), file=sys.stderr)
        return 2

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(configuration, indent=2) + "\n", encoding="utf-8")
    args.output.chmod(0o600)
    print("Wrote Mellowsgram configuration to {}".format(args.output))
    if not configuration["team_id"]:
        print("Warning: APPLE_TEAM_ID is empty; application-identifier will be added during re-signing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
