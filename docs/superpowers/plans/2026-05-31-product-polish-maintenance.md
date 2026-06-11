# MindDesk Product Polish Maintenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or inline TDD execution task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve existing MindDesk product logic, interaction defaults, performance guardrails, and release readiness for the next small version.

**Architecture:** Keep risky UI behavior behind small core policies that can be unit tested. Apply UI changes locally in existing SwiftUI views, following current file boundaries and avoiding broad refactors.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, SwiftPM macOS app packaging scripts.

---

### Task 1: Core Policy Tests

**Files:**
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] Add failing tests for task-panel defaults, scroll-wheel pass-through, edge-handle drag start, node state reconciliation, finite card sizes, manifest cross-workspace resource validation, and recent workspace ordering.
- [ ] Run targeted `swift test --scratch-path /tmp/minddesk-red-tests` and confirm the new expectations fail before production edits.

### Task 2: Core Policy Implementation

**Files:**
- Modify: `Sources/MindDeskCore/AppPreferences.swift`
- Modify: `Sources/MindDeskCore/CanvasPerformancePolicies.swift`
- Modify: `Sources/MindDeskCore/WorkbenchOrdering.swift`
- Modify: `Sources/MindDeskCore/ExportManifest.swift`

- [ ] Implement the minimal policy changes required by Task 1.
- [ ] Re-run targeted tests and keep existing tests passing.

### Task 3: SwiftUI Integration

**Files:**
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Views/AppSettingsView.swift`
- Modify: `Sources/MindDesk/Views/WorkspaceTodoBoardView.swift`
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`

- [ ] Wire core policies into Home, Workspace, Canvas Add menu, scroll-wheel monitor, edge handles, selection reconciliation, and task panel initialization.
- [ ] Keep changes scoped to existing controls and state.

### Task 4: Documentation And Release Metadata

**Files:**
- Modify: `VERSION`
- Modify: `README.md`
- Modify: `docs/feature-checklist.md`
- Create: `docs/releases/v2.2.0.md`

- [ ] Update version references and release notes.
- [ ] Include an audit log: issues found, fixes made, and validation results.

### Task 5: Verification And Release Prep

- [ ] Run Swift tests, debug build, release build, script syntax checks, metadata checks, app bundle launch verification, local packaging where possible, and Git whitespace checks.
- [ ] Use subagent review loops before final commit.
- [ ] Push branch and create/update GitHub release artifacts if credentials and repository state allow.
