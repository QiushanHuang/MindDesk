# Review Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the concrete findings from the 40-pass review, add regression coverage where the codebase can support it, rebuild locally, and publish the change set.

**Architecture:** Keep fixes narrow and aligned with the existing SwiftPM app. Core data validation and layout behavior stay in `MindDeskCore`; app-only workflow fixes stay in SwiftUI/service files; shell/release hardening stays in `script/` and CI config.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, zsh/bash release scripts, GitHub Actions.

---

### Task 1: Core Regression Coverage

**Files:**
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
- Modify: `Sources/MindDeskCore/CanvasLayoutEngine.swift`
- Modify: `Sources/MindDeskCore/ExportManifest.swift`

- [ ] Add failing tests for finite coordinate alignment.
- [ ] Add failing tests for cyclic canvas frame parents.
- [ ] Add failing tests for invalid node/object type combinations.
- [ ] Implement the smallest core changes that make those tests pass.
- [ ] Run `swift test --filter CoreBehaviorTests`.

### Task 2: App Data And Workflow Fixes

**Files:**
- Modify: `Package.swift`
- Add: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `Sources/MindDesk/Models/WorkbenchModels.swift`
- Modify: `Sources/MindDesk/Views/ResourceSnippetViews.swift`

- [ ] Add an app test target that imports the executable module.
- [ ] Add tests proving resource and snippet tags preserve comma-containing values.
- [ ] Change tag persistence to JSON arrays with legacy comma-string fallback.
- [ ] Add a test proving the resource rename sheet save path preserves a cleared custom name.
- [ ] Remove the list-view override that rewrites `customName` to `title`.
- [ ] Run `swift test --filter MindDeskTests`.

### Task 3: UI And Canvas Usability Fixes

**Files:**
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Views/AppSettingsView.swift`
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDesk/App/MindDeskApp.swift`

- [ ] Add visible empty states for pinned resources.
- [ ] Add menu commands for New Workspace, Quick Open, Import, and Export where the current architecture can route them safely.
- [ ] Respect locked canvas nodes for destructive and direct-manipulation operations.
- [ ] Improve accessibility labels for custom icon/symbol surfaces touched in this change.
- [ ] Keep Settings scrollable/resizable instead of a fixed clipped panel.

### Task 4: Build, Release, And CI Hardening

**Files:**
- Modify: `script/build_and_run.sh`
- Modify: `script/package_release.sh`
- Modify: `.github/workflows/release.yml`
- Modify: `.github/workflows/ci.yml`

- [ ] Re-sign the staged app bundle in `build_and_run.sh`.
- [ ] Make `--verify` run bundle signature verification, not only process detection.
- [ ] Make release staging retry-friendly and clean disposable staging by default.
- [ ] Quote GitHub Actions keychain handling safely.
- [ ] Add a lightweight CI smoke check for script syntax and app bundle verification.

### Task 5: Changelog And Publication

**Files:**
- Modify: `docs/releases/v2.2.0.md`
- Modify: `docs/feature-checklist.md`

- [ ] Add a changelog entry describing the hardening work.
- [ ] Update checklist items covered by this pass.
- [ ] Run full local verification: `swift test`, `./script/build_and_run.sh --verify`, and targeted release script checks.
- [ ] Commit the intended files.
- [ ] Push the branch to GitHub and open a draft PR when the GitHub tooling is authenticated.
