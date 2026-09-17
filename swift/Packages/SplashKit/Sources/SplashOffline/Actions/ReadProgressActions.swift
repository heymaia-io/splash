import Foundation
import KomgaAPI

// Ports of komelia-domain/offline/.../readprogress/actions/*. Offline progress is stored locally with
// `lastModifiedDate = now`; `SyncReadProgressAction` pushes it once the server is reachable.

/// Port of `ProgressCompleteForBookAction`.
public struct ProgressCompleteForBookAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(bookId: KomgaBookId, userId: KomgaUserId) async throws {
        try await env.store.write { repos in
            let media = try repos.media.get(bookId)
            try repos.readProgress.save(
                OfflineReadProgress(bookId: bookId, userId: userId, page: media.pageCount, completed: true))
        }
        env.events.emit(OfflineEvents.readProgressChanged(bookId, userId))
    }
}

/// Port of `ProgressCompleteForSeriesAction`.
public struct ProgressCompleteForSeriesAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(seriesId: KomgaSeriesId, userId: KomgaUserId) async throws {
        let progresses = try await env.store.write { repos in
            let user = try repos.users.get(userId)
            let bookIds = try repos.books.findAllIdsBySeriesId(seriesId)
            let completed = Set(
                try repos.readProgress.findAllByBookIds(bookIds, userId: user.id).filter(\.completed).map(\.bookId))
            let pending = bookIds.filter { !completed.contains($0) }
            let progresses = try repos.media.findAll(pending).map {
                // Kotlin uses `pages.size`; `pageCount` is the same value and survives an empty page list.
                OfflineReadProgress(bookId: $0.bookId, userId: user.id, page: $0.pageCount, completed: true)
            }
            try repos.readProgress.save(progresses)
            return progresses
        }
        for progress in progresses { env.events.emit(OfflineEvents.readProgressChanged(progress.bookId, userId)) }
        env.events.emit(OfflineEvents.readProgressSeriesChanged(seriesId, userId))
    }
}

/// Port of `ProgressDeleteForBookAction`.
public struct ProgressDeleteForBookAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(bookId: KomgaBookId, userId: KomgaUserId) async throws {
        let deleted = try await env.store.write { repos in
            let existing = try repos.readProgress.find(bookId: bookId, userId: userId)
            try repos.readProgress.deleteByBookIds([bookId], userId: userId)
            return existing != nil
        }
        if deleted { env.events.emit(OfflineEvents.readProgressDeleted(bookId, userId)) }
    }
}

/// Port of `ProgressDeleteForSeriesAction`.
public struct ProgressDeleteForSeriesAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(seriesId: KomgaSeriesId, userId: KomgaUserId) async throws {
        let progresses = try await env.store.write { repos in
            let bookIds = try repos.books.findAllIdsBySeriesId(seriesId)
            let progresses = try repos.readProgress.findAllByBookIds(bookIds, userId: userId)
            try repos.readProgress.deleteByBookIds(bookIds, userId: userId)
            return progresses
        }
        for progress in progresses { env.events.emit(OfflineEvents.readProgressDeleted(progress.bookId, userId)) }
        env.events.emit(OfflineEvents.readProgressSeriesDeleted(seriesId, userId))
    }
}

/// Port of `ProgressMarkAction`.
public struct ProgressMarkAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(bookId: KomgaBookId, userId: KomgaUserId, page: Int) async throws {
        try await env.store.write { repos in
            let media = try repos.media.get(bookId)
            guard (1...max(media.pageCount, 1)).contains(page), media.pageCount > 0 else {
                throw OfflineError.invalidArgument(
                    "Page argument (\(page)) must be within 1 and book page count (\(media.pageCount))")
            }
            var locator: R2Locator?
            if media.mediaProfile == .epub {
                guard media.epubDivinaCompatible else {
                    throw OfflineError.invalidArgument("epub book is not Divina compatible")
                }
                guard let positions = media.epubExtension?.positions, positions.indices.contains(page - 1) else {
                    throw OfflineError.invalidState("Epub extension not found")
                }
                locator = positions[page - 1]
            }
            try repos.readProgress.save(
                OfflineReadProgress(
                    bookId: bookId, userId: userId, page: page, completed: page == media.pageCount, locator: locator))
        }
        env.events.emit(OfflineEvents.readProgressChanged(bookId, userId))
    }
}

/// Port of `ProgressMarkProgressionAction` (Readium progression → page / completed, including Komga's EPUB
/// position matching).
public struct ProgressMarkProgressionAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(bookId: KomgaBookId, userId: KomgaUserId, progression: R2Progression) async throws {
        try await env.store.write { repos in
            let media = try repos.media.get(bookId)
            guard let profile = media.mediaProfile else { throw OfflineError.invalidState("Media has no profile") }
            let progress: OfflineReadProgress
            switch profile {
            case .divina, .pdf:
                guard let position = progression.locator.locations?.position,
                    (1...max(media.pageCount, 1)).contains(position)
                else {
                    throw OfflineError.invalidArgument("Page argument must be within 1 and \(media.pageCount)")
                }
                progress = OfflineReadProgress(
                    bookId: bookId, userId: userId, page: position, completed: position == media.pageCount,
                    readDate: progression.modified, deviceId: progression.device.id,
                    deviceName: progression.device.name, locator: progression.locator)
            case .epub:
                progress = try Self.epubProgress(bookId: bookId, userId: userId, media: media, progression: progression)
            }
            try repos.readProgress.save(progress)
        }
        env.events.emit(OfflineEvents.readProgressChanged(bookId, userId))
    }

    static func epubProgress(
        bookId: KomgaBookId, userId: KomgaUserId, media: OfflineMedia, progression: R2Progression
    ) throws -> OfflineReadProgress {
        var href = progression.locator.href
        if let hash = href.firstIndex(of: "#") { href = String(href[..<hash]) }
        href = href.removingPercentEncoding ?? href
        guard let target = progression.locator.locations?.progression else {
            throw OfflineError.invalidArgument("location.progression is required")
        }
        guard let epub = media.epubExtension else { throw OfflineError.invalidState("Epub extension not found") }

        let matching = epub.positions.filter { $0.href == href }
        let matched: R2Locator
        if epub.isFixedLayout && matching.count == 1 {
            matched = matching[0]
        } else if let exact = matching.first(where: { $0.locations?.progression == target }) {
            matched = exact
        } else {
            // No exact match: the closest position before, provided one exists after as well.
            let before = matching.filter { ($0.locations?.progression ?? 0) < target }
                .max { ($0.locations?.position ?? 0) < ($1.locations?.position ?? 0) }
            let after = matching.filter { ($0.locations?.progression ?? 0) > target }
                .min { ($0.locations?.position ?? 0) < ($1.locations?.position ?? 0) }
            guard let before, let after,
                (before.locations?.position ?? 0) <= (after.locations?.position ?? 0)
            else { throw OfflineError.invalidArgument("Invalid progression") }
            matched = before
        }

        let total = matched.locations?.totalProgression
        var locator = progression.locator
        locator.type = matched.type
        locator.koboSpan = progression.locator.koboSpan ?? matched.koboSpan
        locator.locations?.totalProgression = total
        return OfflineReadProgress(
            bookId: bookId, userId: userId,
            page: total.map { Int((Float(media.pageCount) * $0).rounded()) } ?? 0,
            completed: total.map { $0 >= 0.99 } ?? false,
            readDate: progression.modified, deviceId: progression.device.id, deviceName: progression.device.name,
            locator: locator)
    }
}
