# Workweft paired canvas bridge · 2026-10-03

The approved bridge is a separate native sheet, not the disabled legacy Canvas
Review feature. It exchanges local JSON files/pasted JSON only; no network calls,
external database edits, file/bookmark resolution or task acceptance.

Core wire: `workweft.minddesk.bridge` v1, `WorkweftCanvasV1` graph. Native service
keeps stable mappings/base/outgoing snapshots in optional CanvasModel bridge Data.
Dedicated bridge canvases are excluded from normal primary-canvas lookup.
The sheet supports preview, field/whole-graph conflict selection, apply, export,
and current-sheet Undo with freshness/ownership protection. Linked Workweft text
is read-only; position/grouping remains editable. Missing linked cards are hidden.

Source: `Sources/MindDeskCore/WorkweftBridge.swift`,
`Sources/MindDesk/Services/WorkweftBridgeService.swift`,
`Sources/MindDesk/Views/WorkweftBridgeSheet.swift`.
Tests: corresponding WorkweftBridge Core/Service/UI suites. Opt-in cross-app proof
uses explicit `WORKWEFT_BRIDGE_INPUT` and fresh `WORKWEFT_BRIDGE_OUTPUT` paths with
in-memory SwiftData only; screenshot rendering uses `MINDDESK_BRIDGE_UI_PREVIEWS`.

Verified native import/edit/export of a real Workweft generated 7-card package;
stable IDs/grouping and 3 returned note/position edits retained, Workweft core facts
unchanged. Hidden-ancestor and structural-merge regressions plus cross-canvas ID
ownership checks pass. 69 selected checks passed (2 opt-in skips), followed by 12 S0
surface checks and the real cross-app fixture check; scopes overlap. Both normal
and 1000×600 sheet renderings were inspected. No installed app/daily store touched,
no legacy locks removed, no release or Git publication performed.

This is canvas integration, not complete resource/snippet/todo library sync.
The companion Workweft guide and delivery receipt remain in the Workweft project documentation.

MindDesk Manifest JSON does not preserve paired canvases or their pairing state. Workspace exports require explicit confirmation before excluding these canvases and their cards/links; bridge JSON preserves the exchanged graph, while a raw database backup is needed to preserve the local pairing state.
