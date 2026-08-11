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
    private var displayLinkLifetime: CanvasInteractionDisplayLinkLifetime?

    init(automaticallySchedulesDisplayLink: Bool = true) {
        self.automaticallySchedulesDisplayLink = automaticallySchedulesDisplayLink
        super.init()
    }

    var pendingChannelCount: Int {
        pendingUpdates.count
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

    func cancelAll() {
        pendingUpdates.removeAll()
        scrollAccumulator = CanvasScrollFrameAccumulator()
        pendingScrollUpdate = nil
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
        let scrollSample = scrollAccumulator.consume()
        let scrollUpdate = pendingScrollUpdate
        pendingScrollUpdate = nil

        for update in updates.values {
            update()
        }
        if let scrollSample {
            scrollUpdate?(scrollSample)
        }

        pauseDisplayLinkIfIdle()
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
