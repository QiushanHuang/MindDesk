# MindDesk Private Canvas-First Canonical v3 Design

**Status:** Approved product direction; implementation remains gated by the evidence in this document.

**Decision date:** 2026-07-29

**Route:** B — Private Canvas-first Project Map

**Common P0 prerequisite:** Workspace Context Firewall (WCF)

## Decision Governance

This design is the result of three complete product, UX, and technical review rounds followed by an independent fourth-seat jury. All four reviewers used GPT-5.6-sol at xhigh reasoning effort. The user selected the route, vertical-first sequence, and Context Rail layout, then authorized the review panel to resolve the remaining product and engineering decisions autonomously.

The design is approved as a product contract. It is not approval to release every capability at once. The work is deliberately split into independently gated specifications, beginning with S0 only.

## Product Promise

MindDesk helps an individual make a private, manually maintained visual map of a research or software project, then return days later and continue without reconstructing the project's context from memory.

The user-facing promise is:

> Turn local research and software resources into a private spatial project map you can resume without reorganizing Finder.

"Private" describes what MindDesk actively includes in this feature's data flows. It does not claim operating-system isolation, encryption, secure deletion, or control over other processes that already have macOS file access.

## Primary User and Job to Be Done

The first release serves individuals who advance personal research or software projects across multiple sessions.

The primary job is:

> When I return to an interrupted project, help me see its important objects, relationships, and current focus quickly enough to make the next meaningful edit.

Research and software are two vertical cohorts built on one object model. They may use different template copy and starting layouts, but they must not acquire separate navigation, schemas, success metrics, or privacy rules.

### Explicit Non-Goals

- Team collaboration or shared workspaces.
- A general-purpose knowledge-management platform.
- Automatic project management.
- Agent execution, terminal agency, action plans, or automated write-back.
- Whole-library or cross-project AI analysis.
- Moving, renaming, or reorganizing Finder content.
- Text-semantic scoring of the user's work.

## Value Loop

The manual Canvas must create value without Review or any Agent capability:

1. The user creates a Blank, Research, or Software cohort project.
2. MindDesk opens its one logical Primary Canvas.
3. The user places a real local resource or creates a manual project object.
4. The user records project-specific meaning by adding a relationship or direct backing association.
5. The user later returns to the same project.
6. The user makes another qualifying structural edit without rebuilding the project model elsewhere.

Only step 6 establishes the core outcome. Creating a Canvas, choosing a template, moving a card, zooming, selecting, or passively viewing does not prove value.

The optional v1b loop adds a separate read-only activity:

1. The user explicitly requests a Review of the current Canvas.
2. MindDesk builds a new Context Preview from a fixed scope.
3. The user confirms exactly that preview.
4. A read-only reviewer returns advice.
5. Any source change marks the advice stale and requires a new preview.

## Canonical Object and Scope Model

### Workspace and Project

The current persistence model uses Workspace as the project container. Product copy may say "project," but implementation specifications must identify when a rule applies to the existing Workspace record rather than inventing a second persisted Project type.

Each project has:

- A creation cohort: Blank, Research, or Software.
- One Project Brief.
- One logical Primary Canvas in v1.

The Primary Canvas resolver must return exactly one result and a revision. Zero, duplicate, collided, or ambiguous candidates are recoverable data states for manual Canvas use but hard blockers for future Review. It must never select `first`.

### Canvas Graph

- Nodes and frames are owned by the current Canvas.
- Edges are valid only when both endpoints resolve uniquely inside that Canvas.
- A direct backing record is one Task, Resource, or Snippet explicitly referenced by a Node.
- Reverse references may prove ownership, existence, and uniqueness; they never expand the inclusion set.

### Review Scope

Review scope is the current window's current project and current Primary Canvas. It is not the Workspace, Project, library, or a set of "related" material.

The canonical term is **This Canvas direct backing-object closure**. It is a single-hop allowlist with explicit stopping rules, not a recursive reachable closure.

## Information Architecture

Canvas is the sole primary work surface. The trailing side contains one Context Rail, never two competing rails.

Context Rail modes are:

- Brief.
- Inspect.
- Tasks.
- Review, only after the v1b safety gate passes.

Project Brief exists only in this rail. The old Overview route is a compatibility adapter that activates Canvas and opens Brief; it does not render a second Overview surface or duplicate data and actions.

### Workspace Opening Rules

| Entry | Result |
| --- | --- |
| New project | Empty Primary Canvas |
| Workspace-only open | Honor the user's stored open preference |
| Project Brief preference | Canvas with Brief mode open |
| Object deep link | Canvas with the validated target visible |
| Missing or stale target | Canvas fallback plus persistent recoverable error |

Historical `.overview` raw values remain decodable across skipped versions. Migration is idempotent and maps the meaning to `Canvas + Brief`. The first successful migration explains the move once; subsequent opens honor the user's current rail state.

### Rail Layout and State

The Context Rail is inline when the remaining Canvas can preserve at least 560 points of usable width. This number is an initial desktop layout contract to validate with supported hardware, font scaling, VoiceOver, and localization; it is not a performance promise. Below that boundary, the rail becomes a trailing overlay and does not resize the Canvas. Only one auxiliary overlay may be visible at a time.

Per-window state owns:

- Current workspace/project and Canvas.
- Canvas viewport and object selection.
- Rail visibility, mode, width, scroll positions, and drafts.
- Context Preview and any future Review session.

Model changes may synchronize across windows. Viewport, selection, rail, drafts, and session state must not.

Selecting a Card while Tasks or Review is active updates the selection indicator but does not steal the rail mode. Inspect opens only through an explicit Inspect action or while Brief is active according to the interaction contract.

### Deep Links

Deep links are typed destinations. Resolution validates workspace/project/canvas/object ownership and existence against an immutable focus revision; URL identifiers are never authorization.

Successful object navigation must:

- Choose an unambiguous target window.
- Make the target visible outside any rail or overlay.
- Establish visual selection and an appropriate keyboard focus.
- Preserve a Back destination containing the prior window, Canvas, viewport, selection, rail, and focus.

If multiple windows remain equally valid and the link has no valid window session identity, MindDesk asks the user which visible window to use rather than choosing `first`. Missing, deleted, migrated, and stale targets produce explicit recovery states.

## Empty State, Templates, and First Guidance

The empty Canvas is real and nonmodal. It supports Add First Card, Drop, Paste, Blank start, and optional Research and Software templates without capturing the entire Canvas surface.

Templates are local static arrangements of ordinary Frames, Notes, and Links. They do not create new domain schemas. If templates ship, applying one is an atomic persistence transaction and one standard Undo group. Failure restores the exact pre-template state.

Template, seed, import, restore, and repair objects are system-origin and do not count toward activation. After the first real manually placed Resource or comparable manual map action, MindDesk may show one dismissible micro-tip encouraging a relationship or explanatory note. It must not interrupt continuous dropping, move keyboard or VoiceOver focus, or become a multi-step onboarding system.

## Accessibility Contract

Canvas is a composite keyboard region and one normal Tab stop. Within it, spatial navigation, opening, creation, connection, deletion, and Undo all have keyboard paths. Letter shortcuts are active only while Canvas itself has focus and no text editor is active.

VoiceOver exposes a comprehensible graph hierarchy with object type, visible name, group, relationship, selection, mode changes, and errors. It must not require interpreting two-dimensional position alone. Pointer selection does not unexpectedly move VoiceOver focus.

Overlays trap only their own temporary focus scope and return focus to the triggering control when closed. Reduce Motion removes viewport flight and long transitions without changing selection, focus, Undo, or recovery semantics.

## Workspace Context Firewall

### Threat Model

WCF must defend MindDesk's Review path against:

- Stale or shared window state.
- Cross-workspace/project identifiers and forged string foreign keys.
- Missing, duplicate, collided, ambiguous, global, or nil ownership.
- Whole-store reads followed by late filtering.
- Time-of-check/time-of-use changes and package tampering.
- Old package, approval, or session restoration.
- Leaks through prompts, helpers, templates, argv, environment, output, UI state, logs, errors, crash diagnostics, filenames, and session directories.
- Arbitrary shell or editable command bypasses.
- Multi-window races and abnormal process termination.
- Oversized or adversarial Canvas graphs.

WCF does not promise to stop another process with existing macOS permissions from reading files. It does not promise secure erase. A future external Review provider's transport, retention, logging, and regional policies require their own disclosure and release approval.

### Mandatory Pipeline

The only legal v1b data path is:

```text
lowest-level capability gate
→ immutable ScopeToken
→ scoped fetch
→ direct backing-object closure
→ field projection
→ ownership and graph validation
→ canonical encoding and digest
→ Context Preview
→ explicit user confirmation
→ atomic handoff
```

The capability gate runs before any fetch, read, encoding, temporary-file creation, or process launch. A builder may not receive global arrays and filter them afterward. Context Preview and transmitted input are two renderings of the same canonical projected value and have the same digest.

Revision or digest changes make the result stale. Bounds failures stop before encoding or writing and never silently truncate the context.

### Allowed Fields

The v1b package may contain only:

1. Minimal scope identity: workspace/project ID, Canvas ID, schema version, and `ProjectFocusRevision`; it excludes workspace/project names and paths.
2. Current Canvas identity: Canvas ID, visible title, and revision.
3. Valid current-Canvas nodes: node ID, typed kind, geometry/layering needed to understand the map, and type-specific allowlisted visible fields.
4. Valid current-Canvas edges: edge ID, source ID, target ID, typed kind, and visible label.
5. Single-hop backing records: only records explicitly referenced by a node, uniquely resolved, owned by the current project, and projected to the fields required by that node.

### Explicit Exclusions

The first v1b release excludes:

- Project Brief.
- Workspace Cards and their target workspaces.
- Other Canvases.
- All Tasks, Resources, or Snippets not directly backing a current node.
- Search indexes, history, other usage, and reverse backlinks.
- File or attachment bytes and all local file paths.
- Clipboard, terminal, shell, credentials, argv, environment, and command history.
- Nil, global, cross-project, and cross-workspace backing records.

Encountering an excluded ownership class, dangling edge, unknown type, collision, ambiguity, cross-scope reference, or tamper condition fails the entire package. Global resources are deferred; v1b does not offer a per-item bypass.

### Session and Process Boundary

Prefer a memory-only package. If a temporary file is unavoidable, use an owned session directory with mode `0700`, files with mode `0600`, atomic writes, a marker validated without following untrusted symlinks, and cleanup covering success, failure, cancellation, app relaunch, forced termination, and multiple windows. The UI and documentation must not claim secure deletion.

v1b contains no shell. If a helper process is unavoidable, it is a fixed trusted executable with fixed arguments, an environment allowlist, no sensitive argv/env values, and no claim of operating-system file isolation.

## Capability Stages

| Capability | v1a Private Manual Canvas | v1b Canvas Review |
| --- | --- | --- |
| Manual Canvas edit, link, and Undo | Available | Available |
| Brief, Inspect, and Tasks in one rail | Available | Available |
| Static Research/Software templates | Optional | Optional |
| Agent/Codex UI, menu, Help, restore | Absent | No Agent; Review only |
| Context-package encoding | Zero | Once after explicit confirmation |
| Review/helper process | Zero | Restricted read-only helper only if necessary |
| Context Preview | Absent | Newly built for every request |
| Review result | Absent | Read-only advice |
| Shell, tools, arbitrary file reading | Absent | Absent |
| Execution plan or proposal actions | Absent | Absent |
| Canvas, Task, or Brief write-back | Absent | Absent |
| Apply, Accept, Reject authorization | Absent | Absent |
| Clipboard side effect from Review | Absent | Forbidden |
| Old package/session recovery | Absent | Quarantine view only; never Ready |
| Global-resource Review | Absent | Blocked and deferred |

In v1a, the package, session, and action layers return a structured `featureDisabled` result before performing work. UI visibility is not an authorization boundary.

## User-Facing Privacy Copy

### v1a

> **Canvas Review is currently off.** This version does not start an Agent or review helper, generate an AI context package, or provide Canvas content to a model through this feature. MindDesk's normal storage, system backup, sync, and any external services you use remain subject to their own privacy settings.

### v1b Confirmation

> **Review only this Canvas.** MindDesk will provide only the current Canvas content and directly linked records listed in Context Preview. Other Canvases, Project Brief, tasks or resources not placed on this Canvas, file contents, clipboard, terminal, and environment variables are not added by MindDesk. Review begins only after you confirm.

### v1b Result

> **Canvas Review returns read-only advice.** It cannot edit the Canvas, run commands, read files, or execute suggestions through MindDesk. If the Canvas changes during Review, the result becomes stale.

### System Boundary

> These guarantees describe data actively provided by this MindDesk feature. They are not equivalent to macOS system-level isolation for other applications or user-started processes and do not promise secure disk erasure. If Review uses an external service, its transport and retention policy is shown separately before confirmation.

## Product Measurement

### Outcome Metric

**D7 Meaningful Continuation** is the primary outcome: a project that achieved Meaningful Map Activation is reopened on day 7 and receives a new qualifying manual map action.

### Driver Metric

**Meaningful Map Activation** is the first persisted manual map state containing a non-seed node plus a user-created relationship or direct backing association.

### Anti-Gaming Rules

- Opening, selection, movement alone, zooming, panning, and passive duration do not qualify.
- Template, seed, import, restore, migration, and repair actions do not qualify.
- Each project records activation once and one D7 outcome.
- Blank, Research, and Software cohorts are reported separately.
- Cohort is fixed when the project is created; MindDesk does not infer it from user text.
- Metrics never upload titles, bodies, Canvas contents, or reversible raw object IDs.
- If existing consent does not cover these events, measurement remains local or requires explicit opt-in.

Guardrails cover data loss, migration failure, privacy canaries, crashes, stalls, accessibility task completion, template rollback, and Undo integrity.

## Performance and Stability Gates

Before v1a Beta, establish a reproducible baseline using a Release build, real on-disk stores, and typical, large, and isolation fixtures. Fixtures include realistic path/note/tag lengths, Canvas geometry, frames, crossing edges, task states, legacy/dangling/duplicate records, and an unrelated workspace of comparable size.

Measure at least 30 runs per fixture and retain distributions for p50, p95, variance, peak memory, fetch count, main-thread stalls, frame behavior, and any future package construction. Thirty runs is a reproducibility method, not a product performance target.

No numeric time, frame-rate, memory, or capacity promise is frozen before the baseline. Before GA, the measured baseline becomes explicit regression budgets. WCF construction, canonical sorting, and encoding never run on the main thread.

Any data corruption, hard privacy failure, or candidate exceeding a frozen release budget blocks release.

## Vertical-First Expansion Rule

Research and Software cohorts must first establish trustworthy event definitions, cohort baselines, and D7 continuation without structural failure. Privacy, data-loss, migration, accessibility, and GA performance gates must be closed before horizontal expansion receives a written go decision.

A neighboring use case may expand through copy, static templates, and ordinary object composition. If it requires a new backing type, navigation model, broader closure, or stronger privacy statement, it becomes a separately designed phase with a reopened threat model.

Manual Canvas expansion is independent of v1b; it does not wait for AI Review.

## Specification Dependency Graph

```text
S0 Capability Lockdown and Scope Identity
├── S1 Versioned Model, Primary Canvas, and Overview Migration
├── S2 Window, Rail, Deep Link, and Accessibility State
└── S3 WCF Kernel and Adversarial Fixtures
       │
S1 + S2 ──> S4 Manual Canvas, Empty State, Templates, and Metrics
S0 + S1 + S2 + S3 + S4 ──> S5 v1a Release Evidence
S3 + S5 ──> S6 v1b Context Preview and Read-Only Review
S6 ──> S7 v1b Security, Performance, and Release Evidence
S5 + vertical cohort evidence ──> S8 Horizontal Expansion Go/No-Go
```

S0 is the only first implementation specification. It contains:

- Lowest-level `featureDisabled` gates for package, session, and proposal-action paths.
- Complete absence of Agent/Codex UI, menus, shortcuts, Help, deep-link, and restored state in v1a.
- Zero context-package encodes, temporary files, helper processes, and Review side effects in v1a.
- An immutable scope identity value and focus revision.
- Scope invalidation and in-flight cancellation when project focus changes.
- Release-build negative canary evidence for these claims.

S0 must not implement Context Preview, a new encoder, a helper, a future Review UI, schema migration, or dormant restore state.

## Release Decisions

| Gate | Decision |
| --- | --- |
| Canonical v3 design | Approved |
| S0 specification and plan | Allowed |
| S0 implementation | Allowed after focused spec and reviewed plan |
| v1a internal test | Blocked until S0-S4 evidence closes |
| v1a Beta | Conditional on P0 negative tests, migration, window isolation, accessibility, and real-store baseline |
| v1a GA | Blocked until measured performance/stability budgets are frozen and met |
| v1b threat-model tests | Allowed |
| v1b user capability implementation | Blocked until WCF and v1a foundations pass |
| v1b Beta/GA | Blocked until every privacy release stop is closed |

## Release Stops

Stop v1a if any Agent/package/session/action path runs, a cross-workspace destination enters the current focus, Primary Canvas ambiguity auto-resolves, multi-window focus diverges, Brief or Rail requires a whole-store read, an implicit migration risks data, or a Release-store baseline is missing.

Stop v1b if any foreign canary appears on any session surface, an invalid scope still encodes/writes/launches, a shell or out-of-scope read is possible, an old package becomes Ready, Review produces clipboard or other side effects, stale data remains current, tampering is missed, the builder scans the full store, a helper/file is orphaned, package work blocks the main thread, or public privacy language exceeds demonstrated isolation.

## Deferred Complexity

- Multiple Canvases per project.
- A second Context Rail or simultaneous overlays.
- Global-resource exceptions.
- Project Brief inclusion in Review.
- Review session restoration.
- Apply/Accept/Reject, clipboard, proposal operations, and action bridges.
- Agent, shell, execution plans, and automatic write-back.
- AI-generated or persisted editable Project Briefs.
- Semantic analysis of user text.
- New horizontal domains or public performance numbers before evidence.

## Evidence and Limitations

The review panel inspected the existing product and identified a current path where Canvas Codex source-package construction receives unscoped resource input. Existing repository tests establish a clean starting baseline but do not prove the new product or privacy contracts.

At design approval time, these facts remain to be established by focused specifications and implementation evidence:

- Historical persistence schema and every `.overview` upgrade path.
- Actual analytics consent and retention behavior.
- Helper-process, sandbox entitlement, and network boundaries.
- Supported macOS, VoiceOver, font-scaling, and localization combinations.
- External Review provider transport, logging, and retention.
- Reproducible Release-store performance and stability budgets.

Unknown facts block the affected sub-specification or release gate; they do not silently weaken this design.
