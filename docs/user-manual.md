# MindDesk User Manual

This manual describes the current private, manual Canvas product.

## 1. Core Concepts

- Workspace: a project-specific container for Overview, Tasks, Canvas, Resources, and Snippets.
- Canvas: a manual visual map made of cards, frames, and directional links.
- Resource: a reference to an existing file or folder; MindDesk does not relocate it.
- Snippet: reusable prompt, command, or text stored as metadata.
- Task: a workspace item with group, state, due date, and optional resource link.
- Global Library: reusable resources and snippets that can appear in several workspaces.

## 2. Installation and First Launch

Download MindDesk from the current GitHub Release, drag MindDesk.app into Applications, then launch it. The v3.1.0 package is ad-hoc signed and is not Apple-notarized. If macOS blocks the first launch, confirm the package came from the official repository, then use System Settings > Privacy & Security > Open Anyway.

The first launch creates a starter workspace and sample snippets but does not create a Canvas until one is needed.

If the data store cannot open, MindDesk shows a readable recovery page rather than terminating silently.

## 3. Main Interface

The sidebar opens Home, Global Library, Snippet Library, pinned resources, and workspaces. A workspace provides five views:

1. Overview
2. Tasks
3. Canvas
4. Resources
5. Snippets

The Inspector shows details for the current manual selection. Command+K opens Quick Open.

## 4. Home and Project Re-entry

Home shows recent workspaces and compact status signals. Open a workspace to continue from its current Overview, Tasks, or Canvas state. Re-entry summaries never run commands or open external items automatically.

## 5. Workspace Management

- Create a workspace with the sidebar plus button or File > New Workspace.
- Rename or pin a workspace from its actions.
- Delete removes MindDesk metadata for that workspace; it does not delete Finder files.
- Overview remains available even if the workspace's Primary Canvas is missing or ambiguous.

## 6. Resource Management

Drag or import files and folders into the Global Library or a workspace resource list. You can rename the display label, add notes and tags, pin an item, open it, reveal it in Finder, or copy its path through an explicit action.

Removing a resource deletes only the MindDesk reference and related app metadata. Review the impact message before confirming.

## 7. Snippet Library

Snippets can be global or workspace-scoped. Prompt, command, and text snippets can be created, edited, searched, copied, and placed on Canvas. Storing a command does not execute it.

## 8. Workspace Canvas

### Add Cards

Use Canvas controls or drag supported records to add resource, snippet, task, web, note, and frame cards.

### Basic Operations

- Click to select.
- Drag to move.
- Drag resize handles to resize.
- Pan empty space and use the configured wheel direction to zoom.
- Use Undo after supported edits and deletions.
- Use Fit to restore a useful viewport.

### Links and Layout

Create directional links between cards, edit labels and styles, move route controls, reverse direction, and use alignment or arrangement commands. Dense canvases reduce animation work automatically.

### Canvas Availability

MindDesk resolves one exact Primary Canvas for the focused workspace. While it checks or prepares a missing Canvas, the Canvas view shows progress. If resolution ends missing, ambiguous, or unavailable, Canvas editing fails closed and shows a clear state. Overview, Tasks, Resources, and Snippets remain usable.

Try Again starts one fresh scoped attempt only when the unavailable view offers that action. It does not create an automatic retry loop.

## 9. Tasks / Todo Board

Create task groups and tasks, set due dates, pin priorities, link resources, and move work between open and completed columns. Workspace Overview summarizes next work without replacing the full task board.

## 10. Quick Open

Press Command+K and search by title or relationship text. Quick Open can route to a workspace, resource, snippet, or web card. Cross-workspace Canvas targets are verified against current workspace, Canvas, and node ownership before selection.

## 11. Import, Export, and Backups

Use ordinary Manifest JSON to export or import MindDesk records. An export can contain record titles, notes, paths, snippets, tasks, Canvas text, and relationships.

- Global Library Only excludes workspace-owned records.
- Import validates format, references, and supported versions before insertion.
- Import rewrites record identifiers where required to avoid collisions.
- Manifest data is portable data, not authorization to access a file.
- Raw store backups support recovery but are not portable Manifest files.

## 12. Settings and Help

Command+, opens Settings. Current settings cover general behavior, appearance, Canvas interaction and performance, task defaults, data controls, and Help.

Reset All Settings restores documented preference defaults and removes obsolete preference keys. It does not delete workspaces, resources, snippets, tasks, canvases, cards, exports, raw backups, or quarantine/local recovery data.

The local Help Center covers ordinary Settings, Canvas, import/export, performance, and recovery questions.

## 13. Troubleshooting

### Canvas shows checking or preparing

Wait for the current scoped lookup to finish. Continue working in another workspace view if needed.

### Canvas is unavailable

Read the displayed state. Use Try Again only when offered. Ambiguous data is not automatically merged, repaired, or deleted.

### A file no longer opens

Confirm the item still exists and that macOS access is still valid. Update or re-import the resource through an explicit user action.

### Import is rejected

Confirm the file is an ordinary supported MindDesk Manifest and is within the documented size limits. Rejection messages use sanitized diagnostics.

### The app store cannot open

Use the recovery page details, preserve the current store and backups, and avoid overwriting recovery data before diagnosis.

## Safety Boundary Quick Reference

**Canvas Review is currently off.** This version does not start an Agent or review helper, generate an AI context package, or provide Canvas content to a model through this feature. MindDesk's normal storage, system backup, sync, and any external services you use remain subject to their own privacy settings.

- MindDesk manages metadata; Finder remains the source of truth for real files.
- Destructive metadata actions require a direct user confirmation.
- Commands, URLs, Finder actions, clipboard writes, aliases, import, and export occur only through explicit user actions.
- A raw filesystem path is an actual local path. A sanitized record locator identifies a record without exposing that path.
- System backups, sync products, file providers, and unrelated external services follow their own privacy and retention settings.
- No product documentation should imply secure erasure or operating-system isolation.
