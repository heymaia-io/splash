import Foundation

/// Minimal multipart/form-data body for thumbnail uploads (ktor `MultiPartFormDataContent`).
struct MultipartForm {
    let boundary = "KomeliaBoundary-\(UUID().uuidString)"
    private var body = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func addFile(name: String, filename: String, data: Data, mimeType: String = "application/octet-stream") {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }

    mutating func addField(name: String, value: String) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        body.append(Data("\(value)\r\n".utf8))
    }

    func finalized() -> Data {
        body + Data("--\(boundary)--\r\n".utf8)
    }
}

extension KomgaHTTPClient {
    /// Shared by the four `uploadThumbnail` endpoints.
    func uploadThumbnail<T: Decodable>(path: String, file: Data, filename: String, selected: Bool) async throws -> T {
        var form = MultipartForm()
        form.addFile(name: "file", filename: filename, data: file)
        form.addField(name: "selected", value: String(selected))
        let request = request(.post, path, body: form.finalized(), contentType: form.contentType)
        return try await fetch(request, as: T.self)
    }
}
