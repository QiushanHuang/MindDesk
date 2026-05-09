# MindDesk macOS Workbench Design

Date: 2026-04-28

## Purpose

MindDesk is a native macOS personal workbench for managing daily desktop work contexts. It is designed as a single personal work entry point rather than separate tools for files, commands, prompts, and workflow maps.

The app helps the user quickly return to a project context, open important directories, copy exact paths, create shortcuts, copy common prompts or shell commands, and organize project workflow visually through a mind-map-like canvas.

## Confirmed Product Direction

- Build a pure native macOS app with strong Finder, clipboard, and Terminal integration.
- Prioritize local personal use and independent distribution, while keeping architecture compatible with a future sandboxed/App Store direction where practical.
- Use a workspace-home-first interface. The app opens to a dashboard of recent workspaces, pinned resources, recent snippets, and frequently used actions.
- Support both a global library and project workspaces. Global items can be reused across projects; each project workspace owns its own resources, snippets, and canvas.
- Include four MVP surfaces: resource pins, Finder aliases, a unified snippet library for commands and prompts, and a freeform canvas for workflow maps.
- Limit Terminal execution to Terminal.app in the MVP. Running a command means explicit user confirmation followed by a visible Terminal.app Apple Events run. If Automation permission is denied, the app falls back to copying the command and opening Terminal at the working directory.
- Limit Finder alias creation to Finder Apple Events in the MVP. Alias creation is explicit, user-confirmed, and failure-visible.

## Main Information Architecture

### Home Workbench

The home workbench is the default first screen. It shows:

- Recent project workspaces.
- Frequently used pinned files and folders.
- Recently copied prompts and commands.
- Recently opened directories.
- Quick search across resources, snippets, and workspace nodes.

### Global Library

The global library stores reusable resources and snippets that are not specific to one project. It is not a separate application; it is a shared-library view available from the main sidebar, home workbench, and project workspaces.

- General folders and files.
- Common shell command snippets.
- Common prompt snippets.
- Tags and metadata used for search and filtering.

### Project Workspace

Each project workspace contains:

- Project-specific pinned files and folders.
- A freeform canvas for the project structure and workflow.
- Project-specific snippets.
- References to global snippets and resources.
- Workspace description and recent activity metadata.

### Unified Snippet Library

Commands and prompts are managed through one snippet library. Snippets are differentiated by type:

- Prompt snippets are optimized for search, copy, favorites, tags, and project reuse.
- Command snippets support copy, opening Terminal at a working directory, and running after explicit confirmation.

### Freeform Canvas

Each project workspace has a canvas used as a visual workflow map. Nodes can represent:

- Files.
- Folders.
- Command snippets.
- Prompt snippets.
- Notes or plain workflow steps.

The canvas is a first-class MVP surface, not a later add-on.

## Core User Flows

### Add and Use a Resource Pin

1. User selects a file or folder.
2. App stores it as a resource pin with title, display path, authorization data, note, tags, and project/global scope.
3. User can open it, reveal it in Finder, copy its full path, edit its note, or add it to a canvas.
4. If the path becomes unavailable, the app shows an unavailable state and offers reauthorization.

### Create Shortcuts

The MVP supports two shortcut types:

- App-internal pin: the default shortcut model inside MindDesk.
- Finder alias: an explicit advanced action that creates a macOS Finder alias on the Desktop or in a user-selected destination folder through Finder Apple Events.

Finder alias creation asks the user to confirm source, destination, and alias name. If the destination already contains an item with the same name, the app asks for a different name before creating the alias. If Finder Automation permission is denied, the destination is not writable, or alias creation fails, the app shows the error and does not create a local success record.

The MVP does not create symbolic links, does not batch-modify file structures, and does not silently write shortcuts without confirmation.

### Use Prompt and Command Snippets

1. User searches or browses the snippet library.
2. For a prompt snippet, the primary action is copy.
3. For a command snippet, the primary action is also copy.
4. Command snippets can open Terminal at a configured working directory.
5. Running a command requires a confirmation screen showing the full command and working directory.
6. After confirmation, the app runs the command visibly in Terminal.app using Apple Events. It does not run shell commands as a hidden background `Process`.
7. If Terminal Automation permission is denied or execution cannot be requested, the app degrades to copying the command and opening Terminal at the working directory.

The MVP interprets "prefill" as "copy command and open Terminal to the working directory." Automatic command injection without running is not part of the MVP contract because it can require Accessibility permissions and differs across terminal apps. Direct "run" is a separate, confirmed Terminal.app Automation action.

### Build a Workspace Map

1. User opens a project workspace canvas.
2. User creates or drags in nodes for resources, snippets, and notes.
3. Node cards show title, short description, path summary or snippet type, and common actions.
4. User can drag nodes, zoom and pan, manually connect nodes, save positions, select multiple nodes, box-select nodes, align nodes, and auto-arrange the layout.
5. From a node, user can open a linked resource, copy a path or snippet, pin the linked object, or create a Finder alias when the node references a file or folder.

## MVP Canvas Scope

The MVP canvas includes:

- Dragging nodes.
- Zoom and pan.
- Manual edge creation.
- Persisted node positions and sizes.
- Multi-select.
- Box selection.
- Alignment actions.
- Auto-arrange layout.

The MVP does not include:

- Node grouping.
- Minimap.
- Image or PDF export.
- Advanced whiteboard tools.
- Workflow execution pipelines.
- Complex edge routing controls.

## Data Model

### Workspace

Represents a project workspace.

Key fields:

- id
- title
- description
- createdAt
- updatedAt
- resourceRefs for resources owned by or attached to the workspace
- snippetRefs for snippets owned by or attached to the workspace
- referencedGlobalObjectRefs for global library resources or snippets reused by the workspace
- canvasId
- lastOpenedAt
- schemaVersion

### Global Library

Stores reusable global resources and snippets. It is not a separate application; it is a shared-library view available from the main sidebar, home workbench, and project workspaces.

### ResourcePin

Represents a pinned file or folder.

Key fields:

- id
- title
- targetType: file or folder
- displayPath
- lastResolvedPath
- securityScopedBookmarkData when available
- workspaceId when scope is workspace
- note
- tags
- scope: global or workspace
- sortIndex
- status: available, unavailable, staleAuthorization, missingVolume
- createdAt
- updatedAt

### Snippet

Represents a prompt or command.

Key fields:

- id
- title
- kind: prompt or command
- body
- description
- tags
- scope: global or workspace
- defaultAction
- workingDirectoryRef for command snippets
- requiresConfirmation for command execution
- workspaceId when scope is workspace
- lastCopiedAt
- lastUsedAt

### Canvas

Represents the visual map for one workspace.

Key fields:

- id
- workspaceId
- title
- viewportState
- createdAt
- updatedAt

### CanvasNode

Represents one canvas card.

Key fields:

- id
- canvasId
- title
- body
- nodeType: resource, snippet, note
- objectRef
- position
- size
- collapsed
- selected state is view-local and not persisted as business data
- createdAt
- updatedAt

### CanvasEdge

Represents a manual connection between two canvas nodes.

Key fields:

- id
- canvasId
- sourceNodeId
- targetNodeId
- label
- style
- createdAt
- updatedAt

### ObjectRef

Provides a stable way for canvas nodes and actions to reference resources and snippets without duplicating their fields.

Key fields:

- objectType: resourcePin, snippet, workspace
- objectId

### FinderAliasRecord

Tracks aliases created by the app.

Key fields:

- id
- sourceObjectRef
- aliasDisplayPath
- aliasFileBookmarkData when available
- aliasTargetBookmarkData when available
- createdAt
- status

## Persistence and Backup

The recommended persistence approach is SwiftData for app runtime storage, plus a versioned JSON export/import format for backup and recovery.

Design rules:

- Store schemaVersion from the first release.
- Export a JSON manifest containing workspaces, resources, snippets, canvas nodes, edges, tags, and metadata.
- Do not copy real user folders or large file contents during export by default.
- Do not export bookmarkData by default. Exported resource records keep display paths and status metadata; imported resource pins require reauthorization before privileged file access.
- Imported resource pins that cannot be resolved are marked unavailable and require user reauthorization.
- Keep data local by default.

## macOS Integration

### File and Finder Integration

The app uses system APIs for:

- Opening files and folders.
- Revealing files and folders in Finder.
- Copying paths.
- Creating Finder aliases after explicit confirmation through Finder Apple Events.

Files and folders are not opened through ad hoc shell command strings.

Finder alias creation handles these states explicitly:

- Destination already has the requested alias name.
- Destination folder is not writable.
- Finder Automation permission is denied.
- Source item no longer exists or cannot be resolved.
- Alias creation fails after Finder accepts the request.

### Clipboard Integration

The app copies:

- Full file or folder paths.
- Prompt bodies.
- Command bodies.

It records snippet usage metadata but does not keep arbitrary clipboard history.

### Terminal Integration

Command snippets support:

- Copy command.
- Open Terminal at working directory.
- Run command after explicit confirmation in Terminal.app using Apple Events.

Safety rules:

- No silent background execution.
- No automatic sudo input.
- The app does not automatically collect or store environment variables. User-authored command text is stored as normal snippet content.
- Full command and working directory are shown before execution.
- Automation permission failure degrades to copy plus open Terminal.
- Terminal MVP supports Terminal.app only. iTerm and other terminal apps are deferred.

Run behavior:

1. Resolve the working directory.
2. Show full command and working directory in a confirmation dialog.
3. After confirmation, request Terminal.app to run `cd <working-directory>; <command>` in a visible terminal window through Apple Events.
4. If Automation fails or is denied, copy the command and open Terminal at the working directory, then show the fallback state.

## Security and Permission Boundaries

The app is designed for local independent distribution first, with future sandbox compatibility kept in mind.

MVP requirements:

- Store security-scoped bookmark data for user-selected files and folders when available. Even in independent-distribution mode, the app should create bookmarks in a way that keeps future sandbox migration practical.
- Resolve bookmarks through a dedicated BookmarkService. When a bookmark is stale, refresh it after successful resolution. When access is needed, call `startAccessingSecurityScopedResource` and stop access after the operation.
- Show stale or unavailable file references clearly.
- Provide reauthorization UI.
- Confirm Finder alias creation destination and alias name.
- Confirm every command run.
- Treat Terminal control as permission-sensitive.
- Treat Finder alias creation as permission-sensitive because it depends on Finder Automation and destination folder write access.

Out of scope for MVP:

- Mac App Store compliance guarantee.
- Full App Sandbox validation.
- Global keyboard shortcuts.
- Menu bar-only mode.
- Background command scheduling.
- File organization automation.
- Full-disk scanning.

## Technical Architecture

### Application Structure

The app should use:

- A SwiftPM-first project in the current MindDesk directory, with a project-local script that stages and launches a macOS `.app` bundle for development.
- SwiftUI for main UI and scene structure.
- NavigationSplitView for the main window.
- AppKit-backed services for Finder, clipboard, Terminal, and alias operations.
- SwiftData for local persistence.
- JSON manifest import/export for backup.

Suggested folders:

- App: app entry point and scene configuration.
- Models: Workspace, ResourcePin, Snippet, Canvas, CanvasNode, CanvasEdge, ObjectRef, FinderAliasRecord.
- Stores: persistence, import/export, migration, seed data.
- Services: FinderService, ClipboardService, TerminalService, AliasService, BookmarkService.
- Views: home, global library, workspace, resource list, snippet library, inspector.
- Canvas: canvas rendering, selection, gestures, edges, alignment, auto-arrange.
- Support: formatters, validators, path helpers, error types.

Service tests should use protocols and mock implementations for TCC-sensitive operations. Finder alias and Terminal Automation behavior also require a manual verification checklist because ordinary unit tests cannot reliably grant or deny macOS Automation permissions.

### View Layout

The main window uses a three-zone desktop layout:

- Sidebar: Home, Global Library, project workspaces.
- Content: dashboard, lists, or canvas.
- Inspector: selected object detail, notes, path, snippet body, and actions.

## Testing Strategy

Core tests:

- Data model creation and relationship integrity.
- SwiftData migration and schema version handling.
- JSON export/import round trip.
- Resource pin path status checks.
- Bookmark resolution and reauthorization behavior.
- Copy path, prompt, and command actions.
- Finder open and reveal operations.
- Finder alias creation with user-selected destination.
- Terminal open-at-directory behavior.
- Command run confirmation flow.
- Automation permission denial fallback.
- Canvas node drag, zoom, pan, selection, alignment, auto-arrange, node persistence, and edge persistence.

Manual verification:

- Add a folder, move or remove it, then confirm unavailable and reauthorize states.
- Create a Finder alias to Desktop and to a chosen folder.
- Copy a command and open Terminal to the configured working directory.
- Attempt command run with Automation denied and confirm graceful fallback.
- Create a workspace canvas with resource, prompt, command, and note nodes.

## MVP Deliverables

MVP is complete when the app can:

- Create and manage global resources and snippets.
- Create and manage project workspaces.
- Add files and folders as pins.
- Open, reveal, and copy paths for pins.
- Create Finder aliases for resource pins.
- Search and copy prompt snippets.
- Search, copy, open Terminal for, and confirm-run command snippets.
- Create a project canvas.
- Add resource, snippet, and note nodes.
- Drag, zoom, pan, connect, save, multi-select, box-select, align, and auto-arrange canvas nodes.
- Show selected item detail and actions in an inspector.
- Export and import a JSON manifest backup.

## Deferred Features

- Cloud sync.
- Team collaboration.
- AI-generated prompts.
- Prompt variable forms.
- Command parameter forms.
- Complex execution logs.
- Workflow automation engine.
- Node grouping.
- Minimap.
- Image/PDF export.
- Menu bar mode.
- Global hotkeys.
- Finder symbolic links.
- Batch file organization.
- Full App Store sandbox compliance.

## Open Risk Notes

- The freeform canvas is the largest MVP complexity. It is included by user decision, so implementation should isolate the canvas module and test interaction state carefully.
- Terminal automation differs across user environments and permission states. The minimum reliable fallback is copy command plus open Terminal at a working directory.
- Finder alias creation may require careful API validation and user-visible error handling. It remains in MVP because the user explicitly selected App-internal pins plus Finder aliases.
- Future App Store support may require narrowing or redesigning Terminal and Finder automation features.
