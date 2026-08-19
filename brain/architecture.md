---
type: architecture
updated: 2026-08-19
---

# Architecture

```
ClipSwifty/
  ClipSwiftyApp.swift
  Sources/
    Managers/
      YtDlpManager.swift          Process-Wrapper, Progress, Info-Fetch, Self-Update
      DownloadHistoryManager.swift
      UpdateManager.swift         App-Update-Check
    Models/                       VideoInfo, VideoFormat, DownloadItem, AppSettings, History
    Views/                        MainView, DownloadViewModel, Settings, History, MenuBar, Disclaimer
    Utilities/                    Constants, ErrorMapper
  Resources/
    yt-dlp_macos
    ffmpeg
```

`YtDlpManager` kopiert die Binaries bei Bedarf nach Application Support (`~/Library/Application Support/ClipSwifty/`) und führt sie als `Process` aus. Logger-Subsystem: `com.clipswifty`.
