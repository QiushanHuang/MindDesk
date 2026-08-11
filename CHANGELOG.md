# Changelog

> Historical capability notice: older entries below preserve release-line history and may describe retired review, package, proposal, or embedded helper surfaces. Those entries are no longer current product instructions or availability claims.

## 2026-08-11 - v3.1.0 private manual Canvas release

### New and improved
- MindDesk now presents one clear product: a private, manual visual project map. The retired Canvas Review, Agent Review, Proposal Review, embedded terminal, and Canvas Codex entry points are no longer part of the app.
- Opening a workspace now resolves its Primary Canvas within that window and workspace. If the Canvas is missing, MindDesk prepares it safely. If the data is ambiguous or unavailable, the Canvas stops and explains what happened instead of guessing.
- Switching workspaces cancels outdated Canvas work. A slow result from the previous workspace can no longer replace the state of the workspace currently on screen.
- Quick Open now checks that a requested card still belongs to the expected workspace and Canvas before selecting it.
- Overview, Tasks, Resources, and Snippets stay usable while Canvas is preparing or unavailable.
- The Canvas unavailable view now has one controlled Try Again action rather than an automatic retry loop.
- Canvas connection animation remains visible during pan and zoom, while drag, resize, and connection editing avoid unnecessary animation work.
- Reset All Settings removes obsolete Agent, Codex, and Proposal Review preferences without deleting workspaces, tasks, resources, Canvas data, backups, or recovery data.

### Fixed
- Fixed stale Canvas results surviving a workspace or window change.
- Fixed repeated focus, binding, and retry actions doing duplicate work or rotating state unnecessarily.
- Fixed missing-Canvas preparation sharing state with unrelated unsaved scene work.
- Fixed old, replayed, moved, or deleted Quick Open targets being able to select the wrong card.
- Fixed cards that were still rendering being reported as deleted too early.
- Fixed ambiguous Primary Canvas data being treated as if one record were safe to use.
- Fixed retired review-package imports reaching old review behavior; they are now rejected without changing app data.
- Fixed imported error details exposing local paths, URLs, or command fragments in user-facing status text.
- Fixed Help reopening pages for features that no longer exist.
- Fixed release packaging gaps that could leave a ZIP, DMG, app bundle, or proof file without an exact source and checksum relationship.

### Privacy and release
- MindDesk does not start an AI review helper, create an AI context package, or send Canvas content to a model through the retired review feature.
- Historical `.mip.json`, Proposal Envelope, and Validation Report files are recognized and rejected safely rather than imported as ordinary Manifest data.
- Real Finder files remain in place. Removing MindDesk metadata does not delete, move, or rename those files.
- Debug and Release each passed 666 tests with no failures. Independent Release builds, ZIP extraction, read-only DMG mounting, bundle checks, and artifact checks also passed.
- The v3.1.0 GitHub package is ad-hoc signed and is not Apple-notarized.

## 2026-06-27 - v3.0.0 foundation documentation and ad-hoc packaging

### Added
- Added v3.0.0 release metadata and release notes for the Agent Review, `.mip.json`, Proposal Review, validation, Help, Canvas performance, and release guardrail foundation work.
- Added `docs/user-manual.md` as the user-facing manual for installation, navigation, resources, snippets, Canvas, tasks, Quick Open, import/export, Agent Review, Proposal Review, Settings, Help, and troubleshooting.
- Documented that the current v3.0.0 artifact evidence is ad-hoc package validation only, not Developer ID notarization, stapling, Gatekeeper assessment, CI success, or GitHub Release publication.
- Added a Canvas Codex panel that builds bounded read-only Canvas context and starts an embedded PTY terminal without opening Terminal.app.

### Changed
- Refined README into a shorter bilingual project homepage and moved detailed user workflows and agent safety details into the user manual.
- Clarified release artifact naming across local notarized, local ad-hoc, and GitHub Release workflow outputs.
- Integrated v2.4.0 sibling release product behavior into the v3.0.0 branch: Overview-first workspace entry, dedicated Tasks tab, lazy Canvas creation, and exact resource-removal cleanup messaging.
- Kept Canvas edge glow animation active during viewport pan and zoom while preserving geometry-edit safeguards.
- Added editable Canvas Codex prompt groups and presets, with resettable local preferences for common organization, review, summary, and proposal workflows.
- Hardened the Canvas Codex launch path with an empty temporary session root, short helper scripts for Open Codex and Codex + Prompt, a clean embedded shell prompt, a `service_tier="fast"` CLI override, bounded terminal output retention, and stable prompt-template storage.
- Removed the fixed Canvas Codex startup model so the embedded Codex terminal can use the user's active Codex account and model selection.
- Reworked the Canvas Codex sidebar controls around an embedded SwiftTerm-backed terminal, editable command field, and `Run` / `+ Prompt Run` actions so users can type directly or send prepared commands without Terminal.app.
- Replaced the Canvas Codex text-log renderer with a real PTY terminal view so Codex TUI redraws, cursor movement, selection, and direct keyboard input behave like a terminal.
- Added a Canvas Codex proposal loop: MindDesk writes a bound Agent Review source package and proposal template into the temporary session, captures Codex terminal output, previews the latest `minddesk.proposal.envelope`, lets users ask Codex for revisions, discard the draft, or open it in Proposal Review.
- Strengthened `+ Prompt Run` proposal instructions so Canvas organization, path, and environment requests ask Codex for a complete previewable `minddesk.proposal.envelope` with `applyMindDeskChange.payload.proposedText` instead of prose-only replies.

### Release-line Note
- `v2.4.0` is a sibling release on `origin/codex/v2-4-c-lite`, not an ancestor of the current `codex/v3-foundation-p0` branch.
- The v2.4.0 product behavior has been manually integrated into the current v3.0.0 branch for release-line continuity.

### Verification
- Local v3.0.0 ad-hoc artifacts were generated and verified with `script/verify_release_artifacts.sh`.
- Release-critical worktree guard passed after committing the v3 foundation work.

## 2026-06-24 - v2.4.0 sibling release record

### Added
- Preserved the v2.4.0 sibling release note in `docs/releases/v2.4.0.md` for release-line traceability.

### Release-line Note
- v2.4.0 contains product behavior from the sibling `origin/codex/v2-4-c-lite` branch: Overview-first workspace entry, a dedicated Tasks tab, lazy Canvas creation, and exact resource-removal metadata cleanup messaging.
- These behaviors were later manually integrated into the v3.0.0 foundation branch during release readiness closeout.

## 2026-06-11 - Workspace Resume Brief minor release

### Added
- Added Workspace Resume Brief v0 for compact project re-entry below the workspace header.
- Added Home Recent Workspace status badges for tasks and resource issues.
- Added a pure core re-entry policy and app mapper for summarizing tasks, resource issues, canvas counts, dangling references, and recent snippets without SwiftData schema changes.
- Added release notes for v2.3.0 and updated README release metadata.

### Fixed
- Stabilized resume next-task ordering so equal-priority tasks are not reshuffled by edit timestamps.
- Counted dangling snippet canvas node references, including missing, private, and unknown-scope snippets.

### Verification
- Local rebuild and release validation completed with Swift tests, Swift build, bundle verification, release metadata checks, and an ad-hoc release package smoke build.

## 2026-06-07 - Code review remediation

### Fixed
- Mapped imported Finder aliases by `sourceObjectType`, so snippet aliases no longer bind to resource IDs when exported IDs overlap.
- Centralized resource rename field normalization and preserved an intentionally cleared custom name.
- Updated resource preview renames to refresh `updatedAt`, keeping resource ordering and search metadata consistent.
- Consolidated canvas move undo into one undo operation and one SwiftData save.
- Moved manifest file reading and JSON decoding off the main actor before importing records.
- Classified resource access failures as stale authorization, missing volume, or unavailable instead of always using unavailable.
- Preserved file-provider order during multi-item drops.
- Aligned fallback release-note headings with release metadata validation.

### Verification
- Added regression coverage for alias import source mapping and resource rename normalization.

## 2026-05-31 - PR review findings remediation

### Fixed
- Stabilized TODO default-group behavior in `WorkspaceTodoBoardView`:
  - default-group logic no longer relies on editable title text
  - blocked default-group rename and empty group names
  - added default-group state reconciliation when group set changes
- Prevented UI state drift on persistence failures:
  - `addGroup` now enters selection/editing only after save succeeds
  - `addTodo` now enters editing only after save succeeds
- Normalized workspace rename persistence in `ContentView`:
  - workspace title is trimmed before save
  - empty/whitespace title still falls back to `Untitled Workspace`
- Hardened workspace-scoped imports in `SystemServices`:
  - added validation requiring non-empty `workspaceId` when `scope == .workspace`
  - introduced `WorkbenchError.missingWorkspaceIdForWorkspaceScope`
- Improved seed-data error handling in `WorkbenchModels`:
  - `SeedData.seedIfNeeded` now throws on save failure instead of silently swallowing errors
  - startup caller now surfaces seed errors to status output

### Verification
- Local rebuild completed successfully via `swift build`.
