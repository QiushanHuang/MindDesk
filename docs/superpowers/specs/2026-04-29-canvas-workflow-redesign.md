# MindDesk Canvas Workflow Redesign

## Goal

Fix the canvas so it behaves like a folder/file workflow board instead of a generic note board. The canvas should make it easy to place resource cards, connect them, inspect their paths, and keep each card's description visible without wasting space.

## Approved Direction

Use option B from the visual companion:

- Left rail: add resources/snippets and switch canvas mode.
- Center: the largest possible canvas area for workflow cards and connections.
- Right rail: actions for the selected card or selected cards.
- Notes are not standalone cards. A card's note appears at the bottom of the same card and can be expanded/collapsed.

## Functional Changes

- Remove the "New Note" card workflow from the canvas toolbar.
- Add resource and snippet cards through a compact left rail.
- Replace the overloaded horizontal toolbar with a three-column canvas workbench.
- Add explicit canvas modes: Select, Connect, Box Select.
- In Connect mode, selecting two cards creates a connection immediately.
- Keep the existing selected-two-cards connection path as a right-rail action.
- Add deletion for selected cards and selected card connections.
- Deleting cards also removes connected edges.
- Card notes display at the bottom of resource/snippet cards and can be expanded/collapsed.
- Resource cards use their `ResourcePinModel.note` as their initial description; snippet cards use `SnippetModel.details`.
- The card itself remains focused on files/folders/prompts/commands. Notes support the card; they do not become workflow nodes.

## Layout Changes

- Workspace header remains compact.
- Canvas tab content uses all available height.
- Left rail width: roughly 180-220 px.
- Right rail width: roughly 220-260 px.
- Center canvas fills the remaining space.
- Reduce rounded container nesting and remove unused empty regions.
- Move low-frequency layout commands such as Align and Auto Arrange to the right rail.

## Verification

- `swift build`
- `swift test`
- `./script/build_and_run.sh --verify`
- Manual smoke check that cards can be selected, connected, deleted, and notes expanded.
