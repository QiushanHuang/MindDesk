# MindDesk S0 Capability Lockdown and Scope Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILLS: use `superpowers:test-driven-development` for every behavior change, `superpowers:subagent-driven-development` for execution, `superpowers:requesting-code-review` after each task, and `superpowers:verification-before-completion` before every completion claim. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Approved for execution after four-seat implementation-plan review.

**Goal:** Deliver the S0 vertical slice for the private Canvas-first route: permanently close and physically remove Canvas Review runtime, preserve only bounded historical wire compatibility, resolve a workspace's Primary Canvas without guessing, bind all Canvas work to a window-local focus identity, and prevent stale provisioning or node-open work from committing.

**Architecture:** Keep one permanently closed Review lock in `MindDeskCore`; route JSON imports through a 64 MiB guard and bounded classifier; delete Agent/Codex/Proposal runtime and SwiftTerm; retain historical Review values only as stored Codable wire data; add a pure exact-cardinality resolver; make one `@StateObject` controller the sole per-window identity, cancellation, resolution-slot, and request authority; provision a missing Canvas through an isolated SwiftData context; finish with a closed source/sink/symbol verifier wired to every release artifact.

**Tech stack:** Swift 6, SwiftUI, SwiftData, Combine, XCTest, SwiftPM, Bash, GitHub Actions, macOS release tooling.

**Source of truth:**

- `docs/superpowers/specs/2026-07-29-private-canvas-first-canonical-v3-design.md`
- `docs/superpowers/specs/2026-07-29-s0-capability-lockdown-scope-identity-design.md`
- `docs/superpowers/plans/2026-07-29-s0-test-migration-map.md` (the reviewed, count-bearing migration appendix)

The approved S0 specification wins if this plan is ambiguous. Do not expand S0 into WCF data projection, Canvas Review v1b, schema migration, duplicate repair, S2 navigation, or ResearchVault work.

---

## Execution Protocol

For every numbered implementation task after Task 0:

1. Add the intended migration-ledger rows before changing tests.
2. Add one smallest focused test and run it to observe the intended RED reason.
3. Make the smallest production change that can satisfy that test.
4. Run the focused test in Debug and Release.
5. Repeat RED/GREEN for the remaining assertions; do not batch a whole gate's tests before production work.
6. Update the ledger with complete final test names and configuration availability.
7. Compile Debug and Release before moving to the next task.
8. Run `git diff --check` and request both specification-compliance and code-quality review.
9. Commit only that task's coherent slice. Never use `git reset --hard` to recover.

Before Task 0, this approved plan and its migration-map companion must be committed in a clean worktree. Every task stages only the exact paths in its file table; do not use broad `git add Sources`, `git add Tests`, `git add docs`, or `git add -A`. For deletions, use `git add -u --` with the exact deleted paths.

For a brand-new Swift API, use a two-stage RED so failure evidence stays meaningful:

1. Add the smallest contract test and record the expected compile RED (`cannot find ... in scope`).
2. Add only the public/internal type and method signatures with inert behavior so the target compiles.
3. Rerun and record an XCTest assertion RED against that inert behavior.
4. Implement the minimum real behavior and rerun GREEN.

An unresolved identifier may be the explicitly recorded contract RED, but it never substitutes for the subsequent assertion RED. Existing behavior starts with characterization GREEN and adds RED only for a missing or incorrect contract.

SwiftPM compiles the entire target even with `--filter`; a focused filter is not permission to leave unrelated compile failures.

Use fresh scratch directories for evidence. Fixed readable `/tmp/minddesk-s0-*` paths below are notation only: the executing agent always runs each gate through a task-local, self-contained wrapper that binds fresh `mktemp -d` equivalents and never allocates or reuses the literal path. Every manual temporary-directory sequence is one fail-fast shell invocation: initialize path variables, install a fixed-prefix/non-symlink cleanup trap before the first allocation, treat dangling symlinks as failure, emit required evidence before explicit cleanup, and clear the trap only after cleanup succeeds. Test-owned temporary fixtures register equivalent `defer` cleanup before their first write.

Common gate commands:

```bash
swift test --scratch-path /tmp/minddesk-s0-gN-debug --filter TestClassName
swift test -c release --scratch-path /tmp/minddesk-s0-gN-release --filter TestClassName
swift build --scratch-path /tmp/minddesk-s0-gN-build-debug
swift build -c release --scratch-path /tmp/minddesk-s0-gN-build-release
git diff --check
```

No implementation task may write to or inspect ResearchVault.

---

## Planned File Topology

Create Core production files:

- `Sources/MindDeskCore/CanvasReviewCapabilityLock.swift`
- `Sources/MindDeskCore/CanvasEdgeAnimationInteractionPolicy.swift`
- `Sources/MindDeskCore/LegacyReviewWireTypes.swift`
- `Sources/MindDeskCore/WorkspacePrimaryCanvasResolver.swift`

Create app production files:

- `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`
- `Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift`
- `Sources/MindDesk/Models/WorkspacePrimaryCanvasPresentation.swift`
- `Sources/MindDesk/Models/WorkspaceCanvasNodeOpenRequest.swift`
- `Sources/MindDesk/Models/WorkspaceCanvasNodeLookup.swift`

Create focused test files:

- `Tests/MindDeskCoreTests/CanvasReviewCapabilityLockTests.swift`
- `Tests/MindDeskCoreTests/MindDeskJSONDocumentClassifierTests.swift`
- `Tests/MindDeskCoreTests/LegacyReviewWireCompatibilityTests.swift`
- `Tests/MindDeskCoreTests/WorkspacePrimaryCanvasResolverTests.swift`
- `Tests/MindDeskTests/LegacyReviewImportRejectionTests.swift`
- `Tests/MindDeskTests/S0SurfaceAbsenceTests.swift`
- `Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift`
- `Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift`
- `Tests/MindDeskTests/WorkspaceCanvasNodeOpenRequestTests.swift`

Create fixture/evidence/release files:

- `Tests/MindDeskCoreTests/Fixtures/legacy-interchange-v1.json`
- `Tests/MindDeskCoreTests/Fixtures/legacy-proposal-envelope-v1.json`
- `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`
- `script/s0_private_canvas_policy.sh`
- `script/verify_s0_private_canvas.sh`
- `script/test_verify_s0_private_canvas.sh`

The resolution coordinator and node-request files extend `WorkspaceWindowScopeController`; they must not introduce a second `ObservableObject` or another scope authority.

---

### Task 0: Gate 0 — Fresh Debug/Release Baseline and Migration Ledger

**Files:**

- Create: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: Verify the worktree before implementation**

Run:

```bash
git status --short
git branch --show-current
git rev-parse --show-toplevel
```

Expected: branch `codex/private-canvas-first-s0`, root is this isolated worktree, and no unexplained changes exist.

- [ ] **Step 2: Run a fresh Debug baseline**

```bash
set -euo pipefail
S0_G0_DEBUG=
s0_cleanup_g0_debug() {
  path="$S0_G0_DEBUG"
  [ -z "$path" ] && return 0
  case "$path" in
    /tmp/minddesk-s0-g0-debug.??????) ;;
    *) return 1 ;;
  esac
  if [ -e "$path" ] || [ -L "$path" ]; then
    [ -d "$path" ] && [ ! -L "$path" ] || return 1
    rm -rf -- "$path"
  fi
}
trap s0_cleanup_g0_debug EXIT
S0_G0_DEBUG="$(mktemp -d /tmp/minddesk-s0-g0-debug.XXXXXX)"
swift test --scratch-path "$S0_G0_DEBUG"
s0_cleanup_g0_debug
trap - EXIT
```

Expected: exactly `776 tests / 0 failures`, with no skip among required tests.

- [ ] **Step 3: Run a separately built fresh Release baseline**

```bash
set -euo pipefail
S0_G0_RELEASE=
s0_cleanup_g0_release() {
  path="$S0_G0_RELEASE"
  [ -z "$path" ] && return 0
  case "$path" in
    /tmp/minddesk-s0-g0-release.??????) ;;
    *) return 1 ;;
  esac
  if [ -e "$path" ] || [ -L "$path" ]; then
    [ -d "$path" ] && [ ! -L "$path" ] || return 1
    rm -rf -- "$path"
  fi
}
trap s0_cleanup_g0_release EXIT
S0_G0_RELEASE="$(mktemp -d /tmp/minddesk-s0-g0-release.XXXXXX)"
swift test -c release --scratch-path "$S0_G0_RELEASE"
s0_cleanup_g0_release
trap - EXIT
```

Expected: exactly `776 tests / 0 failures`, with no skip among required tests. Do not reuse the Debug scratch directory or a cached test binary.

- [ ] **Step 4: Create the checked-in ledger**

Seed the ledger from `docs/superpowers/plans/2026-07-29-s0-test-migration-map.md`; do not reinterpret a reviewed `retired`, `migrated`, or `retained-with-body-edit` row during implementation. The ledger must record:

- Baseline command, UTC/local timestamp, Swift version, commit SHA, configuration, observed count, failures, and skips.
- One row per later `retired`, `migrated`, or `added` test: file, complete test name, Debug/Release availability, classification, evidence-based reason, and complete origin/replacement name.
- Separate final equations:

```text
final_debug = 776 - retired_debug + added_debug
final_release = 776 - retired_release + added_release
```

`migrated` is count-neutral and does not appear in `added`. A split or merge is represented by real retired and added names.

- [ ] **Step 5: Commit Gate 0 evidence**

```bash
git add -- docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "test: record s0 debug and release baselines"
```

If either baseline is not exactly 776/0, do not create RED tests or change production code. Diagnose the repository difference and return it to a fresh four-seat judgment before amending the approved baseline.

---

### Task 1: Gate 1A — Permanent Capability Lock and Closed Classifier

**Files:**

- Create: `Sources/MindDeskCore/CanvasReviewCapabilityLock.swift`
- Create: `Tests/MindDeskCoreTests/CanvasReviewCapabilityLockTests.swift`
- Create: `Tests/MindDeskCoreTests/MindDeskJSONDocumentClassifierTests.swift`
- Modify: `Sources/MindDeskCore/MindDeskJSONDocumentKind.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED the permanent lock**

Add tests proving every call throws exactly `.unavailable`, the fixed error copy is generic, and a scoped source canary finds no protocol, enabled state, injected closure, counter, defaults/environment/build override, or test permit.

Run and observe failure because the lock does not exist:

```bash
swift test --filter CanvasReviewCapabilityLockTests
```

- [ ] **Step 2: Observe the lock assertion RED, then GREEN it exactly**

First add only the complete `CanvasReviewCapabilityError` and `CanvasReviewCapabilityLock.requireEnabled() throws -> Never` signatures, with `requireEnabled()` throwing a private temporary placeholder error. Compile the full target, rerun the focused test, and record the assertion RED because the error is not `.unavailable`. Then remove the placeholder and implement only `.unavailable`. Do not add a gateway abstraction or future-live branch.

- [ ] **Step 3: Migrate existing classifier characterization before adding missing RED cases**

Move these two existing classifier cases as count-neutral migrations and run them GREEN first:

- `CoreBehaviorTests.testMindDeskJSONDocumentKindClassifiesManifestMIPProposalAndValidationReportWithoutFullDecode` → `MindDeskJSONDocumentClassifierTests.testClassifiesManifestAndRecognizedLegacyReviewFormatsWithoutFullDecode`
- `CoreBehaviorTests.testMindDeskJSONDocumentKindRejectsNestedAndConflictingMarkers` → `MindDeskJSONDocumentClassifierTests.testRejectsNestedAndConflictingTopLevelMarkers`

They already characterize basic Manifest/Review/unknown/nested/conflicting behavior. Then add one test at a time for behavior not yet covered:

- typed Manifest and three recognized legacy Review literals without DTO-factory references;
- one unknown string format;
- duplicate same-value format, duplicate different-value format, non-string format, and conflicting markers;
- schema-only integer Manifest and missing/non-integer/duplicate schema cases;
- nested pseudo-markers;
- invalid JSON, trailing data, depth limit, and token limit.

Some characterization additions may already pass. The required behavioral RED is the scoped source-contract assertion that the classifier still references historical DTO `.currentFormat`; make that assertion fail before replacing the dependency with file-private literals.

- [ ] **Step 4: GREEN the bounded classifier**

Make the three historical Review format strings file-private constants in `MindDeskJSONDocumentKind.swift`; stop referencing DTO `.currentFormat` factories. Preserve the 64-level depth and 256-character marker-token caps. Duplicate top-level format is ambiguous even when values are equal.

- [ ] **Step 5: Verify Gate 1A**

```bash
swift test --filter CanvasReviewCapabilityLockTests
swift test -c release --filter CanvasReviewCapabilityLockTests
swift test --filter MindDeskJSONDocumentClassifierTests
swift test -c release --filter MindDeskJSONDocumentClassifierTests
swift build
swift build -c release
git diff --check
```

- [ ] **Step 6: Update the ledger and commit**

```bash
git add -- Sources/MindDeskCore/CanvasReviewCapabilityLock.swift Sources/MindDeskCore/MindDeskJSONDocumentKind.swift Tests/MindDeskCoreTests/CanvasReviewCapabilityLockTests.swift Tests/MindDeskCoreTests/MindDeskJSONDocumentClassifierTests.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: permanently close canvas review capability"
```

---

### Task 2: Gate 1B — URL/Data Import Limits and Neutral Legacy Rejection

**Files:**

- Modify: `Sources/MindDesk/Services/SystemServices.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Tests/MindDeskTests/ManifestImportServiceTests.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Create: `Tests/MindDeskTests/LegacyReviewImportRejectionTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED the independent 64 MiB boundaries**

First add a contract test for the internal manifest-specific API `ImportExportService.decodeManifest(from url: URL) throws -> ExportManifest` and observe the missing-member compile RED. Add only the overload signature with a fixed private placeholder failure, compile the full target, and observe the size/order assertion RED before implementing its behavior. `ContentView` must delegate its URL load to that overload; tests must never reconstruct the URL→Data→decode chain themselves.

Give each `ImportExportService` instance an internal URL-read dependency containing metadata-size and capped-read closures, with a default live implementation and no global mutable override. `ManifestImportServiceTests.testDecodeManifestFromURLRejectsMetadataAndCappedReadOverflowBeforeClassification` covers both URL branches: a real/generated metadata size over the cap, and a deterministic seam that reports metadata within the cap but yields cap+1 bytes from the capped read. `ManifestImportServiceTests.testDecodeManifestFromDataRejectsOversizeLegacyTrapBeforeClassification` independently covers direct `Data`. In every case the first in-limit bytes contain a recognized legacy marker, so reaching classification would take the lock route. Prove inputs larger than `64 * 1024 * 1024` return exactly:

```text
This JSON file is larger than the 64 MiB import limit.
```

All cases must instead return the size error, proving the cap wins. Generate the payload at test time; do not check in a giant fixture. Migrate `AppBehaviorTests.testImportExportServiceRejectsProposalEnvelopeAndValidationReportAsManifestImport` to `LegacyReviewImportRejectionTests.testInLimitProposalEnvelopeAndValidationReportUsePermanentLockAndNeutralManifestError`; the old Proposal source-package URL-cap test retires with its deleted runtime.

- [ ] **Step 2: GREEN the fixed processing order**

Implement the URL overload with metadata validation and a capped read, then call the Data overload. The Data overload repeats its own `Data.count` check as its first decision. `ContentView.loadManifest(from:)` may run this synchronous service call from its existing background task, but it cannot call the generic reader and Data decoder separately. The fixed service order is:

```text
URL metadata/capped read
→ direct Data.count cap
→ bounded classifier
→ recognized legacy kind calls private closed lock
→ Manifest layer maps unavailable to neutral copy
→ ordinary Manifest decode/validation
```

The private `rejectLegacyReviewDocument() throws -> Never` must have the lock call as its first and only expression. Neutral copy:

```text
This JSON document is not supported by this version of MindDesk and cannot be imported as a manifest.
```

- [ ] **Step 3: RED/GREEN every non-lock classifier route and ordinary Manifest regression**

Unknown formatted, duplicate/conflicting/non-string, nested, schema-only legacy Manifest, invalid/trailing JSON, typed Manifest, and unsupported Manifest versions must preserve their specified behavior without historical DTO decode.

- [ ] **Step 4: Prove zero side effects**

Use an isolated `mktemp -d` snapshot plus in-memory SwiftData/spies, registering `defer` cleanup before the first fixture write. In-limit legacy rejection must create no record, file, second panel, helper, process, terminal input, clipboard write, pending state, or sheet.

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter LegacyReviewImportRejectionTests
swift test -c release --filter LegacyReviewImportRejectionTests
swift test --filter ManifestImportServiceTests
swift test -c release --filter ManifestImportServiceTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Services/SystemServices.swift Sources/MindDesk/Views/ContentView.swift Tests/MindDeskTests/ManifestImportServiceTests.swift Tests/MindDeskTests/LegacyReviewImportRejectionTests.swift Tests/MindDeskTests/AppBehaviorTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: reject legacy review documents without side effects"
```

---

### Task 3: Gate 2A — Decouple Ordinary Product Behavior from Review Runtime

**Files:**

- Create: `Sources/MindDeskCore/CanvasEdgeAnimationInteractionPolicy.swift`
- Modify: `Sources/MindDeskCore/CanvasCodexPrompt.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Views/ResourceSnippetViews.swift`
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDesk/Services/SystemServices.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: Preserve the ordinary edge-animation policy**

Run the existing edge-animation behavior tests GREEN as characterization. Add a scoped source-location canary that fails while `CanvasEdgeAnimationInteractionPolicy` remains in `CanvasCodexPrompt.swift`, then move the policy unchanged and rerun both the canary and behavior tests GREEN. A same-module file move is not expected to create an import failure.

- [ ] **Step 2: RED the ordinary direct-user sink routes**

First add the contract tests and observe the missing-initializer compile RED. Add only an internal initializer accepting a `@MainActor (String) -> Void` writer plus a default live-writer initializer. In the temporary inert scaffold, `copy(_:)` calls an instance writer, the default initializer installs the real pasteboard writer, and the injected initializer deliberately installs a no-op instead of its supplied spy; the spy therefore observes zero and no test mutates the global pasteboard. Compile and record that assertion RED. Then make the injected initializer retain its supplied writer. `copy(_:)` remains the one service declaration; no test flag or global mutable hook is allowed. Thread a defaulted `ClipboardService` value through `ContentView`, `ResourceListView`, `ResourcePreviewView`, `SnippetLibraryView`, and `WorkspaceCanvasView`, so tests can inject a per-instance spy without changing ordinary callers.

Add assertion REDs proving explicit resource-path, snippet-body, and folder-preview actions invoke the injected writer only after their user action. Extract the folder preview closure to the exact named method `ResourcePreviewView.copyFolderPreviewItemPath(_:)`. Do not inspect global pasteboard `changeCount`.

- [ ] **Step 3: Keep Review surface intact until the Gate 2B absence RED exists**

Do not remove Agent/Codex/Proposal menus, views, preferences, runtime, or tests in this task. Gate 2B must first observe all absence assertions RED against the intact surface, then remove it atomically. This task changes only the ordinary edge policy and testable direct-user clipboard seam.

- [ ] **Step 4: Verify ordinary behavior while runtime files still exist**

```bash
swift test --filter CanvasEdgeAnimation
swift test --filter AppBehaviorTests/testDirectUser
swift test --filter AppBehaviorTests/testFolderPreviewCopyUsesNamedDirectUserClipboardRoute
swift test --filter AppBehaviorTests/testTerminalPrefillAppleScriptTypesCommandWithoutRunningIt
swift test --filter AppBehaviorTests/testFinderRoutingRevealsFilesButOpensFolders
swift test -c release --filter CanvasEdgeAnimation
swift test -c release --filter AppBehaviorTests/testDirectUser
swift test -c release --filter AppBehaviorTests/testFolderPreviewCopyUsesNamedDirectUserClipboardRoute
swift test -c release --filter AppBehaviorTests/testTerminalPrefillAppleScriptTypesCommandWithoutRunningIt
swift test -c release --filter AppBehaviorTests/testFinderRoutingRevealsFilesButOpensFolders
swift build
swift build -c release
git diff --check
```

- [ ] **Step 5: Update the ledger and commit**

```bash
git add -- Sources/MindDeskCore/CanvasEdgeAnimationInteractionPolicy.swift Sources/MindDeskCore/CanvasCodexPrompt.swift Sources/MindDesk/Services/SystemServices.swift Sources/MindDesk/Views/ContentView.swift Sources/MindDesk/Views/ResourceSnippetViews.swift Sources/MindDesk/Canvas/WorkspaceCanvasView.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift Tests/MindDeskTests/AppBehaviorTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "refactor: detach ordinary behavior from review runtime"
```

---

### Task 4: Gate 2B — Physical Runtime and SwiftTerm Removal

**Files:**

- Create: `Tests/MindDeskTests/S0SurfaceAbsenceTests.swift`
- Create: `Tests/MindDeskCoreTests/LegacyReviewWireCompatibilityTests.swift`
- Modify: `Package.swift`
- Delete: `Package.resolved`
- Modify: `Sources/MindDeskCore/AppPreferences.swift`
- Modify: `Sources/MindDeskCore/MindDeskHelpCatalog.swift`
- Modify: `Sources/MindDeskCore/WorkbenchOrdering.swift`
- Modify: `Sources/MindDeskCore/WorkbenchReferences.swift`
- Modify: `Sources/MindDesk/App/MindDeskApp.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Views/AppSettingsView.swift`
- Modify: `Sources/MindDesk/Views/ResourceSnippetViews.swift`
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDesk/Services/SystemServices.swift`
- Modify: `Sources/MindDesk/Services/ValidationDisplayTextSanitizer.swift`
- Delete: `Sources/MindDesk/Canvas/CanvasCodexAgentSidebar.swift`
- Delete: `Sources/MindDesk/Canvas/CanvasCodexSessionController.swift`
- Delete: `Sources/MindDesk/Canvas/CanvasCodexTerminalView.swift`
- Delete: `Sources/MindDesk/Services/CodexTerminalService.swift`
- Delete: `Sources/MindDesk/Views/ProposalReviewSheet.swift`
- Delete: `Sources/MindDeskCore/CanvasCodexPrompt.swift`
- Delete: `Sources/MindDeskCore/MindDeskAgentHandoffPrompt.swift`
- Delete: `Sources/MindDeskCore/MindDeskAgentReviewCustomGuidancePresentation.swift`
- Delete: `Sources/MindDeskCore/MindDeskAgentReviewPackageReadiness.swift`
- Delete: `Sources/MindDeskCore/MindDeskAgentWorkflowSearch.swift`
- Delete: `Sources/MindDeskCore/MindDeskProposalCopyPathPlanner.swift`
- Delete: `Sources/MindDeskCore/MindDeskProposalEnvelopeExtractor.swift`
- Delete: `Sources/MindDeskCore/MindDeskProposalEnvelopeTemplate.swift`
- Delete: `Sources/MindDeskCore/MindDeskProposalReviewGate.swift`
- Delete: `Sources/MindDeskCore/MindDeskProposalSourcePackageRawValidation.swift`
- Delete: `Tests/MindDeskTests/ProposalReviewPresentationTests.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `Tests/MindDeskTests/ManifestImportServiceTests.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
- Modify: `Tests/MindDeskCoreTests/AgentIntegrationContractTests.swift`
- Modify: `Tests/MindDeskCoreTests/ProposalReviewTests.swift`
- Modify: `Tests/MindDeskCoreTests/ValidationReportTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED exact surface/dependency absence**

With the full old surface still present, add scoped source tests for every deleted path, menu/rail/settings/help/resource marker, active obsolete preference consumer, SwiftTerm import, `openpty(`, `.startProcess(`, and app reference to historical DTOs beyond classifier/lock types. Run the test and record assertion REDs for each rule. Assertions must be exact, not generic matches on words like “Agent” or “Review.”

- [ ] **Step 2: GREEN one compile-restoring runtime, dependency, and test-migration edit**

In one compile-restoring GREEN edit, remove Agent/Proposal commands, focused values, sheet/banner/confirmation state, handoff/copy-plan state, Canvas Codex rail/toolbar/session plumbing, Review deep links/restore consumers, active AppStorage consumers, settings rows, and default Help topics. Old preference literals remain only inside `obsoleteKeys` cleanup data.

Remove the 15 specified runtime files, all SwiftTerm package/product entries, and all remaining imports/call sites. Rewrite `ValidationDisplayTextSanitizer.swift` as a neutral ordinary Manifest-display sanitizer over plain strings; remove the `ProposalReviewSafeDisplayText` name and all Proposal/report-specific source-type signatures. In this same uncommitted edit, perform every Gate 2 test retirement/migration/body edit below before running any GREEN command.

Delete all 19 tests in `ProposalReviewPresentationTests.swift` and record each complete name as `retired`. In `AgentIntegrationContractTests.swift` and `ProposalReviewTests.swift`, retire only tests that reference the deleted handoff/search/readiness/template/gate/copy-planner/raw-source runtime. Keep stored-wire and pure Proposal decode/validation tests compiling for Gate 3. Migrate Agent-named Manifest rejection cases to neutral names where their obligation remains. The reviewed migration-map companion is authoritative for these rows.

In `CoreBehaviorTests.swift`, apply every Gate 2 row from the companion in the same compile-restoring edit: retire the 26 Canvas Codex/custom-guidance/Agent Help tests and body-edit the 11 ordinary preference/Help tests. Do not defer a test that still names a deleted production symbol.

Create `LegacyReviewWireCompatibilityTests.swift` now and complete the five App→pure-wire migrations whose old App Proposal-import APIs disappear in this gate. In `ValidationReportTests.swift`, complete `AgentIntegrationContractTests.testTypedExportManifestWireMetadataDoesNotChangeValidationReportSemantics` → `ValidationReportTests.testTypedExportManifestWireMetadataDoesNotChangeManifestValidationReportSemantics` before deleting the raw-source validator. These destinations use only still-retained pure DTO/validation behavior; Gate 3 later modifies the same file to use literal fixtures and the normalized stored-value boundary.

Run SwiftPM resolution after the dependency is gone, then delete the tracked `Package.resolved` rather than editing pins.

- [ ] **Step 3: Verify zero external dependencies and the full compile boundary**

```bash
swift package resolve
test ! -e Package.resolved
swift package show-dependencies --format json
swift test --filter S0SurfaceAbsenceTests
swift test -c release --filter S0SurfaceAbsenceTests
swift test
swift test -c release
swift build
swift build -c release
git diff --check
```

The dependency JSON must contain only the root package. Gate 2 does not yet freeze the final sink/codec inventory; Gate 8 does that after the production tree is final.

- [ ] **Step 4: Update the ledger and commit the deletion boundary**

```bash
git add -- Package.swift Tests/MindDeskTests/S0SurfaceAbsenceTests.swift Tests/MindDeskCoreTests/LegacyReviewWireCompatibilityTests.swift Sources/MindDeskCore/AppPreferences.swift Sources/MindDeskCore/MindDeskHelpCatalog.swift Sources/MindDeskCore/WorkbenchOrdering.swift Sources/MindDeskCore/WorkbenchReferences.swift Sources/MindDesk/App/MindDeskApp.swift Sources/MindDesk/Views/ContentView.swift Sources/MindDesk/Views/AppSettingsView.swift Sources/MindDesk/Views/ResourceSnippetViews.swift Sources/MindDesk/Canvas/WorkspaceCanvasView.swift Sources/MindDesk/Services/SystemServices.swift Sources/MindDesk/Services/ValidationDisplayTextSanitizer.swift Tests/MindDeskTests/AppBehaviorTests.swift Tests/MindDeskTests/ManifestImportServiceTests.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift Tests/MindDeskCoreTests/AgentIntegrationContractTests.swift Tests/MindDeskCoreTests/ProposalReviewTests.swift Tests/MindDeskCoreTests/ValidationReportTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git add -u -- Package.resolved Sources/MindDesk/Canvas/CanvasCodexAgentSidebar.swift Sources/MindDesk/Canvas/CanvasCodexSessionController.swift Sources/MindDesk/Canvas/CanvasCodexTerminalView.swift Sources/MindDesk/Services/CodexTerminalService.swift Sources/MindDesk/Views/ProposalReviewSheet.swift Sources/MindDeskCore/CanvasCodexPrompt.swift Sources/MindDeskCore/MindDeskAgentHandoffPrompt.swift Sources/MindDeskCore/MindDeskAgentReviewCustomGuidancePresentation.swift Sources/MindDeskCore/MindDeskAgentReviewPackageReadiness.swift Sources/MindDeskCore/MindDeskAgentWorkflowSearch.swift Sources/MindDeskCore/MindDeskProposalCopyPathPlanner.swift Sources/MindDeskCore/MindDeskProposalEnvelopeExtractor.swift Sources/MindDeskCore/MindDeskProposalEnvelopeTemplate.swift Sources/MindDeskCore/MindDeskProposalReviewGate.swift Sources/MindDeskCore/MindDeskProposalSourcePackageRawValidation.swift Tests/MindDeskTests/ProposalReviewPresentationTests.swift
git commit -m "refactor: remove canvas review runtime and SwiftTerm"
```

---

### Task 5: Gate 3 — Atomic Historical Wire Normalization

**Files:**

- Create: `Sources/MindDeskCore/LegacyReviewWireTypes.swift`
- Modify: `Tests/MindDeskCoreTests/LegacyReviewWireCompatibilityTests.swift`
- Create: `Tests/MindDeskCoreTests/Fixtures/legacy-interchange-v1.json`
- Create: `Tests/MindDeskCoreTests/Fixtures/legacy-proposal-envelope-v1.json`
- Modify: `Package.swift`
- Modify: `Sources/MindDeskCore/MindDeskInterchangePackage.swift`
- Modify: `Sources/MindDeskCore/MindDeskProposalEnvelope.swift`
- Create: `Sources/MindDeskCore/MindDeskProposalEnvelopeValidation.swift`
- Modify: `Sources/MindDeskCore/MindDeskValidationReport.swift`
- Modify: `Sources/MindDeskCore/MindDeskAgentIntegrationContract.swift`
- Modify: `Sources/MindDeskCore/MindDeskExtensionCapabilityCatalog.swift`
- Modify: `Sources/MindDeskCore/MindDeskHelpCatalog.swift`
- Modify: `Sources/MindDeskCore/WorkbenchReferences.swift`
- Modify: `Tests/MindDeskCoreTests/AgentIntegrationContractTests.swift`
- Modify: `Tests/MindDeskCoreTests/ProposalReviewTests.swift`
- Modify: `Tests/MindDeskCoreTests/ValidationReportTests.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: Add literal fixtures and resource declaration in one compile-safe slice**

Add `.process("Fixtures")` to `MindDeskCoreTests`. Fixtures are literal files with deliberately non-current contract, capabilities, report, and help values; they cannot call a builder. Load them through `Bundle.module`. The fixture directory, package resource declaration, and loader use land together so `Bundle.module` always compiles.

- [ ] **Step 2: Complete every Gate 3 test migration before deleting production APIs**

While every old production declaration still exists, apply all remaining Gate 3 retired, migrated, and retained-body rows from the migration map so no test target refers to a symbol that the next step removes. Extend the Gate 2-created `LegacyReviewWireCompatibilityTests.swift` with all Gate 3 destinations and the three added tests.

`LegacyReviewWireCompatibilityTests.testLegacyInterchangePackageRoundTripPreservesAllStoredFieldsAndDeliberatelyNonCurrentValues` decodes then encodes `format`, `formatVersion`, `packageInstanceID`, `createdAt`, `summary`, `privacy`, `agentGuide`, `agentPolicy`, `agentIntegrationContract`, `extensionCapabilities`, `externalActionPolicy`, `helpTopics`, `validationIssues`, `validationReport`, and `manifest`. Compare semantic JSON, normalizing only object-key order and documented date representation. `testStoredAgentContractAndCapabilityCodableRejectMissingRequiredFields` proves missing required fields fail with sanitized structural errors rather than rebuilding `.current`, allowed-field schemas, or defaults. `testRawReviewStateAndEventValuesRoundTripWithoutTransitionPolicy` preserves only raw Codable values.

Run the focused Debug and Release targets now. The full test targets must compile; record assertion REDs for stored-value reconstruction/strict-field behavior rather than unresolved-symbol failures. Some pure characterization rows may already be GREEN.

- [ ] **Step 3: GREEN one atomic production normalization edit**

Do not run or commit a tree in which production APIs are deleted but old tests remain. In one compile-restoring production edit:

- give `MindDeskInterchangePackage` the 15 stored properties plus an explicit all-value initializer; delete live-Manifest/package constructors, `.current`, default guide/policy/help reconstruction, current contract/catalog/report builders, and manifest-derived fields;
- move raw Codable `MindDeskProposalReviewState` and `MindDeskProposalReviewEvent` into `LegacyReviewWireTypes.swift` in the same edit that removes their old declarations;
- move `MindDeskAnyCodingKey` and `MindDeskProposalDecodeLimitGuards` plus pure Proposal collection/reference/text/payload limits, tamper checks, freshness, and sanitized diagnostics into `MindDeskProposalEnvelopeValidation.swift`;
- delete transition/approval/rejection/Apply/action policy, `WorkbenchObjectReferenceIndex`, and live package/Manifest Proposal validation overloads;
- move ordinary Manifest issue/message mapping into `MindDeskManifestValidationReport`, then delete `MindDeskInterchangePackageValidationReport`, `MindDeskProposalValidationReport`, `MindDeskExtensionCapabilityCatalogValidationReport`, and `MindDeskAgentIntegrationContractValidationReport`; `MindDeskValidationReportToken` may remain only in the retained sanitization file.

No commit may contain both the stored record and live/default reconstruction authority. In `CoreBehaviorTests.swift`, the already-prepared test edit contains its three Gate 3 migrations, eleven retirements, one body edit, and deletion of unused `normalizedText(_:)` and `containsWholeWord(_:in:)` helpers.

- [ ] **Step 4: Verify the normalized authority boundary GREEN**

```bash
swift test --filter LegacyReviewWireCompatibilityTests
swift test -c release --filter LegacyReviewWireCompatibilityTests
swift test --filter ManifestImportValidation
swift test -c release --filter ManifestImportValidation
swift test --filter ValidationReportTests
swift test -c release --filter ValidationReportTests
swift test
swift test -c release
swift build
swift build -c release
git diff --check
```

- [ ] **Step 5: Commit one authority boundary**

```bash
git add -- Package.swift Sources/MindDeskCore/LegacyReviewWireTypes.swift Sources/MindDeskCore/MindDeskInterchangePackage.swift Sources/MindDeskCore/MindDeskProposalEnvelope.swift Sources/MindDeskCore/MindDeskProposalEnvelopeValidation.swift Sources/MindDeskCore/MindDeskValidationReport.swift Sources/MindDeskCore/MindDeskAgentIntegrationContract.swift Sources/MindDeskCore/MindDeskExtensionCapabilityCatalog.swift Sources/MindDeskCore/MindDeskHelpCatalog.swift Sources/MindDeskCore/WorkbenchReferences.swift Tests/MindDeskCoreTests/LegacyReviewWireCompatibilityTests.swift Tests/MindDeskCoreTests/Fixtures/legacy-interchange-v1.json Tests/MindDeskCoreTests/Fixtures/legacy-proposal-envelope-v1.json Tests/MindDeskCoreTests/AgentIntegrationContractTests.swift Tests/MindDeskCoreTests/ProposalReviewTests.swift Tests/MindDeskCoreTests/ValidationReportTests.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "refactor: preserve historical review wire values"
```

---

### Task 6: Gate 4A — Pure Exact-Cardinality Primary Canvas Resolver

**Files:**

- Create: `Sources/MindDeskCore/WorkspacePrimaryCanvasResolver.swift`
- Create: `Tests/MindDeskCoreTests/WorkspacePrimaryCanvasResolverTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED zero/one/two/three and collision cases individually**

Use the new-type two-stage RED protocol: first record the missing-type compile RED, then add only the resolver enum/API signatures with inert `.missing` behavior and observe assertion REDs before implementing real branching.

Required complete behaviors:

- zero → `.missing`;
- one nonblank raw ID → `.unique`;
- two or three → `.duplicate`;
- one blank → duplicate collision;
- repeated IDs remain repeated duplicate evidence;
- duplicate output is stable-sorted and never selects one.

- [ ] **Step 2: GREEN without normalization**

Do not trim, filter, deduplicate, use `Set`, or repair IDs. Sorting exists only for deterministic duplicate output.

- [ ] **Step 3: Verify and commit**

```bash
swift test --filter WorkspacePrimaryCanvasResolverTests
swift test -c release --filter WorkspacePrimaryCanvasResolverTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDeskCore/WorkspacePrimaryCanvasResolver.swift Tests/MindDeskCoreTests/WorkspacePrimaryCanvasResolverTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: resolve primary canvas cardinality safely"
```

---

### Task 7: Gate 4B — Exact SwiftData Lookup and Cardinality Fingerprint

**Files:**

- Modify: `Sources/MindDesk/Models/WorkspaceCanvasLookup.swift`
- Create: `Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift`
- Create: `Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: Migrate the existing lookup tests**

Migrate exactly:

- `AppBehaviorTests.testWorkspaceCanvasLookupLimitsExistingCanvasFetch` → `WorkspacePrimaryCanvasIntegrationTests.testLookupDescriptorUsesExactWorkspaceStableSortAndFetchLimitTwo`
- `AppBehaviorTests.testWorkspaceCanvasLookupFetchesOnlyRequestedWorkspace` → `WorkspacePrimaryCanvasIntegrationTests.testLookupExcludesForeignWorkspacesAndMapsScopedIDsThroughResolver`

- [ ] **Step 2: RED exact lookup**

Require exact `workspaceId`, stable sort by raw Canvas ID, `fetchLimit = 2`, foreign-workspace exclusion, and resolver mapping.

- [ ] **Step 3: RED the pure fingerprint**

Fingerprint the full active-workspace `@Query` Canvas ID multiset, not the lookup descriptor's capped two records. Use record count and UTF-8 byte-length-prefixed stable-sorted entries. Cover order independence, `A` versus `A,A`, blanks, repeats, concatenation collisions, and `A,B,C → A,B,D` so a change hidden beyond `fetchLimit = 2` still changes the root observation. Never use a set.

- [ ] **Step 4: GREEN only lookup/fingerprint**

This gate does not provision or introduce the scope controller. Remove no UI fallback yet if doing so would leave an uncompilable Canvas path; the Gate 6 root integration removes it atomically.

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter WorkspacePrimaryCanvasIntegrationTests
swift test -c release --filter WorkspacePrimaryCanvasIntegrationTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspaceCanvasLookup.swift Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift Tests/MindDeskTests/AppBehaviorTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: add exact primary canvas lookup fingerprint"
```

---

### Task 8: Gate 5A — Pending/Bound Window Scope Identity

**Files:**

- Create: `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`
- Create: `Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED identity construction and transitions**

Use the new-type two-stage RED protocol, then cover distinct controller window IDs, stable same-workspace focus, A→B→A revision rotation, nil initial resolution, first unique/missing/duplicate bind, stale bind, equal idempotence, every unequal transition, changed duplicate payload, exact invalidation, and stale invalidation.

- [ ] **Step 2: GREEN the sole identity authority**

Implement internal, non-Codable, non-persisted scope types with fileprivate raw initializers. The controller is `@MainActor ObservableObject`; it alone creates identities. Tests obtain them via `@testable import MindDesk` and controller APIs.

- [ ] **Step 3: Install one stable scene-root owner**

`ContentView` owns exactly one controller through `@StateObject` and passes that same object downward. No controller or UUID construction may occur in `body`, `WorkspaceDetailView`, or computed properties. This task installs the stable owner only; Task 12 adds the one scene-observation reducer, so no provisional `onAppear`/tab-driven async launch path is allowed here.

- [ ] **Step 4: Verify and commit**

```bash
swift test --filter WorkspaceWindowScopeControllerTests
swift test -c release --filter WorkspaceWindowScopeControllerTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspaceWindowScopeController.swift Sources/MindDesk/Views/ContentView.swift Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: bind canvas work to window scope identity"
```

---

### Task 9: Gate 5B — Exact Cancellation Registry and Reentrancy

**Files:**

- Modify: `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`
- Modify: `Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED registration/completion/cancellation**

Cover pending-focus registration before binding, stale registration immediate cancellation once, mismatched completion no-op, exact completion removal, completed operation zero cancellation, focus/resolution/invalidation/clear cancellation once, and reentrant callback observation.

- [ ] **Step 2: GREEN detach → install → callback**

Every transition first detaches the live registry, installs complete new state, then synchronously invokes each still-registered callback once. Reentrant code can see only new state and cannot rerun the detached registry.

- [ ] **Step 3: Verify and commit**

```bash
swift test --filter WorkspaceWindowScopeControllerTests
swift test -c release --filter WorkspaceWindowScopeControllerTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspaceWindowScopeController.swift Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: cancel stale window scope work exactly once"
```

---

### Task 10: Gate 6A — One Resolution Slot and Atomic Attempt Lifecycle

**Files:**

- Modify: `Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift`
- Modify: `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`
- Modify: `Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED slot launch, replace, handoff, and terminal order**

Cover one installed slot, registration failure, fingerprint invalidation, A→B→A request IDs, same-fingerprint replacement, failed replacement preserving the current slot, superseded completion isolation, exact `complete → clear → bind`, failed completion, and pre-insert→post-save phase handoff without self-cancellation. `testSameFingerprintReplacementCancelsDisplacedTaskOnceCompletesOldRegistrationAndPreservesReplacement` uses controlled continuations to prove the displaced Task observes one cancellation, its exact completed registration receives zero cancellation callbacks, the replacement slot/registration survives untouched, and later invalidation cancels the replacement exactly once.

- [ ] **Step 2: GREEN one controller-owned slot**

The controller owns one mutable slot containing attempt, immutable operation ID, Task, and cancellation-observed state. Coordinator types/extensions live in the coordinator file; there is no second `ObservableObject`.

Every production slot worker is created as `Task { @MainActor [weak controller] in ... }`; no slot or SwiftData work uses `Task.detached`. It may capture the controller weakly, Sendable IDs/attempt/resolution/fingerprint values, a `ModelContainer` when later needed, and explicitly injected `@MainActor @Sendable` value/service seams or terminal/handoff callbacks whose inputs and outputs are Sendable values. It never captures a `ModelContext`, `@Model` instance, or other context-bound value. The existing retain-cycle and context-ownership tests cover both production and injected paths.

Use a cancellation-safe one-shot start gate, such as a one-element `AsyncStream`, so a worker cannot commit before registration and slot installation. Open the gate only after a successful registration and installed slot. Every failure path performs `cancel + finish/open`; the gate terminates exactly once, so an immediately stale registration cannot strand a continuation. Do not rely only on scheduling luck or `Task.yield()`.

Add tests proving a zero-latency worker cannot beat slot installation, an immediately stale registration's synchronous callback still lets the Task terminate, and invalidation before the gate opens leaves neither Task nor registration alive. Task and callback capture the controller weakly to avoid a slot/Task/controller retain cycle.

- [ ] **Step 3: Verify and commit**

```bash
swift test --filter WorkspacePrimaryCanvasIntegrationTests
swift test -c release --filter WorkspacePrimaryCanvasIntegrationTests
swift test --filter WorkspaceWindowScopeControllerTests
swift test -c release --filter WorkspaceWindowScopeControllerTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift Sources/MindDesk/Models/WorkspaceWindowScopeController.swift Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: serialize primary canvas resolution attempts"
```

---

### Task 11: Gate 6B — Scoped Lookup and Isolated Missing-Canvas Provisioning

**Files:**

- Modify: `Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift`
- Modify: `Sources/MindDesk/Models/WorkspaceCanvasLookup.swift`
- Modify: `Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED initial lookup and returned-focus handoff**

Only the exact attempt/focus/fingerprint may complete. Initial results complete and clear before bind. Only `.missing` starts provisioning, using the focus returned by bind rather than its captured predecessor.

- [ ] **Step 2: RED pre-insert race handling**

A second scoped fetch that returns unique/duplicate performs no insert and binds that result. Consecutive missing alone reaches mutation.

- [ ] **Step 3: GREEN isolated SwiftData provisioning**

Define the store/test seam as `@MainActor`; it accepts and returns only Sendable value records/IDs/resolutions, never `CanvasModel`, `CanvasNodeModel`, `ModelContext`, or another context-bound value. Production workers remain `Task { @MainActor ... }`. They capture the `ModelContainer`, create each `ModelContext` on MainActor, set `autosaveEnabled = false`, use it only on MainActor, and release it at the end of that phase.

Use a dedicated provisioning `ModelContext` with no unrelated staged changes. Pre-insert fetch → cancellation/slot/focus/fingerprint guard → insert → save is one MainActor segment with no `await` or actor hop between the final guard and save. Never call rollback on the shared scene context. Do not place an `await controller.accepts(...)` between the final guard and mutation; the controller and mutation are already on the same MainActor.

- [ ] **Step 4: RED/GREEN post-save reconciliation**

After save success or failure, release/discard the provisioning context, atomically hand the same operation/Task/registration to a fresh post-save attempt ID, and create a different MainActor context for the fresh scoped fetch. Missing/duplicate stop without recursive retry, third insert, repair, deletion, or compensation rollback.

Use controlled continuations rather than sleeps for race tests. Resume or cancel every continuation during teardown.

- [ ] **Step 5: Verify real-store and controlled-store cases, then commit**

```bash
swift test --filter WorkspacePrimaryCanvasIntegrationTests
swift test -c release --filter WorkspacePrimaryCanvasIntegrationTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift Sources/MindDesk/Models/WorkspaceCanvasLookup.swift Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: provision missing canvas through isolated scope"
```

---

### Task 12: Gate 6C — Error/Cancellation Closure and Canvas Availability UI

**Files:**

- Create: `Sources/MindDesk/Models/WorkspacePrimaryCanvasPresentation.swift`
- Modify: `Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift`
- Modify: `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift`
- Modify: `Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED every cancellation/error boundary**

Initial, pre-insert, and post-save fetch throws; cancellation before second fetch, before insert/save, after successful save, and during post-save fetch; fingerprint change between save and handoff; stale/current non-cancellation error; and every exit leaving no live registration or finished slot.

Gate 6 never creates, reads, or clears pending node state.

- [ ] **Step 2: GREEN exact terminal cleanup**

Handle `CancellationError` before ordinary errors. Stale exits are silent. Current non-cancellation errors sanitize their message, complete and clear only the exact slot, preserve the current resolution, discard the provisioning context, and do not retry.

Define a pending-neutral `WorkspacePrimaryCanvasTerminalOutcome` with `operationID`, the full final `WorkspacePrimaryCanvasResolutionAttempt`, and a kind of either `.resolution(WorkspacePrimaryCanvasResolution)` or `.recoverableError(message: String)`. The coordinator invokes its scene-root terminal callback only for an exact current terminal result/error after registration and slot cleanup; it emits nothing for cancellation or stale work. Gate 6 neither imports nor names a pending-node type.

Also define pending-neutral `WorkspacePrimaryCanvasOperationHandoff(oldOperationID:newOperationID:newAttempt:)`. When an exact initial `.missing` successfully registers a new provisioning operation, emit this handoff after the new slot is accepted and before any terminal callback; do not emit the intermediate missing result. If provisioning registration fails, emit the initial missing outcome under the old operation only after revalidating that the old attempt/focus/fingerprint is still exact-current and no accepted replacement slot exists. A synchronously stale registration failure emits zero outcome and changes no correlation. The type and callback contain no node/pending-target concept.

- [ ] **Step 3: Replace unsafe scene-root Canvas selection and creation**

Remove `createdCanvasByWorkspaceId`, request-driven Canvas `.first`, `ensureCanvas()`, shared-context provisioning, and global rollback. Define one Equatable scene observation `(workspaceID: String?, fingerprint: String?)` from current selection plus the full active-workspace Canvas multiset. `ContentView` drives it through one `.onChange(of: observation, initial: true)` reducer:

- nil/non-workspace/missing workspace → `controller.clear()`;
- new workspace → `focus` then exactly one initial lookup;
- same workspace and same fingerprint → no action;
- same workspace and changed fingerprint → exact invalidation, then exactly one lookup using the returned focus.

Tab changes, child `onAppear`, request render callbacks, and render-model mismatches never invalidate or launch Primary Canvas lookup. Cover `A → Home → A`, one launch per observation, same-view-identity `ContentView` reconstruction retaining its window ID, and a second window receiving a different ID. Only an exact accepted `.unique(canvasID)` whose current query contains exactly one `CanvasModel` satisfying both `id == bound.canvasID` and `workspaceId == bound.focus.workspaceID` renders Canvas. Zero/collision/ownership drift—including the normal interval where post-save fresh-context bind precedes root-query merge—fails closed and renders no Canvas; only the single scene-observation reducer reacts to a later query/fingerprint change and reconciles exactly once. Slot activity, error presentation, and resolution presentation derive from this same `@StateObject`.

- [ ] **Step 4: RED/GREEN availability states**

- Only an accepted missing-Canvas provisioning phase (pre-insert through post-save reconciliation): `Preparing Canvas…`. Initial lookup must not reuse this copy.
- Terminal missing: exact persistent copy and one `Try Again` that starts a fresh initial attempt.
- Duplicate: exact non-destructive paused copy, no selection or retry insertion.
- Current initial-fetch error with `resolution == nil` and no live slot: show the sanitized recoverable error through the existing status/error surface and a non-busy unavailable placeholder; never leave an infinite `Preparing Canvas…` state and never retry automatically.
- Tasks, resources, snippets, and Overview remain usable.

- [ ] **Step 5: Verify Gate 6 in full and commit**

```bash
swift test --filter WorkspacePrimaryCanvasIntegrationTests
swift test -c release --filter WorkspacePrimaryCanvasIntegrationTests
swift test --filter WorkspaceWindowScopeControllerTests
swift test -c release --filter WorkspaceWindowScopeControllerTests
swift test
swift test -c release
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspacePrimaryCanvasPresentation.swift Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift Sources/MindDesk/Models/WorkspaceWindowScopeController.swift Sources/MindDesk/Views/ContentView.swift Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: fail closed on unavailable primary canvas"
```

---

### Task 13: Gate 7A — UUID Pending Target and Bound Request State Machine

**Files:**

- Create: `Sources/MindDesk/Models/WorkspaceCanvasNodeOpenRequest.swift`
- Create: `Tests/MindDeskTests/WorkspaceCanvasNodeOpenRequestTests.swift`
- Modify: `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`
- Modify: `Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: Retire the complete old Int-only policy honestly and establish the UUID scaffold**

Retire all three split obligations in the same compile-restoring slice:

- `AppBehaviorTests.testQuickOpenWebCardOpenActionClearsPendingRequestOnBlockedResult`
- `AppBehaviorTests.testQuickOpenWebCardOpenActionKeepsPendingRequestOnReadyResult`
- `AppBehaviorTests.testWorkspaceCanvasNodeOpenRequestPolicyHandlesOnlyNewCurrentCanvasRequests`

Use the new-API two-stage RED protocol. First observe the UUID contract compile RED, then atomically remove the old Int declarations/policy and add only inert UUID request/target/factory signatures so the full target compiles. Observe assertion REDs against the inert state machine before implementing behavior. The three old tests retire into multiple added obligations, not one-to-one migrations.

In that same compile-restoring scaffold, remove every old request consumer from `WorkspaceCanvasView.swift`, including `handledOpenCanvasNodeRequestID`, `WorkspaceCanvasNodeOpenRequestPolicy`, and old request/target field reads. Gate 7A leaves a neutral no-consumer boundary; Gate 7B adds the new ownership/readiness consumer. `testLegacyIntRequestTargetPolicyAndCanvasConsumerSymbolsAreAbsent` scans both `ContentView.swift` and `WorkspaceCanvasView.swift`.

- [ ] **Step 2: RED pending creation/replacement/result correlation**

Every target gets a new UUID. The controller owns one flow: `idle`, `pending(exact four-field target, optional launch correlation)`, or `issued(exact four-field target, exact request, exact ownership evidence)`. Claiming a target atomically replaces the entire old flow. If the old flow is issued and deferred, revoke its request without advancing `lastConsumedSequence` or changing selection/viewport; a late callback for that request is only an unissued/replaced rejection and cannot clear the new flow. A launch correlation is `starting(launchID, exact focus, exact fingerprint)` or `accepted(operationID)`. The scene-root adapter keeps no parallel copy: it uses controller compare-and-swap methods to install a fresh starting nonce before Gate 6 registration, upgrade only that exact nonce to the returned operation ID, perform operation handoff, or clear it. The Gate 6 coordinator still sees only its pending-neutral terminal outcome.

When a new target arrives during an accepted exact initial/pre-insert/post-save slot for the same workspace observation, associate the new target with that slot's operation ID without cancelling or restarting provisioning. A cross-workspace claim installs no starting nonce until its selection observation changes; only the one observation reducer launches it. A same-workspace claim whose observation remains unchanged may install one nonce and start one explicit fresh lookup. Replacing a target atomically replaces its correlation. Every terminal outcome from an accepted operation requires both the exact outcome operation ID and equality with the current four-field target. Among error/cancellation outcomes, only a current exact accepted-operation `.recoverableError` may terminally clear; stale/cancellation/old A→B→A outcomes cannot clear or issue from a replacement target. Ordinary `missing`/`duplicate`/target-mismatch/confirmed-absence outcomes use the explicit active-flow table rather than this error rule.

On `WorkspacePrimaryCanvasOperationHandoff`, atomically replace `(oldOperationID, target)` with `(newOperationID, same target)` only when the correlation and current four-field target still match exactly. Every accepted launch caused by fingerprint replacement, `Try Again`, or another explicit fresh lookup similarly captures the current target and reassociates it only if the target remains exact; old outcomes then fail while the newest outcome can finish the flow.

Cover targets created/replaced during every phase, including replacement of a deferred issued flow, same-operation reassociation, failed new registration, and old outcome/request delivery after replacement. `testTargetLaunchHandshakeRetainsCurrentTargetOnRegistrationFailureWhileStaleFailureMutatesNothing` proves the controller installs the provisional nonce before registration; a still-current injected failure removes only that exact nonce, retains the target, and exposes sanitized recoverable retry with no accepted operation; a synchronous stale failure changes no current flow, correlation, or status. Never infer correlation from a global `lastError` or workspace ID alone.

- [ ] **Step 3: RED allocation, identity, replay, readiness, and overflow**

Sequence starts at 1 per bound scope. Rotation resets sequence/issued/consumed request state, but a same-workspace internal rotation demotes the newest unconsumed issued flow back to its exact pending target without advancing counters; it never resurrects a target already replaced by a newer claim. A transition into that target's workspace preserves it, while a later user switch to another workspace, Home, or nil clears the exact flow. Identity mismatch, unissued/revoked sequence, and replay reject without advancing or mutating the current flow. `dataNotReady` retains the exact issued request and originating target unchanged; ready/confirmed absent atomically consume both. Seed the pure allocator near `UInt64.max`; use `addingReportingOverflow`, never a huge loop or wrapping addition. Overflow emits no request, demotes the still-current target to pending, returns structured `.overflowInvalidated(focus)`, and lets the scene adapter start exactly one fresh lookup and correlate its accepted operation ID even when the Canvas fingerprint did not change.

Gate 7A also implements the controller's pure, exact-match evidence CAS surface: synchronously change the current issued evidence from ready to dirty for a supplied full target/request/scope/fingerprint; install fresh ready evidence only when all four still match; and consume confirmed absence only under that same match. `testDataNotReadyRetainsIssuedFlowWhileReadyOwnedAndConfirmedAbsenceConsumeExactTarget` exercises this pure state surface with in-memory values. Gate 7A does not create a SwiftData lookup or a Canvas render consumer.

- [ ] **Step 4: GREEN in one authority**

Define request initializer and controller checked factory/consumer extension in the same file. The existing window controller owns the single flow plus sequence and consumed state. Issuing performs an idempotent `pending → issued` transition, retains the exact target beside the request, and clears only operation correlation. Exact accept or confirmed absence clears that exact request and originating target together. Overflow invalidates to a new nil-resolution/unbound focus with normal exactly-once cancellation while retaining the newest target as pending, then returns `.overflowInvalidated(focus)` for the one explicit recovery launch.

Continue from Step 1's signature-only UUID scaffold and implement its behavior without reintroducing the deleted Int declarations or policy. The Int request and UUID request never coexist in a committed tree.

- [ ] **Step 5: Migrate the Quick Open creation side**

Quick Open creates only a claimed UUID target. For a cross-workspace target it first claims, then changes selection, and relies exclusively on the one scene-observation reducer to focus/resolve/provision/bind; it cannot also launch a parallel lookup. Only a same-workspace claim whose selection/fingerprint observation remains unchanged may request one explicit fresh launch. Its all-array lookup is not authorization evidence.

- [ ] **Step 6: Verify and commit**

```bash
swift test --filter WorkspaceCanvasNodeOpenRequestTests
swift test -c release --filter WorkspaceCanvasNodeOpenRequestTests
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspaceCanvasNodeOpenRequest.swift Sources/MindDesk/Models/WorkspaceWindowScopeController.swift Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift Sources/MindDesk/Views/ContentView.swift Sources/MindDesk/Canvas/WorkspaceCanvasView.swift Tests/MindDeskTests/WorkspaceCanvasNodeOpenRequestTests.swift Tests/MindDeskTests/AppBehaviorTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: scope node open requests to bound canvas"
```

---

### Task 14: Gate 7B — Scoped Node Ownership and Render Consumption

**Files:**

- Create: `Sources/MindDesk/Models/WorkspaceCanvasNodeLookup.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Tests/MindDeskTests/WorkspaceCanvasNodeOpenRequestTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

Gate 7B wires the Gate 7A pure dirty/ready/absence CAS surface to the fresh SwiftData lookup and Canvas render lifecycle. It does not modify `WorkspaceWindowScopeController.swift` or `WorkspaceCanvasNodeOpenRequest.swift`; any newly discovered need to change those files invalidates this task boundary and returns to Gate 7A review rather than broadening the exact-path commit.

- [ ] **Step 1: RED exact ownership**

In one fresh context, first fetch `CanvasModel` by exact `id == bound.canvasID` and `workspaceId == bound.focus.workspaceID` with `fetchLimit = 2`; only exactly one may continue. Then fetch `CanvasNodeModel` by exact node ID and `canvasId == bound.canvasID`, also with `fetchLimit = 2`; only exactly one produces `readyOwned`. Zero, cross-workspace/cross-Canvas, or collision evidence at either stage is `definitelyAbsentOrCrossCanvas`. A pre-issue result commits only under the unchanged full bound identity and exact current pending flow. Issue stores ownership evidence bound to full target, request, scope, and the current node-observation fingerprint.

Build that fingerprint from stable-sorted raw `(nodeID, canvasID)` pairs with count and length prefixes, retaining blank and duplicate values. On any changed node observation, synchronously mark the exact issued evidence dirty for the new fingerprint before running the same two-stage lookup. While dirty, every render/surface event must defer and cannot reuse old ready evidence. A lookup result commits only if target/request/scope/fingerprint remain exact: fresh ready evidence may continue to render handling, confirmed absence consumes, and stale results do nothing.

The production ownership lookup is deliberately synchronous on MainActor in a fresh read-only `ModelContext` with `autosaveEnabled = false`; both ownership queries use that context, it returns only the readiness enum, and releases the context before render handling. It creates no Task or cancellation registration. If either fetch throws, a pending flow remains pending and unissued; an issued flow retains its exact target/request but keeps the current evidence dirty. Both report sanitized recoverable status and wait for explicit later reevaluation; no render event may accept until a fresh lookup for the same generation succeeds. Add throw-before-issue, throw-after-dirty, scope-rotation, pending/issued replacement, A→B→A, and post-bind Canvas `workspaceId` drift tests proving no old or cross-workspace result can consume current state.

- [ ] **Step 2: RED render readiness**

A missing render-dictionary entry or zero surface size is `dataNotReady`, not confirmed absence. Defer without consuming either request or originating target. Reevaluate on node IDs, request, scope, and surface-size changes; node-ID/query reevaluation first dirties and reruns scoped ownership, while pure render/surface reevaluation may reuse only ready evidence whose full request/scope/fingerprint still equals the current flow. Dirty/missing/stale evidence always defers.

- [ ] **Step 3: GREEN the Canvas consumer**

Keep the Gate 7A-deleted `handledOpenCanvasNodeRequestID` absent. Only `.accept` changes selection/viewport. `.rejectAndConsume` clears the exact current issued flow only when request and originating target still match; a mismatch mutates neither current flow nor receiving-scope counters. `.defer` retains the complete issued flow and emits no “deleted” status.

- [ ] **Step 4: Verify Gate 7 in full and commit**

```bash
swift test --filter WorkspaceCanvasNodeOpenRequestTests
swift test -c release --filter WorkspaceCanvasNodeOpenRequestTests
swift test
swift test -c release
swift build
swift build -c release
git diff --check
git add -- Sources/MindDesk/Models/WorkspaceCanvasNodeLookup.swift Sources/MindDesk/Views/ContentView.swift Sources/MindDesk/Canvas/WorkspaceCanvasView.swift Tests/MindDeskTests/WorkspaceCanvasNodeOpenRequestTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "feat: consume node requests only after scoped readiness"
```

---

### Task 15: Gate 8A — Current-Capability Documentation and Mandatory Ordinary Regressions

**Files:**

- Modify: `README.md`
- Modify: `docs/user-manual.md`
- Modify: `docs/releases/v3.0.0.md`
- Modify: `docs/feature-checklist.md`
- Modify: `CHANGELOG.md`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`
- Modify: `Tests/MindDeskTests/ManifestImportServiceTests.swift`
- Modify: `Tests/MindDeskTests/S0SurfaceAbsenceTests.swift`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED exact copy and placement**

Require the canonical English notice in README English privacy section, user manual Safety Boundary Quick Reference, release note top current-capability notice, and feature checklist; require faithful Chinese README copy. Require no notice in product UI/default Help/onboarding/menu/rail. Mark old release Agent material historical/no longer current. CHANGELOG gets a historical-capability notice, not the canonical current privacy badge.

The approved exact Chinese README copy is:

> **Canvas Review 当前处于关闭状态。** 此版本不会通过该功能启动 Agent 或审阅助手、生成 AI 上下文包，也不会向模型提供 Canvas 内容。MindDesk 的常规存储、系统备份、同步以及您使用的任何外部服务，仍受其各自隐私设置约束。

Add exactly these net-new documentation/regression tests:

- `CoreBehaviorTests.testCanvasReviewOffNoticeHasExactApprovedDocumentationPlacement`
- `CoreBehaviorTests.testCurrentCapabilityDocumentationContainsNoActionableAgentCodexOrProposalReviewInstructions`
- `CoreBehaviorTests.testV3ReleaseNotesPlaceRetiredAgentMaterialBelowSingleHistoricalBoundary`
- `S0SurfaceAbsenceTests.testCanvasReviewOffNoticeIsAbsentFromProductSourcesDefaultHelpOnboardingMenusAndRails`
- `AppBehaviorTests.testWorkspaceOverviewRouteRendersCurrentOverviewWhenCanvasIsUnavailable`

- [ ] **Step 2: GREEN documentation without overclaiming**

Use the exact approved copy. Distinguish raw filesystem paths from sanitized record locators. Do not imply protection from system backup, sync, or unrelated external services.

Remove live Agent/Codex/Proposal instructions from every current-capability section, not merely add a notice beside them:

- README: both-language table of contents, surface tables, Agent workflow, current feature list, and What's New;
- user manual: concepts, Settings, Canvas Codex/terminal/session instructions, Agent package export, Proposal Review, and troubleshooting;
- feature checklist: every old live-capability checkbox/instruction;
- `docs/releases/v3.0.0.md`: place all old Agent material below one conspicuous top `Historical / no longer current` boundary.

Retire `CoreBehaviorTests.testAgentReviewHelpTopicsContractIsDocumentedForHumansAndAgents` and body-edit `CoreBehaviorTests.testSettingsResetDescriptorContractIsDocumentedInFeatureChecklist` exactly as recorded in the migration map.

Negative tests reject actionable names of removed menus, buttons, sessions, terminal start, MIP export, and Proposal Review inside current-capability sections. The canonical notice may appear only at its four specified documentation locations and must be absent from `Sources`, default Help, onboarding, menus, and rails.

- [ ] **Step 3: Run every mandatory ordinary regression family**

Run, not sample:

- all `ManifestImportServiceTests` and `ManifestImportValidation*`;
- typed/legacy Manifest decode, unsupported version, formatted non-Manifest rejection, export/import round trip;
- Terminal prefill and command failure fallback;
- explicit resource/snippet/folder clipboard routes;
- Finder file/folder and Canvas resource open routing;
- Help descriptor/selection/reader and ordinary Settings/Canvas/Data search;
- workspace Canvas/Overview routing while Canvas is unavailable;
- Inspector manual-only behavior;
- Canvas select, drag, pan, resize, connect, drop, and edge animation.

- [ ] **Step 4: Verify and commit**

```bash
swift test --filter AppBehaviorTests/testDirectUserResourceCopyPathWritesOnlyAfterExplicitAction
swift test --filter AppBehaviorTests/testDirectUserSnippetCopyWritesBodyOnlyAfterExplicitAction
swift test --filter AppBehaviorTests/testFolderPreviewCopyUsesNamedDirectUserClipboardRoute
swift test -c release --filter AppBehaviorTests/testDirectUserResourceCopyPathWritesOnlyAfterExplicitAction
swift test -c release --filter AppBehaviorTests/testDirectUserSnippetCopyWritesBodyOnlyAfterExplicitAction
swift test -c release --filter AppBehaviorTests/testFolderPreviewCopyUsesNamedDirectUserClipboardRoute
swift test
swift test -c release
git diff --check
git add -- README.md CHANGELOG.md docs/user-manual.md docs/releases/v3.0.0.md docs/feature-checklist.md Tests/MindDeskCoreTests/CoreBehaviorTests.swift Tests/MindDeskTests/AppBehaviorTests.swift Tests/MindDeskTests/ManifestImportServiceTests.swift Tests/MindDeskTests/S0SurfaceAbsenceTests.swift docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "docs: present MindDesk as private manual canvas"
```

---

### Task 16: Gate 8B — Closed Policy, Verifier, and Adversarial Self-Test

**Files:**

- Create: `script/s0_private_canvas_policy.sh`
- Create: `script/verify_s0_private_canvas.sh`
- Create: `script/test_verify_s0_private_canvas.sh`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED the first verifier rule through the real harness**

Create the self-test harness first with a declarative positive `Package.swift`; malicious primary-manifest fixtures for Foundation/Darwin import and file/process/network/environment/argv side effects; valid numeric and nonnumeric/newline/control-character `Package@swift-*.swift` root fixtures; one positive root-only dependency fixture; and one negative external-dependency fixture. Cover regular, symlink, tracked-like, untracked-like, and ignored versioned-manifest forms. The harness proves physical NUL-safe root enumeration requires exactly one regular non-symlink `Package.swift`, rejects every versioned root manifest, and fails the non-executing manifest gate before any mocked SwiftPM command is invoked. Run it and record failure because the shared policy/verifier contract is absent. Then add only enough policy/verifier behavior to make that rule GREEN. Repeat RED→GREEN per rule class rather than writing the complete policy before its tests.

- [ ] **Step 2: Manually freeze each final rule as its test is added**

After Gates 2–7 are complete, manually enumerate approved roots, deleted paths/tokens, closed compatibility symbols/helpers, the complete approved system/framework import and resolved external-system callee inventory, normalized generated/macro/synthesized production inputs, every sensitive source/sink triple, and the complete reverse-reachable local effect-gateway graph from the final Release build. Do not derive or auto-learn approval. A new import/external callee fails before sink classification; a new local caller/wrapper/closure edge into an existing Finder/alias/resource import-export/persistence/defaults/file/terminal/AppleScript/URL/clipboard gateway also fails even without a new external API. The closed inventory includes:

- codecs: every `JSONEncoder`/`JSONDecoder`, property-list/archive encoder, and alternate serialization call;
- Foundation file/session mutation: `Data`/`NSData`/`String` writes, `OutputStream` open/write, `FileHandle` write/truncate/update, and every mutating `FileManager` create/copy/move/replace/remove/trash/link/symbolic-link/attribute/temporary-item call;
- Darwin/POSIX mutation: `open`/`openat`/`creat`, `write`/`pwrite`/`writev`, `truncate`/`ftruncate`, rename/link/symlink/unlink/remove, mkdir/rmdir, chmod/chown/time/xattr mutation, mkstemp/mkdtemp/mknod/mkfifo, copyfile/clonefile, writable/shared mapping, `fcntl`, and direct `syscall` routes;
- process/terminal: `Process`, `NSTask`, `posix_spawn*`, `fork`, `vfork`, every `exec*`, `system`, `popen`, and `openpty`;
- UI/system/dynamic bridges: raw `NSPasteboard`, `NSAppleScript`, Apple Event/OSA/ScriptingBridge APIs, Finder/workspace launch, argv, environment, URL opening, and `dlopen`/`dlsym` or equivalent dynamic invocation;
- network: `URLSession`, Network-framework APIs, sockets, and any equivalent outbound client.

Manually allow only exact ordinary Manifest, persistence-bootstrap, release-independent local storage, and named direct-user action triples/edges required by the product. Freeze every effectful declaration, every local call edge into or between effect gateways, permitted root entrypoints, and effectful closure/function-value injection edge. For every rule, first add a positive and near-miss negative fixture and observe the intended RED, then add the reviewed policy entry.

The completed self-test covers argument validation, paths with spaces/newlines/control bytes, sole-primary/versioned root manifest topology, root-only dependency JSON, malformed/truncated dependency/target/build-description JSON, unknown roots/imports/external callees, mismatched scratch/build plan, tampered or extra SwiftPM DerivedSources, unapproved macro/synthesized calls, new callers/wrappers/escaping closures into existing local gateways, allowed/forbidden source, exact/near-miss and undefined symbols, binary/resource strings, missing/failing required tools, unreadable/incomplete traversal, hidden helper/framework/plugin/XPC, resource executable/Mach-O, extra `Contents/MacOS` file, symlink, and binary replacement. Structural fixtures cover multiline calls, extensions, overloads, type aliases, nested/local closures, imported C calls, dynamic/unresolved external or effect-graph targets, and near-miss declarations for every sink family. Every unused process/POSIX/network/Apple Event/dynamic-loading family has zero allowed production triples.

- [ ] **Step 3: GREEN a fail-closed verifier**

The CLI is:

```text
script/verify_s0_private_canvas.sh --repo-root DIR --package-manifest-only
script/verify_s0_private_canvas.sh --repo-root DIR --scratch-path DIR --configuration release --build-description FILE --evidence-dir DIR --binary FILE [--app-bundle DIR]
```

It must:

- start with `set -euo pipefail` and source the shared read-only policy;
- before executing any `swift package`, `swift build`, or `swift test`, physically and NUL-safely enumerate the repository root without following symlinks; require exactly one regular non-symlink `Package.swift`, reject every other root basename matching `Package@swift-*.swift` whether regular, symlinked, tracked, untracked, or ignored—including supported MAJOR, MAJOR.MINOR, and MAJOR.MINOR.PATCH forms—then parse the sole `Package.swift` through the Swift compiler frontend without evaluating it. Permit only `PackageDescription` import plus the manually frozen declarative package/product/target/dependency construction used by this repository; reject Foundation/Darwin, arbitrary top-level execution, file/process/network/environment/argv access, and every unrecognized construct. `--package-manifest-only` runs exactly this gate, and the full verifier runs it as its first action;
- require full mode to receive an absolute private non-symlink scratch outside the repository, exact Release configuration, the sole regular non-symlink Release `description.json` produced by that scratch, and a private evidence directory; run every SwiftPM metadata command with the same explicit package/scratch paths and never default `.build`; the first call atomically writes normalized build/policy facts to the initially empty evidence directory, while later calls for unsigned, signed, extracted, or mounted copies recompute and require byte equality without overwriting; exclude volatile paths, symbol addresses, signatures, and raw binary/bundle hashes from those two canonical evidence files because provenance and bundle manifests bind those bytes separately;
- structurally parse `swift package show-dependencies --format json`, `swift package describe --type json`, and the captured build description; freeze/recheck its hash, configuration, compiler, exact production modules, sources, objects, outputs, and command graph before and after AST work;
- require zero external packages and absent `Package.resolved`;
- scan approved repository production roots plus all production inputs in that build description; allow only frozen normalized SwiftPM DerivedSources/templates and expanded macro/property-wrapper/compiler-synthesized declarations, reject unknown/tampered generated inputs, and atomically create deterministic strict `normalized-build-plan.json` plus `source-policy-evidence.json` in an initially empty evidence directory; later calls recompute and require byte equality without overwriting;
- use `nm -a` piped to the `xcrun`-located Swift demangler plus `strings -a`; use `otool -L` only as supporting evidence;
- reconstruct source AST invocations from exact `swiftCommands`/`swiftFrontendCommands` in that build description, changing only reviewed non-codegen AST-output flags, then match normalized file/generated provenance + enclosing fully qualified declaration + resolved callee triples. Freeze all system/framework imports, external callees, generated/macro/synthesized call edges, and the manually approved reverse-reachable local effect graph. Fail closed if AST production/parsing is incomplete, an external/effectful call is unresolved or dynamic, a new local edge reaches a gateway, or a call cannot be assigned to an enclosing declaration. Line-number or short-name regular expressions are not authority;
- allow zero process/terminal alternatives (`Process`/`NSTask`/spawn/fork/vfork/exec/system/popen/openpty), zero POSIX mutation, Apple Event/ScriptingBridge, dynamic-loading, and network callpoints; allow raw clipboard, the exact ordinary AppleScript route, Foundation file mutation, environment/argv, and codec calls only at their complete manually frozen triples;
- when given a bundle, prove `CFBundleExecutable` and `--binary` are the same sole regular code object and reject every extra code/symlink/unhandled file type.

- [ ] **Step 4: Verify scripts and direct Release binary**

```bash
set -euo pipefail
chmod 0755 script/verify_s0_private_canvas.sh script/test_verify_s0_private_canvas.sh
test -x script/verify_s0_private_canvas.sh
test -x script/test_verify_s0_private_canvas.sh
bash -n script/s0_private_canvas_policy.sh
bash -n script/verify_s0_private_canvas.sh
bash -n script/test_verify_s0_private_canvas.sh
bash script/test_verify_s0_private_canvas.sh
bash script/verify_s0_private_canvas.sh --repo-root "$PWD" --package-manifest-only
S0_G8B_BUILD=
S0_G8B_EVIDENCE=
s0_cleanup_g8b() {
  for path in "$S0_G8B_BUILD" "$S0_G8B_EVIDENCE"; do
    [ -z "$path" ] && continue
    case "$path" in
      /tmp/minddesk-s0-g8b-build.??????|/tmp/minddesk-s0-g8b-evidence.??????) ;;
      *) return 1 ;;
    esac
    if [ -e "$path" ] || [ -L "$path" ]; then
      [ -d "$path" ] && [ ! -L "$path" ] || return 1
      rm -rf -- "$path"
    fi
  done
}
trap s0_cleanup_g8b EXIT
S0_G8B_BUILD="$(mktemp -d /tmp/minddesk-s0-g8b-build.XXXXXX)"
S0_G8B_EVIDENCE="$(mktemp -d /tmp/minddesk-s0-g8b-evidence.XXXXXX)"
swift build -c release --scratch-path "$S0_G8B_BUILD"
S0_RELEASE_BIN_DIR="$(swift build -c release --scratch-path "$S0_G8B_BUILD" --show-bin-path)"
S0_G8B_BUILD_DESC="$(find -P "$S0_G8B_BUILD" -type f -path '*/release/description.json' -print -quit)"
test -n "$S0_G8B_BUILD_DESC"
bash script/verify_s0_private_canvas.sh --repo-root "$PWD" --scratch-path "$S0_G8B_BUILD" --configuration release --build-description "$S0_G8B_BUILD_DESC" --evidence-dir "$S0_G8B_EVIDENCE" --binary "$S0_RELEASE_BIN_DIR/MindDesk"
shasum -a 256 "$S0_RELEASE_BIN_DIR/MindDesk" "$S0_G8B_BUILD_DESC" "$S0_G8B_EVIDENCE/normalized-build-plan.json" "$S0_G8B_EVIDENCE/source-policy-evidence.json"
git diff --check
s0_cleanup_g8b
trap - EXIT
```

- [ ] **Step 5: Update ledger and commit**

```bash
git add -- script/s0_private_canvas_policy.sh script/verify_s0_private_canvas.sh script/test_verify_s0_private_canvas.sh docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "test: enforce private canvas release policy"
```

---

### Task 17: Gate 8C — Artifact Identity Chain and Workflow Wiring

**Files:**

- Modify: `script/package_release.sh`
- Modify: `script/verify_release_artifacts.sh`
- Modify: `script/test_release_artifact_verifier.sh`
- Modify: `script/test_release_package_failure_diagnostics.sh`
- Modify: `script/test_release_workflow_guards.sh`
- Modify: `script/verify_release_worktree.sh`
- Modify: `script/test_release_worktree_guard.sh`
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: RED the required release order in workflow guards**

Assert `package_release.sh`, CI, and release each invoke `verify_s0_private_canvas.sh --package-manifest-only` before their first `swift package`, `swift build`, or `swift test`; the guard uses mocked SwiftPM and proves no SwiftPM invocation occurs when the sole-primary/versioned-manifest gate fails. Assert each direct/formal Release path captures full HEAD, creates a unique private scratch plus initially empty evidence directory after clean-tree capture, passes that same explicit scratch to build, `--show-bin-path`, every SwiftPM metadata command, exact build-description parsing, and verifier AST work, passes the same evidence directory to every verifier call for that build, and never reads default `.build`. Bind build-description, normalized build plan/source-policy evidence, fresh binary, unsigned bundle, and pre-sign manifest hashes into strict build provenance. Assert every non-signature bundle mutation precedes the first full S0 verifier; only codesign/stapling may mutate the app until final-app manifest; post-final-app-state verification precedes packaging; each extracted ZIP/mounted DMG inner app receives mode-specific signature/ticket assessment as well as S0/manifest verification; upload/publish consumes exact proof-bound paths and digests rather than globs. RED the worktree guard against changes to `CHANGELOG.md`, any fixture or critical/generated-policy root regardless of extension, any root `Package@swift-*.swift`, symlink/untracked/ignored entries, and full-HEAD changes between direct build, package start, and output exposure.

- [ ] **Step 2: RED failure injection**

Inject missing/failing `nm`, demangler, JSON parser, `file`, `otool`, `strings`, signature/ticket, and hash tools; numeric/nonnumeric/newline/control-character versioned manifests; a pre-populated or mutated default `.build`; wrong/reused scratch or build description; SwiftPM ignoring the supplied scratch/no-op build; changed/extra DerivedSources, macro/synthesized call, or local effect-gateway edge; direct/package HEAD drift; build→hash→copy replacement; malformed or duplicate-key/wrong-root/wrong-type notarization JSON; unreadable/incomplete traversal; post-verification mutation; hidden code object/symlink; binary/signature/xattr/ticket replacement after ZIP/DMG packaging; wrong upload path/digest; and every strict proof JSON with duplicate keys, unknown/missing keys, wrong types/values, absolute/escaping/symlink paths, extra files, non-lowercase/non-64-character digests, or cross-proof disagreement. Archive fixtures also cover ZIP absolute/traversal/duplicate/symlink/extra-root entries and DMG hidden/extra roots, wrong Applications links, and a symlinked app root.

- [ ] **Step 3: GREEN `package_release.sh` identity chain**

Required sequence:

1. after fail-closed shell argument validation, run the strengthened worktree guard, require a clean tree, reject every tracked/untracked/ignored/symlink versioned root manifest, and capture the full start HEAD; then invoke `verify_s0_private_canvas.sh --repo-root "$PWD" --package-manifest-only` before any SwiftPM command;
2. create one private unique `mktemp -d` Release scratch directory and one initially empty private evidence directory, both with cleanup on every exit; pass that same explicit scratch to Release build, `--show-bin-path`, every metadata command, build-description lookup, and verifier, and pass the same evidence directory to every full verifier call for this build. Never read default `.build`. Require exactly one regular non-symlink Release `description.json` inside the scratch; freeze and recheck its hash; require the build produced the regular non-symlink `MindDesk` binary in that plan; generate strict normalized build-plan and source-policy evidence from the exact expanded AST/generated inputs/effect graph; hash and directly verify the scratch binary with the same scratch/description/evidence directory;
3. copy that exact binary into the unsigned app, finish every non-signature bundle mutation, require its hash still equals the scratch binary, run full bundle verification with the same scratch/description/evidence directory, record `pre-sign.bundle.manifest.json`, recompute it immediately before codesign, and require byte equality. Write strict `build-provenance.json` binding schema `1`, full source HEAD, Release configuration, build-description/normalized-plan/source-policy hashes, equal scratch/unsigned-bundle binary hashes, and pre-sign-manifest hash;
4. codesign the app in both modes. In notarized mode, create any notary transport ZIP outside the app, submit/poll with strict duplicate-key-rejecting JSON whose root is an object and whose required `id`/`status` are strings with accepted status, then staple the app; transport creation and read-only checks cannot mutate the app. In ad-hoc mode explicitly skip notarization/stapling and make no such claim. After the mode-specific final app state, run strict app signature verification and, in notarized mode, app-level `stapler validate` and Gatekeeper assessment; rerun the full S0 verifier with the same scratch/description/evidence directory, then record distinct `final-app.bundle.manifest.json`;
5. create the ZIP from that exact app and inspect archive entries before extraction: the root contains only one real `MindDesk.app` directory, with no absolute/`..`/duplicate/symlink/extra entry. Hash it, extract to a fresh directory, require the app root itself is not a symlink, traverse physically and NUL-safely, rerun the full verifier with the same scratch/description/evidence directory, compare to `final-app.bundle.manifest.json`, and run strict codesign verification on the extracted app; notarized mode also reruns app `stapler validate` and Gatekeeper. Then rehash the unchanged ZIP;
6. create the DMG from the same exact final app; in notarized mode codesign, notarize, and staple the outer DMG with strict submission JSON, then run outer strict signature, `stapler validate`, and Gatekeeper assessment; in ad-hoc mode make no notarization claim. Compute its final hash only after finalization, mount read-only/nobrowse, require exactly a real `MindDesk.app` plus `Applications -> /Applications`, reject hidden/extra entries and a symlinked app root, traverse physically/NUL-safely, rerun the full verifier with the same scratch/description/evidence directory, compare to `final-app.bundle.manifest.json`, and strictly verify the mounted inner app's codesign; notarized mode also reruns inner-app `stapler validate` and Gatekeeper. Detach on every exit, then rehash the unchanged DMG;
7. only after both paths pass, write strict `verified-artifacts.json` with exact top-level keys `schemaVersion`, `sourceHead`, `version`, `suffix`, `mode`, `artifacts`, and `proofs`. `schemaVersion` is JSON integer `1`; `sourceHead` equals captured full HEAD; version/suffix/mode equal exact verifier arguments and mode is `adhoc` or `notarized`. `artifacts` has exactly ZIP and DMG; `proofs` has exactly build provenance, normalized build plan, source-policy evidence, pre-sign bundle manifest, and final-app bundle manifest. Each entry has exact `kind`, artifact-relative `relativePath`, and lowercase SHA-256. Reject duplicate keys, wrong/unknown/missing types/values, duplicate kinds, absolute/escaping/symlink paths, unexpected names/extra files, and digest disagreement. Derive `SHA256SUMS.txt` from and require exact agreement with every artifact/proof entry; neither file self-hashes;
8. after staging moves to its final directory, fully revalidate scratch/build-description/generated/effect evidence, fresh/unsigned binary equality, build provenance, both bundle manifests, archive/mount signature/ticket proofs, strict JSON, checksums, paths, and digests. Independently hash `verified-artifacts.json` and `SHA256SUMS.txt`; rerun the worktree guard and require current full HEAD equals captured start HEAD before exposing any exact path+digest output.

Both bundle-manifest JSON files have exact top-level keys `schemaVersion` and `entries`, with `schemaVersion` fixed to the JSON integer `1`. Entries are unique and byte-sorted by a valid UTF-8 artifact-relative `relativePath`, with exact `type` and normalized four-digit `mode`; directories have no size/hash, while regular files have byte `size` and lowercase SHA-256. Reject any other schema value or JSON type, absolute/`..` paths, duplicate paths or JSON keys, unknown fields/types, invalid UTF-8, symlinks, and every unhandled file type. Directory filesystem size is never recorded.

Never compare an extracted signed app to the unsigned pre-sign manifest; codesign legitimately changes the bundle. The final-app JSON manifest is the extraction/mount comparison authority.

The DMG's top-level `/Applications` convenience symlink is outside the app bundle and must not be confused with forbidden symlinks under `MindDesk.app/Contents`.

- [ ] **Step 4: GREEN CI and release workflows**

CI and release both capture full HEAD, run the sole-primary/versioned package-manifest-only gate before their first SwiftPM command, and fail if any SwiftPM command can precede it. Their direct Release build and verifier share one private scratch/build description/evidence directory; they record its binary hash and recheck clean tree/full HEAD afterward. CI then runs separate Debug/Release suites, script self-tests, ad-hoc package smoke through a second private fresh-scratch/evidence build, extracted-artifact signature/policy verification, and release guards. Release performs the same direct evidence and separate fresh-scratch/evidence formal package before credentials/signing. Task 18's direct and packaged binaries are separate fresh builds from the same captured full HEAD, each with independent hash/build evidence, and neither may come from default `.build`.

The sole workflow proof step has `id: verified_release_artifacts` and emits exact path+SHA-256 pairs for ZIP, DMG, build provenance, normalized build plan, source-policy evidence, pre-sign manifest, final-app manifest, verified-artifacts JSON, and checksums. Use unambiguous output names such as `zip_path`/`zip_sha256` through `checksums_path`/`checksums_sha256`; no path output lacks its own digest. `actions/upload-artifact` and draft `gh release` consume only those outputs—never `dist/**` globs—and immediately recheck every digest before use. “Two artifacts” means payload entries; all proof files are also uploaded. Remove `gh release upload --clobber`; an existing same-name asset fails for explicit operator handling rather than replacing verified bytes.

- [ ] **Step 5: Verify all mock/script harnesses before commit**

```bash
bash -n script/package_release.sh
bash -n script/verify_release_artifacts.sh
bash -n script/test_release_artifact_verifier.sh
bash -n script/test_release_package_failure_diagnostics.sh
bash -n script/test_release_workflow_guards.sh
bash -n script/verify_release_worktree.sh
bash -n script/test_release_worktree_guard.sh
bash script/test_verify_s0_private_canvas.sh
bash script/test_release_artifact_verifier.sh
bash script/test_release_package_failure_diagnostics.sh
bash script/test_release_workflow_guards.sh
bash script/test_release_worktree_guard.sh
git diff --check
```

- [ ] **Step 6: Commit the release implementation before invoking the clean-worktree packager**

The existing packager always enforces a clean-worktree guard. Do not weaken or bypass it. Stage only these files and commit before the real smoke:

```bash
git add -- script/package_release.sh script/verify_release_artifacts.sh script/test_release_artifact_verifier.sh script/test_release_package_failure_diagnostics.sh script/test_release_workflow_guards.sh script/verify_release_worktree.sh script/test_release_worktree_guard.sh .github/workflows/ci.yml .github/workflows/release.yml docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "build: verify every private canvas release artifact"
```

- [ ] **Step 7: Run the real ad-hoc smoke from the clean commit with a unique suffix**

```bash
bash script/verify_release_worktree.sh
test -z "$(git status --short)"
S0_G8_HEAD="$(git rev-parse HEAD)"
S0_G8_SHA="$(git rev-parse --short HEAD)"
S0_G8_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
S0_G8_SUFFIX="macOS-s0-g8c-${S0_G8_SHA}-${S0_G8_RUN_ID}"
RELEASE_PLATFORM_SUFFIX="$S0_G8_SUFFIX" bash script/package_release.sh --mode adhoc --allow-adhoc
S0_VERSION="$(tr -d '[:space:]' < VERSION)"
bash script/verify_release_artifacts.sh --artifact-dir "dist/release/MindDesk-v${S0_VERSION}-${S0_G8_SUFFIX}-adhoc/artifacts" --source-head "$S0_G8_HEAD" --version "$S0_VERSION" --suffix "$S0_G8_SUFFIX" --mode adhoc
test "$S0_G8_HEAD" = "$(git rev-parse HEAD)"
```

Record the captured full source HEAD, strict build-description/normalized-plan/source-policy hashes, fresh scratch and unsigned bundled-binary equality, all proof-file path/digest pairs, and actual verified ZIP/DMG paths/digests in the ledger with `apply_patch`, then commit only that evidence. Do not claim formal notarized evidence locally without valid credentials; the workflow must fail closed when they are absent.

```bash
git add -- docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "test: record s0 package smoke evidence"
```

---

### Task 18: Gate 8D — Clean-Room Final Verification and Ledger Reconciliation

**Files:**

- Modify: `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md`

- [ ] **Step 1: Complete a four-seat release-stop review before collecting final evidence**

Dispatch three distinct 5.6-sol xhigh reviewers in parallel:

1. specification, product scope, and migration-ledger arithmetic;
2. TDD, code quality, actor isolation, SwiftData context ownership, cancellation, and continuation lifetime;
3. privacy/security, shell traversal, bundle identity, signing/notarization order, and workflow path/digest identity.

After receiving all three written conclusions, dispatch a fourth distinct 5.6-sol xhigh jury with the complete findings and proposed dispositions. Resolve every Critical and Major finding. Explicitly accept, defer with a bounded reason, or resolve every Minor finding. Any reviewer-marked release-stop concern blocks evidence collection until the fourth jury returns GO.

Each corrective slice follows RED/GREEN where behavior changes, uses exact-path staging, commits before re-review, and triggers another complete four-seat review round. Start Step 2 only from a clean worktree after all four seats return GO in the same round.

- [ ] **Step 2: Run fresh full suites, builds, final policy, release guards, and package in one shell invocation**

```bash
set -euo pipefail
test -z "$(git status --short)"
S0_FINAL_HEAD="$(git rev-parse HEAD)"
S0_FINAL_DEBUG=
S0_FINAL_RELEASE=
S0_FINAL_BUILD=
S0_FINAL_EVIDENCE=
s0_cleanup_final() {
  for path in "$S0_FINAL_DEBUG" "$S0_FINAL_RELEASE" "$S0_FINAL_BUILD" "$S0_FINAL_EVIDENCE"; do
    [ -z "$path" ] && continue
    case "$path" in
      /tmp/minddesk-s0-final-debug.??????|/tmp/minddesk-s0-final-release.??????|/tmp/minddesk-s0-final-build.??????|/tmp/minddesk-s0-final-evidence.??????) ;;
      *) return 1 ;;
    esac
    if [ -e "$path" ] || [ -L "$path" ]; then
      [ -d "$path" ] && [ ! -L "$path" ] || return 1
      rm -rf -- "$path"
    fi
  done
}
trap s0_cleanup_final EXIT
S0_FINAL_DEBUG="$(mktemp -d /tmp/minddesk-s0-final-debug.XXXXXX)"
S0_FINAL_RELEASE="$(mktemp -d /tmp/minddesk-s0-final-release.XXXXXX)"
S0_FINAL_BUILD="$(mktemp -d /tmp/minddesk-s0-final-build.XXXXXX)"
S0_FINAL_EVIDENCE="$(mktemp -d /tmp/minddesk-s0-final-evidence.XXXXXX)"
bash script/verify_s0_private_canvas.sh --repo-root "$PWD" --package-manifest-only
swift test --scratch-path "$S0_FINAL_DEBUG"
swift test -c release --scratch-path "$S0_FINAL_RELEASE"
swift build -c release --scratch-path "$S0_FINAL_BUILD"
S0_FINAL_BIN_DIR="$(swift build -c release --scratch-path "$S0_FINAL_BUILD" --show-bin-path)"
S0_FINAL_BUILD_DESC="$(find -P "$S0_FINAL_BUILD" -type f -path '*/release/description.json' -print -quit)"
test -n "$S0_FINAL_BUILD_DESC"
S0_FINAL_BINARY_SHA256="$(shasum -a 256 "$S0_FINAL_BIN_DIR/MindDesk" | awk '{print $1}')"
bash script/verify_s0_private_canvas.sh --repo-root "$PWD" --scratch-path "$S0_FINAL_BUILD" --configuration release --build-description "$S0_FINAL_BUILD_DESC" --evidence-dir "$S0_FINAL_EVIDENCE" --binary "$S0_FINAL_BIN_DIR/MindDesk"
test "$S0_FINAL_HEAD" = "$(git rev-parse HEAD)"
# The final-policy and package phase remains in this same fail-fast shell.
bash -n script/s0_private_canvas_policy.sh
bash -n script/verify_s0_private_canvas.sh
bash -n script/test_verify_s0_private_canvas.sh
bash -n script/verify_release_worktree.sh
bash script/test_verify_s0_private_canvas.sh
bash script/test_release_worktree_guard.sh
bash script/verify_s0_private_canvas.sh --repo-root "$PWD" --scratch-path "$S0_FINAL_BUILD" --configuration release --build-description "$S0_FINAL_BUILD_DESC" --evidence-dir "$S0_FINAL_EVIDENCE" --binary "$S0_FINAL_BIN_DIR/MindDesk"
test "$S0_FINAL_BINARY_SHA256" = "$(shasum -a 256 "$S0_FINAL_BIN_DIR/MindDesk" | awk '{print $1}')"
test "$S0_FINAL_HEAD" = "$(git rev-parse HEAD)"
bash script/test_release_workflow_guards.sh
git diff --check
bash script/verify_release_worktree.sh
test -z "$(git status --short)"
test "$S0_FINAL_HEAD" = "$(git rev-parse HEAD)"
S0_FINAL_SHA="$(git rev-parse --short "$S0_FINAL_HEAD")"
S0_FINAL_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
S0_FINAL_SUFFIX="macOS-s0-g8d-${S0_FINAL_SHA}-${S0_FINAL_RUN_ID}"
RELEASE_PLATFORM_SUFFIX="$S0_FINAL_SUFFIX" bash script/package_release.sh --mode adhoc --allow-adhoc
S0_FINAL_VERSION="$(tr -d '[:space:]' < VERSION)"
S0_FINAL_ARTIFACT_DIR="dist/release/MindDesk-v${S0_FINAL_VERSION}-${S0_FINAL_SUFFIX}-adhoc/artifacts"
bash script/verify_release_artifacts.sh --artifact-dir "$S0_FINAL_ARTIFACT_DIR" --source-head "$S0_FINAL_HEAD" --version "$S0_FINAL_VERSION" --suffix "$S0_FINAL_SUFFIX" --mode adhoc
test "$S0_FINAL_BINARY_SHA256" = "$(shasum -a 256 "$S0_FINAL_BIN_DIR/MindDesk" | awk '{print $1}')"
test "$S0_FINAL_HEAD" = "$(git rev-parse HEAD)"
printf '%s  %s\n' "$S0_FINAL_BINARY_SHA256" "$S0_FINAL_BIN_DIR/MindDesk"
shasum -a 256 "$S0_FINAL_BUILD_DESC" "$S0_FINAL_EVIDENCE/normalized-build-plan.json" "$S0_FINAL_EVIDENCE/source-policy-evidence.json"
s0_cleanup_final
trap - EXIT
```

The package command must exercise its strengthened clean-worktree/full-HEAD and sole-primary/versioned-manifest guards, create its own unique private Release scratch plus evidence directory, and bind its exact build description, generated/macro/effect evidence, fresh build hash, unsigned bundle, and pre-sign manifest without reading default `.build`. This packaged build is separate from `S0_FINAL_BUILD`, but both are fresh builds from `S0_FINAL_HEAD` and carry independent binary/build evidence. Before deleting temporary payloads, `package_release.sh` runs the full same-scratch/build-description/evidence verifier on the finalized bundle, freshly extracted ZIP app, and read-only mounted DMG app; both artifact apps compare to `final-app.bundle.manifest.json` and separately pass mode-specific inner-app codesign/ticket/Gatekeeper checks. `verify_release_artifacts.sh` validates source HEAD, all proof paths/digests, exact two payloads, verified JSON and checksums—not merely payload checksums. Record the direct binary digest plus every final proof/payload path and independently recomputed digest. The run-ID suffix is unique and intentionally differs from Task 17.

- [ ] **Step 3: Reconcile the ledger arithmetically**

Record observed final Debug and Release test counts. Both configuration-specific equations must balance exactly, failures must be zero, and required/unledgered skips must be zero. Include complete command evidence and limitations.

- [ ] **Step 4: Freeze evidence validity**

After Step 2 begins, any change to production code, tests, scripts, package/workflow configuration, fixtures, or product documentation invalidates the clean-room run and restarts this task at Step 1. Only appending observed evidence to the migration ledger is permitted after successful collection. If the ledger edit reveals an arithmetic or evidence defect, do not patch around it: restart at Step 1 after correcting the underlying issue.

- [ ] **Step 5: Commit only final evidence**

```bash
git add -- docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md
git commit -m "test: record s0 final verification evidence"
```

S0 is not complete merely because tests compile. Completion requires every approved verification gate, ordinary regression family, source/binary/bundle/artifact canary, and ledger equation above.

---

## Review and Execution Handoff

After this plan receives four-seat approval, execute it in the current session with `superpowers:subagent-driven-development`:

- one fresh 5.6-sol xhigh implementer per task;
- after implementation, three distinct 5.6-sol xhigh reviewers run in parallel: specification/TDD, concurrency/data ownership, and privacy/security/product regression;
- after all three written conclusions arrive, a fourth distinct 5.6-sol xhigh jury reviews the implementation, all findings, dispositions, and fresh command evidence;
- root agent independently runs the required commands, inspects the exact diff, and accepts the task only after the fourth jury returns GO.

No material product, architecture, safety, migration, or release judgment is accepted with fewer than four subagent conclusions. A finding-driven code change invalidates the previous conclusions and requires a new four-seat review round. Clerical command execution does not become evidence until root independently verifies its output.

For Task 18, the fourth-seat GO precedes clean-room evidence and reviews the committed implementation plus pre-final focused evidence. Clean-room evidence is collected only afterward; any invalidating change restarts Task 18 at its four-seat review.

Do not parallel-edit overlapping files. Gate 1 classifier/import work, Gate 2 deletion, Gate 3 wire normalization, Gate 5 controller, Gate 6 provisioning, Gate 7 node requests, and Gate 8 release wiring are sequential dependency boundaries. Parallel agents may perform read-only review, test inventory, or independent threat analysis while one writer owns the active slice.
