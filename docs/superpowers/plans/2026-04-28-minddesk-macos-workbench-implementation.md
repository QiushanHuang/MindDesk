# MindDesk macOS Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable native macOS MVP for MindDesk with workspaces, resource pins, snippets, Finder/Terminal integration, a freeform canvas, and JSON backup.

**Architecture:** Use a SwiftPM-first macOS app. `MindDeskCore` holds pure, testable helpers and DTOs; the `MindDesk` executable holds SwiftUI, SwiftData models, and AppKit services. System integrations are isolated behind services so TCC-sensitive behavior can be manually verified and lower-level logic can still be unit tested.

**Tech Stack:** Swift 6.3, SwiftUI, SwiftData, AppKit, SwiftPM, XCTest, Apple Events through `NSAppleScript`, project-local `.app` bundle staging.

---

## File Map

- Create `Package.swift`: SwiftPM package with `MindDeskCore`, `MindDesk`, and `MindDeskCoreTests`.
- Create `Sources/MindDesk/main.swift`: app entry point and SwiftData container.
- Create `Sources/MindDeskCore/ShellQuoter.swift`: shell and AppleScript quoting.
- Create `Sources/MindDeskCore/CanvasLayoutEngine.swift`: auto-arrange and alignment helpers.
- Create `Sources/MindDeskCore/ExportManifest.swift`: JSON manifest DTOs.
- Create `Sources/MindDesk/Models/WorkbenchModels.swift`: SwiftData models.
- Create `Sources/MindDesk/Services/SystemServices.swift`: clipboard, Finder, bookmark, Terminal, alias, import/export services.
- Create `Sources/MindDesk/Views/ContentView.swift`: NavigationSplitView shell, home, library, workspace, inspector.
- Create `Sources/MindDesk/Views/ResourceSnippetViews.swift`: resource and snippet list/editor views.
- Create `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`: canvas rendering and interactions.
- Create `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`: unit tests for quoting, canvas layout, and manifest round trip.
- Create `script/build_and_run.sh`: build, stage `.app`, launch, logs, telemetry, verify.
- Create `.codex/environments/environment.toml`: Codex Run action.

## Task 1: SwiftPM Scaffold and Core Tests

**Files:**
- Create: `Package.swift`
- Create: `Sources/MindDeskCore/ShellQuoter.swift`
- Create: `Sources/MindDeskCore/CanvasLayoutEngine.swift`
- Create: `Sources/MindDeskCore/ExportManifest.swift`
- Create: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] **Step 1: Write failing core tests**

```swift
import XCTest
@testable import MindDeskCore

final class CoreBehaviorTests: XCTestCase {
    func testShellQuoterHandlesSpacesAndSingleQuotes() {
        XCTAssertEqual(ShellQuoter.singleQuote("/tmp/My Folder"), "'/tmp/My Folder'")
        XCTAssertEqual(ShellQuoter.singleQuote("/tmp/Joshua's Work"), "'/tmp/Joshua'\\''s Work'")
    }

    func testCanvasAutoArrangeProducesGridPositions() {
        let nodes = [
            CanvasLayoutNode(id: "a", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "c", x: 0, y: 0, width: 120, height: 80)
        ]
        let arranged = CanvasLayoutEngine.autoArrange(nodes, columns: 2, spacing: 40)
        XCTAssertEqual(arranged[0].x, 0)
        XCTAssertEqual(arranged[1].x, 160)
        XCTAssertEqual(arranged[2].y, 120)
    }

    func testManifestRoundTripKeepsSchemaVersion() throws {
        let manifest = ExportManifest(schemaVersion: 1, exportedAt: Date(timeIntervalSince1970: 0), workspaces: [], resources: [], snippets: [], canvases: [], nodes: [], edges: [], aliases: [])
        let data = try JSONEncoder.minddesk.encode(manifest)
        let decoded = try JSONDecoder.minddesk.decode(ExportManifest.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `swift test --filter CoreBehaviorTests`

Expected: fails because `MindDeskCore` and the tested types do not exist.

- [ ] **Step 3: Implement the core target**

Create the package, quoter, layout engine, and manifest DTOs exactly under the paths listed in the File Map section. `ShellQuoter.singleQuote(_:)` must use POSIX-safe single-quote escaping. `ExportManifest` must not include bookmark data fields.

- [ ] **Step 4: Run tests and verify pass**

Run: `swift test --filter CoreBehaviorTests`

Expected: all `CoreBehaviorTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/MindDeskCore Tests/MindDeskCoreTests
git commit -m "feat: add minddesk core package"
```

## Task 2: SwiftData Models and Seeded App Shell

**Files:**
- Create: `Sources/MindDesk/main.swift`
- Create: `Sources/MindDesk/Models/WorkbenchModels.swift`
- Create: `Sources/MindDesk/Views/ContentView.swift`

- [ ] **Step 1: Write app model smoke test by compiling**

Run: `swift build`

Expected: fails because executable target files do not exist.

- [ ] **Step 2: Add app entry point and models**

Implement `MindDeskApp`, SwiftData model container, and models for `WorkspaceModel`, `ResourcePinModel`, `SnippetModel`, `CanvasNodeModel`, `CanvasEdgeModel`, and `FinderAliasRecordModel`. Use string IDs for cross-object refs and enum raw values for kind/status/scope.

- [ ] **Step 3: Add a seeded `ContentView`**

Implement `NavigationSplitView` with sidebar entries Home, Global Library, and Workspaces. Seed one sample workspace and one sample prompt/command only if stores are empty, so first launch is usable without fake success states.

- [ ] **Step 4: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/MindDesk
git commit -m "feat: add app shell and models"
```

## Task 3: System Services

**Files:**
- Create: `Sources/MindDesk/Services/SystemServices.swift`
- Modify: `Sources/MindDesk/Models/WorkbenchModels.swift`

- [ ] **Step 1: Compile before services exist**

Run: `swift build`

Expected: current build passes; service types are not present.

- [ ] **Step 2: Implement services**

Implement:

- `ClipboardService.copy(_:)` using `NSPasteboard`.
- `FinderService.open(_:)` and `FinderService.reveal(_:)` using `NSWorkspace`.
- `BookmarkService.makeBookmark(for:)` and `resolveBookmark(_:fallbackPath:)` using security-scoped bookmark APIs when possible.
- `TerminalService.open(at:)` and `run(command:workingDirectory:)` using Terminal.app Apple Events. Build the command with `ShellQuoter.singleQuote`.
- `AliasService.createAlias(source:destinationDirectory:name:)` using Finder Apple Events and visible error values.
- `ImportExportService` stubs that encode/decode the current schema manifest and deliberately omit bookmark data.

- [ ] **Step 3: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/MindDesk/Services Sources/MindDesk/Models
git commit -m "feat: add macOS system services"
```

## Task 4: Resource and Snippet Management UI

**Files:**
- Create: `Sources/MindDesk/Views/ResourceSnippetViews.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`

- [ ] **Step 1: Build before UI integration**

Run: `swift build`

Expected: current build passes; resource/snippet editors are not available.

- [ ] **Step 2: Implement resource workflows**

Add file/folder picking with `NSOpenPanel`, create `ResourcePinModel` records, and wire actions for open, reveal, copy path, reauthorize, and create Finder alias. Every alias operation must surface success or failure text.

- [ ] **Step 3: Implement snippet workflows**

Add prompt/command creation and editing. Wire copy for both kinds. For commands, wire open Terminal and confirmed run through `TerminalService`; failed Automation must show the fallback message.

- [ ] **Step 4: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/MindDesk/Views
git commit -m "feat: add resources and snippets UI"
```

## Task 5: Freeform Canvas

**Files:**
- Create: `Sources/MindDesk/Canvas/WorkspaceCanvasView.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `Sources/MindDesk/Models/WorkbenchModels.swift`

- [ ] **Step 1: Run core tests**

Run: `swift test --filter CoreBehaviorTests`

Expected: pass before UI integration.

- [ ] **Step 2: Implement canvas MVP**

Implement a native SwiftUI canvas that can:

- Add note/resource/snippet nodes.
- Drag nodes and persist positions.
- Zoom and pan.
- Select one or multiple nodes.
- Box-select nodes.
- Create manual edges between selected nodes.
- Align left and align top.
- Auto-arrange through `CanvasLayoutEngine`.
- Show selected node details in the inspector.

- [ ] **Step 3: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/MindDesk/Canvas Sources/MindDesk/Views Sources/MindDesk/Models
git commit -m "feat: add workspace canvas"
```

## Task 6: Backup Import/Export and Run Script

**Files:**
- Modify: `Sources/MindDesk/Services/SystemServices.swift`
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

- [ ] **Step 1: Run tests first**

Run: `swift test`

Expected: all current tests pass.

- [ ] **Step 2: Implement backup actions**

Wire export to `NSSavePanel` and import to `NSOpenPanel`. Export must include schemaVersion and core records but not bookmark data. Import must mark resource pins as unavailable until reauthorized.

- [ ] **Step 3: Add run script and Codex action**

Create a project-local script that kills existing `MindDesk`, builds with SwiftPM, stages `dist/MindDesk.app`, writes a minimal Info.plist, and launches with `/usr/bin/open -n`. Add `--logs`, `--telemetry`, and `--verify` modes.

- [ ] **Step 4: Verify**

Run: `./script/build_and_run.sh --verify`

Expected: Swift build succeeds, app bundle is staged, app process launches, and `pgrep -x MindDesk` succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/MindDesk/Services Sources/MindDesk/Views script .codex
git commit -m "feat: add backup and run workflow"
```

## Task 7: Final Verification and Review

**Files:**
- Modify only files needed to fix verification failures.

- [ ] **Step 1: Run full test suite**

Run: `swift test`

Expected: pass.

- [ ] **Step 2: Run app verification**

Run: `./script/build_and_run.sh --verify`

Expected: pass.

- [ ] **Step 3: Manual TCC checklist**

Verify manually:

- Add a folder pin, copy path, open, reveal in Finder.
- Create a Finder alias to a temporary user-selected folder; if Automation is denied, confirm the app reports the error.
- Copy a prompt snippet.
- Copy a command snippet.
- Open Terminal at a working directory.
- Confirm-run a harmless command such as `printf minddesk-ok`; if Automation is denied, confirm fallback is shown.
- Add and move canvas nodes; create an edge; auto-arrange; relaunch and confirm positions persist.
- Export JSON; import it; confirm imported resources require reauthorization.

- [ ] **Step 4: Commit fixes**

```bash
git add .
git commit -m "fix: complete minddesk verification"
```
