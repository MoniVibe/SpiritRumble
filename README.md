# Spirit Rumble

## Play Without Local Scripts

This repo auto-deploys the web build to GitHub Pages on every push to `main`.

After Pages is enabled in repository settings, the game is available at:

`https://monivibe.github.io/SpiritRumble/`

This avoids Windows Smart App Control blocking local launcher scripts on other PCs.

## Local Run (Developer)

```powershell
flutter pub get
flutter run -d edge
```

Or use:

`Launch Spirit Rumble.bat`

If Smart App Control blocks downloaded launchers, right-click the downloaded ZIP,
open `Properties`, click `Unblock`, then extract.
