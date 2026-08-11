import AppKit
import Combine
import MindDeskCore
import QuartzCore

@MainActor
final class CanvasInteractionFrameDriver: NSObject, ObservableObject {
    enum Channel: Hashable {
        case viewport
        case magnify
        case nodeDrag
        case edgeControl
    }

    private let automaticallySchedulesDisplayLink: Bool
    private var pendingUpdates: [Channel: () -> Void] = [:]
    private var scrollAccumulator = CanvasScrollFrameAccumulator()
    private var pendingScrollUpdate: ((CanvasScrollFrameSample) -> Void)?
    private var pendingDebouncedCommit: (() -> Void)?
    private var nextDebouncedCommitGeneration: UInt64 = 0
    private var pendingDebouncedCommitGeneration: UInt64?
    private var debouncedCommitTask: Task<Void, Never>?
    private var displayLinkLifetime: CanvasInteractionDisplayLinkLifetime?

    init(automaticallySchedulesDisplayLink: Bool = true) {
        self.automaticallySchedulesDisplayLink = automaticallySchedulesDisplayLink
        super.init()
    }

    var pendingChannelCount: Int {
        pendingUpdates.count
    }

    var pendingDebouncedCommitGenerationForTesting: UInt64? {
        pendingDebouncedCommitGeneration
    }

    func submitLatest(channel: Channel, update: @escaping () -> Void) {
        pendingUpdates[channel] = update
        scheduleIfNeeded()
    }

    func submitScroll(
        _ sample: CanvasScrollFrameSample,
        update: @escaping (CanvasScrollFrameSample) -> Void
    ) {
        scrollAccumulator.submit(sample)
        pendingScrollUpdate = update
        scheduleIfNeeded()
    }

    func flush(_ channel: Channel) {
        pendingUpdates.removeValue(forKey: channel)?()
        pauseDisplayLinkIfIdle()
    }

    func flushScroll() {
        performPendingScrollUpdate()
        pauseDisplayLinkIfIdle()
    }

    func scheduleDebouncedCommit(
        delayNanos: UInt64,
        action: @escaping () -> Void
    ) {
        cancelDebouncedCommit()
        nextDebouncedCommitGeneration &+= 1
        let generation = nextDebouncedCommitGeneration
        pendingDebouncedCommitGeneration = generation
        pendingDebouncedCommit = action
        debouncedCommitTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanos)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.performDebouncedCommit(generation: generation)
        }
    }

    func flushDebouncedCommit() {
        debouncedCommitTask?.cancel()
        debouncedCommitTask = nil
        guard let generation = pendingDebouncedCommitGeneration else { return }
        performDebouncedCommit(generation: generation)
    }

    func cancelDebouncedCommit() {
        debouncedCommitTask?.cancel()
        debouncedCommitTask = nil
        pendingDebouncedCommit = nil
        pendingDebouncedCommitGeneration = nil
    }

    func fireDebouncedCommitForTesting(generation: UInt64) {
        performDebouncedCommit(generation: generation)
    }

    func cancelAll() {
        pendingUpdates.removeAll()
        scrollAccumulator = CanvasScrollFrameAccumulator()
        pendingScrollUpdate = nil
        cancelDebouncedCommit()
        displayLinkLifetime?.invalidate()
        displayLinkLifetime = nil
    }

    func fireForTesting() {
        drainPendingUpdates()
    }

    fileprivate func displayLinkDidFire() {
        drainPendingUpdates()
    }

    private var hasPendingWork: Bool {
        !pendingUpdates.isEmpty || pendingScrollUpdate != nil
    }

    private func scheduleIfNeeded() {
        guard automaticallySchedulesDisplayLink else { return }
        if let displayLinkLifetime {
            displayLinkLifetime.displayLink.isPaused = false
            return
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let target = CanvasInteractionDisplayLinkTarget(driver: self)
        let displayLink = screen.displayLink(
            target: target,
            selector: #selector(CanvasInteractionDisplayLinkTarget.displayLinkDidFire(_:))
        )
        displayLink.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: 120,
            preferred: 120
        )
        displayLink.isPaused = true
        displayLink.add(to: .main, forMode: .common)

        displayLinkLifetime = CanvasInteractionDisplayLinkLifetime(displayLink: displayLink)
        displayLink.isPaused = false
    }

    private func drainPendingUpdates() {
        let updates = pendingUpdates
        pendingUpdates.removeAll(keepingCapacity: true)

        for update in updates.values {
            update()
        }
        performPendingScrollUpdate()

        pauseDisplayLinkIfIdle()
    }

    private func performPendingScrollUpdate() {
        let sample = scrollAccumulator.consume()
        let update = pendingScrollUpdate
        pendingScrollUpdate = nil
        if let sample {
            update?(sample)
        }
    }

    private func performDebouncedCommit(generation: UInt64) {
        guard pendingDebouncedCommitGeneration == generation else { return }
        debouncedCommitTask = nil
        let action = pendingDebouncedCommit
        pendingDebouncedCommit = nil
        pendingDebouncedCommitGeneration = nil
        action?()
    }

    private func pauseDisplayLinkIfIdle() {
        displayLinkLifetime?.displayLink.isPaused = !hasPendingWork
    }
}

private final class CanvasInteractionDisplayLinkLifetime {
    let displayLink: CADisplayLink

    init(displayLink: CADisplayLink) {
        self.displayLink = displayLink
    }

    func invalidate() {
        displayLink.invalidate()
    }

    deinit {
        displayLink.invalidate()
    }
}

@MainActor
private final class CanvasInteractionDisplayLinkTarget: NSObject {
    private weak var driver: CanvasInteractionFrameDriver?

    init(driver: CanvasInteractionFrameDriver) {
        self.driver = driver
    }

    @objc
    func displayLinkDidFire(_ displayLink: CADisplayLink) {
        driver?.displayLinkDidFire()
    }
}
