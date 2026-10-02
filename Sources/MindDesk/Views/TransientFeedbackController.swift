import Combine
import Foundation

@MainActor
final class TransientFeedbackController: ObservableObject {
    typealias Scheduler = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> AnyCancellable

    @Published private(set) var message: String?
    private let scheduleDismissal: Scheduler
    private var pendingDismissal: AnyCancellable?
    private var presentationID: UUID?

    init(scheduleDismissal: Scheduler? = nil) {
        self.scheduleDismissal = scheduleDismissal ?? Self.scheduleDismissal
    }

    func show(_ message: String) {
        let presentationID = UUID()
        self.presentationID = presentationID
        pendingDismissal?.cancel()
        self.message = message
        pendingDismissal = scheduleDismissal(1.1) { [weak self] in
            // Cancellation may race with an already delivered expiration callback.
            // Text equality cannot distinguish two successive "Copied" messages.
            guard let self, self.presentationID == presentationID else { return }
            self.presentationID = nil
            self.message = nil
            self.pendingDismissal = nil
        }
    }

    func cancel() {
        presentationID = nil
        pendingDismissal?.cancel()
        pendingDismissal = nil
        message = nil
    }

    private static func scheduleDismissal(
        after delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> AnyCancellable {
        let task = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
        return AnyCancellable { task.cancel() }
    }
}
