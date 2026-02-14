import Foundation

struct MappedError {
    let userMessage: String
    let originalMessage: String
    let isRetryable: Bool
}

struct ErrorMapper {
    static func map(stderr: String) -> MappedError {
        let lower = stderr.lowercased()

        // Video unavailable
        if lower.contains("video unavailable") || lower.contains("this video is unavailable") ||
           lower.contains("video is not available") {
            return MappedError(
                userMessage: "Video nicht verfügbar",
                originalMessage: stderr,
                isRetryable: false
            )
        }

        // Private video
        if lower.contains("private video") || lower.contains("sign in to confirm your age") ||
           lower.contains("this video is private") {
            return MappedError(
                userMessage: "Privates Video - Zugriff verweigert",
                originalMessage: stderr,
                isRetryable: false
            )
        }

        // Geo-blocked
        if lower.contains("geo") && (lower.contains("block") || lower.contains("restrict")) ||
           lower.contains("not available in your country") ||
           lower.contains("geo restriction") {
            return MappedError(
                userMessage: "Video in deiner Region nicht verfügbar",
                originalMessage: stderr,
                isRetryable: false
            )
        }

        // Age-restricted
        if lower.contains("age-restricted") || lower.contains("age restricted") ||
           lower.contains("age gate") || lower.contains("confirm your age") {
            return MappedError(
                userMessage: "Altersbeschränktes Video - Anmeldung erforderlich",
                originalMessage: stderr,
                isRetryable: false
            )
        }

        // Copyright / removed
        if lower.contains("copyright") || lower.contains("removed by the uploader") ||
           lower.contains("account associated with this video has been terminated") ||
           lower.contains("video has been removed") {
            return MappedError(
                userMessage: "Video wegen Urheberrecht entfernt",
                originalMessage: stderr,
                isRetryable: false
            )
        }

        // Invalid URL
        if lower.contains("unsupported url") || lower.contains("is not a valid url") ||
           lower.contains("no video formats found") || lower.contains("unable to extract") {
            return MappedError(
                userMessage: "Ungültige oder nicht unterstützte URL",
                originalMessage: stderr,
                isRetryable: false
            )
        }

        // 404 Not Found
        if lower.contains("404") || lower.contains("not found") {
            return MappedError(
                userMessage: "Video nicht gefunden (404)",
                originalMessage: stderr,
                isRetryable: false
            )
        }

        // 403 Forbidden
        if lower.contains("403") || lower.contains("forbidden") {
            return MappedError(
                userMessage: "Zugriff verweigert (403)",
                originalMessage: stderr,
                isRetryable: true
            )
        }

        // Rate limited
        if lower.contains("rate limit") || lower.contains("too many requests") ||
           lower.contains("429") || lower.contains("throttl") {
            return MappedError(
                userMessage: "Zu viele Anfragen - bitte warte kurz",
                originalMessage: stderr,
                isRetryable: true
            )
        }

        // Timeout
        if lower.contains("timed out") || lower.contains("timeout") ||
           lower.contains("read timed out") {
            return MappedError(
                userMessage: "Zeitüberschreitung - Server antwortet nicht",
                originalMessage: stderr,
                isRetryable: true
            )
        }

        // Network / connection errors
        if lower.contains("network") || lower.contains("connection") ||
           lower.contains("urlopen error") || lower.contains("errno") ||
           lower.contains("socket") || lower.contains("ssl") ||
           lower.contains("getaddrinfo") || lower.contains("name resolution") ||
           lower.contains("unreachable") || lower.contains("reset by peer") {
            return MappedError(
                userMessage: "Netzwerkfehler - Überprüfe deine Internetverbindung",
                originalMessage: stderr,
                isRetryable: true
            )
        }

        // Incomplete download / HTTP error
        if lower.contains("http error") || lower.contains("incomplete") ||
           lower.contains("server returned") {
            return MappedError(
                userMessage: "Download unterbrochen - Server-Fehler",
                originalMessage: stderr,
                isRetryable: true
            )
        }

        // Fallback
        return MappedError(
            userMessage: "Download fehlgeschlagen",
            originalMessage: stderr,
            isRetryable: false
        )
    }
}
