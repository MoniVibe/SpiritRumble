# bullethole_shared

Shared Flutter package for cross-game concerns used by both chess and backgammon clients.

Current contents:
- Reusable UI widgets (`AppAssetIcon`, `CompactModeSwitch`, `GameChatPanel`,
  `CooldownMeter`, `CollapsibleSettingsCard`, `TimeBarOrientationSwitch`)
- Skin model types (board/piece metadata models)
- Multiplayer helpers (`BackendHealthChecker`, `MultiplayerClientUtils`,
  `MultiplayerTransportClient`, shared connection/health enums)

Transport-only entrypoint for headless tools/scripts:
- `package:bullethole_shared/bullethole_shared_transport.dart`

The package intentionally contains no game rules or game-specific assets.

## Consumer contract

Consumers should depend on this repo via a pinned Git ref in `pubspec.yaml`.
Use a tag for releases when available, or a commit SHA as a fallback.

Tracked app `pubspec.yaml` files should not use a local `path:` dependency.
For local side-by-side development, use an untracked `pubspec_overrides.yaml`
in the app repo instead.

## Release flow

1. Land shared-package changes on `main`.
2. Bump `version:` in `pubspec.yaml`.
3. Create a Git tag that matches the version, prefixed with `v`.
   Example: `version: 0.1.0` -> tag `v0.1.0`
4. Update consuming app repos to the new tag or commit and run `flutter pub get`.

CI now verifies the package on pushes and PRs and verifies tagged releases
against the package version.
