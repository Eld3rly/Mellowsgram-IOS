#!/usr/bin/env python3
"""Publish a prepared device IPA to the Mellowsgram AltSource on amd1.

The IPA is uploaded to the staging directory by GitHub Actions. This script
checks its metadata, moves it into the public directory, then atomically
updates the catalogue. It never needs Telegram or Apple credentials.
"""

import argparse
import datetime
import json
import os
import plistlib
import re
import tempfile
import zipfile
from pathlib import Path


ROOT = Path("/srv/mellowsgram-testsource")
BASE_URL = "https://testsource.mellowsgram.cc"
BUNDLE_ID = "com.mellowsgram.ios"
MAX_VERSIONS = 5


def publish(staged_ipa: Path, run_id: str, commit: str) -> Path:
    staged_ipa = staged_ipa.resolve(strict=True)
    if staged_ipa.parent != (ROOT / "staging").resolve():
        raise ValueError("IPA must be in the test source staging directory")
    if not re.fullmatch(r"[0-9]+", run_id):
        raise ValueError("invalid Actions run ID")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("invalid commit SHA")

    with zipfile.ZipFile(staged_ipa) as archive:
        info = plistlib.loads(archive.read("Payload/Telegram.app/Info.plist"))
        damaged_member = archive.testzip()
        if damaged_member is not None:
            raise ValueError(f"damaged IPA member: {damaged_member}")

    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise ValueError("unexpected bundle identifier")
    if "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", []):
        raise ValueError("not a device IPA")

    version = str(info["CFBundleShortVersionString"])
    build = str(info["CFBundleVersion"])
    if not re.fullmatch(r"[A-Za-z0-9._-]+", version) or not re.fullmatch(r"[0-9]+", build):
        raise ValueError("invalid IPA version")

    filename = f"Mellowsgram-{version}-{build}.ipa"
    destination = ROOT / "ipa" / filename
    os.replace(staged_ipa, destination)
    destination.chmod(0o644)

    privacy = {
        key: value
        for key, value in info.items()
        if key.endswith("UsageDescription") and isinstance(value, str)
    }
    release = {
        "version": version,
        "buildVersion": build,
        "marketingVersion": f"{version} (indev {build})",
        "date": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "localizedDescription": f"Test build {build} from commit {commit[:12]} (Actions run {run_id}). Features may be unstable.",
        "downloadURL": f"{BASE_URL}/ipa/{filename}",
        "size": destination.stat().st_size,
        "minOSVersion": str(info["MinimumOSVersion"]),
    }

    source_path = ROOT / "source.json"
    if source_path.exists():
        source = json.loads(source_path.read_text(encoding="utf-8"))
    else:
        source = {
            "name": "Mellowsgram Test Builds",
            "subtitle": "Development builds for iOS",
            "description": "Unofficial Mellowsgram test builds from the indev branch. Features can be incomplete or unstable.",
            "iconURL": f"{BASE_URL}/icon.png",
            "website": "https://github.com/Eld3rly/Mellowsgram-IOS",
            "tintColor": "#B99BE9",
            "apps": [],
            "news": [],
        }

    apps = source.setdefault("apps", [])
    app = next((value for value in apps if value.get("bundleIdentifier") == BUNDLE_ID), None)
    if app is None:
        app = {"bundleIdentifier": BUNDLE_ID, "versions": []}
        apps.insert(0, app)
    app.update({
        "name": "Mellowsgram",
        "developerName": "Mellowsgram",
        "subtitle": "Telegram iOS client · test build",
        "localizedDescription": "Development build from indev. Install with AltStore or SideStore; stability is not guaranteed.",
        "iconURL": f"{BASE_URL}/icon.png",
        "tintColor": "#B99BE9",
        "category": "social",
        # ci/mellowsgram_sideload.py re-signs the app and extensions with
        # this app group. AltStore omits application/team identifiers here.
        "appPermissions": {
            "entitlements": ["com.apple.security.application-groups"],
            "privacy": privacy,
        },
    })
    versions = [release] + [
        value for value in app.get("versions", [])
        if value.get("buildVersion") != build
    ]
    versions.sort(key=lambda value: int(value["buildVersion"]), reverse=True)
    app["versions"] = versions[:MAX_VERSIONS]

    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=ROOT, prefix=".source-", delete=False) as output:
        json.dump(source, output, ensure_ascii=False, indent=2)
        output.write("\n")
        temporary_path = Path(output.name)
    temporary_path.chmod(0o644)
    os.replace(temporary_path, source_path)
    for old_release in versions[MAX_VERSIONS:]:
        url = old_release.get("downloadURL", "")
        prefix = f"{BASE_URL}/ipa/"
        if url.startswith(prefix):
            old_filename = url[len(prefix):]
            if re.fullmatch(r"Mellowsgram-[A-Za-z0-9._-]+-[0-9]+\.ipa", old_filename):
                (ROOT / "ipa" / old_filename).unlink(missing_ok=True)
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    destination = publish(args.ipa, args.run_id, args.commit)
    print(f"Published {destination.name} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
