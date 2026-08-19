# ClipSwifty

Native macOS video downloader. SwiftUI. Engine is bundled **yt-dlp** + **FFmpeg**, not a custom extractor.

## Brain

Project memory lives in `brain/`. At the start of a task, read `brain/INDEX.md` and only the files it marks as relevant.

Cross-project identity, preferences, and lessons: `~/work/brain/INDEX.md` — load only when needed.

Write durable knowledge back to `brain/` (see `brain/AGENTS.md`) **before you stop** a task that produced a decision or gotcha. `/learn` or „merk dir das“. Do not dump chat logs. Do not invent lessons.

## Hard rules

- Keep the README copyright / personal-use disclaimer intact.
- Do not commit notary credentials or signing identities.
- Release path is `./scripts/release.sh <version>` (Developer ID + notarytool).
- macOS 14+ only unless Stefan asks otherwise.
