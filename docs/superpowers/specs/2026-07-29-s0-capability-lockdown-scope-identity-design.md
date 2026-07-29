# MindDesk S0 Capability Lockdown and Scope Identity Design

**Status:** Approved for implementation planning after four-seat code and dependency review.

**Parent design:** `2026-07-29-private-canvas-first-canonical-v3-design.md`

**Implementation stage:** S0 only

## Goal

Make the current v1a build a genuinely manual, private Canvas product by removing every Agent/Codex/Proposal Review entry and runtime, installing an unopenable lowest-level Canvas Review lock, detecting ambiguous Primary Canvases without choosing one, and binding window work to an immutable in-memory scope identity.

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
- A legacy MIP or proposal submitted to ordinary Manifest import is identified shallowly and rejected with neutral copy. It is not fully decoded, reviewed, quarantined, or redirected to another command.
- Primary Canvas ambiguity is shown as a non-destructive unavailable state. MindDesk does not select, merge, rename, or delete one of the records.
- A window accepts a scope-bound asynchronous result only when window, workspace, Canvas, and focus revision all still match.

## In Scope

1. Physical removal of Agent/Codex/Proposal UI, session, PTY/process, prompt, search, review-state, and action runtime.
2. Removal of the SwiftTerm dependency and its resolved transitive dependencies.
3. A stateless, permanently closed Canvas Review capability lock.
4. Pure historical wire compatibility limited to Codable values, bounded decoding, deterministic validation, sanitized diagnostics, and shallow format classification.
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

public enum CanvasReviewUnavailableError:
    Error,
    Equatable,
    Sendable,
    LocalizedError
{
    case unavailable

    public var errorDescription: String? {
        "This JSON document is not supported by this version of MindDesk and cannot be imported as a manifest."
    }
}

public enum CanvasReviewCapabilityLock: Sendable {
    public static func requireEnabled() throws -> Never {
        throw CanvasReviewUnavailableError.unavailable
    }
}
```

The lock has no protocol, enabled case, injected policy, closure wrapper, UserDefaults key, environment override, build flag, remote flag, or test permit. S0 can never open it. A future v1b specification creates a new WCF-backed capability contract rather than changing this lock.

All product runtime entry points are deleted. Only the ordinary Manifest import branch for a classified historical MIP/proposal invokes this lock. If dependency cleanup proves one old public convenience API cannot be removed safely, its body becomes exactly `try CanvasReviewCapabilityLock.requireEnabled()` with no pre-gate work; the default decision remains deletion.

### 2. Legacy Review Document Rejection

`MindDeskJSONDocumentKind` remains a shallow top-level classifier. Its historical format literals are private constants in that file so classification does not depend on deleted runtime factories.

`ImportExportService.decodeManifest` continues this order:

```text
input size check
→ shallow document classification
→ ordinary Manifest decode and validation
```

For `minddesk.interchange.package`, `minddesk.proposal.envelope`, and other Review-only document kinds, it stops after classification by calling `CanvasReviewCapabilityLock.requireEnabled()`. It does not:

- Decode the full MIP or proposal.
- Build a validation report for Review.
- Open a second file panel.
- Create a pending state or sheet.
- Write data, a temporary file, or the clipboard.
- Suggest a removed menu command.

Ordinary Manifest behavior and typed/legacy Manifest compatibility remain unchanged.

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

S0 retains only compatibility values that are independently useful for decoding fixed historical fixtures and preserving safe validation knowledge. Retained code has no app caller and no live-model factory.

#### Keep and Narrow

- `MindDeskInterchangePackage.swift`: retain format/version constants, Codable wire fields, bounded decode/encode, and pure-value validation. Remove live Manifest package initializers, default Help/contract/capability injection, and package build conveniences.
- `MindDeskProposalEnvelope.swift`: retain Codable DTOs, bounded collection/text/payload decoding, pure validation, freshness comparison, and sanitized diagnostics. Remove review session state, approval/rejection transitions, Apply/action policy, and execution semantics.
- `MindDeskAgentIntegrationContract.swift`: retain historical Codable DTOs/enums and strict structure validation. Remove `.current` factories, live package/Manifest construction, default prompt generation, and live-model digest builders.
- `MindDeskExtensionCapabilityCatalog.swift`: retain Codable DTOs/enums and pure catalog validation. Remove `.current`, policy-derived builders, runtime search, and default catalogs.
- `MindDeskValidationReport.swift`: retain generic report DTOs, codes, severity/source, redaction, ordinary Manifest validation, and pure wire validators. Remove builders that derive a current Review authority graph from live package/current catalog/current contract values.
- `MindDeskHelpCatalog.swift`: retain ordinary Help topics, reader/search behavior, and ordinary Settings/Canvas/Data help. Remove the four Agent topics and `agentReviewPackageTopics`. A historical `.agent` enum raw value may remain for decoding but never enters default topics.
- `MindDeskJSONDocumentKind.swift`: retain shallow classification with local historical literals.
- `WorkbenchReferences.swift`: retain ordinary object references and direct-user action safety. Remove or internalize Agent authorization helpers that could be mistaken for runtime policy.
- `WorkbenchOrdering.swift`: retain ordinary rail/layout/command/Canvas policies; remove Codex-only rail metrics.

#### Delete, Not Preserve for v1b

`MindDeskProposalReviewGate`, raw source-package authority validation, workflow search, prompt/template builders, review state, action planner, and clipboard bridge are not a future foundation. v1b has different semantics and must be designed from Context Preview and WCF evidence.

Pure wire DTOs may use `JSONDecoder` and `JSONEncoder` in compatibility tests. That does not authorize a product package builder or runtime Review path.

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
- Remove Agent package/proposal dialogs, status strings, encode/decode workflow methods, and file-size helpers from `SystemServices`.
- Keep `ManifestImportService`, `ValidationDisplayTextSanitizer`, ordinary Manifest validation, and ordinary file/clipboard/Terminal services.

### 6. Minimum Primary Canvas Resolution

Create `Sources/MindDeskCore/WorkspacePrimaryCanvasResolver.swift`:

```swift
public enum WorkspacePrimaryCanvasResolution: Equatable, Sendable {
    case missing
    case unique(canvasID: String)
    case duplicate(canvasIDs: [String])
}

public enum WorkspacePrimaryCanvasResolver {
    public static func resolve(
        canvasIDs: [String]
    ) -> WorkspacePrimaryCanvasResolution
}
```

The resolver preserves cardinality while sorting IDs for deterministic output. Empty input is `missing`, one nonblank ID is `unique`, and two or more records are `duplicate`. A blank ID or repeated identical ID is an invalid collision and also produces `duplicate`; the resolver never deduplicates invalid records into a safe-looking `unique` result.

`Sources/MindDesk/Models/WorkspaceCanvasLookup.swift` remains responsible for SwiftData:

- Predicate by `workspaceId`.
- Stable sort by Canvas ID.
- `fetchLimit = 2`, which is sufficient to prove non-uniqueness.
- Mapping fetched IDs into the pure resolver.

Only `.unique` may display or create `WorkspaceCanvasScopeIdentity`. `.duplicate` never selects the first record and never provisions another record. `.missing` may enter the existing manual Canvas provisioning flow; after save, MindDesk performs a fresh scoped fetch and accepts only a resulting `.unique` state.

A transient per-window “creation in progress” set may prevent reentrant UI creation. It is not security truth. Cross-window creation may still result in a duplicate; S0 detects that state and fails closed. S1 owns durable uniqueness and repair.

The duplicate UI uses static non-destructive copy:

> MindDesk could not identify one safe Canvas for this workspace. Editing is paused to protect your data. No Canvas was deleted.

### 7. Window Scope Identity

Create value types in `Sources/MindDeskCore/WorkspaceCanvasScopeIdentity.swift`:

```swift
import Foundation

public struct WorkspaceFocusRevision:
    Equatable,
    Hashable,
    Sendable
{
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct WorkspaceCanvasScopeIdentity:
    Equatable,
    Hashable,
    Sendable
{
    public let windowSessionID: UUID
    public let workspaceID: String
    public let canvasID: String
    public let focusRevision: WorkspaceFocusRevision

    public init(
        windowSessionID: UUID,
        workspaceID: String,
        canvasID: String,
        focusRevision: WorkspaceFocusRevision
    ) {
        self.windowSessionID = windowSessionID
        self.workspaceID = workspaceID
        self.canvasID = canvasID
        self.focusRevision = focusRevision
    }
}
```

These values are intentionally not Codable and never enter SwiftData, UserDefaults, SceneStorage, a Manifest, or a Review wire type.

Create `Sources/MindDesk/Models/WorkspaceWindowScopeController.swift`:

```swift
@MainActor
final class WorkspaceWindowScopeController {
    let windowSessionID: UUID
    private(set) var current: WorkspaceCanvasScopeIdentity?

    init(windowSessionID: UUID = UUID())

    @discardableResult
    func begin(workspaceID: String) -> WorkspaceFocusRevision

    func bind(
        canvasID: String,
        workspaceID: String,
        revision: WorkspaceFocusRevision
    ) -> WorkspaceCanvasScopeIdentity?

    func accepts(_ identity: WorkspaceCanvasScopeIdentity) -> Bool

    @discardableResult
    func registerCancellation(
        for identity: WorkspaceCanvasScopeIdentity,
        cancel: @escaping @MainActor @Sendable () -> Void
    ) -> UUID?

    func complete(
        operationID: UUID,
        for identity: WorkspaceCanvasScopeIdentity
    ) -> Bool

    func clear()
}
```

Lifecycle rules:

- Each `ContentView` instance owns one controller and one `windowSessionID`.
- Beginning the same currently pending/bound workspace is idempotent and returns its existing revision.
- Beginning a different workspace synchronously cancels all registered old-scope operations, clears the old identity, and creates a new revision.
- Binding succeeds only for the current pending workspace and exact revision after Primary Canvas resolves `unique`.
- A→B→A creates different A revisions.
- `accepts` and `complete` require full identity equality.
- A late operation that ignores cancellation still cannot commit because its identity is stale.
- `clear` cancels all registered operations and removes pending/bound focus.
- The controller is main-actor isolated and never uses `@unchecked Sendable`.

### 8. Scope-Bound Node Open Requests

Replace unbound workspace/canvas/node request handling with:

```swift
struct WorkspaceCanvasNodeOpenRequest: Equatable, Sendable {
    let requestID: UInt64
    let scopeIdentity: WorkspaceCanvasScopeIdentity
    let nodeID: String
}
```

A request is created only after the target workspace has a unique Primary Canvas and the target Canvas ID matches it. Handling requires:

- Full scope-identity equality with the receiving window.
- A request ID greater than the last consumed ID.
- The node still belongs to that Canvas.

Requests from another window, an earlier focus revision, a missing/duplicate Canvas, a mismatched target Canvas, or a replayed request are consumed as rejected and never become active later.

S0 does not implement the final S2 window chooser, Back navigation, unobscured target placement, or accessibility focus transfer.

## Test Design

All behavior changes follow red-green-refactor. Negative surface tests are written before deleting the old implementation.

### Focused Core Tests

`Tests/MindDeskCoreTests/CanvasReviewCapabilityLockTests.swift`

- Every call throws exactly `.unavailable`.
- Error copy is fixed and contains no path, workspace, command, or recovery instruction.
- The lock exposes no enabled state, protocol, defaults, or environment override.

`Tests/MindDeskCoreTests/LegacyReviewWireCompatibilityTests.swift`

- Fixed MIP and Proposal JSON fixtures decode/encode/decode equivalently through pure DTOs.
- Unsupported version, missing field, unknown enum, oversize collection/text/payload, tamper, and malicious strings fail deterministically.
- Sanitized diagnostics do not replay path, command, URL, or token contents.
- No package builder, Review gate, workflow search, template, session, or action API is used.

`Tests/MindDeskCoreTests/WorkspacePrimaryCanvasResolverTests.swift`

- Zero, one, two, and three IDs.
- Blank and repeated/collided IDs fail closed.
- Duplicate output is deterministic and never selects one ID.

`Tests/MindDeskCoreTests/WorkspaceCanvasScopeIdentityTests.swift`

- Identity equality includes window, workspace, Canvas, and revision.
- Values are not Codable or persisted.

### Focused App Tests

`Tests/MindDeskTests/LegacyReviewImportRejectionTests.swift`

- MIP, proposal, forged markers, and oversize Review documents receive the same neutral rejection.
- No SwiftData insert/save, secondary file panel, full Review decode, file write, process, or clipboard event occurs.
- Ordinary typed and legacy Manifests still import.

`Tests/MindDeskTests/S0SurfaceAbsenceTests.swift`

- Agent/Codex/Proposal menu, focused values, sheet, banner, rail, settings, default Help, shortcuts, deep links, and restore consumers are absent.
- Deleted runtime files do not exist.
- Ordinary Inspector, Help/search, Manifest, clipboard, and Terminal snippet surfaces remain.

`Tests/MindDeskTests/WorkspacePrimaryCanvasIntegrationTests.swift`

- The descriptor is workspace-scoped, stably sorted, and capped at two.
- Foreign-workspace Canvases are excluded.
- Missing provisions once per local in-flight operation and must refetch before binding.
- Duplicate does not select, provision a third Canvas, or mutate data.

`Tests/MindDeskTests/WorkspaceWindowScopeControllerTests.swift`

- Two window controllers have different session IDs.
- Same-workspace begin is idempotent.
- A→B→A revisions differ.
- Switch and clear invoke cancellation exactly once.
- Late, other-window, other-Canvas, and old-revision completions are rejected.
- A current completion is accepted and deregistered.

`Tests/MindDeskTests/WorkspaceCanvasNodeOpenRequestTests.swift`

- Full identity binding, request monotonicity, target ownership, and stale/replay rejection.

### Existing Test Migration

- Delete `Tests/MindDeskTests/ProposalReviewPresentationTests.swift` after negative absence tests fail for the expected reason.
- Migrate only fixed wire fixtures, limits, and sanitization from `AgentIntegrationContractTests`, `ProposalReviewTests`, and relevant `ValidationReportTests` into the compatibility suite.
- Delete positive tests for handoff, readiness, workflow search, current catalog, prompt/template, pending Review session, approval/rejection, CopyPath, Agent settings/help, Canvas Codex UI, PTY, process, and input.
- Preserve all ordinary Manifest and `ManifestImportServiceTests`, generic validation/sanitization, normal Terminal snippet, clipboard, Inspector/right-rail, Help/search, Overview, and Canvas interaction tests.
- Source-string checks may prove surface absence, but never replace behavior tests for neutral rejection, zero persistence, cancellation, ownership, or ordinary capability regression.

## Release Canary

Add `script/verify_s0_private_canvas.sh` and a shell fixture test. The verifier receives a built Release binary and checks:

- `swift package show-dependencies --format json` contains neither SwiftTerm nor swift-argument-parser.
- `Package.resolved` is absent or contains neither dependency.
- `otool -L` contains no SwiftTerm.
- Demangled `nm -gjU` output contains no `CanvasCodex`, `CodexTerminalService`, `ProposalReviewSheet`, `MindDeskProposalReviewGate`, or `MindDeskProposalCopyPathPlanner` symbol.
- `strings -a` contains no `Review Agent Proposal`, `Export Agent Review Package`, `minddesk-open-codex`, `minddesk-open-codex-with-prompt`, `Start Shell`, or `+ Prompt Run` runtime/UI marker.
- Source/package scans contain no `import SwiftTerm`, `openpty`, SwiftTerm `startProcess`, Canvas Agent package JSON encoding, or Agent AppStorage consumer.

The canary deliberately permits historical wire literals such as `minddesk.interchange.package` and `minddesk.proposal.envelope`, and it does not forbid the ordinary `TerminalService`, `ClipboardService`, Foundation `Process`, or the word Codex in historical release notes.

Run legacy rejection tests with an isolated temporary directory and prove no `minddesk-codex-terminal-*`, helper script, context package, or proposal file appears.

## Documentation

Update:

- `README.md`
- `docs/user-manual.md`
- `docs/feature-checklist.md`

Current product copy describes MindDesk as a private manual visual project map. It removes current Agent/Codex/Proposal Review availability claims and uses the approved v1a privacy statement. It does not add a disabled feature placeholder.

Historical `CHANGELOG.md` and `docs/releases/v3.0.0.md` may preserve accurate history but must be visibly labeled historical/no longer current where a reader could mistake them for current capability.

## Verification Gates

S0 is complete only when fresh evidence shows:

1. Focused lock, legacy rejection, resolver, scope, and request tests pass.
2. The full `swift test` suite passes after intentional test migration.
3. `swift build -c release` succeeds.
4. The Release binary and dependency canary passes.
5. Ordinary Manifest import/export and validation pass.
6. Ordinary clipboard, Terminal snippets, Inspector/right rail, Help/search, Overview, and Canvas interaction pass.
7. A legacy Review document performs no full decode, persistence mutation, file creation, process launch, terminal input, proposal state mutation, or clipboard write.
8. Duplicate Primary Canvas performs no selection, provisioning, repair, merge, or deletion.
9. Old-window and old-revision results cannot commit.
10. `git diff --check` reports no whitespace errors.

## Release Stops

Stop S0 completion or v1a release if:

- Any Agent/Codex/Proposal Review UI, shortcut, menu, Help topic, restore consumer, deep link, runtime symbol, process path, or dependency remains.
- Any legacy Review document reaches full Review decode or creates state before rejection.
- The capability lock has an enabled path or configurable policy.
- Ordinary Manifest, direct-user clipboard, Terminal snippet, Inspector, Help/search, Overview, or Canvas interaction regresses.
- Primary Canvas ambiguity chooses or mutates a record.
- A stale window/revision operation is accepted.
- Release canaries are skipped or pass only through broad exclusions that hide real symbols.

## Residual Risks Carried Forward

- Existing stores may already contain multiple Canvases. S0 exposes and contains this condition; S1 designs verified repair.
- Root `@Query` remains outside Review because S0 has no Review path. S3 must replace whole-store access in every future WCF chain before v1b.
- Canvas viewport remains persisted on the shared model and may still be last-writer-wins across windows; S2 owns the UX correction.
- Retained wire code is compatibility/security code, not a supported user capability. It must remain unreachable from the app target.
- No performance or capacity promise is made until the later Release-store baseline.
