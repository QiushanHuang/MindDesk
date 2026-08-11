# Canvas Interaction Performance Design

## Goal

Make Canvas zoom, background pan, and card drag feel smooth even on a small canvas with fewer than twenty cards, without lowering the existing visual quality. Pan and zoom must keep the current link glow and rich card content, and the final viewport or card position must remain exact and durable.

## Diagnosis

The current bottleneck is event-driven render churn rather than persistence or obstacle routing:

- Every wheel, pinch, background-pan, and card-drag sample writes top-level `WorkspaceCanvasView` state.
- Each write re-creates the render snapshot, dictionaries, sorted card arrays, edge-index inputs, viewport query results, and screen-space edge segments.
- `CanvasEdgeViewportIndexCache` usually reuses its index during pan and zoom, but callers still rebuild and compare all node and edge signatures. A cache hit also emits synchronous maintenance-log work.
- Wheel input additionally repeats hit testing and replaces a debounce task for every event.
- SwiftData saves already occur at gesture end or after the wheel gesture settles, so persistence is not the per-frame cause.

This explains why a small canvas can still lag: the fixed work is repeated at input-event frequency even when the world data has not changed.

## Selected Approach

Use a display-synchronised interaction pipeline with a stable world layer and a small active interaction overlay.

### 1. Display-synchronised input coordinator

Add a main-actor reference helper that is not observable SwiftUI render state. It stores only the newest pending camera and card-drag samples and releases them on the next native display callback.

- Multiple input events inside one display interval collapse into one visual update.
- The coordinator follows the display refresh cadence; it does not impose a lower animation frame-rate cap.
- Gesture end synchronously flushes the final pending sample before persistence, so the last position cannot be dropped.
- Cancellation or view disappearance clears the callback and uses the existing safe persistence/cleanup paths.

Wheel scroll sequences cache their text-control pass-through decision for the sequence, accumulate the latest anchor and delta, and keep the save-debounce task inside the non-observable helper rather than `@State`.

### 2. Stable world snapshot and prepared geometry

Cache model-derived Canvas data separately from live interaction transforms:

- Node/resource/snippet/edge membership, card ordering, lookup dictionaries, edge-index records, and stable edge geometry are rebuilt only when their structural or geometry revision changes.
- Pan and zoom do not invalidate that cache.
- Cache diagnostics remain available, but ordinary reuse does not synchronously format and emit an info log on every frame. Create, invalidation, and cleanup events remain logged.
- A cache revision change is fail-closed: rebuild the complete derived state rather than reuse uncertain data.

### 3. Camera fast path

The committed world layer is rendered once inside a generous overscan guard band. Live pan and zoom apply one combined translation/scale transform to that layer.

- Cards, link strokes, arrowheads, and the running glow timeline move together through a visual transform.
- The layer rebases only when the transform leaves its guard band, the underlying model changes, or the gesture settles.
- Rebase uses the same anchor-preserving viewport math as the current implementation, avoiding zoom jumps.
- The grid may update independently because it is cheap and must remain visually anchored.

### 4. Card-drag fast path

During card drag, stable peer cards and passive links stay in the world layer. A lightweight interaction overlay contains only:

- the dragged card or selected card group;
- moved frame bend points;
- selected links and links incident to the moving nodes;
- active resize or edge-control affordances.

Only the overlay consumes live drag samples. At gesture end, the exact final delta is committed once, the world cache invalidates once, and the overlay disappears. Existing visibility and force-retention policies remain the authority for which active links must stay visible.

## Visual Quality Contract

The optimisation must not obtain speed by changing the approved presentation:

- Keep link glow and dash animation active during pan and zoom when current policy allows it.
- Keep rich card details on sparse canvases during zoom and normal spatial movement.
- Keep shadows, selection styling, arrowheads, control points, and anchor-preserving zoom.
- Do not introduce a blanket lower frame-rate, raster downsampling, blur, or animation disable.
- Existing adaptive degradation for genuinely dense or reduced-motion cases remains unchanged.

## Data Flow

1. AppKit or SwiftUI receives a wheel, pinch, pan, or card-drag sample.
2. The coordinator replaces the pending sample for that interaction.
3. The next display callback publishes one visual transform or overlay update.
4. Stable world data remains cached unless a revision or guard-band boundary requires a rebase.
5. Gesture end flushes the last sample, commits the exact viewport or model delta, saves once, and rebuilds the stable cache once.

## Failure Handling

- Non-finite zoom, viewport, or drag values continue through the existing validation policies and are ignored safely.
- A failed save follows the existing rollback/status path; the performance layer adds no retry loop or hidden persistence.
- Display-callback teardown is idempotent and must not retain the view or controller.
- Cache uncertainty always causes a rebuild, never stale content reuse.

## Testing Strategy

Use deterministic counters and manual display ticks rather than fragile wall-clock thresholds.

1. A coalescer test submits many wheel, pan, pinch, and drag samples before one tick and observes exactly one latest-value update.
2. A final-flush test proves gesture end applies the last sample even without another display tick.
3. A cache test proves camera-only changes reuse the stable snapshot/index inputs, while membership, ordering, endpoint, or geometry changes rebuild once.
4. A drag-overlay test proves peer cards remain stable and only dragged nodes plus required incident/selected links enter the active set.
5. Existing tests must continue proving that pan/zoom keeps glow animation and sparse rich-card details.
6. Focused Debug/Release tests, the complete Debug/Release suite, and a Release build must pass.
7. A manual smoke pass will cover trackpad pinch, wheel zoom, canvas pan, single-card drag, multi-card drag, and frame drag on a small Canvas.

## Alternatives Rejected

- Replacing the renderer with a custom Metal/Canvas engine offers a higher ceiling but is too disruptive for this targeted fix.
- Hiding card details or lowering link-animation frame rate is faster to implement but directly conflicts with the requested quality boundary.

## Scope

This work changes only Canvas interaction scheduling, derived render caching, world/overlay composition, focused performance policies, tests, and user-facing performance notes if needed. It does not add product features, change Canvas data formats, alter identity rules, or touch ResearchVault.
