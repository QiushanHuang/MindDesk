import Combine
import XCTest
@testable import MindDesk

@MainActor
final class TransientFeedbackControllerTests: XCTestCase {
    func testRepeatedIdenticalFeedbackGetsItsOwnFullDisplayLifetime() {
        let scheduler = FeedbackDismissalScheduler()
        let feedback = TransientFeedbackController(scheduleDismissal: scheduler.schedule)
        feedback.show("Copied")
        feedback.show("Copied")

        XCTAssertEqual(scheduler.jobs.map(\.delay), [1.1, 1.1])
        XCTAssertTrue(scheduler.jobs[0].isCancelled)
        scheduler.jobs[0].action()
        XCTAssertEqual(feedback.message, "Copied", "An older expiration must not hide the latest identical feedback")

        scheduler.jobs[1].action()
        XCTAssertNil(feedback.message)
    }

    func testReplacingFeedbackIgnoresTheOldExpiration() {
        let scheduler = FeedbackDismissalScheduler()
        let feedback = TransientFeedbackController(scheduleDismissal: scheduler.schedule)
        feedback.show("Copied")
        feedback.show("Details")

        scheduler.jobs[0].action()
        XCTAssertEqual(feedback.message, "Details")
        scheduler.jobs[1].action()
        XCTAssertNil(feedback.message)
    }

    func testDisappearanceCancelsFeedbackWithoutAffectingAReappearedCard() {
        let scheduler = FeedbackDismissalScheduler()
        let feedback = TransientFeedbackController(scheduleDismissal: scheduler.schedule)
        feedback.show("Copied")
        feedback.cancel()
        XCTAssertNil(feedback.message)
        XCTAssertTrue(scheduler.jobs[0].isCancelled)

        feedback.show("Copied")
        scheduler.jobs[0].action()
        XCTAssertEqual(feedback.message, "Copied", "A cancelled card lifetime must not dismiss a new lifetime")
        scheduler.jobs[1].action()
        XCTAssertNil(feedback.message)
    }

    func testPendingDismissalDoesNotRetainTheController() {
        let scheduler = FeedbackDismissalScheduler()
        var feedback: TransientFeedbackController? = TransientFeedbackController(scheduleDismissal: scheduler.schedule)
        let currentController = { [weak feedback] in feedback }
        feedback?.show("Copied")
        feedback = nil

        XCTAssertNil(currentController())
        XCTAssertTrue(scheduler.jobs[0].isCancelled)
        scheduler.jobs[0].action()
    }
}

@MainActor
private final class FeedbackDismissalScheduler {
    final class Job {
        let delay: TimeInterval
        let action: @MainActor () -> Void
        var isCancelled = false

        init(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.delay = delay
            self.action = action
        }
    }

    private(set) var jobs: [Job] = []

    func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void) -> AnyCancellable {
        let job = Job(delay: delay, action: action)
        jobs.append(job)
        return AnyCancellable { job.isCancelled = true }
    }
}
