# Spirit Rumble

## Play Without Local Scripts

This repo auto-deploys the web build to GitHub Pages on every push to `main`.

After Pages is enabled in repository settings, the game is available at:

`https://monivibe.github.io/SpiritRumble/`

This avoids Windows Smart App Control blocking local launcher scripts on other PCs.

### GitHub Pages Setup (Required Once)

1. In GitHub, open `Settings` -> `Secrets and variables` -> `Actions`.
2. Add repository secret:
   `PUREFLUTTER_READ_TOKEN`
3. Value should be a GitHub token that has read access to:
   `https://github.com/gammula/pureflutter.git`
4. In `Settings` -> `Pages`, set `Source` to `GitHub Actions`.

Without this secret, the deploy workflow cannot run `flutter pub get` because
`bullethole_shared` is pulled from a private git dependency.

## Local Run (Developer)

```powershell
flutter pub get
flutter run -d edge
```

Or use:

`Launch Spirit Rumble.bat`

If Smart App Control blocks downloaded launchers, right-click the downloaded ZIP,
open `Properties`, click `Unblock`, then extract.
