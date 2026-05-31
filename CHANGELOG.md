# Changelog

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
