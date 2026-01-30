# ClipSwifty – Entwicklungs-ToDo-Liste

**App-Name:** ClipSwifty  
**Technologie:** 100% Swift + SwiftUI + yt-dlp (macOS)  
**Ziel:** Saubere, wartbare und professionelle macOS-App (Clean Code Prinzipien)

## Phase 1: Vorbereitung und Setup
- [ ] Neues Xcode-Projekt erstellen (macOS App, SwiftUI, Ziel: macOS 10.15+)
- [ ] yt-dlp_macos Binary und ffmpeg herunterladen und ins Projekt einfügen (Copy Files Build Phase)
- [ ] Sandbox-Entitlements konfigurieren (`network.client`, `downloads.read-write`, `user-selected.read-write`)
- [ ] Hardened Runtime aktivieren
- [ ] SwiftLint integrieren (Code Style & Clean Code Regeln)
- [ ] Projektstruktur anlegen (Ordner: Models, Views, Services, Managers, Utilities)

## Phase 2: Kernfunktionalität (yt-dlp Integration)
- [ ] `YtDlpManager` Klasse erstellen (Single Responsibility)
- [ ] Funktion zum Kopieren des Binaries in `~/Library/Application Support/ClipSwifty/`
- [ ] Executable-Rechte setzen (0755)
- [ ] Allgemeine `runYtDlp(arguments: [String])` Methode implementieren
- [ ] Automatisches Update (`--update`) beim App-Start implementieren
- [ ] Async/await + Progress-Handling für Downloads
- [ ] Fehlerbehandlung und Logging (os_log)
- [ ] Enums für yt-dlp Optionen erstellen (z. B. VideoFormat, AudioFormat)

## Phase 3: Benutzeroberfläche (UI/UX)
- [ ] Haupt-View mit URL-Eingabe, Format-Picker, Download-Button
- [ ] Download-Queue / Multi-Download Liste
- [ ] Echtzeit-Fortschrittsanzeige (Parsing von yt-dlp Output)
- [ ] Thumbnail-Vorschau anzeigen
- [ ] Download-History (mit UserDefaults oder Core Data)
- [ ] Fehler-Meldungen als Alert anzeigen
- [ ] MVVM-Architektur umsetzen
- [ ] Dark Mode + Responsive Layout

## Phase 4: Sicherheit, Optimierung & Polish
- [ ] yt-dlp & ffmpeg nach Update automatisch signieren (`codesign`)
- [ ] Disclaimer / Rechtlicher Hinweis beim ersten Start
- [ ] Pause / Resume / Abbrechen von Downloads
- [ ] Output-Ordner Auswahl durch Benutzer
- [ ] Konfiguration über yt-dlp.conf Datei
- [ ] Performance-Optimierungen (Throttling, Hintergrund-Downloads)

## Phase 5: Testing, Dokumentation & Release
- [ ] Unit Tests für YtDlpManager und Process-Aufrufe schreiben
- [ ] Auf Intel + Apple Silicon testen
- [ ] Mit verschiedenen Plattformen (YouTube, Vimeo, TikTok, Instagram etc.) testen
- [ ] Sparkle-Framework für automatische App-Updates integrieren
- [ ] README.md + Code-Dokumentation schreiben
- [ ] Release-Build erstellen (.app für GitHub Releases)

## Nice-to-have Features (später)
- [ ] Playlist-Download
- [ ] Automatische Format-Empfehlung
- [ ] Suchfunktion innerhalb der App
- [ ] Menüleiste-Icon (Status Bar)
- [ ] Einstellungen-Fenster

**Tipp:** Bearbeite die Liste regelmäßig und setze Prioritäten.  
Empfohlene Reihenfolge: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

Viel Erfolg bei ClipSwifty! 🚀
