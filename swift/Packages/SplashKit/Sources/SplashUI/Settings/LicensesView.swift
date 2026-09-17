import SwiftUI

/// Third-party notices (plan Phase 16): Komelia is Apache-2.0 — this app is a modified Swift port of it — and the
/// bundled libraries require their license texts to ship with the binary.
struct LicensesView: View {
    struct Entry: Identifiable {
        let name: String
        let license: String
        let file: String
        let url: String
        var id: String { file }
    }

    static let entries: [Entry] = [
        Entry(name: "Komelia (Snd-R) — this app is a modified Swift port", license: "Apache License 2.0",
              file: "LICENSE-Komelia-Apache-2.0", url: "https://github.com/Snd-R/Komelia"),
        Entry(name: "komga-client (Snd-R)", license: "MIT", file: "LICENSE-komga-client-MIT",
              url: "https://github.com/Snd-R/komga-client"),
        Entry(name: "GRDB.swift", license: "MIT", file: "LICENSE-GRDB-MIT", url: "https://github.com/groue/GRDB.swift"),
        Entry(name: "Readium Swift Toolkit", license: "BSD 3-Clause", file: "LICENSE-Readium-BSD-3",
              url: "https://github.com/readium/swift-toolkit"),
        Entry(name: "ZIPFoundation (Readium fork)", license: "MIT", file: "LICENSE-ZIPFoundation-MIT",
              url: "https://github.com/readium/ZIPFoundation"),
        Entry(name: "CryptoSwift", license: "See license", file: "LICENSE-CryptoSwift",
              url: "https://github.com/krzyzanowskim/CryptoSwift"),
        Entry(name: "DifferenceKit", license: "Apache License 2.0", file: "LICENSE-DifferenceKit",
              url: "https://github.com/ra1028/DifferenceKit"),
        Entry(name: "Fuzi", license: "MIT", file: "LICENSE-Fuzi", url: "https://github.com/cezheng/Fuzi"),
        Entry(name: "SwiftSoup", license: "MIT", file: "LICENSE-SwiftSoup", url: "https://github.com/scinfu/SwiftSoup"),
        Entry(name: "Zip", license: "MIT", file: "LICENSE-Zip", url: "https://github.com/marmelroy/Zip"),
    ]

    var body: some View {
        List {
            Section {
                Text("This app is based on Komelia by Snd-R, licensed under the Apache License 2.0. The original Kotlin code was translated to Swift and modified. Komga is a trademark of its respective owner; this app is an unofficial client.")
                    .font(.footnote)
            }
            ForEach(Self.entries) { entry in
                NavigationLink {
                    ScrollView {
                        Text(Self.text(for: entry.file))
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                    }
                    .navigationTitle(entry.name)
                } label: {
                    VStack(alignment: .leading) {
                        Text(entry.name)
                        Text(entry.license).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Third-party licenses")
    }

    static func text(for file: String) -> String {
        guard let url = Bundle.module.url(forResource: file, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "License text unavailable." }
        return text
    }
}
