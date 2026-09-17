import Foundation
import KomgaAPI

// Ports of komelia-domain/offline/.../series/actions/*. Not ported (Kotlin `TODO()`): SeriesAnalyzeAction,
// SeriesRefreshMetadataAction, SeriesUpdateMetadataAction, Series{Add,Select,Delete}ThumbnailAction.

/// Port of `SeriesKomgaImportAction`.
public struct SeriesKomgaImportAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ series: KomgaSeries, source: any OfflineImportSource) async throws {
        do {
            let thumbnail = try await source.selectedSeriesThumbnail(series.id)
            try await env.store.write { repos in
                try repos.series.save(series.toOfflineSeries())
                try repos.seriesMetadata.save(OfflineSeriesMetadata(seriesId: series.id, metadata: series.metadata))
                // Fix: Kotlin overwrote the aggregation with an empty one on every import (it is only rebuilt after
                // a *book* import, so series whose books are all unavailable lost authors/tags).
                if try repos.bookMetadataAggregations.find(series.id) == nil {
                    try repos.bookMetadataAggregations.save(OfflineBookMetadataAggregation(seriesId: series.id))
                }
                if let thumbnail {
                    try repos.seriesThumbnails.deleteBySeriesIds([series.id])
                    try repos.seriesThumbnails.save(thumbnail)
                }
                try repos.logJournal.save(.info("Series updated '\(series.metadata.title)'"))
            }
        } catch {
            await env.store.log(.error("Series update error '\(series.metadata.title)'", error))
            throw error
        }
    }
}

/// Port of `SeriesDeleteManyAction`.
public struct SeriesDeleteManyAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ series: [OfflineSeries]) async throws {
        let outcome = try await env.store.write { try Self.delete(series, in: $0) }
        try await outcome.publish(events: env.events, taskEmitter: env.taskEmitter)
    }

    static func delete(_ series: [OfflineSeries], in repos: any OfflineRepositories) throws -> DeletionOutcome {
        guard !series.isEmpty else { return DeletionOutcome() }
        let ids = series.map(\.id)
        var outcome = try BookDeleteManyAction.delete(try repos.books.findAllBySeriesIds(ids), in: repos)
        try repos.readProgress.deleteBySeriesIds(ids)
        try repos.seriesThumbnails.deleteBySeriesIds(ids)
        try repos.seriesMetadata.delete(ids)
        try repos.bookMetadataAggregations.delete(ids)
        try repos.series.delete(ids)
        outcome.events += series.map(OfflineEvents.seriesDeleted)
        return outcome
    }
}

/// Port of `SeriesDeleteAction`.
public struct SeriesDeleteAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ seriesId: KomgaSeriesId) async throws {
        let (series, outcome) = try await env.store.write { repos in
            let series = try repos.series.get(seriesId)
            var outcome = try SeriesDeleteManyAction.delete([series], in: repos)
            outcome.events.removeLast()  // the series event depends on the online/offline mode below
            return (series, outcome)
        }
        try await outcome.publish(events: env.events, taskEmitter: env.taskEmitter)
        env.events.emit(env.isOffline ? OfflineEvents.seriesDeleted(series) : OfflineEvents.seriesChanged(series))
    }
}

/// Port of `SeriesAggregateBookMetadataAction` — Komga's series-level "books metadata" (authors, tags, first
/// non-blank summary, earliest release date) over the *downloaded* books.
public struct SeriesAggregateBookMetadataAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ seriesId: KomgaSeriesId) async throws {
        try await env.store.write { repos in
            guard try repos.series.find(seriesId) != nil else { return }  // series deleted meanwhile
            let ids = try repos.books.findAllIdsBySeriesId(seriesId)
            let metadata = try repos.bookMetadata.findAllByIds(ids).map(\.metadata)
            let existing = try repos.bookMetadataAggregations.find(seriesId)
            var aggregation = Self.aggregate(seriesId: seriesId, metadata: metadata)
            aggregation.createdDate = existing?.createdDate ?? aggregation.createdDate
            try repos.bookMetadataAggregations.save(aggregation)
        }
    }

    static func aggregate(seriesId: KomgaSeriesId, metadata: [KomgaBookMetadata]) -> OfflineBookMetadataAggregation {
        var seen = Set<String>()
        let authors = metadata.flatMap(\.authors).filter { seen.insert("\($0.role)__\($0.name)").inserted }
        let withSummary = metadata.sorted { $0.numberSort < $1.numberSort }
            .first { !$0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return OfflineBookMetadataAggregation(
            seriesId: seriesId,
            releaseDate: metadata.compactMap(\.releaseDate).min(),
            summary: withSummary?.summary ?? "",
            summaryNumber: withSummary?.number ?? "",
            authors: authors,
            tags: Set(metadata.flatMap(\.tags)))
    }
}
