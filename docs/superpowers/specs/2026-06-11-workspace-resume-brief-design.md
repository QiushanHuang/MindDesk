# MindDesk Workspace Resume Brief Design

## Goal

Reduce the cost of re-entering a complex workspace. When a user opens a workspace, MindDesk should make the next useful action visible within a few seconds without turning Home into a project-management dashboard or pushing the Canvas out of the main working area.

The v0 product surface is `Workspace Resume Brief v0 + Home status badges`.

## Audit Inputs

Thirteen gpt-5.5/xhigh subagents reviewed the product across three rounds:

- Product needs, jobs-to-be-done, and scope control.
- Code architecture, data flow, and implementation boundaries.
- UI/UX fit for a native macOS workbench.
- QA strategy, TDD sequence, and release checks.
- Performance, stability, and safety constraints.

The reviews converged on one direction: do not add more whiteboard complexity first. Use the existing workspace, task, resource, snippet, and canvas data to answer one practical question: what should the user look at when returning to this workspace?

## Product Scope

### Workspace Resume Brief

Add a compact Resume row or lightweight band below the workspace title area. It should stay visually subordinate to the workspace title and Canvas.

It shows, at most:

1. Three next tasks.
2. Two resource issues.
3. A Resume Canvas summary with card and link counts plus the most recent canvas update.
4. Two recently used snippets.

The brief must be action-oriented and quiet. It does not show total resource counts, total snippet counts, progress scores, health scores, charts, or activity timelines.

### Home Status Badges

Home keeps the existing structure: Recent Workspaces, Pinned Resources, and Recent Snippets.

Recent workspace entries may show up to two lightweight badges, such as open task count, due/overdue status, or resource issue count. Home must not become a cross-workspace task wall.

## Rules

### Next Tasks

Only incomplete tasks are eligible.

Ordering is stable:

1. Overdue tasks.
2. Tasks due today or soon.
3. Pinned tasks.
4. Existing manual task order.
5. Title and id tie-breakers.

Completed tasks do not appear in the brief.

### Resource Issues

Resource issues are based only on MindDesk's stored resource status. The brief must not scan Finder, refresh bookmarks, request authorization, or infer real-time file health.

Eligible resources are resources that are visible to or used by the workspace:

- Workspace-scoped resources for the current workspace.
- Global resources referenced by the workspace canvas.
- Resources linked from workspace tasks.

Only non-available statuses appear as issues, and the UI must make clear that these are known MindDesk states, not a fresh filesystem scan.

### Canvas Summary

The Canvas summary is count-only:

- Canvas count.
- Card count.
- Valid link count.
- Most recent canvas, node, or edge update.

It must not render a thumbnail, run layout, run edge routing, or inspect geometry.

### Recent Snippets

Recent snippets are based on real usage first:

1. `lastUsedAt`.
2. `lastCopiedAt`.
3. `updatedAt` only as a low-priority fallback.

The brief does not render snippet bodies, does not run command snippets, and does not open Terminal.

## Architecture

Add a pure core policy file:

- `Sources/MindDeskCore/WorkspaceReentryBrief.swift`

Recommended public types:

- `WorkspaceReentryBrief`
- `WorkspaceReentryBriefItem`
- `WorkspaceReentryBriefItemKind`
- `WorkspaceResumeWorkspaceRecord`
- `WorkspaceResumeResourceRecord`
- `WorkspaceResumeSnippetRecord`
- `WorkspaceResumeTodoRecord`
- `WorkspaceResumeCanvasRecord`
- `WorkspaceResumeCanvasNodeRecord`
- `WorkspaceResumeCanvasEdgeRecord`
- `WorkspaceResumeBriefPolicy`

The policy receives plain Sendable records and returns ids, counts, flags, and short summary values. It does not import SwiftUI, AppKit, SwiftData, or any app service.

`ContentView.swift` maps SwiftData models into core records and passes briefs into:

- `HomeView`
- `WorkspaceDetailView`

The UI components remain read-only and internal-navigation-only. They must not reuse existing resource or snippet action cards that can open Finder, copy paths, run commands, or launch Terminal.

## Explicit Non-Goals

- No SwiftData schema changes.
- No manifest/import/export changes.
- No Canvas gesture, routing, rendering, or auto-arrange changes.
- No AI summary.
- No Canvas thumbnail or minimap.
- No global task queue or cross-workspace task wall.
- No common-resource leaderboard.
- No background Finder scan.
- No bookmark refresh, reauthorization prompt, or filesystem mutation.
- No Quick Open command-mode upgrade.
- No command execution, command copying, or Terminal launch from the brief.

## Performance And Safety

The core policy must run in linear time over already loaded records. It must not do workspace-by-workspace nested scans over every node, edge, resource, snippet, or task.

Required budgets:

- `Recent Workspaces`: keep the existing six-item cap.
- `Pinned Resources`: keep the existing eight-item cap.
- `Recent Snippets`: keep the existing eight-item cap.
- Workspace brief: cap visible tasks at three, resource issues at two, snippets at two.
- Titles and subtitles must be line-limited and truncated in UI.
- Do not render snippet bodies, canvas node bodies, full path lists, or JSON/manifest payloads.

Large-data behavior:

- If the input exceeds established manifest-scale limits, such as 10,000 nodes, 20,000 edges, or 10,000 todos, the brief degrades to count-only status.
- The degraded state must avoid per-workspace detailed lists and must not call Canvas routing or layout code.

Safety grep constraints for new brief code:

- Must not call Finder, Terminal, AppleScript, bookmark, file dialog, process, or security-scoped-resource APIs.
- Must not call Canvas routing, auto-arrange, or geometry planners.
- Must not add `@Model`, `@Attribute`, `Schema`, `ModelContainer`, or persistence bootstrap changes.

## Edge Cases

The policy and UI must handle:

- Empty workspace.
- Workspace with no canvas.
- Duplicate canvases for one workspace.
- Dangling task resource references.
- Canvas nodes pointing at missing objects.
- Edges with missing endpoints.
- Nil usage dates.
- Repeated sort indexes and timestamps.
- Long titles, paths, and details.
- Other workspace private resources and snippets, which must never leak into the current workspace brief.

## Testing Strategy

Use TDD for implementation.

Core tests should cover:

- Current-workspace-only aggregation.
- Workspace/private scope isolation.
- Next task ordering and completed-task exclusion.
- Badge priority: overdue, due soon, open, empty.
- Output caps and deterministic tie-breakers.
- Empty workspace behavior.
- Dangling references and missing objects.
- Large-data degradation.

App tests should stay thin:

- SwiftData model to core record mapping.
- Home workspace selection behavior after badges are added.
- No schema or manifest changes.

Manual smoke should cover:

- Fresh store startup.
- Empty workspace.
- Workspace with overdue/open tasks.
- Workspace with unavailable resources.
- Workspace with canvas cards and links.
- Home recent workspace badges.
- Workspace detail at narrow widths.
- Long titles and subtitles.
- Opening a workspace does not create task groups or trigger external actions.

Required verification gates:

1. MVP: core tests red, core tests green, minimal UI renders.
2. Polish: text, limits, empty states, and narrow-window behavior checked.
3. Hardening: full `swift test`, `swift build`, bundle verification, security grep, and confirmation that model and manifest files were not changed.

## Success And Failure Signals

Success:

- Users can tell what to continue after opening a workspace.
- Workspace open-to-first-action time decreases.
- Overdue and due-soon tasks are easier to find.
- Known resource issues are more visible without becoming noisy.
- Home remains a quick re-entry surface, not a task dashboard.

Failure:

- The brief becomes a mini dashboard.
- Home becomes a cross-workspace task wall.
- Resource warnings imply live filesystem checks that did not happen.
- The Canvas is pushed down or visually deprioritized.
- The brief triggers Finder, Terminal, command execution, bookmark resolution, or other external side effects.
