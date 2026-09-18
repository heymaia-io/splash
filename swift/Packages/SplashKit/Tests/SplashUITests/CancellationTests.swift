import Foundation
import KomgaAPI
import Testing
@testable import SplashUI

/// Screens catch broadly and render whatever they caught. Cancellation is not a failure — it means nobody is
/// waiting for the result any more — and showing it puts "CancellationError error 1" in front of the user.
///
/// This matters more since the shell is keyed on the private-area unlock state: locking or revealing rebuilds
/// the screens, which cancels whatever they had in flight.
@Suite struct CancellationTests {
    @Test func recognisesTaskCancellation() {
        #expect(CancellationError().isCancellation)
    }

    /// A cancelled `URLSession` request surfaces as this, not as `CancellationError`.
    @Test func recognisesACancelledRequest() {
        #expect(URLError(.cancelled).isCancellation)
    }

    @Test func realFailuresAreStillReported() {
        #expect(!URLError(.timedOut).isCancellation)
        #expect(!URLError(.notConnectedToInternet).isCancellation)
        #expect(!KomgaAPIError.httpStatus(code: 500, body: Data()).isCancellation)
        #expect(!KomgaAPIError.invalidResponse.isCancellation)
    }
}
