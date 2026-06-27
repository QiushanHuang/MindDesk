# Changelog

## 2026-06-27 - v3.0.0 foundation documentation and ad-hoc packaging

### Added
- Added v3.0.0 release metadata and release notes for the Agent Review, `.mip.json`, Proposal Review, validation, Help, Canvas performance, and release guardrail foundation work.
- Added `docs/user-manual.md` as the user-facing manual for installation, navigation, resources, snippets, Canvas, tasks, Quick Open, import/export, Agent Review, Proposal Review, Settings, Help, and troubleshooting.
- Documented that the current v3.0.0 artifact evidence is ad-hoc package validation only, not Developer ID notarization, stapling, Gatekeeper assessment, CI success, or GitHub Release publication.
- Added a Canvas Codex panel that builds a bounded read-only Canvas prompt and opens Codex CLI in Terminal with safe interactive flags.

### Changed
- Refined README into a shorter bilingual project homepage and moved detailed user workflows and agent safety details into the user manual.
- Clarified release artifact naming across local notarized, local ad-hoc, and GitHub Release workflow outputs.
- Integrated v2.4.0 sibling release product behavior into the v3.0.0 branch: Overview-first workspace entry, dedicated Tasks tab, lazy Canvas creation, and exact resource-removal cleanup messaging.
- Kept Canvas edge glow animation active during viewport pan and zoom while preserving geometry-edit safeguards.

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
