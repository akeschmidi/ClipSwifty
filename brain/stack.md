---
type: stack
updated: 2026-08-19
---

# Stack

## Tech

- Swift 5.9, SwiftUI, macOS 14+
- Xcode-Projekt `ClipSwifty.xcodeproj` (kein XcodeGen)
- yt-dlp + FFmpeg als gebündelte Binaries
- GitHub Actions: CI + Release (Commit-History)

## Commands

```bash
cd ~/work/ClipSwifty
open ClipSwifty.xcodeproj
# Cmd+R

# Signed, notarized GitHub Release
./scripts/release.sh 1.4.1
```

Release-Skript: Developer ID `Stefan Schwinghammer (34DTFQCK2V)`, Notary-Profil `notarytool-profile`.

## Gotchas

- Binaries müssen ausführbar sein; Setup kopiert sie nach Application Support.
- Sandbox/Helper: `HelperTools.entitlements` existiert — Process-Spawn ist der Kernpfad, nicht „pure Swift Download“.
- Nichtary / Signing-Profile liegen lokal, nicht im Repo.
