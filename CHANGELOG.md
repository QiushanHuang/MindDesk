# Changelog

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
