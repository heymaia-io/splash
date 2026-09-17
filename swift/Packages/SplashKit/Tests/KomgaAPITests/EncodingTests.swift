import Foundation
import Testing
@testable import KomgaAPI

@Suite("Request encoding matches the komga-client wire format")
struct EncodingTests {
    @Test func patchValueOmitsUnsetAndSendsNull() throws {
        var request = KomgaSeriesMetadataUpdateRequest()
        request.title = .some("New")
        request.ageRating = .none
        #expect(try encodedJSON(request) == #"{"ageRating":null,"title":"New"}"#)
        #expect(try encodedJSON(KomgaSeriesMetadataUpdateRequest()) == "{}")
    }

    @Test func patchDiff() {
        #expect(PatchValue<String>.diff(original: "a", patch: "a") == .unset)
        #expect(PatchValue<String>.diff(original: "a", patch: nil) == .none)
        #expect(PatchValue<String>.diff(original: "a", patch: "b") == .some("b"))
    }

    @Test func userUpdateUsesSharedLibrariesIdsKey() throws {
        var request = KomgaUserUpdateRequest()
        request.sharedLibraries = .some(KomgaSharedLibrariesUpdate(all: false, libraryIds: ["L1"]))
        #expect(try encodedJSON(request) == #"{"sharedLibrariesIds":{"all":false,"libraryIds":["L1"]}}"#)
    }

    @Test func libraryUpdateOmitsNilOptionals() throws {
        var request = KomgaLibraryUpdateRequest()
        request.name = "X"
        request.oneshotsDirectory = .none
        #expect(try encodedJSON(request) == #"{"name":"X","oneshotsDirectory":null}"#)
    }

    @Test func bookSearchCondition() throws {
        let search = KomgaBookSearch(
            condition: .allOfBooks(
                .seriesId(.isEqualTo("S1")),
                .readStatus(.isNotEqualTo(.read)),
                .anyOf([.tag(.isNull), .title(.contains("hero"))]),
                .deleted(.isFalse)
            ))
        #expect(try encodedJSON(search) == #"{"condition":{"allOf":[{"seriesId":{"operator":"is","value":"S1"}},{"readStatus":{"operator":"isNot","value":"READ"}},{"anyOf":[{"tag":{"operator":"isNull"}},{"title":{"operator":"contains","value":"hero"}}]},{"deleted":{"operator":"isFalse"}}]}}"#)
    }

    @Test func seriesConditionRoundTrip() throws {
        let condition: SeriesCondition = .allOfSeries(
            .libraryId(.isEqualTo("L1")),
            .ageRating(.greaterThan(12)),
            .releaseDate(.isInTheLast(.days(30))),
            .author(.isEqualTo(AuthorMatch(name: "A"))),
            .complete(.isTrue)
        )
        let json = try encodedJSON(condition)
        #expect(json.contains(#"{"releaseDate":{"duration":"PT720H","operator":"isInTheLast"}}"#))
        #expect(json.contains(#"{"author":{"operator":"is","value":{"name":"A"}}}"#))
        let decoded = try KomgaJSON.makeDecoder().decode(SeriesCondition.self, from: Data(json.utf8))
        #expect(decoded == condition)
    }

    @Test func durationIso() {
        #expect(KomgaDuration.days(30).isoString == "PT720H")
        #expect(KomgaDuration(seconds: 5430).isoString == "PT1H30M30S")
        #expect(KomgaDuration(isoString: "PT1H30M30S")?.seconds == 5430)
        #expect(KomgaDuration(isoString: "P1D") == nil)
    }

    @Test func pageRequestQueryItems() {
        let request = KomgaPageRequest(
            pageIndex: 2, size: 50, sort: KomgaBooksSort.byNumber(.asc).and(KomgaBooksSort.byTitle(.desc)))
        #expect(request.queryItems.map { "\($0.name)=\($0.value ?? "")" } == [
            "size=50", "page=2", "unpaged=false", "sort=metadata.numberSort,asc", "sort=metadata.title,desc",
        ])
    }

    @Test func eventDecoding() {
        let event = KomgaEvent.decode(
            event: "BookChanged", data: #"{"bookId":"B","seriesId":"S","libraryId":"L"}"#)
        #expect(event == .bookChanged(.init(bookId: "B", seriesId: "S", libraryId: "L")))
        #expect(KomgaEvent.decode(event: "Nope", data: "{}") == .unknown(event: "Nope", data: "{}"))
        #expect(KomgaEvent.decode(event: "BookChanged", data: "{bad") == .unknown(event: "BookChanged", data: "{bad"))
    }

    @Test func localDate() throws {
        #expect(KomgaLocalDate("2001-01-01") == KomgaLocalDate(year: 2001, month: 1, day: 1))
        #expect(try encodedJSON([KomgaLocalDate(year: 2001, month: 2, day: 3)]) == #"["2001-02-03"]"#)
    }
}
