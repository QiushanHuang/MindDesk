# MindDesk 3.3 — inspectable organization

The user authorized application replacement, first-principles acceptance, GitHub publication, README/release-note improvements and packages. After discovering that the original checkout predated the published release, the user explicitly chose to enhance the current preview → edit → apply → undo organizer. The old implementation is retained locally at `661134b`; it is not restored into the release.

Release base: `d540a03` (published main, v3.2.0). Work is isolated on `codex/agent-context-release`.

## User outcomes and acceptance

1. **Understand input:** selected editable cards are the only modification targets. Optional neighboring cards, parent frames and directed/labeled links provide read-only context. Show their counts and the exact structured request; file contents are never fetched.
2. **Express intent:** custom instructions and named local workflows are explicit inputs. Editing intent, scope or instructions retires the previous preview. Saved workflows have staged Save/Cancel editing and size limits.
3. **Evaluate output:** a generation is bound to its frozen request. Users may edit the preview or supply feedback to regenerate it. Strict operation/ID validation prevents the model from acting on context-only cards or inventing targets.
4. **Apply deliberately:** compare the source snapshot and included relationships immediately before applying. Source edits or changed reference context require a fresh preview. Preview generation alone changes no records.
5. **Recover:** generation failure/cancellation leaves source data unchanged; supported applied operations have Undo. Verify summary, grouping and task outcomes with synthetic data.
6. **Trust the release:** preserve current canvas features and dependency/runtime policy, pass local and GitHub checks, verify package identity/checksums, retain the old installed app and consistent data backup, replace only MindDesk, and confirm the installed binary and startup.

No unrestricted terminal, legacy proposal importer, dependencies or automatic file mutation are introduced. No real personal card content is used for model tests or documentation screenshots.

## Validation plan

- Baseline: 715 tests, 2 opt-in tests skipped, no failures on the release base.
- Behavioral checks: scope projection, read-only context, frozen request, invalid/stale preview, custom workflow persistence, retry/feedback, cancellation and apply/undo.
- Actual signed-in Codex with synthetic content, including a constrained desktop PATH.
- Native component previews in both appearances; real app interactions where the native automation bridge is available. Report any bridge limitation separately.
- Debug/Release suites, release-policy checks, script self-tests, clean-source package verifier, completed GitHub CI.
- Ad-hoc Apple-silicon DMG/ZIP with bilingual documentation and integrity evidence; no Developer ID identity is available on this host.

## Checked before publication

Debug and Release suites each passed 724 tests (opt-in skips as recorded in the public acceptance note). The actual Codex context/revision smoke passed twice using synthetic data. Six release/script guard suites, package-manifest policy and release metadata passed. Independent review accepted the three scoped UI fixes after re-review. Native automation remains unavailable after a session reset; preserve that explicit limit in the release notes. The user has authorized installation, GitHub publication and packages for this reviewed scope.
