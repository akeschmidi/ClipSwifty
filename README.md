# ClipSwifty – Detaillierte Entwicklungs-ToDo-Liste (mit Fokus auf Clean Code-Prinzipien)

**App-Name:** ClipSwifty  
**Technologie:** 100% Swift + SwiftUI für macOS, Integration von yt-dlp als Binary  
**Ziel:** Eine benutzerfreundliche Video-Download-App, die Videos von Plattformen wie YouTube herunterlädt und konvertiert. Die Entwicklung folgt Clean Code-Prinzipien (z. B. SRP, DRY, lesbarer Code, Modulare Struktur, Unit-Tests).  
**Annahme:** "Claude Code" bezieht sich auf "Clean Code" (sauberen, wartbaren Code). Falls gemeint ist etwas anderes (z. B. Claude AI), kläre das bitte.  
**Schätzung:** Gesamtaufwand ca. 50-100 Stunden für einen Solo-Entwickler.  

Diese Liste ist in Phasen unterteilt, mit detaillierten Unteraufgaben. Jede Phase enthält Clean-Code-Tipps. Priorisiere: Starte mit Phase 1, baue iterativ auf. Verwende Git für Versionierung.

## Phase 1: Vorbereitung und Setup (ca. 5-10 Stunden)
Ziel: Solide Grundlage schaffen, ohne funktionale Logik.  
- [ ] **Xcode-Projekt erstellen:**  
  - Neues macOS-App-Projekt in Xcode anlegen (SwiftUI als UI-Framework, Minimum Deployment Target: macOS 10.15).  
  - Projektname: ClipSwifty.  
  - Clean Code: Verwende klare Ordnerstruktur (z. B. Sources > Models, Views, Services, Managers, Utilities). Vermeide Standardnamen wie "ContentView".  
- [ ] **Abhängigkeiten herunterladen und einbinden:**  
  - Lade yt-dlp_macos Binary von GitHub-Releases (https://github.com/yt-dlp/yt-dlp/releases).  
  - Lade statische ffmpeg-Build für macOS (https://ffmpeg.org/download.html).  
  - Füge sie als Ressourcen hinzu: In Build Phases > Copy Files > Destination: Resources.  
  - Clean Code: Erstelle eine Constants-Datei für Pfade (z. B. `enum Resources { static let ytDlpName = "yt-dlp_macos" }`).  
- [ ] **Sandbox- und Security-Entitlements konfigurieren:**  
  - In .entitlements: Aktiviere `com.apple.security.app-sandbox`, `com.apple.security.network.client`, `com.apple.security.files.downloads.read-write`, `com.apple.security.files.user-selected.read-write`.  
  - Aktiviere Hardened Runtime in Signing & Capabilities.  
  - Clean Code: Dokumentiere Entitlements in einem README (warum welche benötigt werden).  
- [ ] **Coding-Standards einrichten:**  
  - Installiere SwiftLint via Homebrew oder Podfile.  
  - Konfiguriere .swiftlint.yml für Regeln (z. B. Linelänge < 100, keine force-unwraps).  
  - Clean Code: Füge Pre-Commit-Hooks hinzu, um Lint vor Commits zu enforcen.  
- [ ] **Projektstruktur finalisieren:**  
  - Erstelle leere Klassen/Structs für zukünftige Komponenten (z. B. YtDlpManager, DownloadModel).  
  - Clean Code: Verwende Protocols für Abstraktion (z. B. `protocol DownloaderProtocol`).  

## Phase 2: Kernfunktionalität (yt-dlp-Integration) (ca. 10-20 Stunden)
Ziel: yt-dlp als Backend integrieren, ohne UI.  
- [ ] **YtDlpManager-Klasse erstellen:**  
  - Eine dedizierte Klasse für alle yt-dlp-Interaktionen (SRP: Nur yt-dlp-Handling).  
  - Methode: `setupYtDlp() -> URL?` – Kopiert Binary in `~/Library/Application Support/ClipSwifty/yt-dlp_macos` beim ersten Start.  
  - Setze POSIX-Rechte: `FileManager.default.setAttributes([.posixPermissions: 0o755])`.  
  - Clean Code: Handle Errors mit einem custom Error-Enum (z. B. `enum YtDlpError: Error { case copyFailed, permissionsFailed }`).  
- [ ] **Process-Aufruf implementieren:**  
  - Methode: `runYtDlp(arguments: [String], completion: @escaping (Result<(output: String, error: String), Error>) -> Void)`.  
  - Verwende `Process()`, Pipes für stdout/stderr, async/await für Modernität.  
  - Parse Output für Fortschritt (z. B. regex für "[download] XX%").  
  - Clean Code: Extrahiere Parsing in eine separate Funktion (DRY).  
- [ ] **Automatisches Update implementieren:**  
  - Methode: `updateYtDlp(completion: @escaping (Bool) -> Void)`.  
  - Rufe `yt-dlp --update` auf.  
  - Fallback: Wenn Update fehlschlägt, kopiere bundled Version zurück.  
  - Rufe beim App-Launch async auf (z. B. in `onAppear` oder AppDelegate).  
  - Clean Code: Verwende Timer für tägliche Checks (z. B. UserDefaults für lastUpdateDate).  
- [ ] **ffmpeg-Integration sicherstellen:**  
  - Kopiere ffmpeg in denselben Ordner wie yt-dlp.  
  - Teste Konvertierungen (z. B. `--audio-format mp3`).  
  - Clean Code: Füge eine Config-Datei (yt-dlp.conf) hinzu für Default-Optionen.  
- [ ] **Enums und Hilfsstrukturen:**  
  - Erstelle Enums: `enum VideoFormat: String { case best = "best", mp4 = "mp4" }`.  
  - Clean Code: Vermeide Magic Strings in Arguments.  

## Phase 3: Benutzeroberfläche (UI/UX) (ca. 15-25 Stunden)
Ziel: Intuitive macOS-Oberfläche bauen.  
- [ ] **Haupt-View aufbauen:**  
  - SwiftUI: `ContentView` mit `TextField` für URL, `Picker` für Formate, `Button` für Download.  
  - Füge `ProgressView` für laufende Downloads hinzu.  
  - Clean Code: Teile in Subviews (z. B. `URLInputView`, `FormatSelectorView`).  
- [ ] **Download-Logik integrieren:**  
  - Methode in ViewModel: `startDownload(url: String, format: VideoFormat)`.  
  - Verwende `@State` oder `@ObservedObject` für Status-Updates.  
  - Implementiere Queue für Multi-Downloads (Array von DownloadTasks).  
  - Clean Code: MVVM-Pattern – ViewModel handhabt Logik, View nur Darstellung.  
- [ ] **Erweiterte Features:**  
  - Download-History: Speichere in UserDefaults (Array von Structs: URL, Date, Path).  
  - Thumbnail: Rufe `yt-dlp --get-thumbnail` und lade Bild mit `AsyncImage`.  
  - Pause/Resume: yt-dlp unterstützt es nicht nativ – simuliere mit Process-Termination und Restart.  
  - Clean Code: Verwende Combine oder async Streams für Echtzeit-Updates.  
- [ ] **UX-Polish:**  
  - Dark Mode-Support (automatisch in SwiftUI).  
  - Accessibility: Labels für VoiceOver.  
  - Responsives Layout für verschiedene Fenstergrößen.  
  - Clean Code: Schreibe Previews für Views (Xcode Previews).  

## Phase 4: Sicherheit, Optimierung & Polish (ca. 10-15 Stunden)
Ziel: App robust und benutzerfreundlich machen.  
- [ ] **Sicherheit verbessern:**  
  - Nach Update: Signiere Binaries mit `codesign --force --sign - path/to/binary`.  
  - Implementiere Disclaimer-Pop-up beim ersten Start (SwiftUI Alert oder Sheet).  
  - Clean Code: Zentrale Security-Manager-Klasse.  
- [ ] **Fehlerhandling und Logging:**  
  - Globale Error-Handling: Custom Alerts für yt-dlp-Fehler.  
  - Verwende `os_log` für Debugging.  
  - Clean Code: Extension auf Error für user-friendly Messages.  
- [ ] **Optimierungen:**  
  - Throttle Downloads (yt-dlp-Option `--limit-rate`).  
  - Hintergrund-Downloads: Verwende Background Tasks.  
  - Output-Ordner: NSOpenPanel für Benutzer-Auswahl.  
  - Clean Code: Profile mit Instruments, refactore langsame Teile.  
- [ ] **Konfiguration:**  
  - Erstelle yt-dlp.conf im App-Support-Ordner für Defaults.  
  - Clean Code: Serializable Struct für App-Settings.  

## Phase 5: Testing, Dokumentation & Release (ca. 10-20 Stunden)
Ziel: App deploybar machen.  
- [ ] **Testing:**  
  - Unit-Tests: XCTest für YtDlpManager (z. B. mock Process).  
  - UI-Tests: Für Download-Flow.  
  - Manuelles Testing: Auf Intel/M1-Macs, verschiedene URLs (YouTube, Vimeo), Formate.  
  - Simuliere Updates/Fehler.  
  - Clean Code: Ziel 80% Code Coverage.  
- [ ] **App-Updates integrieren:**  
  - Füge Sparkle-Framework hinzu (Pod oder manuell).  
  - Konfiguriere für GitHub-Releases.  
  - Clean Code: Separate UpdateManager-Klasse.  
- [ ] **Dokumentation:**  
  - README.md: Build-Anleitung, Features, Rechtliche Hinweise.  
  - Code-Kommentare: /// für DocC.  
  - Generiere DocC-Archive.  
  - Clean Code: Dokumentiere jede public Methode.  
- [ ] **Release:**  
  - Baue .app: Archive > Distribute App > Developer ID.  
  - Notarize bei Apple.  
  - Verteile via GitHub Releases (kein App Store wegen Richtlinien).  

## Nice-to-have Features (nach Kernfertigstellung)
- [ ] Playlist-Support: yt-dlp-Option `--yes-playlist`.  
- [ ] Automatische Qualitäts-Empfehlung basierend auf Metadaten.  
- [ ] Suchfunktion: Integriere yt-dlp `--search`.  
- [ ] Menüleiste-Integration: Status-Bar-Item für schnellen Zugriff.  
- [ ] Einstellungen-Fenster: Für Update-Channel (stable/nightly), Defaults.  

**Tipps für Clean Code während der Entwicklung:**  
- Halte Funktionen kurz (< 20 Zeilen).  
- Refactore nach jeder Phase (z. B. Extract Method).  
- Verwende Guard-Clauses für frühe Returns.  
- Commit oft mit descriptiven Messages.  

Viel Erfolg, Stef! Wenn du Code-Snippets für eine Aufgabe brauchst oder die Liste anpassen möchtest, lass es mich wissen. 🚀
