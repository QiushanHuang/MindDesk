# Canvas Interaction Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make small-canvas zoom, background pan, and card drag display-synchronised and substantially lighter without reducing card detail or link animation quality.

**Architecture:** A main-actor `CADisplayLink` driver coalesces input samples before they touch SwiftUI state. A stable world cache owns model-derived snapshot/index inputs, while a pure camera-transform policy lets live pan/zoom move the committed world as one visual layer and rebase exactly at gesture end.

**Tech Stack:** Swift 6, SwiftUI, AppKit, QuartzCore `CADisplayLink`, SwiftData, XCTest.

---

### Task 1: Add deterministic interaction-frame primitives

**Files:**
- Modify: `Sources/MindDeskCore/CanvasPerformancePolicies.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] **Step 1: Write failing accumulator and transform tests**

Add tests that submit several absolute samples and several scroll deltas before a manual tick, then require one latest absolute value and one summed scroll value. Add a camera-transform test for:

```swift
let transform = CanvasLiveViewportTransformPolicy.transform(
    baseZoom: 1,
    baseViewportX: 20,
    baseViewportY: 30,
    liveZoom: 1.5,
    liveViewportX: -10,
    liveViewportY: 12
)
XCTAssertEqual(transform.scale, 1.5)
XCTAssertEqual(transform.translationX, -40)
XCTAssertEqual(transform.translationY, -33)
```

- [ ] **Step 2: Run the focused RED**

Run:

```bash
swift test --filter 'CoreBehaviorTests/testCanvasInteractionFrameAccumulator|CoreBehaviorTests/testCanvasLiveViewportTransform'
```

Expected: compile failure because the new types do not exist.

- [ ] **Step 3: Implement the minimal pure policies**

Add exact-value structures with no clocks or UI dependencies:

```swift
public struct CanvasInteractionFrameAccumulator<Value> {
    private var pending: Value?
    public mutating func submit(_ value: Value) { pending = value }
    public mutating func consume() -> Value? {
        defer { pending = nil }
        return pending
    }
}

public struct CanvasScrollFrameSample: Equatable, Sendable {
    public var deltaY: Double
    public var location: CanvasEdgePoint
}

public enum CanvasLiveViewportTransformPolicy {
    public static func transform(
        baseZoom: Double,
        baseViewportX: Double,
        baseViewportY: Double,
        liveZoom: Double,
        liveViewportX: Double,
        liveViewportY: Double
    ) -> CanvasViewportVisualTransform {
        let scale = liveZoom / baseZoom
        return .init(
            scale: scale,
            translationX: liveViewportX - baseViewportX * scale,
            translationY: liveViewportY - baseViewportY * scale
        )
    }
}
```

The scroll accumulator must sum finite deltas, keep the latest location, and fail closed on invalid values. The transform must return identity for invalid or non-positive zoom inputs.

- [ ] **Step 4: Run the focused GREEN**

Run the same filter and expect all new tests to pass without warnings.

- [ ] **Step 5: Commit the primitive layer**

```bash
git add Sources/MindDeskCore/CanvasPerformancePolicies.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift
git commit -m "perf: add canvas frame coalescing policies"
```

### Task 2: Add a non-observable display-link driver

**Files:**
- Create: `Sources/MindDesk/Canvas/CanvasInteractionFrameDriver.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`

- [ ] **Step 1: Write failing driver tests**

Add `@MainActor` tests using a manual-tick initializer:

```swift
let driver = CanvasInteractionFrameDriver(automaticallySchedulesDisplayLink: false)
var values: [Int] = []
driver.submitLatest(channel: .viewport) { values.append(1) }
driver.submitLatest(channel: .viewport) { values.append(2) }
XCTAssertEqual(driver.pendingChannelCount, 1)
driver.fireForTesting()
XCTAssertEqual(values, [2])
```

Also prove `flush(.viewport)` executes the latest closure immediately, scroll deltas combine once, cancellation executes nothing, and the driver does not retain a captured owner after cancellation.

- [ ] **Step 2: Run the focused RED**

```bash
swift test --filter 'AppBehaviorTests/testCanvasInteractionFrameDriver'
```

Expected: compile failure because the driver does not exist.

- [ ] **Step 3: Implement the driver**

Create an internal main-actor `NSObject & ObservableObject` with no `@Published` state:

```swift
@MainActor
final class CanvasInteractionFrameDriver: NSObject, ObservableObject {
    enum Channel: Hashable { case viewport, magnify, nodeDrag, edgeControl }
    private var pending: [Channel: () -> Void] = [:]
    private var displayLink: CADisplayLink?

    func submitLatest(channel: Channel, update: @escaping () -> Void) {
        pending[channel] = update
        scheduleIfNeeded()
    }

    func flush(_ channel: Channel) { pending.removeValue(forKey: channel)?() }
    func cancelAll() { pending.removeAll(); displayLink?.invalidate(); displayLink = nil }
}
```

Use `CADisplayLink` on the main run loop with minimum 30, maximum 120, and preferred 120 frames per second. The selector swaps out the pending dictionary before executing closures so reentrant submissions wait for the next frame. A manual-tick mode uses the same drain method.

- [ ] **Step 4: Run the focused GREEN**

Run the driver filter and expect all tests to pass.

- [ ] **Step 5: Commit the driver**

```bash
git add Sources/MindDesk/Canvas/CanvasInteractionFrameDriver.swift Tests/MindDeskTests/AppBehaviorTests.swift
git commit -m "perf: coalesce canvas input to display frames"
```

### Task 3: Wire wheel, pinch, pan, and card drag through the driver

**Files:**
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDesk/Canvas/CanvasInteractionFrameDriver.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`

- [ ] **Step 1: Write a failing integration/source contract test**

Require the view to own one `@StateObject` driver, submit camera and card-drag updates through named channels, flush on every matching `onEnded`, cancel on disappear, and keep existing persistence only after the flush. Require the old per-event `pendingScrollZoomCommit` `@State` declaration to be absent.

- [ ] **Step 2: Run the focused RED**

```bash
swift test --filter 'AppBehaviorTests/testWorkspaceCanvasCoalescesLiveGestureStateAtDisplayCadence'
```

Expected: assertion failure because gesture handlers still mutate state directly.

- [ ] **Step 3: Wire absolute gesture samples**

Map background pan to `.viewport`, pinch to `.magnify`, node drag and node resize to `.nodeDrag`, and edge-control drag to `.edgeControl`. Replace their direct transient writes with:

```swift
interactionFrameDriver.submitLatest(channel: .viewport) { [latest = value.translation] in
    transientViewportOffset = latest
}
```

Capture only the latest derived value. Every matching `onEnded` first submits its end-derived value to the same channel, calls `flush(channel)`, and only then runs the existing commit.

- [ ] **Step 4: Wire scroll accumulation and debounce**

Move scroll-delta accumulation and the save-debounce task into the driver. The driver invokes `zoomFromScroll` once per display frame with the summed delta and latest anchor. Cache the pass-through decision for an AppKit scroll sequence and clear it on ended/cancelled phases.

- [ ] **Step 5: Verify the integration GREEN**

Run the source-contract test plus existing drag/zoom persistence tests. Expected: all pass; no save occurs during changed events.

- [ ] **Step 6: Commit the wiring**

```bash
git add Sources/MindDesk/Canvas/CanvasInteractionFrameDriver.swift Sources/MindDesk/Canvas/WorkspaceCanvasView.swift Tests/MindDeskTests/AppBehaviorTests.swift
git commit -m "perf: schedule canvas gestures on display cadence"
```

### Task 4: Cache stable world-derived data

**Files:**
- Create: `Sources/MindDesk/Canvas/CanvasWorldDerivedCache.swift`
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDeskCore/CanvasEdgeViewportIndex.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] **Step 1: Write failing cache tests**

Construct a small set of real `CanvasNodeModel` and `CanvasEdgeModel` instances. Require two camera-only reads to return the same derived generation, then mutate node geometry, card z-order, edge endpoints, and membership one at a time and require one generation increase for each. Require model text changes that do not affect topology/geometry to preserve the generation.

- [ ] **Step 2: Run the focused RED**

```bash
swift test --filter 'AppBehaviorTests/testCanvasWorldDerivedCache'
```

Expected: compile failure because the cache does not exist.

- [ ] **Step 3: Extract and implement the cache**

Move `CanvasRenderSnapshot` and `CanvasEdgeSegment` into the new focused file. Add exact structural/geometry tokens and store:

```swift
struct CanvasWorldDerivedState {
    let generation: Int
    let snapshot: CanvasRenderSnapshot
    let edgeIndex: CanvasEdgeViewportIndex
    let edgeIndexDiagnostics: CanvasEdgeViewportIndexCacheDiagnostics
}
```

The cache scans exact tokens on access but rebuilds dictionaries, sorts, index records, and the core index only when tokens differ. It must not key on viewport, transient zoom, or transient drag offsets.

- [ ] **Step 4: Remove per-frame reuse logging from the UI path**

Add a `logsReuseEvents` option to `CanvasEdgeViewportIndexCache`, defaulting to `true` for existing diagnostic tests. The world cache constructs its core cache with reuse logging disabled while preserving create/invalidate/cleanup logs and counters.

- [ ] **Step 5: Wire the cached state and run GREEN**

Replace `renderSnapshot` plus per-body node/edge index mapping with one cached derived-state read. Run cache tests, edge-cache diagnostic tests, and existing viewport-index pan/zoom tests.

- [ ] **Step 6: Commit stable derived caching**

```bash
git add Sources/MindDesk/Canvas/CanvasWorldDerivedCache.swift Sources/MindDesk/Canvas/WorkspaceCanvasView.swift Sources/MindDeskCore/CanvasEdgeViewportIndex.swift Tests/MindDeskTests/AppBehaviorTests.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift
git commit -m "perf: cache stable canvas world derivations"
```

### Task 5: Apply a single live camera transform and preserve active drag work

**Files:**
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDeskCore/CanvasPerformancePolicies.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] **Step 1: Write failing camera-fast-path tests**

Require camera-only interaction to use committed zoom/viewport for card and edge geometry and apply `CanvasLiveViewportTransformPolicy` once to the world layer. Require the grid and screen-space selection overlay to remain outside that transform. Add an active-set policy test proving a card drag retains moving nodes, selected edges, transient-control edges, and incident edges while passive peers remain stable.

- [ ] **Step 2: Run the focused RED**

Run the new core and app tests. Expected: source assertions/policies fail because the world layer is not split.

- [ ] **Step 3: Implement committed render geometry plus live transform**

Introduce committed render accessors used only by world geometry:

```swift
private var worldRenderZoom: Double { canvas.zoom }
private var worldRenderViewportX: Double { canvas.viewportX }
private var worldRenderViewportY: Double { canvas.viewportY }
private var liveWorldTransform: CanvasViewportVisualTransform {
    CanvasLiveViewportTransformPolicy.transform(
        baseZoom: worldRenderZoom,
        baseViewportX: worldRenderViewportX,
        baseViewportY: worldRenderViewportY,
        liveZoom: effectiveZoom,
        liveViewportX: effectiveViewportX,
        liveViewportY: effectiveViewportY
    )
}
```

Wrap cards, edges, arrowheads, handles, and active drag affordances in a fixed-size inner `ZStack`, then apply one top-leading scale and translation. Keep the grid, selection rectangle, empty state, drop border, and gestures in the outer screen-space layer.

- [ ] **Step 4: Preserve visibility and drag correctness**

While the camera transform is non-identity, expand the committed visible region by the inverse live transform plus existing overscan. Continue using existing force-retention/active-edge policies for moving nodes. Display-link coalescing limits live drag changes; persistence and force-retention semantics remain unchanged.

- [ ] **Step 5: Verify visual-quality contracts**

Run tests proving pan/zoom still admits glow animation, sparse zoom still renders rich details, and no new reduced-frame-rate or animation-disable branch exists.

- [ ] **Step 6: Commit the camera and drag fast paths**

```bash
git add Sources/MindDesk/Canvas/WorkspaceCanvasView.swift Sources/MindDeskCore/CanvasPerformancePolicies.swift Tests/MindDeskTests/AppBehaviorTests.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift
git commit -m "perf: transform stable canvas world during interaction"
```

### Task 6: Verify and document delivery evidence

**Files:**
- Modify if user-visible behavior needs explanation: `CHANGELOG.md`
- Modify if evidence tracking remains active: `docs/review/macos26-coordination.md`

- [ ] **Step 1: Run focused Debug tests**

```bash
swift test --filter 'Canvas|WorkspaceCanvas'
```

Expected: all focused tests pass with no warnings or failures.

- [ ] **Step 2: Run complete Debug and Release suites**

```bash
swift test
swift test -c release
```

Expected baseline: at least the existing 666 tests plus new tests, zero failures and zero skips.

- [ ] **Step 3: Build Release**

```bash
swift build -c release --product MindDesk
```

Expected: exit 0 with no compiler diagnostics.

- [ ] **Step 4: Run static integrity checks**

```bash
git diff --check
git status --short
```

Expected: only authorised Canvas/core/test/docs paths before commit; no staged or unrelated files.

- [ ] **Step 5: Perform manual interaction smoke**

Launch the app and verify wheel zoom, pinch zoom, background pan, single-card drag, multi-card drag, and frame drag on a small Canvas. Confirm continuous glow, rich cards, exact final positions, and no jump at commit.

- [ ] **Step 6: Commit final evidence/docs**

```bash
git add CHANGELOG.md docs/review/macos26-coordination.md
git commit -m "docs: record canvas interaction performance evidence"
```

Skip this commit when neither file needs a truthful update.
