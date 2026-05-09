# Global Library And Canvas Frames Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement explicit Global Library resources, pinned shortcuts, directed canvas links, fixed cards, note cards, organization frames, drag-to-import, and frame drag propagation.

**Architecture:** Keep the existing SwiftData models for migration safety and add defaulted fields. Put deterministic resource/canvas rules in `MindDeskCore` so behavior is testable without SwiftUI. Update SwiftUI views to call those rules and keep drag state transient until persistence is needed.

**Tech Stack:** SwiftPM macOS app, SwiftUI, SwiftData, AppKit Finder services, `UniformTypeIdentifiers`, XCTest.

---

### Task 1: Core Behavior Tests And Helpers

**Files:**
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
- Modify: `Sources/MindDeskCore/WorkbenchOrdering.swift`

- [ ] Add failing tests for resource library filtering, display naming, directional edge duplicates, group frame child detection, and frame drag propagation.
- [ ] Run `swift test --filter CoreBehaviorTests` and verify the new tests fail because helper types do not exist yet.
- [ ] Add helper structs/functions:
  - `ResourceLibraryRecord`
  - `ResourceLibraryFiltering`
  - `CanvasEdgeIdentity`
  - `CanvasFrameGeometry`
- [ ] Re-run `swift test --filter CoreBehaviorTests` and verify the tests pass.

### Task 2: Migration-Safe Model And Manifest Fields

**Files:**
- Modify: `Sources/MindDesk/Models/WorkbenchModels.swift`
- Modify: `Sources/MindDeskCore/ExportManifest.swift`
- Modify: `Sources/MindDesk/Services/SystemServices.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] Extend `ResourcePinModel` with `isPinned`, `originalName`, `customName`, and `searchText`, all with defaults.
- [ ] Extend `CanvasModel`, `CanvasNodeModel`, and `CanvasEdgeModel` with defaulted animation, frame, and arrow fields.
- [ ] Add `groupFrame` to `CanvasNodeKind`.
- [ ] Extend export/import records with default decoding for new fields.
- [ ] Run manifest tests and full core tests.

### Task 3: Resource Import And Library UI

**Files:**
- Modify: `Sources/MindDesk/Services/SystemServices.swift`
- Modify: `Sources/MindDesk/Views/ResourceSnippetViews.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`

- [ ] Add a resource import service that deduplicates by resolved path and accepts an explicit `pinImported` flag.
- [ ] Update Global Library to show separate Folders and Files source sections.
- [ ] Update Pinned Folders and Pinned Files to filter `isPinned == true`.
- [ ] Add row double-click open, pin/unpin, remove metadata, inspect, rename, copy path, reveal, alias, and reauthorize actions.
- [ ] Add file/folder drag-drop import to Global Library and Pinned sections.

### Task 4: Canvas Directed Links, Notes, Frames, And Drops

**Files:**
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`

- [ ] Render note and group frame nodes in the canvas instead of filtering notes out.
- [ ] Add buttons for Note and Frame creation.
- [ ] Draw directed arrow links and allow A -> B and B -> A as distinct edges.
- [ ] Add Blue, Minimal, and Off glow theme controls.
- [ ] Render frame nodes behind cards and allow frames to connect to normal cards or other frames.
- [ ] Implement drag propagation: at drag start, capture normal child nodes fully inside the frame; during drag, move the frame and child cards visually; on drag end, persist all moved node positions once.
- [ ] Add canvas drag-drop import that creates or reuses a resource source and creates a resource card at the drop location.

### Task 5: Verification And Subagent Review

**Files:**
- Review all changed source and test files.

- [ ] Run `swift test`.
- [ ] Run `swift build`.
- [ ] Run `./script/build_and_run.sh --verify` if the local script is still compatible.
- [ ] Dispatch at least two reviewer subagents: one for requirement coverage, one for SwiftUI/SwiftData performance risk.
- [ ] Fix any blocking findings.
