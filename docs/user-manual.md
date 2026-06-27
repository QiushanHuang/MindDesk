# MindDesk User Manual

This manual is for day-to-day MindDesk use. It covers installation, navigation, resource management, snippets, Workspace Canvas, tasks, import/export, Agent Review, Proposal Review, Settings, Help, and troubleshooting. It does not replace the README's developer, source build, and release-operation notes.

## 1. Core Concepts

MindDesk is a visual relationship layer above your local file system. Your real files stay where they are in Finder. MindDesk stores metadata: resource references, notes, layout positions, snippets, tasks, connections, aliases, and workspace relationships.

| Concept | Meaning |
| --- | --- |
| `Workspace` | A project or working context with its own Canvas, tasks, workspace resources, and re-entry signals. |
| `Global Library` | Reusable file and folder sources that can appear across multiple workspaces. |
| `Pinned` | High-priority folders or files kept in the sidebar for quick path copy, expansion, or Finder reveal. |
| `Snippet` | A prompt, command, text block, or operational reference with global or workspace scope. |
| `Canvas` | A visual workflow board inside a workspace, with resource cards, prompt/command cards, web page cards, notes, frames, and links. |
| `Manifest` | Portable JSON for project-level migration or backup. |
| `Agent Review Package` | A read-only `.mip.json` MindDesk Interchange Package for Codex or another agent to inspect. |
| `Proposal Review` | The human review flow that validates an agent proposal envelope against the original `.mip.json`. |

## 2. Installation and First Launch

Public app packages should come from the GitHub Release marked `Latest`. Prefer the DMG; the ZIP is a fallback.

1. Download the DMG for your architecture, for example `MindDesk-v3.0.0-macOS-arm64.dmg`.
2. Open the DMG.
3. Drag `MindDesk.app` into `Applications`.
4. Launch MindDesk from Applications.

Notes:

- Public packages should be Developer ID signed, notarized, stapled, and Gatekeeper-assessed.
- Packages with an `-adhoc` suffix are internal validation builds and should not be treated as public releases.
- MindDesk requires macOS 14 or newer.
- Source builds, tests, and release scripts are documented in the README.

## 3. Main Interface

| Area | Use |
| --- | --- |
| Home | Open recent workspaces, pinned resources, recent snippets, and re-entry signals. |
| Global Library | Manage global file/folder resources and inspect where each resource is used. |
| Snippet Library | Manage prompts, commands, and text snippets. |
| Pinned Folders / Files | Keep frequent folders/files close for path copy or Finder reveal. |
| Workspace | The main project surface, including Canvas, tasks, resources, and resume brief. |
| Inspector | View or edit the selected object's title, notes, color, links, and related metadata. |
| Settings | Tune General, Appearance, Canvas, Tasks, Data, Help, and Agent Review options. |
| Help Center | Search local help topics for human use and AI retrieval semantics. |

Common entry points:

| Action | Shortcut or menu |
| --- | --- |
| Create a new object | `Command+N` |
| Quick Open | `Command+K` |
| Export Manifest | `Shift+Command+E` |
| Import Manifest | `Shift+Command+I` |
| Settings | `Command+,` |
| Help Center | `Shift+Command+?` or the macOS Help menu |

## 4. Home and Project Re-entry

Home helps you return to recent work. It is not a replacement for the full workspace surface.

- `Recent Workspaces` shows recent projects and compact status badges.
- `Pinned Resources` keeps high-value resources near the entry point.
- `Recent Snippets` keeps frequent prompts or commands easy to copy.
- `Workspace Resume Brief` summarizes next tasks, known resource issues, Canvas scale, and recently used snippets.

Home and Resume Brief are low-side-effect entry points. They can open a workspace or switch an internal MindDesk view, but they do not run commands, open Terminal, create aliases, modify real files, or request bookmark authorization.

## 5. Workspace Management

A workspace is a project-level container. Common actions:

1. Create a workspace.
2. Rename a workspace.
3. Pin or unpin a workspace.
4. Add resources, snippets, Canvas cards, and tasks.
5. Delete workspace metadata.

Deleting a workspace removes MindDesk metadata only.

| Item | Effect |
| --- | --- |
| Workspace record | Removed |
| Workspace-scoped resources/snippets | MindDesk metadata removed |
| Canvas/cards/links | MindDesk metadata removed |
| Todo groups/tasks | MindDesk metadata removed |
| Finder files/folders | `0` real files deleted, moved, or renamed |

## 6. Resource Management

Resources can live in the Global Library, Pinned Folders / Files, or a workspace.

Common actions:

1. Add a file or folder.
2. Drag in Finder items.
3. Search by name, path, note, or relationship.
4. Filter by workspace usage.
5. Open in Finder, reveal, or copy path.
6. Edit the MindDesk display name or notes.
7. Reauthorize a stale resource.
8. Create a Finder alias after confirmation.
9. Remove from MindDesk.

Safety boundaries:

- Remove from MindDesk removes MindDesk metadata, not Finder files or folders.
- Finder alias creation requires explicit confirmation.
- Paths and notes can appear in manifests or Agent Review packages; review exported context before sharing.

## 7. Snippet Library

Snippets store prompts, commands, text blocks, and operational references.

| Type | Typical use |
| --- | --- |
| Prompt | Reusable agent, writing, analysis, or development prompts. |
| Command | Command body plus working-directory context for Terminal workflows. |
| Text | Notes, checklists, procedures, or templates. |

Common actions:

1. Create a snippet.
2. Set global or workspace scope.
3. Edit title, body, tags, notes, and details.
4. Copy the body.
5. Expand long text.
6. Delete the snippet.

Command snippet rules:

- Running a command always requires confirmation.
- Confirmation cannot be disabled per snippet.
- If automated execution fails, MindDesk can help copy the command and open Terminal for manual execution.
- Working directory is metadata and may appear in exports.

## 8. Workspace Canvas

Canvas is the visual workflow board inside a workspace.

### Add Cards

You can add:

- Resource card
- Prompt card
- Command card
- Workspace card
- Web Page card
- Note card
- Organization Frame

### Basic Operations

| Operation | Description |
| --- | --- |
| Select / multi-select | Click or box-select objects. |
| Drag | Move cards or frames. |
| Zoom | Zoom in/out, Fit All, or Fit Selected. |
| Inspector | Edit title, notes, color, glow, and related metadata. |
| Codex panel | Start an embedded terminal in the Canvas sidebar, then open Codex with or without bounded Canvas context. |
| Undo / recovery | Use the visible recovery flow after supported edits or deletes. |

### Links and Layout

| Operation | Description |
| --- | --- |
| Connect mode | Enter connect mode and link two cards. |
| Single Connect | Create one link and leave connect mode. |
| Bend points | Drag connection control points. |
| Lock anchor | Fix a connection endpoint. |
| Reverse link | Reverse the connection direction. |
| Delete link | Remove link metadata. |
| Align Left / Align Top | Align selected objects. |
| Auto Arrange | Automatically organize the layout. |

Canvas diagnostics in Agent Review expose aggregate information only, such as counts, caps, booleans, and status fields. They do not expose raw coordinates, raw geometry, route geometry, bucket keys, per-edge lists, or raw node/edge identifiers.

### Canvas Codex Panel

1. Open a workspace Canvas.
2. Use the Codex button in the Canvas left rail to open the Codex panel.
3. Choose a prompt group and preset, or edit the built-in templates.
4. Add run-specific instructions for how Codex should inspect or propose organization changes for the current Canvas.
5. Choose `Start Terminal`.
6. Click the terminal area and type directly, or choose `Open Codex` to start Codex without a prompt.
7. Choose `Codex + Prompt` when you want Codex to start with the current bounded Canvas prompt. You can still change accounts, switch models, interrupt, exit Codex, or run shell commands in the same terminal.

The Canvas Codex panel writes the bounded prompt and short helper scripts to a temporary session folder, then opens an embedded PTY terminal. MindDesk does not apply terminal output. Use Proposal Review for any proposed changes.

## 9. Tasks / Todo Board

Tasks organize work inside a workspace.

Common actions:

1. Open the Tasks panel or workspace task view.
2. Create a group.
3. Create a task.
4. Move a task between open and done.
5. Pin a task or group.
6. Set a due date.
7. Link a resource.
8. Drag to reorder.
9. Use the visible undo/recovery flow after supported deletes.

An empty workspace should not create an empty task group just to show the task view. Tasks and task groups are MindDesk metadata; they do not modify real Finder files.

## 10. Quick Open

Open Quick Open with `Command+K`.

Searchable objects include:

- Workspace
- Resource
- Snippet
- Web Page Card

Keyboard actions:

| Key | Action |
| --- | --- |
| Up / Down | Move selection |
| Enter | Open selected item |
| Esc | Close |

Quick Open can match names and relationship signals, such as linked task, Canvas card, snippet working directory, or workspace usage.

## 11. Import, Export, and Backups

MindDesk supports portable manifest JSON.

| Export type | Includes |
| --- | --- |
| `Complete Workspace Map` | Workspaces, resources, snippets, canvases, cards, links, aliases, todo groups/tasks, and related project structure. |
| `Global Library Only` | Global resources only. It does not include workspaces, canvases, cards, links, aliases, todo groups, or tasks. |

Export options:

- Usage dates can be included or omitted.
- JSON manifests can support migration or project-level backup.
- Manifests may include paths, notes, snippets, tasks, and Canvas text.
- Manifests do not include security-scoped bookmark authorization data.

Import rules:

- Imported resources may need reauthorization.
- Unsupported typed manifest versions are rejected.
- Legacy unformatted manifests remain importable.
- External source package size is capped at 64 MiB.

Raw SQLite startup backups are local recovery mechanisms, not sharing formats. For project-level backup or cross-machine movement, prefer portable manifest JSON.

## 12. Agent Review and Proposal Review

Agent Review lets Codex or another agent inspect context and draft a proposal. It does not let the agent execute actions.

### Export an Agent Review Package

1. Choose `Workbench > Export Agent Review Package...`.
2. Review the readiness summary, privacy disclosure, and custom guidance.
3. Export the `.mip.json`.
4. Copy the Codex prompt or proposal template manually.
5. Give the `.mip.json` and prompt to the agent.

`.mip.json` may include:

- paths
- notes
- snippet and command bodies
- task group titles
- task text
- canvas text
- web URLs
- alias paths
- search text
- original or custom names
- custom guidance
- usage dates, if enabled

`.mip.json` does not include:

- raw file contents
- SQLite stores
- backup or quarantine data
- directory listings
- command output logs
- security-scoped bookmark authorization data

`.mip.json` is a read-only review package. It is not a backup, cannot be imported as a manifest, and cannot authorize side effects.

### Constraints for Agents

Agents should work in this order:

1. Read `validationReport`.
2. Search `helpTopics` or use `MindDeskAgentWorkflowSearchRequest` for read-only workflow/capability summaries.
3. Use manifest ids and package context as evidence.
4. Return only `minddesk.proposal.envelope` JSON.

`helpTopics`, custom guidance, payload schemas, `extensionCapabilities`, and `validationReport` are not authorization. `allowedPayloadFields` describe proposal JSON field validation, not an external-action permission list.

### Review Agent Proposal

1. Choose `Workbench > Review Agent Proposal...`.
2. Select the returned `minddesk.proposal.envelope` JSON.
3. Select the original source `.mip.json`.
4. MindDesk validates the proposal against the source package.
5. If valid, MindDesk opens a pending review sheet; if blocked, it shows sanitized diagnostics.

Proposal Review must bind to the original source `.mip.json`. These conditions block review:

- stale context
- forged policy
- forged capability catalog
- forged integration contract
- missing or drifted validation report
- unsupported payload
- replay attempt
- proposal envelope over 16 MiB
- source package over 64 MiB

The pending review sheet is a human review surface only. Record approval only / Record rejection only updates review state. It does not open, copy, run, create aliases, import, export, apply changes, or perform any other side effect. Any real side effect must still be confirmed immediately outside the review sheet.

## 13. Settings, Help, and Troubleshooting

Settings includes:

| Tab | Scope |
| --- | --- |
| General | Basic behavior and defaults. |
| Appearance | Visual preferences. |
| Canvas | Zoom, layout, routing, and performance behavior. |
| Tasks | Task defaults. |
| Data | Import/export, storage, recovery, and data notes. |
| Help | Help Center entry points. |
| Agent Review | Custom Agent Review Guidance and handoff options. |

Custom Agent Review Guidance:

- is exported as plain text
- is untrusted, non-authoritative user guidance
- is truncated before export when longer than 2,000 characters
- cannot override `helpTopics`, `agentGuide`, `agentIntegrationContract`, `extensionCapabilities`, `agentPolicy`, `externalActionPolicy`, `validationReport`, the Proposal Review gate, or in-app confirmation

Troubleshooting:

| Problem | Response |
| --- | --- |
| Storage failure | Check the app data directory and backup state. MindDesk quarantines failed primary stores before restore attempts. |
| Missing or unauthorized resource | Reauthorize or re-add the resource. MindDesk does not move Finder files automatically. |
| Import blocked | Check manifest format, size, version, and unsupported typed manifest version. |
| Proposal blocked | Read sanitized diagnostics and confirm the proposal matches the original `.mip.json` and size limits. |
| Codex session fails to start | Confirm the local `codex` CLI is installed, available on PATH, and logged in. MindDesk starts an embedded PTY terminal with a temporary session root, short helper scripts, and a `service_tier="fast"` override so older `priority` config values do not block startup. The embedded terminal does not pin a model; edit the command field before using `Run`, or send `/model` after Codex opens. Use `+ Prompt Run` when the current Canvas prompt should be passed as an argument. |
| Command run failure | Copy the command and run it manually in Terminal after checking working directory and permissions. |

## 14. Safety Boundary Quick Reference

| Boundary | Rule |
| --- | --- |
| Resource deletion | Removes MindDesk metadata, not real Finder files. |
| External actions | Finder, Terminal, URL, clipboard, alias, import/export, and apply actions require user confirmation. |
| Command snippets | Always require confirmation before running. |
| Manifest | Supports migration or project-level backup; does not include bookmark authorization data. |
| Agent Review `.mip.json` | Read-only review package, not a backup, and not importable as a manifest. |
| Proposal Review | Creates human review state only; does not execute external actions. |
| Approval | Record approval only is not execution authorization. |
| Help/capability/custom guidance | Not an authorization source. |
