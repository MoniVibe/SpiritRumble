# Spirit Rumble

## Play Without Local Scripts

This repo auto-deploys the web build to GitHub Pages on every push to `main`.

After Pages is enabled in repository settings, the game is available at:

`https://monivibe.github.io/SpiritRumble/`

This avoids Windows Smart App Control blocking local launcher scripts on other PCs.

## Multiplayer-Ready Foundation

The project now includes an authoritative multiplayer contract layer so we can
plug in real hosting later without rewriting the rules/UI core:

- Shared wire codec in `packages/puredots_turn_engine`:
  - `TurnEngineJsonCodec` for `GameState`, `GameCommand`, and `MatchRules`
  - Protocol envelopes: `MatchmakingRequest`, `MatchAssignment`,
    `CommandEnvelope`, `StateEnvelope`
- App-side backend abstraction:
  - `lib/battle/application/multiplayer/multiplayer_backend.dart`
- Local authoritative simulation backend for development/tests:
  - `lib/battle/application/multiplayer/in_memory_multiplayer_backend.dart`
- Client session primitive for future UI matchmaking integration:
  - `lib/battle/application/multiplayer/multiplayer_client.dart`

This means current gameplay remains local, but networking concerns (matchmaking,
command submission, state snapshots, versioning) are already separated and
test-covered.

### GitHub Pages Setup (Required Once)

1. In `Settings` -> `Pages`, set `Source` to `GitHub Actions`.
2. Run workflow `Deploy Flutter Web To GitHub Pages` from `Actions`.

No extra repository secrets are required.

## Local Run (Developer)

```powershell
flutter pub get
flutter run -d edge
```

Or use:

`Launch Spirit Rumble.bat`

If Smart App Control blocks downloaded launchers, right-click the downloaded ZIP,
open `Properties`, click `Unblock`, then extract.
