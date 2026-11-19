<div align="center">
  <img src="docs/mellowsgram-icon.svg" width="160" alt="Mellowsgram icon">

  <h1>Mellowsgram iOS</h1>

  <p>Telegram iOS client with local message history, configurable Ghost Mode and a privacy-first archive of deleted content.</p>

  <p>
    <a href="https://github.com/Eld3rly/Mellowsgram-IOS/actions/workflows/build.yml">
      <img src="https://github.com/Eld3rly/Mellowsgram-IOS/actions/workflows/build.yml/badge.svg" alt="Build status">
    </a>
    <a href="https://github.com/TelegramMessenger/Telegram-iOS">
      <img src="https://img.shields.io/badge/based%20on-Telegram%20iOS-2AABEE" alt="Based on Telegram iOS">
    </a>
    <a href="https://t.me/mellowsgram">
      <img src="https://img.shields.io/badge/channel-@mellowsgram-2AABEE" alt="Mellowsgram channel">
    </a>
  </p>
</div>

> **Status:** experimental work in progress. Mellowsgram is an unofficial Telegram client and is not affiliated with Telegram or AyuGram.

> **⚠️ Development warning:** Mellowsgram is still under active development. Features may be incomplete, unavailable, or behave incorrectly. Building or launching the project at this stage is not recommended. Please wait for a release before using it.

<p><a href="README.md">English</a> · <a href="README-RU.md">Русский</a></p>

## Overview

Mellowsgram is an iOS-focused Telegram client built on top of the open-source Telegram iOS codebase. It brings a small, carefully scoped set of AyuGram-inspired features to the native iOS interface instead of trying to copy desktop-only UI one-to-one.

The project is designed around three principles:

- keep Telegram's native message renderer and interaction model;
- keep Mellowsgram data local to the current account and device;
- make network-side behavior explicit and configurable.

## Features

### Spy & Ghost

- **Configurable Ghost Mode** with independent switches for:
  - message read receipts;
  - story reads;
  - online presence;
  - typing indicators and upload-progress activities;
  - automatic offline behavior.
- Local read state is preserved while receipts are suppressed.
- Disabling Ghost Mode affects new actions only; suppressed receipts are not replayed automatically.
- Message sending and file uploads themselves are not blocked.
- The Ghost Mode coordinator applies these policies at the network boundary, so the same rules cover chat, stories and presence flows.

### Deleted messages

- Deleted messages remain at their original position with the original MessageId, direction and timestamp.
- The row uses Telegram's normal bubble and media renderer with a compact Deleted message marker.
- Text, captions and available media descriptors are preserved for photos, videos, round videos, voice messages, audio, files, GIFs and stickers.
- Available local media can still be opened, played, copied, forwarded or saved through the regular Telegram flows.
- Long-press actions include reply, copy, forward, save and edit-history access where applicable.
- Deleted rows never participate in Telegram synchronization, unread state, reactions or server-side message history.

### Edit history

- Previous text and entities are saved locally before an edit is applied.
- History is available from the message context menu.
- The current version is shown together with older versions in newest-to-oldest order.
- Media edit history is intentionally out of scope for the first version.

### Media timers

- Eligible cloud-chat media with auto-remove or view-once timers can be displayed and opened again as ordinary media when the option is enabled.
- The original timer/view-once state remains visible as a badge instead of silently disappearing.
- Secret chats and ephemeral messages keep Telegram's original privacy semantics.

### Settings

The **Mellowsgram** entry is placed above **My Profile** in Telegram Settings. Its root screen has category buttons and links; each category opens a separate native settings screen:

- **Spy&Ghost** — Ghost Mode, deleted-message and edit-history archives, background notifications, and story behavior;
- **Appearance** — deleted-message opacity, account-color saturation, sticker size and timestamps, channel layout, tabs, folders, and chat-list layout;
- **Profiles & Calls** — profile and chat details, call confirmation, and phone visibility;
- **Media & Voice** — outgoing photo quality and HD photos, camera and PiP behavior, transfer boosts, translation, and voice transcription;
- **Messages & Context** — context-menu actions, message behavior, and input controls.

Channel and GitHub links remain on the Mellowsgram root screen. Appearance sliders show their current value and what their minimum and maximum mean. The outgoing photo-quality slider and **Send HD Photos** are grouped with media settings, not appearance settings.

Ghost Mode, deleted-message archive and edit history remain account-scoped. Client customization is stored app-wide, while settings already owned by Telegram continue using Telegram's shared preferences. The screen includes controls for tabs and folders, story behavior, profile details, translation and transcription services, media quality, context-menu actions, and message input.

The app includes Mellowsgram alternate icons, including icons normally gated by Telegram Premium. Optional background notifications use local notifications while the app keeps selected account connections active; they require notification permission, are best-effort, and increase battery use. They are not APNs push notifications.

Mellowsgram allows up to **32 connected accounts** without making the account count depend on Telegram Premium. Each account keeps its own Telegram session and local data.

## Privacy and limitations

- Deleted-message and edit-history data is local, account-scoped and not synchronized between devices.
- The archive stores text, entities, message metadata and media descriptors; it does not copy media bytes.
- A media item can only be opened if its resource is still available locally or can be resolved by the current MediaBox.
- Secret chats, ephemeral messages and other privacy-sensitive message types are excluded from the archive and timer bypass.
- Ghost Mode is best-effort client behavior. It cannot change what Telegram has already received and may carry account or Terms of Service risks.
- This project is experimental. Use a test account if you are not comfortable with those trade-offs.

## Build model

The supported project workflow builds the simulator IPA through **GitHub Actions**. Generated configuration files, API credentials, signing data and IPA files must not be committed.

The workflow is defined in [build.yml](.github/workflows/build.yml). It:

1. checks out the repository and submodules;
2. generates an ignored Mellowsgram configuration;
3. restores the Bazel disk cache;
4. builds the simulator IPA;
5. uploads Telegram.ipa as an artifact.

There is intentionally no unit-test stage in the simulator workflow. Static checks and manual simulator verification are performed separately when needed.

### Required Actions secrets

Configure these repository secrets before starting a build:

| Secret | Purpose |
| --- | --- |
| TELEGRAM_API_ID | Telegram application API ID |
| TELEGRAM_API_HASH | Telegram application API hash |
| APPLE_TEAM_ID | Optional for simulator-only output; required when generating pre-entitled device identifiers |

The repository workflow uses com.mellowsgram.ios as the main bundle identifier and generates matching extension identifiers and app-group configuration.

### Local configuration generation

This command only creates the ignored JSON input. It does not build the application:

    export TELEGRAM_API_ID="..."
    export TELEGRAM_API_HASH="..."
    export APPLE_TEAM_ID="XXXXXXXXXX"

    python3 ci/mellowsgram_configuration.py \
      --output build-input/mellowsgram-configuration.json \
      --api-id "$TELEGRAM_API_ID" \
      --api-hash "$TELEGRAM_API_HASH" \
      --team-id "$APPLE_TEAM_ID" \
      --bundle-id com.mellowsgram.ios \
      --url-scheme mellowsgram

For normal development, run the Mellowsgram iOS simulator IPA workflow from the Actions tab or trigger it with the GitHub CLI:

    gh workflow run build.yml --ref indev

Download the resulting artifact from the completed workflow. The simulator IPA can then be installed with simctl on a compatible iOS Simulator. No device signing is required for simulator testing.

## Device sideloading

A device IPA needs to be re-signed with the user's own Apple certificate and provisioning profile. AltStore or SideStore can perform that final signing step. The repository includes [mellowsgram_sideload.py](ci/mellowsgram_sideload.py) for preparing app-group entitlements before the final re-signing flow.

Do not commit provisioning profiles, certificates, API hashes or generated configuration files.

## Project layout

| Path | Contents |
| --- | --- |
| submodules/Postbox | Local archive tables and account-scoped Ghost Mode coordination |
| submodules/TelegramCore | Settings, archive projections, timer and network-side guards |
| submodules/TelegramUI | Native chat rendering, media interaction, context menus and settings entry points |
| submodules/SettingsUI | Mellowsgram root and category screens |
| ci/ | Configuration generation and sideload preparation helpers |
| .github/workflows/ | GitHub Actions simulator build |

## Credits

- [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS) — the upstream client and platform foundation.
- [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop) — inspiration for Ghost Mode, local history and customization concepts.
- [AyuGram documentation](https://github.com/AyuGram/AyuGramDocs) — reference material for the behavior of local deleted-message and edit-history features.

## Links

- Russian README: [README-RU.md](README-RU.md)
- Channel: [@mellowsgram](https://t.me/mellowsgram)
- Telegram: [telegram.org](https://telegram.org)
- Upstream Telegram iOS: [TelegramMessenger/Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS)
