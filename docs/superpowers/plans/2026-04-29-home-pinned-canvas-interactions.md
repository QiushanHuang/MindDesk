# Home Pinned Canvas Interactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix Home, Pinned, and Canvas interaction regressions so resource actions are consistent, resource previews are useful, canvas links work, frames are usable, and directional edge animation communicates workflow direction.

**Architecture:** Keep Finder/resource behavior centralized through small core helpers and view-level action closures. Add focused SwiftUI subviews for Home resource cards and resource preview/detail pages. Rework canvas gestures so selection/link actions do not compete with double-click and drag gestures.

**Tech Stack:** SwiftPM macOS app, SwiftUI, AppKit Finder services, Quick Look, SwiftData, XCTest.

---

### Task 1: Core Interaction Rules

**Files:**
- Modify: `Sources/MindDeskCore/WorkbenchOrdering.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] Add tests for folder preview ordering and directional edge animation eligibility.

Run:

```bash
swift test --filter CoreBehaviorTests
```

Expected red first if helpers are missing, then green after adding helpers.

- [ ] Add helpers:
  - `FolderPreviewItemRecord`
  - `FolderPreviewOrdering.ordered(_:)`
  - `CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme:animationsEnabled:reduceMotion:edgeCount:)`

### Task 2: Home And Pinned Resource Actions

**Files:**
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Views/ResourceSnippetViews.swift`
- Modify: `Sources/MindDesk/Services/SystemServices.swift`

- [ ] Add `ResourceActionSet` closures in `ContentView` for open/reveal/copy/inspect/rename/pin/remove.
- [ ] Replace Home pinned resource `DashboardCard` with `HomeResourceCard`.
- [ ] Add sidebar resource row double-click Finder routing and copy-path context action.
- [ ] Make Pinned Folders and Pinned Files section labels directly select `.pinnedFolders` / `.pinnedFiles`.

Verification:

```bash
swift build
```

Expected: build succeeds.

### Task 3: Resource Preview Detail Page

**Files:**
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Views/ResourceSnippetViews.swift`
- Modify: `Sources/MindDesk/Services/SystemServices.swift`

- [ ] Replace `.resource(id)` one-row table with `ResourcePreviewView`.
- [ ] Folder preview reads first-level contents only, sorted by folder-first then localized name.
- [ ] File preview uses Quick Look when possible and falls back to metadata/actions.
- [ ] Folder/file preview rows support double-click Finder routing and copy path.

Verification:

```bash
swift build
```

Expected: build succeeds.

### Task 4: Canvas Connection, Frame, Selection, And Edge Flow

**Files:**
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDeskCore/WorkbenchOrdering.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] Fix selection to update immediately on pointer down/tap without waiting for double-click recognition.
- [ ] Keep double-click open behavior without clearing connection state.
- [ ] Prevent card button taps from being canceled by card-level tap handling.
- [ ] Move frames above the background and below normal cards while keeping them hit-testable.
- [ ] Replace card glow with edge-level moving blue highlight from source to target.
- [ ] Keep unconnected cards visually neutral.

Verification:

```bash
swift test
swift build
./script/build_and_run.sh --verify
```

Expected: tests pass, build succeeds, app process launches.

### Task 5: Final Review And Commit

**Files:**
- Review changed files from Tasks 1-4.

- [ ] Run:

```bash
git diff --check -- Desktop/Qiushan_Studio/6_Personal/MindDesk
swift test
swift build
./script/build_and_run.sh --verify
```

- [ ] Commit only the task files and this plan.

Expected: clean diff check, tests pass, build succeeds, app launches.
