# MindDesk Pin, Workspace, Index, and Preview Design

Date: 2026-04-29

## Purpose

This design upgrades MindDesk from a basic file/workflow board into a reliable daily desktop workbench. The app should make files and folders easy to pin in batches, easy to open from the canvas, easy to preview, and safe to manage without changing the user's real Finder contents.

The design also introduces a controlled hidden Finder index file and an internal operation log. The hidden file is an opt-in local cache and recovery hint. It is not the source of truth, does not replace SwiftData, and does not bypass macOS security-scoped bookmark permissions.

## Approved Direction

- Add first-class main-sidebar sections for pinned folders and pinned files.
- Support Finder drag-and-drop batch pinning.
- Add high-frequency file actions directly to canvas cards: open/reveal, info, Quick Look where supported, and copy full path.
- Add workspace rename and delete inside MindDesk.
- Keep real Finder file management out of scope: MindDesk will not delete, rename, move, or reorganize the user's actual files, folders, packages, or symlink targets.
- Treat `.minddesk-index.json` as the only approved Finder write in this iteration, and only for opt-in create/update/read in an authorized folder root. This iteration will not automatically delete hidden index files from Finder.
- Record every hidden index operation in app-owned local logs so future cleanup and cache audits are possible.
- Preserve prompt and command snippet workflows while improving file/folder resource workflows.
- Prepare the data model for later true sync and system-wide hotkeys, but do not combine those two larger systems with this implementation pass.

## Current Iteration Scope

### Sidebar Pin Sections

The main sidebar gains two library entries next to Home, Global Library, and Snippet Library:

- Pinned Folders
- Pinned Files

Both views reuse `ResourcePinModel` and filter by resource classification. They provide search, add, drag-and-drop import, open/reveal, Quick Look where applicable, copy full path, info, reauthorize, and unpin.

Pinned Folders is not a separate data store. It displays folder-like resource pins from the global scope. Pinned Files displays file-like and package resource pins from the global scope. If a user drops mixed files and folders on either page, MindDesk imports all valid items into the correct global pin category and then shows a summary of where each item landed.

### Import Entry Matrix

All file/folder import entry points use one import pipeline: parse dropped URLs, read `FileManager` resource values, create security-scoped bookmarks when possible, classify the target, deduplicate within the destination scope, insert `ResourcePinModel`, optionally create canvas nodes, then return inserted/skipped/failed counts.

| Entry point | Pin scope created | Allowed new targets | Duplicate handling | Creates canvas node | Result display |
|---|---|---|---|---|---|
| Pinned Folders | Global | regular files, folders, packages, symlinks | Deduplicate within global scope by resource identity, normalized resolved path, then path fingerprint. Duplicates are skipped. | No | Folder-like items appear in Pinned Folders. File-like/package items appear in Pinned Files. |
| Pinned Files | Global | regular files, folders, packages, symlinks | Same global-scope dedupe. Duplicates are skipped. | No | File-like/package items appear in Pinned Files. Folder-like items appear in Pinned Folders. |
| Workspace resource list | Workspace | regular files, folders, packages, symlinks | Deduplicate within the current workspace. Matching global pins may coexist and are not deleted or modified. | No | Items appear in the current workspace resources tab and are grouped or filtered by type. |
| Canvas drop | Workspace | regular files, folders, packages, symlinks | Reuse an existing current-workspace pin if present. If the canvas already has a node for that pin, skip node creation. | Yes | Resource cards are created near the drop point, with inserted/reused/skipped/failed summary. |

Inaccessible dropped URLs fail the import item and do not create new pins. Existing pins may later become unavailable or missing when the underlying Finder item is moved, disconnected, or authorization expires.

### Resource Classification

MindDesk must not use `url.hasDirectoryPath` as the source of truth for resource type. Classification uses `FileManager` resource values.

| File system classification | MindDesk target type | Resource kind | Rules |
|---|---|---|---|
| `isDirectory == true` and `isPackage != true` | `folder` | `folder` | Can be a pinned folder or workspace root. |
| `isRegularFile == true` | `file` | `regularFile` | Can be revealed, copied, and previewed with Quick Look when supported. |
| `isPackage == true` | `file` | `package` | Treated as a file/package, not as a folder; reveal/open behavior must be explicit. |
| `isSymbolicLink == true` | resolved target type | `symlink` plus resolved kind | Store the symlink display path and resolved path. Broken symlinks fail new import and mark existing pins unavailable. |
| Finder alias file | `file` | `aliasFile` | This iteration does not automatically resolve Finder alias targets during import, to avoid bypassing authorization semantics. |
| Missing or unauthorized path | none for new import | `unavailable` for existing pins | New batch import fails that item. Existing pins show unavailable/stale state and offer reauthorization. |

### Resource Identity and Deduplication

`displayPath` is UI text and cannot be the only dedupe key.

| Field | Model location | Rule |
|---|---|---|
| `resourceIdentity` | `ResourcePinModel` | Prefer a stable value derived from volume identifier plus file resource identifier when available. |
| `normalizedPath` | `ResourcePinModel` | Use the resolved, standardized absolute file URL. Apply symlink policy and volume case-sensitivity rules. |
| `pathFingerprint` | `ResourcePinModel` | Use a non-recursive fingerprint of target type, normalized path, volume id, file size, and content modification date where available. |
| `resourceKindRaw` | `ResourcePinModel` | Store `regularFile`, `folder`, `package`, `symlink`, `aliasFile`, or `unavailable` for UI, validation, and reauthorization. |

Deduplication order:

1. If both resources have the same `resourceIdentity`, treat them as duplicates.
2. Otherwise compare `normalizedPath`.
3. Otherwise compare `pathFingerprint`.
4. If all identity signals are unavailable, allow insertion but mark the item as needing review in the import summary.

### Batch Import Transaction Rules

Batch import is transactional per item:

- Valid items are inserted or reused.
- Duplicate items are skipped and counted.
- Failed items are counted with an error reason.
- Canvas drops never leave a canvas node without a matching resource pin.
- A partial batch failure does not rollback successfully inserted independent items.
- The result summary must report inserted, reused, skipped, and failed counts.

### Canvas Workflow and Card Actions

Batch drop to the canvas creates visible resource cards for all successfully inserted or reused workspace pins, unless the current canvas already has a node for that pin.

Layout rules:

- A single card is centered near the drop point.
- Multiple cards are placed in a stable left-to-right, top-to-bottom grid near the drop point.
- Spacing must prevent overlap from action buttons, long titles, and note footers.
- Newly created nodes are selected as a group so the user can move the batch.
- Failed or skipped items do not reserve layout space.

Connect mode rules:

- Connect mode creates edges only through explicit user gestures.
- Batch drop does not auto-connect nodes.
- Self-edges are not allowed.
- Duplicate edges for the same source, target, and edge kind are skipped.
- Deleting a node deletes connected edges.
- Deleting an edge deletes only the relationship, not nodes, pins, or snippets.

Resource cards gain:

- Double-click: folders open in Finder; files and packages reveal in Finder.
- `info.circle`: opens details for the card and linked object.
- Copy-path button: copies the full resolved path.
- Quick Look button when the linked resource is previewable.
- Accurate file/folder/package/symlink/missing iconography.
- Delete-card action that removes the canvas node and connected edges without deleting the underlying resource pin.

Info details must include title, type, resource kind, full resolved path, display path, scope, workspace, status, note, tags, created date, updated date, last opened date, authorization state, and index/log state where relevant.

Card action state table:

| Linked object state | Double-click | Info | Copy path | Quick Look | Reauthorize |
|---|---|---|---|---|---|
| Folder | Open Finder at folder | Enabled | Enabled | Hidden | Available |
| Regular file | Reveal in Finder | Enabled | Enabled | Enabled when supported | Available |
| Package | Reveal or open using explicit package behavior | Enabled | Enabled | Enabled only when system supports it | Available |
| Symlink | Use resolved target behavior and show symlink badge | Enabled | Copy symlink path or resolved path with visible choice | Based on resolved target | Available |
| Missing/unavailable | Disabled | Enabled | Copy last known path with stale warning | Disabled | Primary recovery action |
| Unauthorized/stale bookmark | Disabled until access recovers | Enabled | Copy last known path with stale warning | Disabled | Primary recovery action |

### Card Notes

The card note remains part of the card. Standalone note-card creation is not part of this workflow.

- Resource card notes appear at the bottom of the card.
- Notes support expand/collapse at the card bottom.
- Empty notes do not occupy a large footer until the user edits them.
- Expanded notes may grow the card downward, but the title row, action row, and edge anchor placement should remain stable.
- Note edits save to the linked resource or snippet metadata, not to a new node.

### Prompt and Command Snippet Non-Regression

Resource pin work must not turn snippets into file resources.

- Batch Finder drop creates resource pins only. It does not create or modify prompt/command snippets.
- Prompt snippets and command snippets keep their existing model, list entry, edit flow, copy flow, command run flow, and canvas node type.
- Deleting a snippet card from canvas removes only the canvas node and connected edges.
- Workspace delete removes only workspace-scoped snippets. Global prompt and command snippets remain.
- Hidden index files never contain prompt bodies, command bodies, snippet notes, or private snippet content.
- `ResourcePinService` does not own snippet creation, edit, or deletion. Shared cleanup service only handles references.

### Workspace Rename and Delete

Workspace rename edits MindDesk metadata only:

- `WorkspaceModel.title`
- `WorkspaceModel.details`
- `updatedAt`

It keeps the current workspace, canvas selection, sidebar selection, and open sheets/popovers stable unless the user closes them.

Workspace delete uses a confirmation dialog. The dialog must say that MindDesk deletes only internal workspace metadata and will not delete, rename, or move Finder files, folders, packages, symlinks, Finder aliases, or alias targets.

The confirmation dialog shows at least these counts:

| Count | Meaning |
|---|---|
| Workspace-scoped pins | Pins owned by this workspace, grouped by file/folder/package/symlink/unavailable. |
| Workspace-scoped snippets | Snippets owned by this workspace, grouped by prompt/command. |
| Canvases | Canvas records owned by the workspace. |
| Canvas nodes | Nodes grouped by resource/snippet/note. |
| Canvas edges | Edges owned by the workspace canvases. |
| Alias/index records | MindDesk alias/index records that will be marked orphaned/tombstoned or removed from live queries. |
| Global references retained | Global pins/snippets referenced by this workspace that will remain. |
| Finder items affected | Always `0`, with explicit text that real Finder contents are untouched. |

After successful deletion:

- If the deleted workspace was open, close its detail, canvas, popovers, and sheets.
- Clear selections that reference the deleted workspace.
- Navigate to the next available workspace; if none exists, navigate to the workspace empty state.
- Preserve global pins, global prompt snippets, and global command snippets.

### Quick Look

Pinned files and supported packages use Quick Look through an AppKit/QuickLook bridge. Folders reveal in Finder instead of using Quick Look.

Quick Look requires a long-lived security-scoped access session:

| Lifecycle point | Requirement |
|---|---|
| Start preview | Resolve bookmark, confirm file/package target, call `startAccessingSecurityScopedResource()`, and keep a strong `SecurityScopedAccessSession`. |
| Stale bookmark | If resolution succeeds but bookmark is stale, refresh bookmark data and status before preview. |
| Preview visible | Keep the access session alive while the preview panel is visible. |
| Switch preview item | Release old session, create a new session for the new URL. |
| Close preview/window | Clear data source and call `stopAccessingSecurityScopedResource()`. |
| Missing/unauthorized | Do not open Quick Look. Mark unavailable/stale and offer reauthorization. |

Unsupported Quick Look targets show an error state and never crash the app.

### Reauthorize and Replace Target

Reauthorize renews access to the same logical target. It must not silently change a file pin into a folder pin, a folder pin into a package, or a package pin into a regular file.

Reauthorize succeeds when:

- New classification matches the original target type.
- Existing `resourceIdentity` matches, when available.
- Or `normalizedPath` and `pathFingerprint` match when identity is unavailable.

If the selected item does not match, the UI must treat the action as Replace Target, show a stronger confirmation, and update classification only after explicit user approval.

### Internal Mapping and Cleanup

MindDesk adds a shared cleanup service so string-based references do not drift. Views must not directly delete workspaces, resources, snippets, canvas nodes, or index records with ad hoc `modelContext.delete(...)`.

Cleanup must run in one `ModelContext`, fetch affected records, clean references, save once, and return a visible error on failure. Any retained audit data that contains a deleted id must be named and treated as a snapshot, not as a live foreign key.

| Delete action | Required cleanup | Retain or mark | Forbidden |
|---|---|---|---|
| Delete resource pin | Delete canvas nodes referencing the resource; delete connected edges; clear snippet `workingDirectoryRef`; mark related index records inactive/orphaned. | Alias/index audit records may keep display-path snapshots. | Do not delete real Finder files, folders, or Finder alias files. Do not keep live references to the deleted resource. |
| Delete snippet | Delete canvas nodes referencing the snippet; delete connected edges. | Optional cleanup log. | Do not keep canvas nodes pointing to deleted snippet. |
| Delete canvas node | Delete edges where source or target is the node. | None. | Do not leave dangling edges. |
| Delete workspace | Delete workspace-owned resources, snippets, canvases, nodes, and edges; clear workspace live refs from alias/index records. | Operation logs remain as local audit snapshots until retention/redaction. | Do not delete, rename, move, or reorganize real Finder contents. |
| Cleanup orphaned alias/index | Remove from live queries or mark `orphaned`/`tombstone`. | Keep enough local audit data for future cleanup UI. | Do not let orphaned records appear as live resources. |

### Hidden Finder Index File

The hidden index file is named `.minddesk-index.json`.

This iteration allows only create, update, and read in Finder. MindDesk does not automatically delete `.minddesk-index.json` from Finder during workspace delete, resource delete, unpin, index disable, or cleanup scans. Cleanup only records `candidate`, `orphan`, or `tombstone` state inside MindDesk for a future explicit cleanup UI.

The index file may be written only when all conditions are true:

- Hidden indexing is globally enabled.
- Hidden indexing is enabled for that specific authorized folder.
- The target is a user-authorized folder root from a pinned folder or workspace root.
- MindDesk currently has write access through bookmark access or direct user selection.
- The target is not blocked by package, symlink, hardlink, Git, cloud-sync, or ownership rules below.

The index file must not be written recursively to child folders. It must not be written next to ordinary pinned files. It must not be treated as a portable sync payload.

Index file field rules:

| Field | Allowed | Rule |
|---|---|---|
| `schemaVersion` | Yes | Must match a supported index schema. |
| `appNamespace` | Yes | Fixed MindDesk app namespace/bundle identifier, validated on read. |
| `indexFileId` | Yes | Opaque local id meaningful only to this installation. |
| `ownershipMarker` | Yes | Includes local installation id, bundle id, and creating app version. |
| `folderIndexRecordId` | Yes | Opaque local id pointing to local SwiftData. |
| `workspaceId` / `resourceIds` | Limited | Opaque local ids only; not cross-device sync identity. |
| `displayTitle` | Limited | Folder/resource display name only. No notes, prompts, command bodies, or private text. |
| `pathFingerprint` | Yes | HMAC fingerprint using a local secret. Never store the secret. |
| `payloadChecksum` | Yes | Detects corruption or unexpected edits. Does not establish trust by itself. |
| `createdAt` / `updatedAt` | Yes | Index file timestamps only. |
| full path, bookmark data, prompt body, command body, private notes, operation logs, directory listings, raw error messages | No | Always forbidden. |

### Hidden Index Trust and File-System Safety

`.minddesk-index.json` is untrusted input. Reading it may assist recovery and diagnostics, but it cannot override SwiftData, cannot bypass bookmark reauthorization, cannot create pins by itself, and cannot trigger Finder delete/move/rename.

`FolderIndexService.readIndex` must validate schema, `appNamespace`, `ownershipMarker`, `indexFileId`, and checksum. Validation failure records a failed or cleanup-candidate log and ignores the payload.

File-system safety rules:

| Risk | Rule |
|---|---|
| Symlink | Use `lstat` before and after write. Do not follow an existing `.minddesk-index.json` symlink. Reject paths that escape the authorized folder root. |
| Hardlink/non-regular file | Refuse to overwrite if the existing index path is not a regular file or appears as a multi-link file. |
| Package | Do not write inside `.app`, `.photoslibrary`, or other packages by default. |
| Git repo | Default to blocked for Git worktrees and `.git` directories. Do not modify `.gitignore`. |
| Cloud-sync directory | Default to blocked for iCloud, OneDrive, Dropbox, Google Drive, and similar roots unless a future explicit override exists. |
| Atomic write | Write canonical JSON to a same-directory temp file, validate checksum, then atomically replace. Failure must not leave broken JSON or remove the previous index. |

### Hidden Index Logs

All hidden index operations are recorded inside MindDesk local storage, not in pinned folders.

Logs are local-only and not part of default sync or default export. Full paths and raw error details are diagnostic fields and must support retention/redaction.

Each log entry records:

- `id`
- `operationId`
- `folderIndexRecordId`
- `indexFileId`
- `operation`: `create`, `update`, `read`, `cleanupScan`, `cleanupMark`, or `failed`
- `workspaceIdSnapshot` and `resourceIdSnapshot`, when relevant
- `targetDisplayPath` and `indexFilePath` as local-only diagnostics
- `status`: `succeeded`, `failed`, `ignored`, or `blocked`
- `cleanupStatus`: `none`, `candidate`, `orphan`, or `tombstone`
- `errorCode` and redaction-capable `errorMessage`
- `schemaVersion`
- `appVersion`
- `createdAt`
- `retentionExpiresAt`
- `redactedAt`

`read` logs may be throttled or coalesced to avoid excessive log growth, but create, update, failure, cleanup scan, and cleanup mark logs must be retained until retention/redaction policy handles them.

## Deferred Scope

### System-Wide Global Hotkeys

This iteration may add app menu commands and local keyboard shortcuts only. True system-wide global hotkeys are deferred.

Allowed this iteration:

- SwiftUI `.commands`
- SwiftUI `.keyboardShortcut`
- focused scene commands
- menu commands routed to the current window, current workspace, or current canvas selection

Forbidden this iteration:

- `NSEvent.addGlobalMonitorForEvents`
- `CGEventTap`
- Carbon global hotkey registration
- LaunchAgent helpers
- Accessibility permission flow
- global hotkey preferences or global conflict detection

### Cross-Device Sync

True sync is deferred to a separate design and implementation pass.

The current work should make sync possible later by separating:

- Portable metadata: titles, notes, tags, ids, relationships, timestamps.
- Local-only authorization: security-scoped bookmark data.
- Local-only index data: `.minddesk-index.json`, index paths, ownership markers, HMAC fingerprints, checksums, and logs.
- Conflict state: future revisions, tombstones, and device ids.

Bookmark data, index files, index logs, local full paths, HMAC secrets, HMAC fingerprints, checksums, and cleanup state must not be treated as portable sync payloads. Default JSON export also excludes them. A future diagnostic export must be explicit and redacted by default.

### Finder Real File Management

MindDesk will not rename, delete, move, or reorganize real Finder files as part of this feature. MindDesk may create or update `.minddesk-index.json` only under the opt-in hidden index rules above. Automatic physical deletion of `.minddesk-index.json` is deferred to a future cleanup UI with explicit user confirmation.

## Data Model Changes

### ResourcePinModel

Keep existing fields and add or standardize:

- `resourceIdentity: String?`
- `normalizedPath: String`
- `pathFingerprint: String?`
- `resourceKindRaw: String`
- `authorizationStatusRaw: String`
- `lastReauthorizedAt: Date?`

`securityScopedBookmarkData`, full paths, normalized paths, and fingerprints are local-only. They do not enter default sync/export.

### WorkspaceModel

Workspace root is optional and user-authorized. It is not implied by workspace metadata.

Add:

- `rootDisplayPath: String?`
- `rootLastResolvedPath: String?`
- `rootSecurityScopedBookmarkData: Data?`
- `rootResourceIdentity: String?`
- `rootNormalizedPath: String?`
- `rootPathFingerprint: String?`
- `indexEnabled: Bool` defaulting to `false`
- `rootAuthorizationStatusRaw: String`
- `lastIndexedAt: Date?`

Selecting a root folder does not automatically enable hidden indexing.

### FolderIndexRecordModel

Add:

- `id`
- `workspaceIdSnapshot`
- `resourceIdSnapshot`
- `folderDisplayPath`
- `indexFilePath`
- `indexFileId`
- `ownershipMarker`
- `schemaVersion`
- `statusRaw`
- `cleanupStatusRaw`
- `isLive`
- `createdAt`
- `updatedAt`
- `lastReadAt`
- `lastWriteAt`

Folder index records are local-only. If the related workspace or resource is deleted, the record must not remain as a live reference.

### IndexOperationLogModel

Add:

- `id`
- `operationId`
- `folderIndexRecordId`
- `indexFileId`
- `operationRaw`
- `workspaceIdSnapshot`
- `resourceIdSnapshot`
- `targetDisplayPath`
- `indexFilePath`
- `statusRaw`
- `cleanupStatusRaw`
- `errorCode`
- `errorMessage`
- `schemaVersion`
- `appVersion`
- `createdAt`
- `retentionExpiresAt`
- `redactedAt`

Index operation logs are local-only and excluded from default sync/export.

## Services

### ResourcePinService

Owns adding, deduplicating, opening, revealing, copying, reauthorizing, replacing, and unpinning resource pins. Batch import and canvas drop flows call this service rather than duplicating pin creation in views.

### WorkspaceDeletionService

Owns workspace, resource, snippet, canvas node, edge, alias, index, and log cleanup. Views do not manually delete related rows one by one.

### QuickLookService

Owns Quick Look preview coordination and long-lived scoped access sessions for previewed files.

### FolderIndexService

Owns `.minddesk-index.json` create, update, read, validation, blocked-path checks, atomic write, and cleanup marking. It records every operation through `IndexOperationLogModel`.

This service does not physically delete hidden index files from Finder in this iteration.

### KeyboardCommandService

Owns app-local commands for the current window. It should be designed so a later global hotkey service can call the same command actions, but no global hotkey implementation is part of this iteration.

## Error Handling

- Replace critical `try? modelContext.save()` paths with visible errors.
- Batch import reports inserted, reused, skipped, and failed counts.
- Hidden index write failures do not block pin creation; they mark index status failed or blocked and create a log entry.
- Quick Look authorization failures offer reauthorization.
- Workspace delete uses a confirmation dialog and clearly states that Finder files are not deleted.
- Cleanup service save failure returns a visible error and must not leave partially cleaned live references.

## Testing and Verification

Automated checks:

- `swift build`
- `swift test`
- Core tests for FileManager classification: regular file, folder, package, symlink target, broken symlink, alias file, and missing path.
- Core tests for resource identity, normalized path, and fingerprint deduplication order.
- Tests that batch import reports inserted, reused, skipped, and failed counts.
- Tests that canvas drop does not create nodes without matching resource pins.
- Cleanup tests confirming no dangling canvas nodes, edges, snippet working-directory refs, or live alias/index foreign keys after resource/snippet/node/workspace deletion.
- Reauthorization tests for type mismatch, identity match, path match, and replace-target flow.
- Quick Look session tests confirming scoped access is retained during preview and released after close/switch.
- Index payload tests confirming allowed fields exist and forbidden fields are absent.
- Index validation tests for schema, namespace, ownership marker, and checksum failures.
- HMAC fingerprint tests for same-secret stability and different-secret difference.
- Hidden index cleanup tests confirming only `candidate`, `orphan`, or `tombstone` state is recorded and no real `.minddesk-index.json` is deleted.
- Safety tests for symlink, hardlink, package, Git repo, and cloud-sync blocked paths.
- Atomic write tests confirming failure does not leave corrupted JSON or delete the previous index.
- Export tests confirming bookmark, index, log, path, fingerprint, checksum, and HMAC secret data are excluded from default export.

Manual smoke checks:

- Drag five mixed Finder items into Pinned Folders/Files and verify correct type split and summary.
- Drag mixed Finder items to the canvas and verify resource pins plus resource cards are created near the drop point without overlap.
- Double-click a folder card and confirm Finder opens it.
- Double-click a file card and confirm Finder reveals it.
- Copy path from a card and verify the full path is on the clipboard.
- Preview a supported file with Quick Look, keep preview open, then close it and confirm no crash or stale access.
- Rename and delete a workspace and confirm Finder files remain untouched.
- Delete a workspace and confirm global pins/snippets remain.
- Enable hidden indexing for an authorized folder and confirm only one `.minddesk-index.json` appears at the authorized folder root.
- Delete the workspace/resource and confirm Finder `.minddesk-index.json` is not automatically deleted, while MindDesk records cleanup candidate/orphan/tombstone state.
- Tamper with `.minddesk-index.json` namespace, schema, or checksum and confirm MindDesk ignores it and records a failure log.
- Attempt hidden indexing in Git repo and cloud-sync folders and confirm the app blocks by default with a visible reason.
- Trigger log retention/redaction and confirm paths/error details are redacted while audit records remain understandable.
- Confirm app-local shortcuts work only while MindDesk is active and focused.

## Acceptance Criteria

- The main sidebar clearly separates pinned folders and pinned files.
- Drag-and-drop batch pinning follows the entry matrix and reports inserted/reused/skipped/failed results.
- Resource classification uses `FileManager` resource values, not `url.hasDirectoryPath`.
- Deduplication uses resource identity, normalized path, then fingerprint.
- Canvas resource cards expose open/reveal, info, copy path, Quick Look where supported, bottom note expansion, and delete-card.
- Canvas drops create stable, non-overlapping resource cards and do not auto-connect them.
- Prompt and command snippet search, copy, edit, run, list, and canvas behavior remain available.
- Workspace rename and delete are metadata-only and preserve global pins/snippets.
- Workspace delete leaves no live orphan canvas nodes, edges, alias refs, index refs, or snippet working-directory refs.
- Quick Look works for supported pinned files and fails safely for unsupported, missing, or unauthorized targets.
- Hidden index files are opt-in, folder-root-only, minimal, validated as untrusted input, and fully logged inside MindDesk.
- MindDesk does not automatically delete `.minddesk-index.json` from Finder in this iteration.
- Hidden index/log/bookmark/path/fingerprint/checksum data is local-only and excluded from default sync/export.
- No user Finder file, folder, package, symlink target, or Finder alias target is deleted, renamed, moved, or reorganized by this feature.
