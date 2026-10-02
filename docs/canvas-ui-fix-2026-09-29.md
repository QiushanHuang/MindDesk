# Canvas UI repair — 2026-09-29

Local changes based on `b4fb60c`. No commit, installation replacement, or publication.

## Changes

- Constrain the tool rail's scroll document to its allocated width. Replace native group/control minimum-width overflow with scoped section and button styles; preserve active/disabled states. Restore the web-card add button and use a menu for Glow so all choices fit.
- Keep card, frame, bend, and edge geometry in model coordinates. Apply the camera transform once; committing zoom/pan no longer changes the geometry's coordinate system or relayouts every card.
- Choose obstacle routing from the graph's bounded workload, independent of zoom, viewport, or gesture state. Cache routes using endpoint, obstacle, bend, and style values; geometry edits invalidate the affected cache entry. Cache size is bounded.
- Prepare vector paths outside the animation timeline. Draw static/selected strokes separately from moving accents. Use matching screen-space dash lengths and phase, preventing phase-wrap jumps at low zoom. Remove the baseline-zoom animation cutoff; retain density, complexity, reduced-motion, and editing-interaction limits.
- Improve the default note background's dark-mode contrast.

## Evidence

- Before-change native rendering reproduced side-rail overflow and the missing web-card icon.
- The new animation regression failed at actual zoom 0.12, 0.175, and 0.349 before removing the cutoff, then passed.
- Native bitmap tests verify the frame's width and height with detailed/lightweight content at zoom 0.175, 0.35, 0.7, and 1.4.
- Cache regression verifies route reuse for 120 unchanged requests, obstacle avoidance, and invalidation after obstacle, bend, endpoint, and arrow edits.
- Full suite: 293 app tests (2 opt-in integrations skipped) and 434 core tests. One obsolete assertion expecting low-zoom animation to stop was updated to the intended behavior and re-run successfully. Following the final dark-mode and expanded bitmap changes, all 5 affected regression/preview/core tests passed.
- `swift build -c release` succeeded. Candidate app passes `codesign --verify --deep --strict`. `git diff --check` passed.
- Actual SwiftUI/AppKit previews inspected at displayed zoom 50%, 100%, 200%, 400%, 800×620 window size, and dark mode. Only synthetic in-memory fixtures were used for rendering.

## Candidate and remaining acceptance

The independent candidate and previews are in `dist/local-updates/canvas-ui-20260929-1945/`.
Use `试用画布修复.command` to launch the candidate with a separate Application Support directory and preview bundle identity. That launcher has not been run here. Opening the `.app` directly uses the app's normal data-location behavior, so use the launcher for isolated testing.

Live desktop verification was blocked by `Sky Computer Use native pipe closed before response`. No real-time frame-rate measurement or end-to-end wheel/pinch/drag acceptance is claimed. The existing installation was not replaced. Remaining manual check: wheel/pinch across 100%, drag nested frames and bends, and assess animation smoothness on the user's actual canvas before installation.

## Installation authorized and completed

The user subsequently requested replacement. The running installed app exited normally through `NSRunningApplication.terminate()`; no force-quit was used. The approved binary was packaged with the installed production bundle identity and metadata, with build number raised from 30300 to 30301. The previous app was moved intact to `dist/local-updates/canvas-ui-20260929-1945/MindDesk-previous-30300.app` before replacement.

`/Applications/MindDesk.app` was replaced and reopened. Installed binary identity and code-signature integrity passed; the new process was verified at the installed path. The installer did not modify application data or preferences. The receipt is `dist/local-updates/canvas-ui-20260929-1945/installation-receipt.json`. The earlier live-interaction/frame-rate acceptance limitation remains.
