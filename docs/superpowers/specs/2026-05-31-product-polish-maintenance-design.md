# MindDesk Product Polish Maintenance Design

## Goal

Polish existing MindDesk behavior without adding new product surfaces. The release tightens current interaction rules, default state, workspace boundaries, and release metadata so the app feels more predictable under mouse, trackpad, canvas, task, import, and publishing workflows.

## Audit Inputs

Five gpt-5.5/xhigh subagents reviewed the product from separate angles:

- Product logic and information architecture.
- Canvas mouse and trackpad interaction.
- Settings, defaults, and persistence.
- Performance, stability, and data safety.
- Versioning, README, and GitHub release workflow.

## Selected Fixes

1. Canvas resource boundaries: workspace-scoped resources stay private to their owning workspace. The Canvas Add menu should expose global resources and current-workspace resources only.
2. Manifest import validation: workspace snippets and canvas resource nodes must not silently reference resources from another workspace.
3. Home recency: the Home "Recent Workspaces" section should use actual last-opened recency, not sidebar ordering.
4. Workspace open persistence: opening a workspace should update `lastOpenedAt` without marking project metadata as edited through `updatedAt`.
5. Task defaults: the workspace task panel should default closed for a cleaner canvas-first opening state, and merely viewing a canvas should not create a default task group.
6. Canvas interaction stability: scroll-wheel zoom should pass through horizontal or near-zero events, edge handles should remain visible during drag start, and node-backed transient state should reconcile when nodes disappear.
7. Geometry and performance guardrails: card sizes should reject non-finite or extreme persisted values, and peer-card detail should stay rich during small drags/pans while degrading on denser canvases.
8. Documentation and release metadata: update README, release notes, version, and regression checklist for a new small version.

## Explicit Non-Goals

- No automatic workspace-resource promotion to global.
- No new permission or sharing model.
- No new UI screens or major layout redesign.
- No silent command execution setting.
- No migration of real Finder files.

## Verification Strategy

- Add failing core tests first for policy-level behavior.
- Run `swift test`, `swift build`, `swift build -c release`, release metadata checks, whitespace checks, and local app bundle rebuild.
- Use macOS app launch verification and a focused UI smoke pass where tooling is available.
