import Foundation

/// Port of `BookDownloadService.doDownload` path logic + `prepareOutput` (jvm):
/// `downloadRoot/<host[_port][_segments]>/<libraryName>/<seriesName>/<bookFileName>`.
///
/// Kotlin only sanitized names on Windows. iOS file names cannot contain `/` (it would silently create
/// sub-folders) or NUL, so every component is sanitized with the Windows rules, which are a superset.
public enum DownloadPathBuilder {
    /// `host` + `_port` when explicit + `_segment` per non-empty path segment (`http://nas:8080/komga` →
    /// `nas_8080_komga`).
    public static func serverDirectoryName(for serverURL: URL) -> String {
        var name = serverURL.host(percentEncoded: false) ?? "server"
        if let port = serverURL.port { name += "_\(port)" }
        for segment in serverURL.pathComponents where segment != "/" && !segment.isEmpty {
            name += "_\(segment)"
        }
        return sanitize(name)
    }

    /// Relative path (from the download root) of a book file.
    public static func relativePath(serverURL: URL, libraryName: String, seriesName: String, bookURL: String)
        -> String
    {
        [
            serverDirectoryName(for: serverURL),
            sanitize(libraryName),
            sanitize(seriesName),
            sanitize(bookFileName(fromBookURL: bookURL)),
        ].joined(separator: "/")
    }

    /// `Path(book.url).name` — Komga URLs are server file paths (`/data/Comics/X/X v01.cbz`) or `file:` URIs.
    public static func bookFileName(fromBookURL bookURL: String) -> String {
        let path = bookURL.hasPrefix("file:") ? (URL(string: bookURL)?.path(percentEncoded: false) ?? bookURL) : bookURL
        let name = path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? path
        return name.isEmpty ? "book" : name
    }

    /// `removeIllegalWindowsPathChars`: `<>:"/\|?*`, control characters and trailing dots/spaces.
    public static func sanitize(_ component: String) -> String {
        let illegal = Set("<>:\"/\\|?*")
        var result = String(component.unicodeScalars.filter { $0.value >= 0x20 && !illegal.contains(Character($0)) })
        while let last = result.last, last == "." || last == " " { result.removeLast() }
        if result.isEmpty || result == ".." { return "_" }
        return result
    }
}
