# MindDesk S0 Capability Lockdown and Scope Identity Design

**Status:** Approved for implementation after four-seat amendment review.

**Parent design:** `2026-07-29-private-canvas-first-canonical-v3-design.md`

**Implementation stage:** S0 only

## Goal

Make the current v1a build a manual Canvas product with Canvas Review off by removing every Agent/Codex/Proposal Review entry and runtime, installing a permanently closed Canvas Review lock for legacy-document rejection, detecting ambiguous Primary Canvases without choosing one, and binding window work to immutable in-memory focus and Canvas scope identities.

S0 is containment and identity infrastructure. It does not implement the durable Workspace Context Firewall data pipeline, Context Rail redesign, Review, schema migration, or duplicate-data repair.

## Evidence Behind S0

The code review found four independent bypass classes:

1. `WorkspaceCanvasView` builds and directly encodes an Agent source package from `allResources`, bypassing the dedicated Agent export method.
2. `CodexTerminalService.prepare` creates a session directory and writes prompt, package, template, helper, and shell files before any capability check.
3. Production starts `/bin/zsh -i` through SwiftTerm while a second `openpty + Process.run` path remains separately callable.
4. Proposal approval can create a `copyPath` plan and write to the system clipboard.

The Primary Canvas lookup also uses `fetchLimit = 1` and downstream `.first` selection. It cannot distinguish one Canvas from two or more. Window-local state has no explicit window identity or focus revision, so a late result can be accepted after the user changes workspace.

These are current implementation facts, not future threat speculation.

## S0 Product Contract

In v1a:

- Canvas, Brief/Overview, Tasks, resources, snippets, ordinary Manifest import/export, direct-user clipboard operations, and confirmed command snippets remain usable.
- Agent Review, Canvas Codex, Proposal Review, handoff prompts, embedded Agent terminal, proposal actions, and Review clipboard bridges do not exist as user capabilities.
- No disabled Codex button, placeholder rail, onboarding hint, Help topic, restored state, menu, deep link, or release headline advertises an unavailable feature.
- A legacy MIP, proposal envelope, or standalone Review validation report submitted to ordinary Manifest import is identified by bounded top-level classification and rejected with neutral copy. It is not fully decoded, reviewed, quarantined, or redirected to another command.
- Primary Canvas ambiguity is shown as a non-destructive unavailable state. MindDesk does not select, merge, rename, or delete one of the records.
- A window accepts a scope-bound asynchronous result only when window, workspace, Canvas, and focus revision all still match.

## In Scope

1. Physical removal of Agent/Codex/Proposal UI, session, PTY/process, prompt, search, review-state, and action runtime.
2. Removal of the SwiftTerm dependency and its resolved transitive dependencies.
3. A stateless, permanently closed Canvas Review capability lock.
4. Pure historical wire compatibility limited to stored Codable values, existing Proposal-envelope limits, deterministic validation, sanitized diagnostics, and bounded top-level format classification.
5. Neutral rejection of legacy Review documents through ordinary Manifest import.
6. A minimum `missing | unique | duplicate` Primary Canvas resolver.
7. Per-window in-memory scope identity, focus revision, cancellation registration, and stale-result rejection.
8. Scope-bound Canvas node-open requests.
9. Current documentation and Release-binary canaries.
10. Regression evidence for ordinary Manifest, clipboard, Terminal snippets, Inspector, Help/search, Overview, and core Canvas interaction.

## Out of Scope

- WCF scoped fetch, direct backing-object closure, field projection, Context Preview, digest, or package encoder.
- A live Review provider, helper, process, shell, or network path.
- Proposal approval, rejection, Apply, write-back, action planning, or clipboard support.
- Schema or `@Model` changes.
- Persisted `primaryCanvasID`, focus revision, window state, or Review state.
- Automatic duplicate Canvas repair, merge, deletion, or migration.
- Overview-to-Context-Rail migration.
- Final multi-window chooser, Back stack, overlay, focus, VoiceOver, or viewport redesign.
- Performance targets not derived from a Release-store baseline.
- Removal of ordinary Manifest, clipboard, Finder, or user-confirmed command-snippet capabilities.

## Architecture

### 1. Permanent S0 Capability Lock

Create `Sources/MindDeskCore/CanvasReviewCapabilityLock.swift`:

```swift
import Foundation

public enum CanvasReviewCapabilityError: Error, Equatable, Sendable, LocalizedError {
    case unavailable

    public var errorDescription: String? {
        "Canvas Review is unavailable in this version of MindDesk."
    }
}

public enum CanvasReviewCapabilityLock {
    public static func requireEnabled() throws -> Never {
        throw CanvasReviewCapabilityError.unavailable
    }
}
```

The lock has no protocol, gateway, operation closure, enabled case or state, injected policy, counter, UserDefaults key, environment override, build flag, remote flag, test permit, or future-live implementation. S0 can never open it. A future v1b specification creates a new WCF-backed capability contract rather than changing this lock.

All package/proposal/session/action runtime and convenience APIs are deleted. The only retained product call is private `rejectLegacyReviewDocument() throws -> Never`, whose first and only expression is `try CanvasReviewCapabilityLock.requireEnabled()`. The Manifest layer catches `.unavailable` and maps it to this neutral import copy; the lock itself never owns import-specific language:

> This JSON document is not supported by this version of MindDesk and cannot be imported as a manifest.

### 2. Legacy Review Document Rejection

`MindDeskJSONDocumentKind` remains a bounded top-level classifier. Its three historical Review format literals are file-private constants in that file so classification does not depend on deleted runtime factories.

`ImportExportService.decodeManifest` uses this single order:

```text
file metadata/read cap (when URL-backed)
→ direct Data.count cap
→ bounded top-level document classification
→ in-limit legacy Review kind: closed lock, then neutral import error mapping
→ ordinary Manifest decode and validation
```

The only file and direct-`Data` limit is `64 * 1024 * 1024` bytes. The URL-backed path checks metadata and applies a capped read. `decodeManifest(from: Data)` repeats the direct `Data.count` guard and cannot rely on its caller. Oversize input returns this generic static error before classification, full decoding, or lock invocation:

> This JSON file is larger than the 64 MiB import limit.

For an in-limit recognized legacy Review format, bounded token scanning examines JSON syntax only to extract top-level `format` and legacy `schemaVersion` markers; it is not a prefix heuristic and never constructs a historical DTO. The branch then calls the closed lock and maps its error to neutral Manifest-import copy.

The classifier contract is closed:

| Top-level input after size guard | Classification and import behavior |
| --- | --- |
| Exactly one string `format: "minddesk.export.manifest"` | Typed Manifest decode and ordinary validation |
| Exactly one string `format: "minddesk.interchange.package"` | Legacy Review kind → permanent lock → neutral unsupported-document copy |
| Exactly one string `format: "minddesk.proposal.envelope"` | Legacy Review kind → permanent lock → neutral unsupported-document copy |
| Exactly one string `format: "minddesk.validation.report"` | Legacy Review kind → permanent lock → neutral unsupported-document copy |
| Exactly one unknown string `format` | Existing formatted non-Manifest rejection; no lock and no historical DTO decode |
| Duplicate top-level `format`, non-string `format`, or conflicting format values | Ambiguous formatted non-Manifest rejection; no lock and no historical DTO decode, even if one value is recognized |
| No top-level `format` and exactly one integer `schemaVersion` | Legacy ordinary Manifest decode and validation |
| No top-level `format`, with missing/non-integer/duplicate `schemaVersion` | Existing unknown/invalid JSON rejection; no lock |
| A recognized literal only below the top level | Ignored as a format marker; classify from actual top-level markers |
| Invalid JSON, depth/token-limit failure, or trailing content | Unknown/invalid JSON rejection; no lock |

When an exact recognized Review `format` is present, unrelated fields—including `schemaVersion`—do not expand scope or trigger full decoding. Tests cover all rows, three forged recognized markers, an unknown formatted marker, duplicate keys, and nested pseudo-markers. The closed branch does not:

- Decode the full MIP, proposal, or validation report.
- Build a validation report for Review.
- Open a second file panel.
- Create a pending state or sheet.
- Write data, a temporary file, or the clipboard.
- Suggest a removed menu command.

Ordinary typed and legacy Manifest behavior within the cap remains unchanged. Oversize input intentionally receives the generic size error rather than the in-limit legacy-document error.

### 3. Physical Runtime Removal

Delete these app runtime files:

- `Sources/MindDesk/Canvas/CanvasCodexAgentSidebar.swift`
- `Sources/MindDesk/Canvas/CanvasCodexSessionController.swift`
- `Sources/MindDesk/Canvas/CanvasCodexTerminalView.swift`
- `Sources/MindDesk/Services/CodexTerminalService.swift`
- `Sources/MindDesk/Views/ProposalReviewSheet.swift`

Delete these Core workflow/runtime files after moving any non-Agent policy noted below:

- `Sources/MindDeskCore/CanvasCodexPrompt.swift`
- `Sources/MindDeskCore/MindDeskAgentHandoffPrompt.swift`
- `Sources/MindDeskCore/MindDeskAgentReviewCustomGuidancePresentation.swift`
- `Sources/MindDeskCore/MindDeskAgentReviewPackageReadiness.swift`
- `Sources/MindDeskCore/MindDeskAgentWorkflowSearch.swift`
- `Sources/MindDeskCore/MindDeskProposalCopyPathPlanner.swift`
- `Sources/MindDeskCore/MindDeskProposalEnvelopeExtractor.swift`
- `Sources/MindDeskCore/MindDeskProposalEnvelopeTemplate.swift`
- `Sources/MindDeskCore/MindDeskProposalReviewGate.swift`
- `Sources/MindDeskCore/MindDeskProposalSourcePackageRawValidation.swift`

Move the ordinary `CanvasEdgeAnimationInteractionPolicy` currently located at the end of `CanvasCodexPrompt.swift` into `Sources/MindDeskCore/CanvasEdgeAnimationInteractionPolicy.swift` before deleting the original file.

Remove SwiftTerm from `Package.swift`. Run SwiftPM resolution after the dependency is gone; with no external package dependencies, delete the tracked `Package.resolved` rather than manually editing pins. This removes the transitive `swift-argument-parser` resolution as well.

### 4. Pure Wire Compatibility Boundary

The compatibility symbols remain linked through `MindDeskCore`. They are stored DTO/validator code with no production caller from `Sources/MindDesk` beyond bounded legacy-document classification; they are not an unlinked or unreachable target. Release canaries therefore allow wire DTO symbols and the three historical Review format literals while forbidding runtime builders, gates, sessions, actions, and UI.

`MindDeskInterchangePackage` becomes a stored-value historical record. Its decoder reads and its encoder writes these exact Codable fields without reconstructing, defaulting, normalizing, or deriving them:

1. `format`
2. `formatVersion`
3. `packageInstanceID`
4. `createdAt`
5. `summary`
6. `privacy`
7. `agentGuide`
8. `agentPolicy`
9. `agentIntegrationContract`
10. `extensionCapabilities`
11. `externalActionPolicy`
12. `helpTopics`
13. `validationIssues`
14. `validationReport`
15. `manifest`

An explicit all-field value initializer is allowed. Live-`Manifest` convenience initializers and package factories are forbidden. Computed `.current` capabilities, computed validation reports, manifest-derived summary/privacy, replacement default guide/policy/help values, and current contract/catalog construction are deleted.

#### Keep and Narrow

- `MindDeskInterchangePackage.swift`: keep the stored fields above, strict Codable structure, and pure-value validation only.
- `MindDeskProposalEnvelope.swift`: keep historical Codable DTOs, the existing collection/reference/text/payload decode limits, pure validation, freshness comparison, and sanitized diagnostics. Remove review session state, approval/rejection transitions, Apply/action policy, and execution semantics.
- `LegacyReviewWireTypes.swift`: retain only the raw-value Codable `MindDeskProposalReviewState` and `MindDeskProposalReviewEvent` enums referenced by the historical integration-contract wire. No transition, approval, rejection, or authorization policy remains.
- `MindDeskAgentIntegrationContract.swift`: keep stored historical DTOs/enums and strict structure validation. Delete `.current`, package/live factories, default prompts, and live-model digest builders.
- `MindDeskExtensionCapabilityCatalog.swift`: keep stored DTOs/enums and pure validation. Delete `.current`, runtime search, policy-derived builders, and default catalogs.
- `MindDeskValidationReport.swift`: keep stored report DTOs, ordinary Manifest validation, redaction, and existing pure validators. Delete current-authority-graph builders. If ordinary Manifest validation and historical Interchange reporting are coupled, split them without changing ordinary Manifest semantics.
- `MindDeskHelpCatalog.swift`: keep ordinary Help/search and ordinary Settings/Canvas/Data topics. Remove all four Agent default topics and `agentReviewPackageTopics`; a historical `.agent` raw value may exist only for wire decode. Historical MIP `helpTopics` are stored and re-encoded, never rebuilt from defaults.
- `MindDeskJSONDocumentKind.swift`: keep only bounded top-level classification and file-private historical literals.
- `WorkbenchReferences.swift`: keep ordinary references and direct-user safety policy; remove Agent authorization helpers.
- `WorkbenchOrdering.swift`: keep ordinary layout/command/Canvas policy; remove Codex-only rail metrics.

S0 does not invent a universal bounded-decoder contract. Its decode boundary is the 64 MiB file/direct-`Data` guard plus the Proposal envelope's already existing collection/reference/text/payload limits. Other historical DTOs promise strict Codable and existing pure validation only. A future runtime MIP decoder must be threat-modeled in S3.

`MindDeskProposalSourcePackageRawValidation.swift` is deleted. If an existing pure helper is required solely to preserve a Proposal-envelope decode limit, move that helper to `MindDeskProposalEnvelopeValidation.swift` first; no source-package authority policy moves with it.

`WorkbenchObjectReferenceIndex` and every Proposal validation overload accepting a live `MindDeskInterchangePackage`/`Manifest` are deleted; stored Proposal wire validation does not resolve live package ownership in S0. Move the manifest-only `issues(in: ExportManifest)` and manifest-message mapping needed by `MindDeskManifestValidationReport` into that ordinary validator, then delete `MindDeskInterchangePackageValidationReport`, `MindDeskProposalValidationReport`, `MindDeskExtensionCapabilityCatalogValidationReport`, and `MindDeskAgentIntegrationContractValidationReport` rather than retaining package-coupled authority builders.

#### Delete, Not Preserve for v1b

`MindDeskProposalReviewGate`, raw source-package authority policy, workflow search, prompt/template builders, review transitions, action planner, and clipboard bridge are not a future foundation. v1b must be designed from Context Preview and WCF evidence.

Pure stored-wire DTOs may use `JSONDecoder` and `JSONEncoder` in compatibility tests. That is historical round-trip evidence, not a product package builder or runtime Review path.

### 5. App Surface Removal

#### `MindDeskApp.swift`

Remove:

- Export Agent Review Package menu descriptor and button.
- Review Agent Proposal menu button.
- Focused command members for those actions.

Keep ordinary Manifest Import and Export unchanged.

#### `ContentView.swift`

Remove:

- Agent/Proposal focused-command handlers.
- Agent custom-guidance AppStorage.
- Proposal sheet, handoff, banner, confirmation, and copy-path state.
- Agent package export and proposal import functions.
- Inline proposal review and transcript routes.
- Handoff prompt/template clipboard actions.
- Proposal action planning and clipboard confirmation.
- Local Agent/Proposal presentation helper types.

Keep ordinary JSON import/export, ordinary file reading, resource/snippet clipboard actions, Finder actions, and confirmed command snippets.

#### `WorkspaceCanvasView.swift`

Remove:

- Codex AppStorage keys and prompt/template state.
- `CanvasRightRailPanel.codexAgent`.
- Codex toolbar and rail controls.
- Session controller and Agent sidebar.
- All prompt/package/template/computed JSON encoding.
- Run, revise, preview, discard, Review, and terminal-input paths.
- `onReviewAgentProposal` and related view plumbing.

Keep Inspector/right-rail behavior and `allResources` where it serves ordinary Canvas resource menus or rendering. Remove it only from the deleted Agent package path.

#### Settings, Preferences, Help, and Services

- Remove Agent Review settings, custom guidance, Canvas Codex templates, active AppStorage consumers, and reset rows.
- Preserve old key literals only in `obsoleteKeys` so Reset can clear them without restoring them.
- Rewrite reset/help safety copy to describe direct-user confirmation without Proposal Review claims.
- Remove Agent topics from default Help while preserving ordinary Help/search.
- Remove Proposal/MIP-specific file helpers, dialogs, status strings, and encode/decode workflow methods from `SystemServices`.
- Keep `ManifestImportService`, its 64 MiB import guard, generic bounded file reader, ordinary file dialog/status behavior, `ValidationDisplayTextSanitizer`, ordinary Manifest validation, and ordinary file/clipboard/Terminal services.

### 6. Minimum Primary Canvas Resolution

Create `Sources/MindDeskCore/WorkspacePrimaryCanvasResolver.swift`:

```swift
public enum WorkspacePrimaryCanvasResolution: Equatable, Sendable {
    case missing
    case unique(canvasID: String)
    case duplicate(canvasIDs: [String])
}

public enum WorkspacePrimaryCanvasResolver {
    public static func resolve(canvasIDs: [String]) -> WorkspacePrimaryCanvasResolution
}
```

The resolver preserves cardinality and sorts IDs only for deterministic output. Empty input is `missing`, one nonblank ID is `unique`, and two or more records are `duplicate`. Blank or repeated IDs are collisions and fail closed as `duplicate`; the resolver never deduplicates them into `unique`.

`Sources/MindDesk/Models/WorkspaceCanvasLookup.swift` remains the SwiftData boundary:

- Predicate by exact `workspaceId`.
- Stable sort by Canvas ID.
- `fetchLimit = 2`, sufficient to distinguish zero, one, and more than one.
- Map fetched IDs through the pure resolver.

Delete both truth-bypassing fallbacks: the `canvases.first` selection after a request override and `createdCanvasByWorkspaceId`, including that cache's state. The scene root fingerprints a cardinality-preserving serialization of the active workspace's stable-sorted raw Canvas IDs: record count and length-prefixed IDs are included, and blank or repeated IDs are retained rather than deduplicated into a set. It reruns lookup and resolution whenever that fingerprint changes, not only when workspace or tab selection changes.

Every scoped Primary Canvas fetch that may authorize provisioning mutation or pass a resolution to `bind` is represented by one root-owned attempt:

```swift
import Foundation

enum WorkspacePrimaryCanvasResolutionPhase: Equatable, Sendable {
    case initialLookup
    case preInsertRecheck
    case postSaveRecheck
}

struct WorkspacePrimaryCanvasResolutionAttempt: Equatable, Sendable {
    let requestID: UUID
    let focus: WorkspaceFocusScopeIdentity
    let fingerprint: String
    let phase: WorkspacePrimaryCanvasResolutionPhase
}

@MainActor
struct WorkspacePrimaryCanvasResolutionSlot {
    var attempt: WorkspacePrimaryCanvasResolutionAttempt
    let operationID: UUID
    let task: Task<Void, Never>
    var cancellationObserved: Bool
}
```

The scene-root controller stores at most one slot; the attempt, cancellation registration, and Task therefore have one owner. Every fetch phase gets a fresh `requestID`; `A → B → A` has three IDs even when the first and third serialized fingerprints match.

Slot transitions are atomic on the MainActor:

1. To launch work, register cancellation for the exact focus, create its Task handle, and install the matching attempt/operation/task slot before the Task can commit a result. If registration fails, cancel the Task and install no slot.
2. When a fingerprint changes, invalidate the exact focus to nil resolution/unbound. The detached callback sets `cancellationObserved`, cancels the old Task, and clears only a slot whose attempt and operation ID still match. Then launch the new initial-lookup slot under the returned focus.
3. A same-fingerprint explicit replacement first obtains a valid new registration/Task, atomically swaps in the new slot, then cancels the displaced Task and completes only its displaced operation ID. If new registration fails, install nothing and leave any existing/newer slot untouched.
4. Immediately before mutation or terminal result handling, completion must match the current slot's full attempt and operation ID, the current focus, and the currently observed fingerprint. A mismatch may complete only its own registration; it cannot mutate, bind, cancel, or clear the current slot.
5. Terminal success/result handling uses one no-suspension sequence: exact-match guard → matched `complete(operationID:for:)` → clear that exact slot → `bind`. Clearing precedes `bind`, so a focus rotation during binding cannot orphan the reporting attempt. If `complete` returns false, do not bind or clear any replacement slot.
6. `preInsertRecheck(.missing) → postSaveRecheck` is not ordinary replacement. The same slot keeps its operation ID, Task, and cancellation registration; after insert/save and exact focus/fingerprint checks, it atomically replaces only `attempt` with a fresh request ID and `.postSaveRecheck`, then starts the post-save fetch. It neither invokes its cancellation callback nor calls `complete` during this phase handoff.
7. If fingerprint/focus changes between save and phase handoff, do not install post-save phase or start its fetch. The normal invalidation callback terminates the old slot, and a new initial-lookup slot for the latest fingerprint performs reconciliation.
8. Terminal error/cancellation handling clears only the exact slot after its registration was detached or matched `complete` succeeded. Every exit leaves no finished operation registration or stale in-flight marker.

After the first resolution is established, every unequal resolution is a scope transition. This includes `unique(A) → missing`, `unique(A) → duplicate(...)`, `unique(A) → unique(B)`, `missing → unique(...)`, `missing → duplicate(...)`, `duplicate(...) → missing`, `duplicate(...) → unique(...)`, and `duplicate(X) → duplicate(Y)` when their deterministic ID arrays differ. Each transition synchronously cancels old work, clears the bound identity, and creates a new focus revision. Reapplying an exactly equal resolution to the same focus is idempotent. Only `unique` can bind or display Canvas content.

Duplicate state pauses Canvas only and uses exact non-destructive copy:

> MindDesk could not identify one safe Canvas for this workspace. Canvas editing is paused to protect your data. Tasks, resources, snippets, and Overview remain available. No Canvas was deleted.

#### Missing-Canvas Provisioning Contract

The initial lookup uses the slot contract above. After fetch it verifies the exact slot/token/fingerprint, then on the MainActor without suspension completes its registration, clears the exact slot, and passes the full result to `bind`; a completed lookup cannot be cancelled by the transition it reports.

If initial resolution returns `.unbound(..., .missing)`, provisioning uses the returned current focus identity—not its originally captured token—and registers a new provisioning operation. Before insert it performs a second scoped fetch:

- `unique` or `duplicate`: do not insert; exact match → `complete` → clear exact slot → `bind`, then stop.
- `missing`: check the exact focus token again immediately before mutation, then continue.

Insert and save use a dedicated provisioning `ModelContext` with no unrelated staged mutations and no suspension point between insert and save. A stale token stops before mutation. On save failure, discard this dedicated context; never call global `rollback()` on the shared scene context.

After either save success or save failure, use the same slot's explicit phase handoff and perform one fresh scoped fetch. For all three results, require the exact post-save slot/focus/fingerprint, then `complete` → clear exact slot → `bind`. Only `unique` displays Canvas. `missing` and `duplicate` remain unavailable; the operation does not recursively retry, create a third record, choose one, roll back or delete a record from another window. The slot is the sole in-flight marker. A cross-window creation race may end in fail-closed `duplicate`; S1 owns durable uniqueness and repair.

Cancellation and thrown-fetch exits are terminal for that exact attempt:

1. Its cancellation callback synchronously marks the operation cancelled and cancels its Task. Before every new fetch, mutation, or commit, the operation checks both cancellation and the exact current attempt/focus.
2. Once cancellation or staleness is known, it starts no later fetch. An already in-flight fetch may return, but its value is discarded.
3. Cancellation after a successful save never rolls back or deletes persisted data. Work stops; the current scene fingerprint or next focus lookup reconciles the record.
4. `CancellationError` and stale exits show no old-scope error and do not bind. The registration must already have been detached by transition or be removed by an explicit exact `complete`.
5. For any non-cancellation fetch error: if slot/focus/fingerprint is stale, stop silently after removing only its own live registration; if still exact, first complete the exact registration, clear that slot, do not call `bind`, preserve current resolution, discard any provisioning context, and do not retry automatically. The existing status/error surface shows a sanitized recoverable message. Provisioning never owns node-target state. After §8 is introduced, the scene-root node-open coordinator may terminally clear a target for this outcome only when the current four-field active target exactly equals the target captured for that node-open flow, including `requestID`.
6. Every exit path proves one of two states: transition already detached the registration, or matched `complete` removed it. No finished operation remains in the live cancellation registry.

Tests inject throws at initial, pre-insert, and post-save fetches, plus cancellation before the second fetch, immediately before insert/save, after successful save but before fresh fetch, and while fresh fetch is in flight.

While an accepted provisioning operation is active, Canvas shows the nonmodal status `Preparing Canvas…`; Tasks, resources, snippets, and Overview remain available. If the latest exact attempt ends at `missing` with no accepted provisioning operation active, Canvas shows this persistent recoverable state:

> **Canvas isn't available yet.** MindDesk could not make a Canvas available for this workspace. Tasks, resources, snippets, and Overview remain available.

It offers one `Try Again` action. `Try Again` starts a new scoped initial lookup with a fresh resolution-attempt ID and can provision only through this complete contract. It is disabled while an accepted attempt is active, never inserts directly, never loops automatically, and does not steal keyboard or VoiceOver focus. Terminal `duplicate` continues to use the duplicate-state copy.

### 7. Two-Stage Window Scope Identity

All scope types are app-only in `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`. They are `internal`, have `fileprivate` raw initializers, are not Codable, and never enter SwiftData, UserDefaults, SceneStorage, Manifest, or historical Review wire values.

```swift
import Combine
import Foundation
import MindDeskCore

struct WorkspaceFocusRevision: Hashable, Sendable {
    fileprivate let rawValue: UUID
}

struct WorkspaceFocusScopeIdentity: Hashable, Sendable {
    let windowSessionID: UUID
    let workspaceID: String
    let focusRevision: WorkspaceFocusRevision

    fileprivate init(
        windowSessionID: UUID,
        workspaceID: String,
        focusRevision: WorkspaceFocusRevision
    )
}

struct WorkspaceCanvasScopeIdentity: Hashable, Sendable {
    let focus: WorkspaceFocusScopeIdentity
    let canvasID: String

    fileprivate init(focus: WorkspaceFocusScopeIdentity, canvasID: String)
}

enum WorkspaceScopeOperationIdentity: Hashable, Sendable {
    case focus(WorkspaceFocusScopeIdentity)
    case canvas(WorkspaceCanvasScopeIdentity)
}

enum WorkspaceCanvasBindingResult: Equatable, Sendable {
    case stale
    case unbound(
        focus: WorkspaceFocusScopeIdentity,
        resolution: WorkspacePrimaryCanvasResolution
    )
    case bound(WorkspaceCanvasScopeIdentity)
}

@MainActor
final class WorkspaceWindowScopeController: ObservableObject {
    let windowSessionID: UUID
    @Published private(set) var pendingFocus: WorkspaceFocusScopeIdentity?
    @Published private(set) var boundCanvas: WorkspaceCanvasScopeIdentity?
    @Published private(set) var primaryResolution: WorkspacePrimaryCanvasResolution?

    init(windowSessionID: UUID = UUID())

    @discardableResult
    func focus(workspaceID: String) -> WorkspaceFocusScopeIdentity

    @discardableResult
    func bind(
        _ resolution: WorkspacePrimaryCanvasResolution,
        for focus: WorkspaceFocusScopeIdentity
    ) -> WorkspaceCanvasBindingResult

    func accepts(_ focus: WorkspaceFocusScopeIdentity) -> Bool
    func accepts(_ canvas: WorkspaceCanvasScopeIdentity) -> Bool

    @discardableResult
    func invalidatePrimaryResolution(
        for focus: WorkspaceFocusScopeIdentity
    ) -> WorkspaceFocusScopeIdentity?

    @discardableResult
    func registerCancellation(
        for scope: WorkspaceScopeOperationIdentity,
        cancel: @escaping @MainActor () -> Void
    ) -> UUID?

    func complete(
        operationID: UUID,
        for scope: WorkspaceScopeOperationIdentity
    ) -> Bool

    func clear()
}
```

`WorkspaceWindowScopeController` is the sole production identity authority; tests obtain identities through it with `@testable import MindDesk` and never construct raw values directly.

Its transition semantics are exhaustive:

1. `focus(workspaceID:)` for a new workspace detaches old registrations, creates a new revision, installs `primaryResolution = nil` and no bound Canvas, then synchronously runs detached callbacks. Repeating the current workspace returns its current pending token. A→B→A always creates a new A revision.
2. `bind(result, for: token)` with a noncurrent token returns `.stale` with zero state change.
3. When current `primaryResolution == nil`, `bind` installs the initial result under the same revision. It returns `.bound` only for `unique`; `missing` and `duplicate` return `.unbound`.
4. An exactly equal complete result is idempotent and returns the current binding result.
5. Any other result—including a changed duplicate ID array—atomically detaches the old registry, creates a new focus revision, installs that new result and its unique-only binding, and then synchronously runs detached callbacks. The return value contains the new identity; callers must stop using the captured token.
6. `invalidatePrimaryResolution(for:)` accepts only the exact current focus. It atomically detaches registrations, creates a new same-workspace focus revision, installs nil resolution/no binding, then invokes detached callbacks; stale input returns nil without mutation. The scene root uses the returned focus for the next fingerprint attempt.
7. A registered operation that produced a resolver result performs this MainActor sequence without suspension:

   ```swift
   guard resolutionSlotMatches(attempt, operationID: id) else { return }
   guard complete(operationID: id, for: .focus(token)) else { return }
   clearResolutionSlot(matching: attempt, operationID: id)
   let binding = bind(result, for: token)
   ```

   The slot-match/clear helpers are scene-root controller internals defined by §6; they are shown here to make the ordering explicit. A matched completion and slot are removed before transition and therefore receive no cancellation. An operation detached by a transition runs its callback and any later `complete` returns `false`.

The controller removes a detached registry from live state before installing the new state. Every callback still registered in that detached registry runs synchronously exactly once after installation; a callback already removed by a matching `complete` runs zero times, and reentrant code cannot access or rerun the detached registry. Registering against stale scope invokes the supplied cancellation once immediately and returns `nil`. `complete` matches both operation ID and exact scope before removal; a mismatch removes nothing. Late work that ignores cancellation still calls `accepts` immediately before insert/save or result commit. `clear` applies the same detach→install-empty→exactly-once-callback order.

Each `WindowGroup` scene root creates exactly one controller through a stable `@StateObject` owned by `ContentView` and passes that same object down. No `UUID()` or controller initialization occurs in `body`, `WorkspaceDetailView`, or a computed property. The root observes workspace selection plus the active workspace Canvas fingerprint and drives focus, resolution, provisioning, binding, and cancellation through this one controller.

### 8. Two-Stage Scope-Bound Node Open Requests

Create app-only `Sources/MindDesk/Models/WorkspaceCanvasNodeOpenRequest.swift`:

```swift
import Foundation

struct PendingWorkspaceCanvasNodeTarget: Equatable, Sendable {
    let requestID: UUID
    let workspaceID: String
    let canvasID: String
    let nodeID: String
}

struct WorkspaceCanvasNodeOpenRequest: Equatable, Sendable {
    let sequence: UInt64
    let scopeIdentity: WorkspaceCanvasScopeIdentity
    let nodeID: String

    fileprivate init(
        sequence: UInt64,
        scopeIdentity: WorkspaceCanvasScopeIdentity,
        nodeID: String
    )
}

enum WorkspaceCanvasNodeReadiness: Equatable, Sendable {
    case dataNotReady
    case definitelyAbsentOrCrossCanvas
    case readyOwned
}

enum WorkspaceCanvasNodeOpenRequestDecision: Equatable, Sendable {
    case accept
    case rejectAndConsume
    case `defer`
}
```

The §6 provisioning coordinator exposes scope-bound outcomes but never creates, inspects, issues, or clears node targets. The unique window controller instead owns one continuous active-intent flow through the entire pending and issued lifetime:

```text
idle
pending(exact four-field target, optional exact launch correlation)
issued(exact four-field target, exact bound request, exact ownership evidence)
```

A pending launch correlation is either `starting(launchID, exact focus, exact fingerprint)` or `accepted(operationID)`. The adapter never stores a parallel correlation: it invokes controller methods that atomically install, upgrade, hand off, or clear this one field. Before asking Gate 6 to register a launch, it installs a fresh `starting` nonce only if the target/focus/fingerprint are still exact. Success upgrades that exact nonce to the returned operation ID. A still-current registration failure clears only its exact nonce, retains the target, and presents a sanitized recoverable status with explicit retry; it is not fabricated as a `missing` terminal outcome. A synchronously stale failure changes no current flow or status.

Every Quick Open or deep target creates a new UUID-bearing target. Claiming a target atomically replaces the entire prior flow, including any deferred issued request and operation correlation. Revoking an older issued request does not advance `lastConsumedSequence`, change selection/viewport, or clear the new flow; a late callback for that request is only an unissued/replaced rejection. Lookup/provision completion may issue work only when the active flow is still the exact pending target across all four fields including `requestID`.

For cross-workspace Quick Open, the adapter first claims the target and then changes selection. It does not launch a parallel lookup: the one scene-observation reducer performs the focus/lookup exactly once. If the target already names the current workspace and selection/fingerprint observation does not change, one explicit fresh lookup is permitted. A later user selection of another workspace, Home, or nil terminates the exact active flow; a transition into the active target's own workspace preserves it.

The scene root focuses, resolves, provisions if appropriate, and binds before request issue. A cross-workspace claim waits for the selection observation before installing its starting nonce; a same-workspace claim with unchanged observation may install one nonce for its explicit fresh launch. Active-flow decisions are:

- `missing` while an accepted provisioning operation remains active: defer and keep the exact pending flow.
- `duplicate`, target Canvas mismatch, or a scoped ownership lookup returning `definitelyAbsentOrCrossCanvas`: terminal reject and clear only the matching flow.
- ownership `readyOwned` under the exact bound identity and exact node-observation fingerprint: transition `pending → issued`, retaining the complete target beside the request, storing `ready(full request, full scope, nodeObservationFingerprint)` evidence, and clearing only the no-longer-needed accepted-operation correlation. Repeated evaluation of the same issued flow/evidence is idempotent and allocates no second sequence.
- render `dataNotReady`: retain the complete issued flow unchanged; a missing render-dictionary entry or zero surface alone is never proof of absence.

The ownership decision comes from one fresh read-only context completed for the exact bound identity. `missing` without active provisioning is unavailable and terminal for that pending flow. The node observation uses a cardinality-preserving fingerprint of stable-sorted raw `(nodeID, canvasID)` pairs with count and length prefixes, retaining blanks and duplicates. On any changed node observation, the controller synchronously changes exact issued evidence to `dirty(full request, full scope, newFingerprint)` before starting the fresh lookup. While dirty, every render/surface callback can only defer; it can never reuse older `readyOwned` evidence. A fresh result commits only if target, request, scope, and fingerprint still match: confirmed absence consumes the exact flow, ready ownership installs `ready` for that generation and may continue to render readiness, and a fetch throw retains pending unchanged or retains issued dirty with sanitized recoverable status. A new target can never clear or be cleared by an older callback.

The request type and controller checked-factory extension live in the same file so the request initializer remains `fileprivate`. On each new bound scope, `nextSequence = 1`, `lastConsumedSequence = nil`, and no request is issued. A same-workspace internal rotation—including fingerprint/query reconciliation or allocator overflow—resets sequence/issued/consumed state but preserves the newest active intent: an unconsumed issued flow is demoted back to its exact pending target without advancing counters, and the one reducer or explicit overflow recovery starts one lookup and installs a new correlation only if that target is still current. If a newer claim already exists, rotation never resurrects the older target. A workspace/Home/nil switch away from the active target clears the flow.

The factory records the one current issued flow and uses `addingReportingOverflow(1)` before allocation. If a next value cannot be represented, it emits no request, demotes the still-current target to pending, and performs a controller transition to a new same-workspace revision with `primaryResolution = nil`, no binding, and normal exactly-once cancellation; a fresh lookup is required. It never leaves `primaryResolution == unique` with `boundCanvas == nil`. Overflow tests seed the internal pure allocator through `@testable import`, never by issuing `UInt64.max` requests.

Consumption checks in fixed order: full identity, exact current issued-flow request/sequence, then readiness.

- Full identity mismatch returns `.rejectAndConsume` and does not mutate the receiving scope's current flow or `lastConsumedSequence`.
- A sequence that was never issued, was revoked by a newer claim/rotation, or is already consumed returns `.rejectAndConsume` without advancing or clearing the current flow.
- Exact issued flow plus `.dataNotReady` returns `.defer` with zero state change only when its stored ready evidence matches the full current request/scope/node fingerprint; dirty, missing, or stale evidence also defers and can never accept.
- Exact issued flow plus `.definitelyAbsentOrCrossCanvas` updates `lastConsumedSequence`, atomically clears that exact request and originating target, and returns `.rejectAndConsume`.
- Exact issued flow plus `.readyOwned` updates `lastConsumedSequence`, atomically clears that exact request and originating target, and returns `.accept`.

The caller removes only the exact presented request that produced `.accept` or `.rejectAndConsume`; `.defer` retains it. S0 does not implement the final S2 window chooser, Back navigation, unobscured target placement, or accessibility focus transfer.

## Implementation Compile Gates

Implementation is planned and reviewed in this dependency order; each gate must compile and pass its focused tests before the next starts:

0. Before any implementation test or production edit, run the full Debug and Release suites once, require exactly `776 tests / 0 failures` in each, and create the migration ledger. This is the sole 776 baseline assertion.
1. Classifier, 64 MiB guards, neutral mapping, and permanent lock.
2. App/runtime removal plus SwiftTerm dependency removal.
3. Stored historical DTO normalization and wire fixtures.
4. Primary Canvas resolver and SwiftData lookup boundary.
5. Focus/bound scope controller and cancellation lifecycle.
6. Scene-root Primary Canvas resolution-attempt/slot lifecycle, fingerprint invalidation, binding, missing-Canvas provisioning, and Canvas availability states; this gate neither introduces nor clears pending node targets.
7. UUID-bearing pending-target creation and atomic replacement, exact provisioning-result correlation and terminal clearing, and scope-bound node-open request issuance and consumption.
8. Documentation, full regression, final closed-policy sink/codec inventory, Release verifier, and mandatory workflow wiring.

Within Gates 1–8 the order is mandatory: record the intended ledger change, add the focused red test and observe its intended failure, make the smallest production change, run the focused gate green, update the ledger with complete final test names, then compile before proceeding. After red tests are added, the current suite is not expected to equal the 776 baseline.

## Test Design

All behavior changes follow red-green-refactor. Negative behavior and surface tests are written and observed failing for the intended reason before production deletion or replacement.

### Checked-In Test Migration Ledger

Create `docs/superpowers/evidence/2026-07-29-s0-test-migration-ledger.md` during Gate 0. If either clean Debug or Release baseline is not exactly 776, stop implementation and explain the repository difference before adding a red test or changing any ledger assumption. Gate 0 is not rerun as a count requirement after tests change.

Every `retired`, `migrated`, or `added` test row records its file, complete test name, configuration availability, classification, evidence-based reason, and complete replacement/origin test name where applicable:

- `retired`: a baseline test removed with no one-to-one replacement; subtract one.
- `migrated`: a one-to-one replacement preserving one baseline obligation; count-neutral and not included in `added`.
- `added`: a net-new test that is not a one-to-one migration replacement; add one.
- A split or merge is recorded as its actual retired and added complete test names rather than being called count-neutral.

The final accounting is configuration-specific and must satisfy exactly:

```text
final_debug = 776 - retired_debug + added_debug
final_release = 776 - retired_release + added_release
```

Neither equation requires its final count to remain 776; each must equal its independently observed final suite count. Configuration availability on every row determines the corresponding retired/added column. Any Debug/Release difference is therefore arithmetically reconciled, not explained against one shared number. Skips are listed separately with reason and do not substitute for execution: any skipped focused, migration-replacement, ordinary-regression, verifier, or release-guard test is a release stop; any other unledgered skip is also a release stop.

### Historical Wire Fixtures

Add `.process("Fixtures")` to the `MindDeskCoreTests` target and check in literal, builder-independent fixtures:

- `Tests/MindDeskCoreTests/Fixtures/legacy-interchange-v1.json`
- `Tests/MindDeskCoreTests/Fixtures/legacy-proposal-envelope-v1.json`

Tests load them through `Bundle.module`. Oversize and malicious payloads are generated in test memory; no giant fixture is committed. Fixtures never call `.current`, default catalogs/prompts/help, live-model constructors, or production package builders.

`Tests/MindDeskCoreTests/LegacyReviewWireCompatibilityTests.swift` proves:

- MIP decode→encode preserves every listed stored wire field—the fourteen metadata/report fields plus `manifest`—without reconstruction. Semantic JSON comparison may normalize object-key order and documented date representation only; it may not drop or replace field values.
- `extensionCapabilities`, `validationReport`, `helpTopics`, and `agentIntegrationContract` retain deliberately non-current fixture values.
- The Proposal envelope's existing collection/reference/text/payload limits, tamper checks, and sanitized diagnostics remain deterministic.
- Raw `MindDeskProposalReviewState` and `MindDeskProposalReviewEvent` values round-trip, while transition/approval/rejection policy symbols are absent.
- No package builder, current authority builder, Review gate, workflow search, template, session, action, or clipboard API is reachable from the test.

### Focused Core Tests

`Tests/MindDeskCoreTests/CanvasReviewCapabilityLockTests.swift`

- Every direct call throws exactly `CanvasReviewCapabilityError.unavailable`.
- Its generic fixed message contains no path, workspace, command, import instruction, or recovery instruction.
- Source canaries—not a runtime spy—prove there is no enabled state, protocol, gateway, closure, defaults/environment/build override, counter, or test permit.

`Tests/MindDeskCoreTests/WorkspacePrimaryCanvasResolverTests.swift`

- Zero, one, two, and three records.
- Blank and repeated/collided IDs fail closed.
- Duplicate output is deterministic and never selects one ID.

### Focused App Tests

`Tests/MindDeskTests/LegacyReviewImportRejectionTests.swift`

- URL input applies metadata/capped-read protection and direct `Data` input independently enforces the 64 MiB guard.
- Input greater than 64 MiB returns the generic size error before classifier, full decoder, or lock branch; file and direct-`Data` paths both cover this ordering.
- In-limit MIP, proposal envelope, and validation-report literals each hit bounded classification, the private closed-lock branch, and neutral error mapping without full historical decode.
- Unknown formatted input, duplicate/conflicting/non-string format, nested pseudo-markers, legacy schema-only Manifest, invalid JSON, and every row in the classification table take their specified non-lock path.
- Typed and legacy ordinary Manifests within the cap retain their existing decode/validation semantics.

`Tests/MindDeskTests/S0SurfaceAbsenceTests.swift`

- Agent/Codex/Proposal menus, focused values, sheet, banner, rail mode, settings, default Help, shortcuts, deep links, and restore consumers are absent.
- Deleted runtime files and runtime resource markers do not exist.
- Ordinary Inspector, Help/search, Manifest, clipboard, Terminal snippet, Overview, and Canvas surfaces remain.

`Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift`

- Lookup is exact-workspace scoped, stably sorted, capped at two, and excludes foreign workspaces.
- The Canvas fingerprint preserves cardinality: `A → A,A → A`, blank IDs, and repeated IDs all trigger re-resolution; `.first` and `createdCanvasByWorkspaceId` are absent.
- Out-of-order completion across `A → A,B → A` and across initial/pre-insert/post-save phases accepts only the newest exact resolution attempt; a superseded attempt cannot insert, save, bind, cancel, or clear the newer attempt.
- Pre-insert missing advances the same slot to post-save without self-cancellation or a second registration; terminal handling clears before a focus-rotating bind, leaving no registration or in-flight marker.
- A fingerprint change between save and post-save fetch prevents phase advancement, cancels the old slot exactly once, and launches only a new initial lookup for the latest fingerprint.
- Initial lookup completes before bind. Missing provisioning registers by the returned focus, and every fetch checks exact token.
- A second pre-insert fetch returning unique/duplicate performs no insert and uses `complete → bind`; consecutive missing alone reaches insert/save.
- Provisioning uses an isolated clean context, never globally rolls back, and post-success/post-failure fresh fetch covers missing/unique/duplicate with no recursive retry.
- Every unequal resolution—including missing↔duplicate and changed duplicate payload—rotates scope, clears binding, and invokes old registered cancellations exactly once; duplicate never selects, creates a third record, repairs, rolls back another window, or deletes.
- Duplicate pauses Canvas while Tasks, resources, snippets, and Overview stay available.
- Initial/pre-insert/post-save fetch errors and cancellation at every boundary close exactly one registration, never bind stale data, and never compensate-delete a successful save.
- Active provisioning shows `Preparing Canvas…`; terminal missing shows the exact persistent copy and one scoped `Try Again` action, while non-Canvas surfaces remain usable and no automatic retry occurs.

`Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift`

- Two scene-root controllers have distinct window IDs and stable `@StateObject` lifetime.
- New workspace starts at nil resolution; first resolution installs under the same revision. Same workspace plus equal resolution is idempotent; A→B→A and every subsequent unequal resolution rotate revision.
- Pending-focus operations can register before Canvas binding.
- Resolver operations prove `complete → bind` ordering without suspension; completed operations receive zero cancellation, while detached operations receive one and later complete `false`.
- Switch, resolution change, overflow invalidation, and clear detach, install, then invoke every still-registered cancellation exactly once; reentrant callbacks observe only new state and cannot rerun the detached registry.
- Stale registration invokes its supplied cancellation once and returns nil; mismatched completion removes nothing; current completion removes its exact registration.
- Late, other-window, other-workspace, other-Canvas, and old-revision results cannot insert, save, or commit.

`Tests/MindDeskTests/WorkspaceCanvasNodeOpenRequestTests.swift`

- One UUID-bearing active target precedes focus/lookup/bind and remains paired with any issued request until exact terminal consumption. Pending launch uses an exact provisional nonce upgraded to an accepted operation ID; a current registration failure retains the target with recoverable retry, while stale failure mutates nothing. A new claim atomically replaces correlation and revokes an older deferred issued request, protecting A→B→A so old work cannot issue, accept, or clear a newer target.
- Missing defers only while accepted provisioning is active; duplicate, target mismatch, scoped confirmed absence, and a current exact non-cancellation provisioning error terminally clear only the exact active flow. Cancellation and stale outcomes cannot clear it.
- Request generation requires exact bound Primary Canvas plus scoped ownership `readyOwned`; temporary render absence is `dataNotReady` and retains both request and originating target. Node changes synchronously dirty generation-bound ownership evidence before fresh lookup; throw keeps it dirty, and no render event may reuse older ready evidence.
- Controller-owned sequence starts at 1 per bound scope and resets on rotation. A matching same-workspace rotation demotes the newest unconsumed issued flow to pending; switching away clears it. Seeded allocator overflow emits nothing, preserves that target as pending, rotates to nil resolution/unbound, cancels exactly once, and requires one fresh lookup.
- Identity mismatch, unissued/revoked sequence, and replay reject without advancing or mutating the receiving scope's current flow.
- Exact `.dataNotReady` retains the issued flow and counters; `readyOwned` accept and scoped `definitelyAbsentOrCrossCanvas` rejection atomically advance and consume the exact request plus originating target.

### Zero-Side-Effect Evidence Matrix

| Claim | Required evidence |
| --- | --- |
| No persistence mutation | In-memory SwiftData store plus insert/save/commit spies with zero counts for in-limit legacy rejection |
| No full legacy decode | Classifier/decoder boundary test and source canary showing the private rejection function's only expression is the lock |
| No secondary file UI or file creation | Deleted production path/source canary plus isolated temporary-directory before/after snapshot |
| No helper/process/terminal input | Deleted source, dependency, symbol, and Release-binary canaries |
| No Review clipboard write | Deleted proposal action/bridge source and symbol canaries; do not infer from global pasteboard `changeCount` |
| No proposal state mutation | Absence of transition policy plus stored-wire-only enum tests |

### Ordinary Regression Suites

The following are mandatory, not representative samples:

- All `Tests/MindDeskTests/ManifestImportServiceTests.swift`; rename any Agent-named case to neutral legacy-document rejection.
- App behavior for typed and legacy Manifest decode, unsupported version, and formatted non-Manifest rejection.
- `ManifestImportValidation*` in full.
- `testExportManifestEncodesTypedWireMetadataAndKeepsLegacyDecode`, `testExportManifestScopePolicyCanExportOnlyGlobalLibraryMetadata`, and `testExportedManifestJSONCanBeDecodedAndImportedIntoEmptyStore`.
- `testTerminalPrefillAppleScriptTypesCommandWithoutRunningIt`.
- `testCommandSnippetOpenTerminalRoutesThroughPrefillService`.
- `testCommandRunFailureFallbackCopiesCommandPrefillsTerminalAndKeepsOpenFallback`.
- `testDirectUserResourceCopyPathWritesOnlyAfterExplicitAction` and `testDirectUserSnippetCopyWritesBodyOnlyAfterExplicitAction`, using an injected clipboard spy rather than the global pasteboard.
- `testFolderPreviewCopyUsesNamedDirectUserClipboardRoute`, covering `ResourcePreviewView.copyFolderPreviewItemPath(_:)` with the same injected spy.
- `testFinderRoutingRevealsFilesButOpensFolders`, `testResourceRowDoubleClickRoutesThroughOpenActionAndFinderRouting`, and `testCanvasResourceCardDoubleClickOpensFinderOnlyForResolvedResourceCards`.
- Help Center descriptor, selection, and reader tests; ordinary Settings/Canvas/Data search tests with Agent-query expectations removed.
- `testWorkspaceDetailTabDefaultsToCanvasAndFollowsWorkspaceOpenPreference` and new `testWorkspaceOverviewRouteRendersCurrentOverviewWhenCanvasIsUnavailable`.
- `testCanvasInspectorOpensOnlyFromCardInfoButton` and `testCanvasInspectorVisibilityDefaultsClosedAndTogglesManually`.
- Canvas select, drag, pan, resize, connect, drop, and edge-animation suites.

Source-string checks can prove compile-time surface absence but never substitute for neutral rejection, persistence, cancellation, ownership, or ordinary behavior tests.

## Release Canary

Add:

- `script/s0_private_canvas_policy.sh`
- `script/verify_s0_private_canvas.sh`
- `script/test_verify_s0_private_canvas.sh`

The verifier CLI is:

```text
script/verify_s0_private_canvas.sh --repo-root DIR --package-manifest-only
script/verify_s0_private_canvas.sh --repo-root DIR --scratch-path DIR --configuration release --build-description FILE --evidence-dir DIR --binary FILE [--app-bundle DIR]
```

`--repo-root` is mandatory. Outside package-manifest-only mode, `--scratch-path`, exact `--configuration release`, `--build-description`, private `--evidence-dir`, and `--binary` are all mandatory; packaging also passes `--app-bundle`. The scratch is an absolute, private, newly created non-symlink directory outside the repository. The build description is the sole regular non-symlink Release `description.json` under that scratch and is captured from the same build that produced the binary. On its first successful call, the verifier atomically creates deterministic `normalized-build-plan.json` and `source-policy-evidence.json` in an initially empty evidence directory; every later unsigned, signed, extracted, or mounted call for that build uses the same evidence directory, recomputes into temporary files, and requires byte equality without overwriting. These two canonical files contain normalized build/policy facts, not volatile paths, symbol addresses, signatures, or raw binary/bundle hashes; provenance and the pre-sign/final manifests bind those bytes separately. The verifier starts with `set -euo pipefail`; a missing tool, nonzero pipeline component, invalid/truncated JSON, unreadable path, symlink traversal, or incomplete enumeration is failure. It sources the read-only shared policy and:

- Before any SwiftPM command, physically and NUL-safely enumerates the repository root without following symlinks. Exactly one regular non-symlink `Package.swift` must exist. Every other root basename matching `Package@swift-*.swift` is forbidden whether regular, symlinked, tracked, untracked, or ignored—including the supported MAJOR, MAJOR.MINOR, and MAJOR.MINOR.PATCH forms—because SwiftPM may select a version-specific manifest instead of `Package.swift`. The gate parses the sole manifest through the Swift compiler frontend without evaluating it and permits only the manually frozen `PackageDescription` declaration tree. `--package-manifest-only` performs exactly this preflight, and a failure occurs before any mocked or real `swift package`, `swift build`, or `swift test` invocation.
- Runs every `swift package` metadata command with the same explicit repository package path and Release scratch, never default `.build`. It parses `show-dependencies --format json` structurally and requires the graph to contain only the root package with zero external dependency nodes/identities/URLs. Optional `Package.resolved` must be absent; any future external dependency requires a new approved specification.
- Parses `describe --type json` plus the strict captured SwiftPM build description. It requires the expected Release modules, build configuration, compiler executable, source/object/output paths, and command graph; every path is physically contained in either an approved repository production root or that exact scratch. The description hash and all input/generated-source hashes are rechecked before and after verifier metadata/AST work.
- Reconstructs compiler-frontend AST invocations from the exact `swiftCommands`/`swiftFrontendCommands` in that build description, changing only the reviewed non-codegen AST-output flags. It normalizes volatile repository/scratch/SDK paths before policy comparison and rejects missing, duplicate, contradictory, or unknown commands. Thus source policy evidence and the shipped build use one build plan and one scratch.
- Runs `nm -a "$binary" | "$(xcrun --find swift-demangle)"` and applies exact runtime-symbol stems while allowing only the fully enumerated stored DTO/raw enum/pure-validator stems below.
- Runs `strings -a` over the binary and every regular file in the app bundle, applying exact removed UI/runtime markers.
- Uses `otool -L` only as supporting dependency evidence, never as its only static-link check.
- Scans approved repository production roots plus every production input recorded by the exact build plan. Repository inputs are limited to `Sources/MindDesk`, `Sources/MindDeskCore`, `Package.swift`, and production app Resources. Scratch inputs are limited to manually frozen normalized SwiftPM DerivedSources/templates and compiler/macro-synthesized declarations; unknown generated files, imports, declarations, call edges, or external callees fail. It does not scan tests, specs, other docs, changelog, or release history.
- Rejects exact deleted paths/tokens, direct Canvas Agent-package encoding, exact active Agent AppStorage consumers, and any `Sources/MindDesk` reference to historical MIP/proposal/report DTOs. App code may refer only to `MindDeskJSONDocumentClassifier`, `MindDeskJSONDocumentClassification`, `MindDeskJSONDocumentKind`, `CanvasReviewCapabilityLock`, and `CanvasReviewCapabilityError` for the bounded rejection branch.

When `--app-bundle` is present, `Info.plist`'s `CFBundleExecutable` and `--binary` must resolve to the same regular `Contents/MacOS/MindDesk` file inside the bundle. S0 permits no other bundled code object: any additional file under `Contents/MacOS`, `Contents/Frameworks`, `Contents/PlugIns`, `Contents/XPCServices`, a helper location, or any Mach-O/executable file elsewhere under `Contents` fails. Any symlink or unhandled file type fails. The sole main code object receives dependency, `nm`, demangle, and `strings` checks; all non-code regular files receive `strings` checks. Self-tests include hidden helper, framework, plug-in, XPC, executable-in-Resources, Mach-O-without-executable-bit, and symlink fixtures.

### Closed Canary Policy

`script/s0_private_canvas_policy.sh` is the single policy source used by verifier and self-test. Rules are exact fixed strings or anchored symbol/path prefixes; generic words such as `Agent`, `process`, `input`, `Review`, or `Codex` are forbidden as standalone deny patterns.

| Policy class | Exact deny values | Exact allow values |
| --- | --- | --- |
| Dependency graph | Any external node, identity, URL, or pin | Root package only; `Package.resolved` absent |
| Deleted app file basename/symbol stem | `CanvasCodexAgentSidebar`, `CanvasCodexSessionController`, `CanvasCodexTerminalView`, `CodexTerminalService`, `ProposalReviewSheet` | `TerminalService`, `ClipboardService` |
| Deleted Core runtime symbol stem | `CanvasCodexPrompt`, `MindDeskAgentHandoffPrompt`, `MindDeskAgentReviewCustomGuidancePresentation`, `MindDeskAgentReviewPackageReadiness`, `MindDeskAgentWorkflowSearch`, `MindDeskProposalCopyPathPlanner`, `MindDeskProposalEnvelopeExtractor`, `MindDeskProposalEnvelopeTemplate`, `MindDeskProposalReviewGate`, `MindDeskProposalSourcePackageRawValidation` | The closed compatibility list below only |
| Exact runtime source token | `import SwiftTerm`, `openpty(`, `.startProcess(`, `CanvasRightRailPanel.codexAgent`, `MindDeskInterchangePackage(manifest:` | `JSONDecoder`/`JSONEncoder` only in retained Core compatibility code/tests and exact ordinary app encoder callpoints |
| Exact active preference consumer under `Sources/MindDesk` | `AppPreferenceKeys.agentReviewCustomPromptGuidance`, `AppPreferenceKeys.canvasCodexPromptTemplateLibrary`, `AppPreferenceKeys.canvasCodexPromptTemplateGroup`, `AppPreferenceKeys.canvasCodexPromptTemplateOption` | Same raw obsolete-key literals only in reset cleanup data |
| Exact UI/resource marker | `Review Agent Proposal`, `Export Agent Review Package`, `minddesk-open-codex`, `minddesk-open-codex-with-prompt`, `Start Shell`, `+ Prompt Run` | Historical documentation outside production Resources |
| Historical classifier literal | none | `minddesk.interchange.package`, `minddesk.proposal.envelope`, `minddesk.validation.report`, only in classifier/retained Core wire code and tests |

The closed compatibility symbol stems are:

- Interchange: `MindDeskInterchangePackageFormat`, `MindDeskInterchangePackage`, `MindDeskInterchangeSummary`, `MindDeskInterchangeValidationSeverity`, `MindDeskInterchangeValidationSource`, `MindDeskInterchangeValidationIssue`, `MindDeskInterchangePackageValidation`, `MindDeskInterchangePrivacy`, `MindDeskAgentGuide`, `MindDeskInterchangeExternalActionPolicy`, `MindDeskInterchangeExternalActorPolicy`, `MindDeskInterchangeExternalActionDecision`, `MindDeskAgentWorkflowStep`, and `MindDeskAgentPolicy`.
- Contract: `MindDeskAgentAudience`, `MindDeskAgentAuthorityMode`, `MindDeskAgentReferenceKind`, `MindDeskAgentOperationPayloadField`, `MindDeskAgentOperationPayloadValueShape`, `MindDeskAgentOperationPayloadFieldSchema`, `MindDeskAgentAuthorityContract`, `MindDeskAgentFileFormatContract`, `MindDeskAgentProposalEnvelopeContract`, `MindDeskAgentReferenceSchemas`, `MindDeskAgentOperationRiskContract`, `MindDeskAgentOperationContract`, `MindDeskAgentPromptTemplate`, `MindDeskAgentReviewGateContract`, `MindDeskAgentIntegrationContract`, `MindDeskAgentIntegrationContractValidationIssue`, and `MindDeskAgentIntegrationContractValidation`.
- Capability catalog: `MindDeskExtensionCapabilityCatalog`, `MindDeskExtensionCapability`, `MindDeskExtensionCapabilityPolicyDecision`, `MindDeskExtensionCapabilityCatalogValidationIssue`, and `MindDeskExtensionCapabilityCatalogValidation`.
- Proposal wire: `ProposalImportLimits`, `MindDeskProposalEnvelope`, `MindDeskProposalEnvelopeDecodeLimitError`, `MindDeskProposalContextSnapshot`, `MindDeskProposalContextDigest`, `MindDeskProposal`, `MindDeskProposalOperation`, `MindDeskProposalOperationKind`, `MindDeskProposalOperationRiskTier`, `MindDeskProposalOperationPayload`, `MindDeskProposalValidationIssue`, `MindDeskProposalValidationDiagnostic`, `MindDeskProposalEnvelopeValidation`, `MindDeskProposalReviewState`, `MindDeskProposalReviewEvent`, and `MindDeskProposalContextFreshness`.
- Report: `MindDeskValidationReportSource`, `MindDeskValidationReportIssue`, `MindDeskValidationReportSummary`, `MindDeskValidationReportRedactionPolicy`, `MindDeskValidationReport`, and ordinary `MindDeskManifestValidationReport`.
- File-scoped implementation helpers: `MindDeskAnyCodingKey` and `MindDeskProposalDecodeLimitGuards` only in the Proposal envelope validation file, plus `MindDeskValidationReportToken` only in the retained report sanitization file.

No wildcard such as `MindDeskAgent*`, “stored DTO,” or “pure validator” is an allow entry. Adding/renaming a compatibility symbol is a policy change requiring review.

Within those allowed types, source policy permits stored properties, explicit all-value initializers, compiler/Codable `init(from:)` and `encode(to:)`, the frozen Proposal decode-limit logic, named pure validation/sanitization, and `MindDeskProposalContextFreshness` comparison only. It explicitly rejects member declarations or references containing `.current`, `defaultGuide`, live `Manifest`/model initializers, package/report/catalog builders, `MindDeskExtensionCapabilitySearch`, `MindDeskProposalReviewPolicy`, `MindDeskProposalManifestDigest`, `MindDeskInterchangePackageValidationReport`, `MindDeskProposalValidationReport`, `MindDeskExtensionCapabilityCatalogValidationReport`, or `MindDeskAgentIntegrationContractValidationReport`.

The policy also freezes an exact sink/codec inventory as `(relative file, fully qualified enclosing type and declaration signature, resolved normalized callee)` triples after runtime deletion; a short overloaded function name is not sufficient. The closed inventory covers all of these families, including imported C symbols and alternate spellings:

- Foundation file output: `Data`/`NSData`/`String` writes, `OutputStream` open/write, `FileHandle` write/truncate/update operations, and every mutating `FileManager` create/copy/move/replace/remove/trash/link/symbolic-link/attribute/temporary-item operation;
- Darwin/POSIX mutation: `open`/`openat`/`creat`, `write`/`pwrite`/`writev`, `truncate`/`ftruncate`, rename/link/symlink/unlink/remove, mkdir/rmdir, chmod/chown/time/xattr mutation, mkstemp/mkdtemp/mknod/mkfifo, copyfile/clonefile, writable/shared mapping, `fcntl`, and direct `syscall` routes;
- process and terminal: `Process`, `NSTask`, `posix_spawn*`, `fork`, `vfork`, every `exec*`, `system`, `popen`, and `openpty`;
- UI/system and dynamic bridges: raw pasteboard writes, `NSAppleScript`, Apple Event/OSA/ScriptingBridge APIs, Finder/workspace launches, URL opening, argv/environment access, and `dlopen`/`dlsym` or equivalent dynamic symbol invocation;
- codecs and outbound clients: every JSON/property-list/archive encoder or decoder plus `URLSession`, Network-framework, socket, and equivalent network APIs.

Each family has resolved-AST positive and near-miss-negative fixtures plus complete normalized undefined/external binary-symbol evidence where static linkage can hide a call. The policy freezes the complete approved system/framework import set and resolved external-system callee inventory from the final production build. It also freezes normalized SwiftPM-generated sources such as `resource_bundle_accessor.swift`, every generated-source provenance/template hash, expanded macro body, property-wrapper/accessor synthesis, and compiler-synthesized declaration/call edge visible in the exact build-plan AST. A new or tampered generated file, macro use/expansion, synthesized external call, import, or external callee fails; fixtures modify a generated source after build, add an unknown DerivedSources file, and introduce an unapproved macro/synthesized sink.

External sinks alone are not the authority boundary. Starting at every external sensitive sink triple, the policy manually freezes the reverse-reachable local effect graph: every local gateway declaration, every call edge into or between gateways, every permitted root user/persistence/import entrypoint, and every effectful closure/function-value injection edge. This includes Finder/alias/resource import/export, persistence/save/defaults/file gateways, terminal/AppleScript/URL, clipboard, and any wrapper that transitively reaches them. A new call to an existing wrapper therefore fails even when it adds no import or external callee. The verifier derives candidate edges from the exact expanded AST but compares them to the manually reviewed graph; it never auto-learns approval. Fixtures add a new caller of each existing gateway, an extra wrapper layer, an escaping closure, overload/typealias indirection, and a local-to-local-to-sink path.

An incomplete AST, unresolved/dynamic external or effect-graph call target, unknown generated input, or new production root fails closed. APIs not explicitly needed have zero allowed production callpoints. `Process`/spawn/fork/vfork/exec/system/popen/openpty, network, Apple Event alternatives, dynamic loading, and POSIX mutators have zero allowed production callpoints. `TerminalService`/`AppleScriptRunner` are allowed only in their existing `SystemServices.swift` declarations and the ordinary `SnippetLibraryView.openTerminal(_:)` / `SnippetLibraryView.run(_:)` callpoints. `ClipboardService.copy` is allowed only in direct-user `ContentView.copySnippet(_:)`, `ContentView.copyResourcePath(_:)`, `ResourceListView.performResourceAction(_:action:)`, `ResourcePreviewView.performResourceAction(_:)`, `SnippetLibraryView.copy(_:)`, `SnippetLibraryView.run(_:)`, `WorkspaceCanvasView.open(_:)`, and `WorkspaceCanvasView.copyNodePayload(_:)`.

S0 extracts the inline folder-preview copy closure into the behavior-equivalent named declaration `ResourcePreviewView.copyFolderPreviewItemPath(_:)`; that exact declaration is the only folder-preview clipboard triple. App JSON codec triples are exactly `WorkbenchTagCodec.encode(_:)` with `JSONEncoder().encode`, `WorkbenchTagCodec.decode(_:)` with `JSONDecoder().decode`, `ImportExportService.decodeManifest(from:)` with `JSONDecoder.minddesk.decode`, and `ContentView.exportManifest()` with `JSONEncoder.minddesk.encode`. Core ordinary codec factory declarations `JSONEncoder.minddesk` and `JSONDecoder.minddesk` in `ExportManifest.swift` are also exact allowed triples. Compatibility codec triples are limited to the enumerated retained Core files and their Codable/pure-validation declarations.

The policy enumerates these exact final triples after Gates 2–7 have completed and the production tree is final; any extra file/declaration/callee triple fails. Gate 2 passes only after its focused deleted-source/runtime-surface and dependency-absence tests are green. Gate 8 freezes and enforces the manually reviewed final inventory against the completed production tree and cannot pass with a placeholder, short-name match, line-number-only rule, or automatically learned or generated allowlist.

The policy enumerates every deleted file path from Architecture §3 and every allowed production root. Each deny/allow/sink rule has a positive fixture and a near-miss negative fixture. The verifier makes no unprovable claim that names alone detect arbitrary renamed behavior; instead, new targets, roots, code objects, legacy DTO app references, encoder/process/clipboard/terminal callpoints, package-workflow calls, or sinks fail closed until explicitly reviewed.

`script/test_verify_s0_private_canvas.sh` sources the same policy and supplies positive and negative fixtures for every rule, dependency/target/build-description JSON, generated/macro evidence, effect-graph edges, forbidden/allowed source, demangled/undefined symbols, binary/resource strings, argument validation, paths containing spaces/newlines/control bytes, nonnumeric `Package@swift-*.swift` names, and unknown production/scratch roots. It proves a malformed or mismatched scratch/build description and any generated-source or local-wrapper escape fail before evidence is accepted.

### Mandatory Release Wiring

1. `script/package_release.sh` first captures the full source HEAD and requires the strict clean-worktree/unchanged-HEAD guard plus package-manifest-only gate. It creates one private unique `mktemp -d` Release scratch and one initially empty private evidence directory, uses that same explicit scratch for build, `--show-bin-path`, every SwiftPM metadata command, build-description parsing, and exact-plan AST work, and never reads default `.build`. It captures the strict build description and normalized build/source-policy evidence hashes, records and directly verifies the fresh binary hash, copies that exact file into the bundle, finishes every non-signature bundle mutation, requires the copied hash to remain equal, and only then invokes full bundle verification with the same scratch, build description, and evidence directory. `build-provenance.json` records schema `1`, full source HEAD, Release configuration, normalized build-plan/source-policy evidence digests, scratch/unsigned-bundle binary equality, and the pre-sign bundle-manifest digest. All are rechecked before scratch/evidence cleanup and output exposure.
2. The pre-sign manifest is recomputed immediately before codesign and must remain byte-equal. Only codesign and stapling may mutate the app between the pre-sign and final-app manifests; creation of a notary transport archive, submission/polling, and read-only verification are permitted but cannot mutate it. Notarization JSON must have an object root, no duplicate keys, required string `id`/`status`, and exact accepted status; missing/wrong types or malformed/truncated content fail. After mode-specific final app state, the package script verifies signature/ticket policy, reruns the full source/binary/bundle verifier with the same scratch, build description, and evidence directory, and records the final-app manifest.
3. The exact ZIP is inspected, extracted fresh, and reverified with that same scratch, build description, and evidence directory; the exact DMG is finalized, mounted read-only, and reverified with them as well. For each delivered inner app, both modes rerun strict `codesign --verify`; notarized mode additionally reruns app-level `stapler validate` and Gatekeeper assessment. The outer notarized DMG receives its own codesign/stapler/Gatekeeper checks. S0/source-policy verification and final-app-manifest equality are required in addition to, never instead of, signature/ticket checks. Post-packaging xattr/signature corruption fails. Upload/publish receives only those same digest-checked paths.
4. `.github/workflows/ci.yml` and `.github/workflows/release.yml` capture full HEAD before direct Release build, use one private scratch/build description/evidence directory for build and verifier, record the direct binary digest, and recheck clean tree/full HEAD after direct verification and before/after packaging/output exposure. CI's ad-hoc smoke and release's formal package both use the package script's separate fresh scratch and evidence directory tied to that same unchanged HEAD; no credentials/sign/upload occur before all guards pass.
5. `script/test_release_workflow_guards.sh` asserts this exact ordering and proves mocked SwiftPM is never invoked when the sole-manifest gate fails. Fixtures include valid and nonnumeric/control-character `Package@swift-*.swift` files in ignored/symlink forms; a pre-populated or mutated default `.build`; mismatched/reused scratch or build description; a no-op build; generated-source/macro/build-plan tampering; new local effect-gateway callers; replacement between fresh build/hash/bundle copy; direct/package HEAD drift; malformed/duplicate-key/wrong-type notarization JSON; and signature/ticket/xattr damage after ZIP or DMG packaging. It also injects failures for required tools, malformed proof JSON, unreadable/incomplete traversal, verifier-after mutation, hidden code/symlink, binary replacement, and upload of any path, byte, or digest other than the verified outputs.

The artifact directory contains strict `verified-artifacts.json`, `SHA256SUMS.txt`, `build-provenance.json`, `normalized-build-plan.json`, `source-policy-evidence.json`, `pre-sign.bundle.manifest.json`, and `final-app.bundle.manifest.json`. The verified JSON binds the full source HEAD, exact two payloads, and every other proof file by artifact-relative path and lowercase SHA-256; checksums agree with that non-self set. The verified JSON and checksum file cannot self-hash, so the sole workflow proof step separately emits and immediately rechecks their own digests. Upload and release steps consume only exact path+digest outputs for both payloads and all proof files, never globs.

Legacy rejection tests use an isolated `mktemp -d` directory, register fail-safe cleanup before the first fixture write, and compare before/after snapshots so no terminal directory, helper script, context package, or proposal file can appear.

## Documentation

Current copy presents MindDesk as a manual visual project map with Canvas Review off. It removes current Agent/Codex/Proposal Review availability claims and never adds a disabled feature placeholder or product-UI privacy badge.

The canonical English notice must appear verbatim in these current-capability locations:

> **Canvas Review is currently off.** This version does not start an Agent or review helper, generate an AI context package, or provide Canvas content to a model through this feature. MindDesk's normal storage, system backup, sync, and any external services you use remain subject to their own privacy settings.

- `README.md`, English `Data, Privacy, and Reliability`; the corresponding Chinese section carries a faithful translation.
- `docs/user-manual.md`, at the start of `Safety Boundary Quick Reference`.
- `docs/releases/v3.0.0.md`, top `Current capability notice`; subsequent old Agent material is visibly `Historical / no longer current`.
- `docs/feature-checklist.md`, with exact-copy and placement regression checks.

`CHANGELOG.md` needs a top historical-capability notice but is not a current privacy-copy location. The notice belongs only in release/privacy documentation, never default Help, onboarding, menus, rails, or other product UI. Documentation distinguishes a raw filesystem path—which Review never receives—from a sanitized diagnostic locator that may identify a record without exposing a local path.

## Verification Gates

S0 is complete only when fresh evidence shows:

1. The checked-in migration ledger begins at Debug 776/0 and Release 776/0, and both configuration-specific equations balance to their observed final counts with no required test skipped.
2. Focused lock, classification, wire, resolver, provisioning, scope, and request tests pass in debug and Release configurations.
3. Full `swift test` and `swift test -c release` pass after intentional migration.
4. `swift build -c release` succeeds and the binary/app verifier passes.
5. The mandatory ordinary regression list passes.
6. In-limit legacy Review rejection has zero persistence/file/process/input/clipboard/state side effects; oversize input exits before classification and lock.
7. Duplicate Primary Canvas performs no selection, third provisioning, repair, rollback, merge, or deletion.
8. Old-window, old-focus, old-resolution, old-Canvas, and mismatched request results cannot commit.
9. Packaging, CI, and release guards bind direct and packaged builds to the same unchanged full HEAD while preserving separate scratch/build-description/evidence-directory/binary evidence; pre-sign, post-staple, and extracted/mounted inner-app source-policy plus signature/ticket verification cannot be skipped; every uploaded payload/proof path and digest equals the verified bytes.
10. `git diff --check` and the scoped source canary report clean.

A clean-room verification run uses a newly created temporary directory for side-effect evidence and includes, at minimum:

```bash
set -euo pipefail
S0_CLEAN_HEAD="$(git rev-parse HEAD)"
S0_CLEAN_DEBUG=
S0_CLEAN_RELEASE=
S0_CLEAN_BUILD=
S0_CLEAN_EVIDENCE=
s0_cleanup_design() {
  for path in "$S0_CLEAN_DEBUG" "$S0_CLEAN_RELEASE" "$S0_CLEAN_BUILD" "$S0_CLEAN_EVIDENCE"; do
    [ -z "$path" ] && continue
    case "$path" in
      /tmp/minddesk-s0-design-debug.??????|/tmp/minddesk-s0-design-release.??????|/tmp/minddesk-s0-design-build.??????|/tmp/minddesk-s0-design-evidence.??????) ;;
      *) return 1 ;;
    esac
    if [ -e "$path" ] || [ -L "$path" ]; then
      [ -d "$path" ] && [ ! -L "$path" ] || return 1
      rm -rf -- "$path"
    fi
  done
}
trap s0_cleanup_design EXIT
S0_CLEAN_DEBUG="$(mktemp -d /tmp/minddesk-s0-design-debug.XXXXXX)"
S0_CLEAN_RELEASE="$(mktemp -d /tmp/minddesk-s0-design-release.XXXXXX)"
S0_CLEAN_BUILD="$(mktemp -d /tmp/minddesk-s0-design-build.XXXXXX)"
S0_CLEAN_EVIDENCE="$(mktemp -d /tmp/minddesk-s0-design-evidence.XXXXXX)"
script/verify_s0_private_canvas.sh --repo-root "$PWD" --package-manifest-only
swift test --scratch-path "$S0_CLEAN_DEBUG"
swift test -c release --scratch-path "$S0_CLEAN_RELEASE"
swift build -c release --scratch-path "$S0_CLEAN_BUILD"
S0_CLEAN_BIN_DIR="$(swift build -c release --scratch-path "$S0_CLEAN_BUILD" --show-bin-path)"
S0_CLEAN_BUILD_DESC="$(find -P "$S0_CLEAN_BUILD" -type f -path '*/release/description.json' -print -quit)"
test -n "$S0_CLEAN_BUILD_DESC"
S0_CLEAN_BINARY_SHA256="$(shasum -a 256 "$S0_CLEAN_BIN_DIR/MindDesk" | awk '{print $1}')"
bash -n script/s0_private_canvas_policy.sh
bash -n script/verify_s0_private_canvas.sh
bash -n script/test_verify_s0_private_canvas.sh
script/test_verify_s0_private_canvas.sh
script/verify_s0_private_canvas.sh --repo-root "$PWD" --scratch-path "$S0_CLEAN_BUILD" --configuration release --build-description "$S0_CLEAN_BUILD_DESC" --evidence-dir "$S0_CLEAN_EVIDENCE" --binary "$S0_CLEAN_BIN_DIR/MindDesk"
script/test_release_workflow_guards.sh
test "$S0_CLEAN_HEAD" = "$(git rev-parse HEAD)"
git diff --check
printf '%s  %s\n' "$S0_CLEAN_BINARY_SHA256" "$S0_CLEAN_BIN_DIR/MindDesk"
shasum -a 256 "$S0_CLEAN_BUILD_DESC" "$S0_CLEAN_EVIDENCE/normalized-build-plan.json" "$S0_CLEAN_EVIDENCE/source-policy-evidence.json"
s0_cleanup_design
trap - EXIT
```

The package-release smoke uses its own new scratch/build description and adds `--app-bundle` through `script/package_release.sh`; reviewers record the direct binary digest above and inspect the actual built binary path rather than assuming SwiftPM layout.

## Release Stops

Stop S0 completion or v1a release if:

- Any removed package/session/proposal UI, builder, artifact/process/input, decode/action/clipboard source, dependency, symbol, or resource remains.
- `Sources/MindDesk` calls historical runtime builders, gates, sessions, actions, or UI beyond the private bounded top-level legacy-document rejection branch.
- A legacy Review document reaches full decode or creates state before rejection; or an oversize document reaches classification or the lock.
- The permanent lock gains a protocol, gateway, closure, enabled path/state, override, counter, or future-live implementation.
- Stored historical wire fields are reconstructed from current/default values or raw Review enums regain transition policy.
- Ordinary Manifest import/export, direct-user resource/snippet clipboard, Finder routing, Terminal snippet, Inspector, Help/search, Overview, or Canvas interaction regresses.
- Primary ambiguity chooses or mutates a record, or any resolution change retains the old focus revision.
- A stale operation commits, cancellation is not exactly once, or a mismatched node request advances the current scope counter.
- Release canaries are skipped, run on anything other than the exact binary/bundle/final artifact, tolerate an external dependency/additional code object/symlink/unknown root or sink callpoint, ignore a tool/parse/traversal failure, allow post-verification payload mutation, scan so broadly that history causes false positives, or exclude production paths that hide real runtime symbols.
- Current privacy language appears in product UI or claims stronger system isolation than the evidence.

## Residual Risks Carried Forward

- Existing stores may already contain multiple Canvases. S0 exposes and contains this condition; S1 designs verified repair and durable uniqueness.
- Root `@Query` remains outside Review because S0 has no Review path. S3 must replace whole-store access in every future WCF chain before v1b.
- Canvas viewport remains persisted on the shared model and may still be last-writer-wins across windows; S2 owns the UX correction.
- Retained stored wire/validator code remains linked through `MindDeskCore` for historical compatibility. It is not an unlinked target and has no production caller beyond bounded top-level legacy-document classification.
- No performance or capacity promise is made until a later Release-store baseline is measured and frozen.
