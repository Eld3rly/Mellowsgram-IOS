#!/usr/bin/env python3
"""Check that the fonts are present and registered in an Actions IPA."""

import plistlib
import sys
from pathlib import Path
from zipfile import ZipFile


def main() -> None:
    ipa = Path(sys.argv[1])
    fonts = {path.name for path in Path("Telegram/Telegram-iOS/Resources").glob("Monocraft*.ttf")}
    if len(fonts) != 12:
        raise SystemExit(f"Expected 12 Monocraft files, found {len(fonts)}")

    app_root = "Payload/Telegram.app/"
    with ZipFile(ipa) as archive:
        info = plistlib.loads(archive.read(app_root + "Info.plist"))
        declared = set(info.get("UIAppFonts", []))
        bundled = {name.removeprefix(app_root) for name in archive.namelist() if name.startswith(app_root)}

    missing_declarations = fonts - declared
    missing_resources = fonts - bundled
    if missing_declarations or missing_resources:
        raise SystemExit(
            f"Monocraft registration failed: missing declarations={sorted(missing_declarations)}, "
            f"missing resources={sorted(missing_resources)}"
        )
    print(f"Verified {len(fonts)} Monocraft fonts in {ipa}")


if __name__ == "__main__":
    main()
