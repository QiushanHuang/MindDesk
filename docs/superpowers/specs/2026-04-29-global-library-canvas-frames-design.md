# Global Library And Canvas Frames Design

## Goal

Make MindDesk treat the Global Library as the stable source registry, make Pinned sections explicit shortcuts, and make the workspace canvas feel like a directed, visual workflow map with fixed cards, arrow links, notes, and organization frames.

## Confirmed Scope

- Global Library additions create source records only. They do not automatically appear in Pinned Folders or Pinned Files.
- Pinned Folders and Pinned Files show only resources with an explicit pinned flag.
- Global Library separates folders and files, supports double-click open in Finder, and exposes actions for open, reveal, copy path, inspect, rename metadata, pin or unpin, reauthorize, alias, and remove from MindDesk.
- Dragging files or folders into Global Library imports them as unpinned sources. Dragging into Pinned imports them as pinned sources. Dragging into a canvas imports the source if needed and creates a canvas card.
- Canvas links are directed. A -> B and B -> A are different links, and rendered links show arrowheads.
- Connected cards get a low-cost glow. The first implementation supports theme choices of Blue, Minimal, and Off.
- Canvas cards are fixed size. Resource cards put the folder/file type label beside the top icon; the center of the card emphasizes the file or folder name.
- Note cards are first-class canvas cards and do not map to Finder.
- Organization frames are large canvas nodes that can connect to cards or other frames, hold notes, and organize multiple cards visually.
- Dragging an organization frame moves child cards inside it by the same delta. Child detection is based on the child node's current rectangle being fully inside the frame rectangle at drag start. The first version does not implement recursive nested frame propagation.
- Performance work focuses on avoiding SwiftData writes during every drag frame, limiting animated effects, and keeping canvas rendering based on cheap snapshots.

## Data Model

The current `ResourcePinModel` stays in place for migration safety, but its meaning changes from "pin" to "resource source entry." New migration-safe fields are added with defaults:

- `isPinned`: whether the source appears in Pinned sections.
- `originalName`: Finder file or folder name, derived from the URL.
- `customName`: MindDesk-only display name.
- `searchText`: cached lowercased search material for quick filtering.

Existing `title` remains as a compatibility fallback and can mirror the custom name.

The canvas model gets lightweight defaults for animation theme. Edges get arrow metadata. Nodes get fixed layout metadata and a new `groupFrame` node kind.

## UI Flow

Global Library presents two resource sections, Folders and Files, followed by snippets. Each resource row shows original name first, custom name after it when set, status, path, pin state, and actions. Double-click opens in Finder. Context menus mirror the row actions.

The sidebar Pinned sections remain expandable. Their add/drop behavior pins the imported source, but unpinning only flips `isPinned` and keeps the source in Global Library. Removing from MindDesk is a separate destructive metadata-only operation.

The canvas has Add Resource, Add Prompt/Command, Add Note, and Add Frame controls. Frames render behind normal cards. A frame selected by click can show its note in the inspector, connect to other nodes, and move contained child cards while dragged.

## Performance Constraints

Canvas gestures use transient state during drag and persist to SwiftData only on gesture end. Glow animation is disabled automatically when animation theme is Off, when the node count is high, or when reduced motion is active. Drag/drop import deduplicates by path and does not recursively import folder contents.

## Tests

Core tests cover:

- resource pinned filtering and Global Library inclusion semantics,
- original/custom resource display labels,
- directional edge duplicate behavior,
- organization frame child detection and drag propagation,
- note and group frame nodes being included in canvas workflow rendering decisions,
- legacy manifest decoding defaults for new fields.
