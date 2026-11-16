#!/usr/bin/env python3
"""Embed sideload entitlements and ad-hoc sign a device IPA.

This mirrors the AyuGram sideload preparation step. The output is still not
installable as-is on a device: AltStore/SideStore must re-sign it with the
user's certificate and provisioning profile.
"""

import argparse
import os
import plistlib
import subprocess
import tempfile
from pathlib import Path


def sideload_entitlements(bundle_id, team_id, group):
    entitlements = {
        "com.apple.security.application-groups": [group],
    }
    if team_id:
        entitlements.update({
            "application-identifier": team_id + "." + bundle_id,
            "com.apple.developer.team-identifier": team_id,
        })
    return entitlements


def _run(arguments, capture=False):
    completed = subprocess.run(
        [str(argument) for argument in arguments],
        check=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return completed.stdout if capture else None


def _sign(path, entitlements, work):
    entitlements_path = work / (path.name + ".entitlements")
    entitlements_path.write_bytes(plistlib.dumps(entitlements))
    _run([
        "codesign",
        "--force",
        "--sign",
        "-",
        "--timestamp=none",
        "--entitlements",
        entitlements_path,
        "--generate-entitlement-der",
        path,
    ])


def _nested_code(bundle):
    code = [
        path
        for path in bundle.rglob("*")
        if path.suffix == ".framework" or (path.suffix == ".dylib" and path.is_file())
    ]
    return sorted(code, key=lambda path: len(path.parts), reverse=True)


def _read_bundle_id(bundle):
    return plistlib.loads((bundle / "Info.plist").read_bytes())["CFBundleIdentifier"]


def _embedded_entitlements(bundle):
    output = subprocess.run(
        ["codesign", "-d", "--entitlements", "-", "--xml", str(bundle)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    ).stdout
    return plistlib.loads(output) if output else {}


def embed_sideload_entitlements(ipa, team_id=""):
    ipa = Path(ipa)
    with tempfile.TemporaryDirectory(prefix="mellowsgram-sideload-") as temporary:
        work = Path(temporary)
        root = work / "ipa"
        _run(["ditto", "-x", "-k", ipa, root])

        apps = list((root / "Payload").glob("*.app"))
        if len(apps) != 1:
            raise ValueError("IPA must contain exactly one main application")
        app = apps[0]
        bundle_id = _read_bundle_id(app)
        group = "group." + bundle_id
        plugins = sorted((app / "PlugIns").glob("*.appex"))
        signed = {}

        # Sign nested frameworks before their containing extension/application.
        for code in _nested_code(app):
            _run(["codesign", "--force", "--sign", "-", "--timestamp=none", code])

        for plugin in plugins:
            plugin_id = _read_bundle_id(plugin)
            if not plugin_id.startswith(bundle_id + "."):
                raise ValueError("Extension bundle id is not under the app: " + plugin.name)
            entitlements = sideload_entitlements(plugin_id, team_id, group)
            _sign(plugin, entitlements, work)
            signed[plugin] = entitlements

        app_entitlements = sideload_entitlements(bundle_id, team_id, group)
        _sign(app, app_entitlements, work)
        signed[app] = app_entitlements

        for bundle, expected in signed.items():
            embedded = _embedded_entitlements(bundle)
            if embedded.get("com.apple.security.application-groups") != [group]:
                raise ValueError("App group entitlement was not embedded: " + bundle.name)
            if team_id and embedded.get("application-identifier") != expected["application-identifier"]:
                raise ValueError("Application identifier was not embedded: " + bundle.name)

        rebuilt = work / "rebuilt.ipa"
        _run(["ditto", "-c", "-k", "--norsrc", root, rebuilt])
        ipa.write_bytes(rebuilt.read_bytes())
    return [plugin.name for plugin in plugins]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, required=True)
    parser.add_argument("--team-id", default=os.environ.get("APPLE_TEAM_ID", "").strip().upper())
    args = parser.parse_args()
    if not args.ipa.is_file():
        parser.error("IPA does not exist: {}".format(args.ipa))
    team_id = args.team_id.strip().upper()
    if team_id and (len(team_id) != 10 or not team_id.isalnum()):
        parser.error("--team-id must be the 10-character Apple Team ID")
    extensions = embed_sideload_entitlements(args.ipa, team_id)
    print("Prepared {} with app-group entitlements for {} extension(s).".format(args.ipa, len(extensions)))
    if not team_id:
        print("No Team ID supplied; AltStore/SideStore must inject application-identifier during re-signing.")


if __name__ == "__main__":
    main()
