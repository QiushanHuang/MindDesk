import Foundation
import MindDeskCore
import XCTest
@testable import MindDesk

@MainActor
final class WorkspaceWindowScopeControllerTests: XCTestCase {
    func testTwoControllersHaveDistinctWindowSessionIDsAndContentViewOwnsOneStableStateObject() throws {
        let firstWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000048")
        )
        let secondWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000049")
        )
        let firstController = WorkspaceWindowScopeController()
        let secondController = WorkspaceWindowScopeController()
        let firstInjectedController = WorkspaceWindowScopeController(
            windowSessionID: firstWindowSessionID
        )
        let secondInjectedController = WorkspaceWindowScopeController(
            windowSessionID: secondWindowSessionID
        )

        XCTAssertNotEqual(firstController.windowSessionID, secondController.windowSessionID)
        XCTAssertEqual(firstInjectedController.windowSessionID, firstWindowSessionID)
        XCTAssertEqual(secondInjectedController.windowSessionID, secondWindowSessionID)
        XCTAssertFalse(
            propertyIsWritable(firstController, \.windowSessionID),
            "The per-window identity must not expose a writable key path"
        )
    }

    func testFocusStartsWithNilResolutionAndRepeatingWorkspaceIsIdempotent() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000049")
        )
        let controller = WorkspaceWindowScopeController(windowSessionID: windowSessionID)
        let initialPendingFocus: WorkspaceFocusScopeIdentity? = controller.pendingFocus
        let initialPrimaryResolution: WorkspacePrimaryCanvasResolution? =
            controller.primaryResolution

        XCTAssertNil(initialPendingFocus)
        XCTAssertNil(initialPrimaryResolution)

        let firstReturnedFocus = controller.focus(workspaceID: "workspace-A")
        let firstStoredFocus: WorkspaceFocusScopeIdentity = try XCTUnwrap(
            controller.pendingFocus
        )

        XCTAssertEqual(firstReturnedFocus, firstStoredFocus)
        XCTAssertEqual(firstStoredFocus.windowSessionID, windowSessionID)
        XCTAssertEqual(firstStoredFocus.workspaceID, "workspace-A")
        XCTAssertNil(controller.primaryResolution)

        let repeatedFocus = controller.focus(workspaceID: "workspace-A")

        XCTAssertEqual(repeatedFocus, firstStoredFocus)
        XCTAssertEqual(controller.pendingFocus, Optional(firstStoredFocus))
        XCTAssertNil(controller.primaryResolution)
    }

    func testFocusAToBToACreatesFreshRevisions() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000050")
        )
        let controller = WorkspaceWindowScopeController(windowSessionID: windowSessionID)

        let firstA = controller.focus(workspaceID: "workspace-A")
        XCTAssertEqual(firstA.windowSessionID, windowSessionID)
        XCTAssertEqual(firstA.workspaceID, "workspace-A")
        XCTAssertEqual(controller.pendingFocus, Optional(firstA))
        XCTAssertNil(controller.primaryResolution)

        let focusB = controller.focus(workspaceID: "workspace-B")
        XCTAssertEqual(focusB.windowSessionID, windowSessionID)
        XCTAssertEqual(focusB.workspaceID, "workspace-B")
        XCTAssertEqual(controller.pendingFocus, Optional(focusB))
        XCTAssertNil(controller.primaryResolution)

        let secondA = controller.focus(workspaceID: "workspace-A")
        XCTAssertEqual(secondA.windowSessionID, windowSessionID)
        XCTAssertEqual(secondA.workspaceID, "workspace-A")
        XCTAssertEqual(controller.pendingFocus, Optional(secondA))
        XCTAssertNil(controller.primaryResolution)

        XCTAssertNotEqual(firstA.focusRevision, focusB.focusRevision)
        XCTAssertNotEqual(focusB.focusRevision, secondA.focusRevision)
        XCTAssertNotEqual(firstA.focusRevision, secondA.focusRevision)
    }

    func testInitialUniqueMissingAndDuplicateBindingsUseSameRevisionWithUniqueOnlyBound() throws {
        let uniqueWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000051")
        )
        let missingWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000052")
        )
        let duplicateWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000053")
        )

        let uniqueController = WorkspaceWindowScopeController(
            windowSessionID: uniqueWindowSessionID
        )
        let missingController = WorkspaceWindowScopeController(
            windowSessionID: missingWindowSessionID
        )
        let duplicateController = WorkspaceWindowScopeController(
            windowSessionID: duplicateWindowSessionID
        )

        let uniqueFocus = uniqueController.focus(workspaceID: "workspace-A")
        let missingFocus = missingController.focus(workspaceID: "workspace-A")
        let duplicateFocus = duplicateController.focus(workspaceID: "workspace-A")

        let uniqueResolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-unique"
        )
        let missingResolution: WorkspacePrimaryCanvasResolution = .missing
        let duplicateResolution: WorkspacePrimaryCanvasResolution = .duplicate(
            canvasIDs: ["canvas-a", "canvas-b"]
        )

        let uniqueResult: WorkspaceCanvasBindingResult = uniqueController.bind(
            uniqueResolution,
            for: uniqueFocus
        )
        let missingResult: WorkspaceCanvasBindingResult = missingController.bind(
            missingResolution,
            for: missingFocus
        )
        let duplicateResult: WorkspaceCanvasBindingResult = duplicateController.bind(
            duplicateResolution,
            for: duplicateFocus
        )

        let uniqueBoundCanvas: WorkspaceCanvasScopeIdentity = try XCTUnwrap(
            uniqueController.boundCanvas
        )

        XCTAssertEqual(
            uniqueResult,
            WorkspaceCanvasBindingResult.bound(uniqueBoundCanvas)
        )
        XCTAssertEqual(uniqueBoundCanvas.focus, uniqueFocus)
        XCTAssertEqual(uniqueBoundCanvas.canvasID, "canvas-unique")
        XCTAssertEqual(uniqueController.pendingFocus, Optional(uniqueFocus))
        XCTAssertEqual(uniqueController.primaryResolution, Optional(uniqueResolution))
        XCTAssertEqual(uniqueController.boundCanvas, Optional(uniqueBoundCanvas))

        XCTAssertEqual(
            missingResult,
            WorkspaceCanvasBindingResult.unbound(
                focus: missingFocus,
                resolution: missingResolution
            )
        )
        XCTAssertEqual(missingController.pendingFocus, Optional(missingFocus))
        XCTAssertEqual(missingController.primaryResolution, Optional(missingResolution))
        XCTAssertNil(missingController.boundCanvas)

        XCTAssertEqual(
            duplicateResult,
            WorkspaceCanvasBindingResult.unbound(
                focus: duplicateFocus,
                resolution: duplicateResolution
            )
        )
        XCTAssertEqual(duplicateController.pendingFocus, Optional(duplicateFocus))
        XCTAssertEqual(
            duplicateController.primaryResolution,
            Optional(duplicateResolution)
        )
        XCTAssertNil(duplicateController.boundCanvas)
    }

    func testStaleBindReturnsStaleWithoutChangingControllerState() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000054")
        )
        let controller = WorkspaceWindowScopeController(windowSessionID: windowSessionID)

        let focusA = controller.focus(workspaceID: "workspace-A")
        let initialResolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-A"
        )
        let initialResult: WorkspaceCanvasBindingResult = controller.bind(
            initialResolution,
            for: focusA
        )
        let initialBoundCanvas: WorkspaceCanvasScopeIdentity = try XCTUnwrap(
            controller.boundCanvas
        )

        XCTAssertEqual(
            initialResult,
            WorkspaceCanvasBindingResult.bound(initialBoundCanvas)
        )
        XCTAssertEqual(initialBoundCanvas.focus, focusA)
        XCTAssertEqual(initialBoundCanvas.canvasID, "canvas-A")
        XCTAssertEqual(controller.pendingFocus, Optional(focusA))
        XCTAssertEqual(controller.primaryResolution, Optional(initialResolution))
        XCTAssertEqual(controller.boundCanvas, Optional(initialBoundCanvas))

        let focusB = controller.focus(workspaceID: "workspace-B")
        let pendingFocusBeforeStaleBind = controller.pendingFocus
        let primaryResolutionBeforeStaleBind = controller.primaryResolution
        let boundCanvasBeforeStaleBind = controller.boundCanvas

        XCTAssertEqual(pendingFocusBeforeStaleBind, Optional(focusB))
        XCTAssertNil(primaryResolutionBeforeStaleBind)
        guard controller.boundCanvas == nil else {
            XCTFail("Expected focus B to clear the bound canvas before a stale bind")
            return
        }

        let staleResolution: WorkspacePrimaryCanvasResolution = .missing
        let staleResult: WorkspaceCanvasBindingResult = controller.bind(
            staleResolution,
            for: focusA
        )

        XCTAssertEqual(staleResult, WorkspaceCanvasBindingResult.stale)
        XCTAssertEqual(controller.pendingFocus, pendingFocusBeforeStaleBind)
        XCTAssertEqual(controller.primaryResolution, primaryResolutionBeforeStaleBind)
        XCTAssertEqual(controller.boundCanvas, boundCanvasBeforeStaleBind)
    }

    func testEqualResolutionRebindIsIdempotent() throws {
        let uniqueWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000055")
        )
        let missingWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000056")
        )
        let duplicateWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000057")
        )

        let uniqueController = WorkspaceWindowScopeController(
            windowSessionID: uniqueWindowSessionID
        )
        let missingController = WorkspaceWindowScopeController(
            windowSessionID: missingWindowSessionID
        )
        let duplicateController = WorkspaceWindowScopeController(
            windowSessionID: duplicateWindowSessionID
        )

        let uniqueFocus = uniqueController.focus(workspaceID: "workspace-A")
        let missingFocus = missingController.focus(workspaceID: "workspace-A")
        let duplicateFocus = duplicateController.focus(workspaceID: "workspace-A")

        let uniqueResolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-A"
        )
        let missingResolution: WorkspacePrimaryCanvasResolution = .missing
        let duplicateResolution: WorkspacePrimaryCanvasResolution = .duplicate(
            canvasIDs: ["canvas-A", "canvas-B"]
        )

        let initialUniqueResult = uniqueController.bind(
            uniqueResolution,
            for: uniqueFocus
        )
        let uniquePendingFocusBeforeRebind = uniqueController.pendingFocus
        let uniquePrimaryResolutionBeforeRebind = uniqueController.primaryResolution
        let uniqueBoundCanvasBeforeRebind = uniqueController.boundCanvas

        let repeatedUniqueResult = uniqueController.bind(
            uniqueResolution,
            for: uniqueFocus
        )

        XCTAssertEqual(repeatedUniqueResult, initialUniqueResult)
        XCTAssertEqual(uniqueController.pendingFocus, uniquePendingFocusBeforeRebind)
        XCTAssertEqual(
            uniqueController.primaryResolution,
            uniquePrimaryResolutionBeforeRebind
        )
        XCTAssertEqual(uniqueController.boundCanvas, uniqueBoundCanvasBeforeRebind)

        let initialMissingResult = missingController.bind(
            missingResolution,
            for: missingFocus
        )
        let missingPendingFocusBeforeRebind = missingController.pendingFocus
        let missingPrimaryResolutionBeforeRebind = missingController.primaryResolution
        let missingBoundCanvasBeforeRebind = missingController.boundCanvas

        let repeatedMissingResult = missingController.bind(
            missingResolution,
            for: missingFocus
        )

        XCTAssertEqual(repeatedMissingResult, initialMissingResult)
        XCTAssertEqual(missingController.pendingFocus, missingPendingFocusBeforeRebind)
        XCTAssertEqual(
            missingController.primaryResolution,
            missingPrimaryResolutionBeforeRebind
        )
        XCTAssertEqual(missingController.boundCanvas, missingBoundCanvasBeforeRebind)

        let initialDuplicateResult = duplicateController.bind(
            duplicateResolution,
            for: duplicateFocus
        )
        let duplicatePendingFocusBeforeRebind = duplicateController.pendingFocus
        let duplicatePrimaryResolutionBeforeRebind = duplicateController.primaryResolution
        let duplicateBoundCanvasBeforeRebind = duplicateController.boundCanvas

        let repeatedDuplicateResult = duplicateController.bind(
            duplicateResolution,
            for: duplicateFocus
        )

        XCTAssertEqual(repeatedDuplicateResult, initialDuplicateResult)
        XCTAssertEqual(
            duplicateController.pendingFocus,
            duplicatePendingFocusBeforeRebind
        )
        XCTAssertEqual(
            duplicateController.primaryResolution,
            duplicatePrimaryResolutionBeforeRebind
        )
        XCTAssertEqual(duplicateController.boundCanvas, duplicateBoundCanvasBeforeRebind)
    }

    func testEveryUnequalResolutionIncludingChangedDuplicatePayloadRotatesRevision() throws {
        let transitions: [(
            windowSessionID: String,
            initial: WorkspacePrimaryCanvasResolution,
            target: WorkspacePrimaryCanvasResolution
        )] = [
            (
                "00000000-0000-0000-0000-000000000058",
                .unique(canvasID: "canvas-A"),
                .missing
            ),
            (
                "00000000-0000-0000-0000-000000000059",
                .unique(canvasID: "canvas-A"),
                .duplicate(canvasIDs: ["canvas-A", "canvas-B"])
            ),
            (
                "00000000-0000-0000-0000-000000000060",
                .unique(canvasID: "canvas-A"),
                .unique(canvasID: "canvas-B")
            ),
            (
                "00000000-0000-0000-0000-000000000061",
                .missing,
                .unique(canvasID: "canvas-A")
            ),
            (
                "00000000-0000-0000-0000-000000000062",
                .missing,
                .duplicate(canvasIDs: ["canvas-A", "canvas-B"])
            ),
            (
                "00000000-0000-0000-0000-000000000063",
                .duplicate(canvasIDs: ["canvas-A", "canvas-B"]),
                .missing
            ),
            (
                "00000000-0000-0000-0000-000000000064",
                .duplicate(canvasIDs: ["canvas-A", "canvas-B"]),
                .unique(canvasID: "canvas-A")
            ),
            (
                "00000000-0000-0000-0000-000000000065",
                .duplicate(canvasIDs: ["canvas-A", "canvas-B"]),
                .duplicate(canvasIDs: ["canvas-A", "canvas-C"])
            ),
        ]

        for transition in transitions {
            let windowSessionID = try XCTUnwrap(
                UUID(uuidString: transition.windowSessionID)
            )
            let controller = WorkspaceWindowScopeController(
                windowSessionID: windowSessionID
            )
            let originalFocus = controller.focus(workspaceID: "workspace-A")
            let initialResult = controller.bind(
                transition.initial,
                for: originalFocus
            )

            switch transition.initial {
            case let .unique(canvasID):
                let initialBoundCanvas = try XCTUnwrap(controller.boundCanvas)
                XCTAssertEqual(
                    initialResult,
                    WorkspaceCanvasBindingResult.bound(initialBoundCanvas)
                )
                XCTAssertEqual(initialBoundCanvas.focus, originalFocus)
                XCTAssertEqual(initialBoundCanvas.canvasID, canvasID)
            case .missing, .duplicate:
                XCTAssertEqual(
                    initialResult,
                    WorkspaceCanvasBindingResult.unbound(
                        focus: originalFocus,
                        resolution: transition.initial
                    )
                )
                XCTAssertNil(controller.boundCanvas)
            }

            XCTAssertEqual(controller.pendingFocus, Optional(originalFocus))
            XCTAssertEqual(
                controller.primaryResolution,
                Optional(transition.initial)
            )

            let transitionResult = controller.bind(
                transition.target,
                for: originalFocus
            )

            if case .stale = transitionResult {
                XCTFail("Expected unequal resolution to rotate the focus revision")
                continue
            }

            let rotatedFocus = try XCTUnwrap(controller.pendingFocus)
            XCTAssertEqual(rotatedFocus.windowSessionID, windowSessionID)
            XCTAssertEqual(rotatedFocus.workspaceID, "workspace-A")
            XCTAssertNotEqual(rotatedFocus.focusRevision, originalFocus.focusRevision)
            XCTAssertEqual(
                controller.primaryResolution,
                Optional(transition.target)
            )

            switch transition.target {
            case let .unique(canvasID):
                let rotatedBoundCanvas = try XCTUnwrap(controller.boundCanvas)
                XCTAssertEqual(rotatedBoundCanvas.focus, rotatedFocus)
                XCTAssertEqual(rotatedBoundCanvas.canvasID, canvasID)
                XCTAssertEqual(
                    transitionResult,
                    WorkspaceCanvasBindingResult.bound(rotatedBoundCanvas)
                )
            case .missing, .duplicate:
                XCTAssertEqual(
                    transitionResult,
                    WorkspaceCanvasBindingResult.unbound(
                        focus: rotatedFocus,
                        resolution: transition.target
                    )
                )
                XCTAssertNil(controller.boundCanvas)
            }
        }
    }

    func testExactInvalidationRotatesToNilResolutionWhileStaleInvalidationIsNoOp() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000066")
        )
        let controller = WorkspaceWindowScopeController(
            windowSessionID: windowSessionID
        )
        let originalFocus = controller.focus(workspaceID: "workspace-A")
        let originalResolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-A"
        )
        let originalResult = controller.bind(
            originalResolution,
            for: originalFocus
        )
        let originalBoundCanvas = try XCTUnwrap(controller.boundCanvas)

        XCTAssertEqual(
            originalResult,
            WorkspaceCanvasBindingResult.bound(originalBoundCanvas)
        )
        XCTAssertEqual(originalBoundCanvas.focus, originalFocus)
        XCTAssertEqual(originalBoundCanvas.canvasID, "canvas-A")
        XCTAssertEqual(controller.pendingFocus, Optional(originalFocus))
        XCTAssertEqual(controller.primaryResolution, Optional(originalResolution))
        XCTAssertEqual(controller.boundCanvas, Optional(originalBoundCanvas))

        let invalidatedFocus = try XCTUnwrap(
            controller.invalidatePrimaryResolution(for: originalFocus)
        )

        XCTAssertEqual(invalidatedFocus.windowSessionID, windowSessionID)
        XCTAssertEqual(invalidatedFocus.workspaceID, "workspace-A")
        XCTAssertNotEqual(
            invalidatedFocus.focusRevision,
            originalFocus.focusRevision
        )
        XCTAssertEqual(controller.pendingFocus, Optional(invalidatedFocus))
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)

        let pendingFocusBeforeStaleInvalidation = controller.pendingFocus
        let primaryResolutionBeforeStaleInvalidation = controller.primaryResolution
        let boundCanvasBeforeStaleInvalidation = controller.boundCanvas

        XCTAssertNil(controller.invalidatePrimaryResolution(for: originalFocus))
        XCTAssertEqual(
            controller.pendingFocus,
            pendingFocusBeforeStaleInvalidation
        )
        XCTAssertEqual(
            controller.primaryResolution,
            primaryResolutionBeforeStaleInvalidation
        )
        XCTAssertEqual(
            controller.boundCanvas,
            boundCanvasBeforeStaleInvalidation
        )
    }

    func testScopeIdentitiesRemainAppOnlyNonCodableAndControllerConstructed() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let controllerSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/MindDesk/Models/WorkspaceWindowScopeController.swift"
            ),
            encoding: .utf8
        )

        let exactInternalDeclarations = [
            "struct WorkspaceFocusRevision: Hashable, Sendable {",
            "struct WorkspaceFocusScopeIdentity: Hashable, Sendable {",
            "struct WorkspaceCanvasScopeIdentity: Hashable, Sendable {",
            "enum WorkspaceScopeOperationIdentity: Hashable, Sendable {",
            "@MainActor\nfinal class WorkspaceWindowScopeController: ObservableObject {",
        ]
        for declaration in exactInternalDeclarations {
            XCTAssertEqual(
                controllerSource.components(separatedBy: declaration).count - 1,
                1,
                "Expected exactly one default-internal declaration: \(declaration)"
            )
        }

        let forbiddenAccessDeclarations = [
            "public struct WorkspaceFocusRevision",
            "open struct WorkspaceFocusRevision",
            "public struct WorkspaceFocusScopeIdentity",
            "open struct WorkspaceFocusScopeIdentity",
            "public struct WorkspaceCanvasScopeIdentity",
            "open struct WorkspaceCanvasScopeIdentity",
            "public enum WorkspaceScopeOperationIdentity",
            "open enum WorkspaceScopeOperationIdentity",
            "public final class WorkspaceWindowScopeController",
            "public class WorkspaceWindowScopeController",
            "open class WorkspaceWindowScopeController",
        ]
        for declaration in forbiddenAccessDeclarations {
            XCTAssertFalse(
                controllerSource.contains(declaration),
                "Scope authority must stay app-only: \(declaration)"
            )
        }

        let exactFileprivateIdentityInitializers = [
            "fileprivate init(rawValue: Foundation.UUID)",
            "fileprivate init(\n        windowSessionID: Foundation.UUID,",
            "fileprivate init(focus: WorkspaceFocusScopeIdentity, canvasID: String)",
        ]
        XCTAssertEqual(
            controllerSource.components(separatedBy: "fileprivate init(").count - 1,
            3
        )
        for initializer in exactFileprivateIdentityInitializers {
            XCTAssertEqual(
                controllerSource.components(separatedBy: initializer).count - 1,
                1,
                "Expected exactly one controller-file-only raw initializer: \(initializer)"
            )
        }
        XCTAssertEqual(
            controllerSource.components(
                separatedBy: "fileprivate let rawValue: Foundation.UUID"
            ).count - 1,
            1
        )

        let forbiddenExposureTokens = [
            "Codable",
            "Encodable",
            "Decodable",
            "@Model",
            "SwiftData",
            "ModelContext",
            "UserDefaults",
            "@AppStorage",
            "@SceneStorage",
            "Manifest",
            "Review",
            "Logger",
            "OSLog",
            "os_log",
            "NSLog(",
            "print(",
            "debugPrint(",
            "FileManager",
            "JSONEncoder",
            "JSONDecoder",
            "PropertyListEncoder",
            "PropertyListDecoder",
            "NSManagedObjectContext",
            "NSPersistent",
        ]
        for token in forbiddenExposureTokens {
            XCTAssertFalse(
                controllerSource.contains(token),
                "Scope identities must not expose or persist through \(token)"
            )
        }

        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000067")
        )
        let controller = WorkspaceWindowScopeController(
            windowSessionID: windowSessionID
        )
        let focus = controller.focus(workspaceID: "workspace-A")
        let resolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-A"
        )
        let result = controller.bind(resolution, for: focus)
        let boundCanvas = try XCTUnwrap(controller.boundCanvas)

        XCTAssertEqual(focus.windowSessionID, windowSessionID)
        XCTAssertEqual(focus.workspaceID, "workspace-A")
        XCTAssertEqual(boundCanvas.focus, focus)
        XCTAssertEqual(boundCanvas.canvasID, "canvas-A")
        XCTAssertEqual(result, WorkspaceCanvasBindingResult.bound(boundCanvas))
        XCTAssertEqual(controller.pendingFocus, Optional(focus))
        XCTAssertEqual(controller.primaryResolution, Optional(resolution))
        XCTAssertEqual(controller.boundCanvas, Optional(boundCanvas))
    }

    func testPendingFocusOperationCanRegisterBeforeCanvasBinding() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000068")
        )
        let controller = WorkspaceWindowScopeController(
            windowSessionID: windowSessionID
        )
        let focus = controller.focus(workspaceID: "workspace-A")
        let focusScope: WorkspaceScopeOperationIdentity = .focus(focus)
        var cancellationCount = 0

        XCTAssertTrue(controller.accepts(focus))
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)

        let operationID = try XCTUnwrap(
            controller.registerCancellation(for: focusScope) {
                cancellationCount += 1
            }
        )

        XCTAssertEqual(cancellationCount, 0)
        let repeatedFocus = controller.focus(workspaceID: "workspace-A")
        XCTAssertEqual(repeatedFocus, focus)
        XCTAssertEqual(cancellationCount, 0)

        let resolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-A"
        )
        let initialBinding = controller.bind(resolution, for: focus)
        let boundCanvas = try XCTUnwrap(controller.boundCanvas)

        XCTAssertEqual(
            initialBinding,
            WorkspaceCanvasBindingResult.bound(boundCanvas)
        )
        XCTAssertTrue(controller.accepts(focus))
        XCTAssertTrue(controller.accepts(boundCanvas))
        XCTAssertEqual(cancellationCount, 0)

        let equalBinding = controller.bind(resolution, for: focus)

        XCTAssertEqual(equalBinding, initialBinding)
        XCTAssertEqual(controller.pendingFocus, Optional(focus))
        XCTAssertEqual(controller.primaryResolution, Optional(resolution))
        XCTAssertEqual(controller.boundCanvas, Optional(boundCanvas))
        XCTAssertEqual(cancellationCount, 0)
        XCTAssertTrue(controller.complete(operationID: operationID, for: focusScope))
        XCTAssertFalse(controller.complete(operationID: operationID, for: focusScope))

        controller.clear()

        XCTAssertEqual(cancellationCount, 0)
        XCTAssertNil(controller.pendingFocus)
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)
    }

    func testStaleRegistrationCancelsSynchronouslyOnceAndReturnsNil() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000069")
        )
        let controller = WorkspaceWindowScopeController(
            windowSessionID: windowSessionID
        )
        let staleFocus = controller.focus(workspaceID: "workspace-A")
        let currentFocus = controller.focus(workspaceID: "workspace-B")
        let staleScope: WorkspaceScopeOperationIdentity = .focus(staleFocus)
        var cancellationCount = 0
        var registrationReturned = false

        let operationID = controller.registerCancellation(for: staleScope) {
            cancellationCount += 1
            XCTAssertFalse(registrationReturned)
            XCTAssertFalse(controller.accepts(staleFocus))
            XCTAssertTrue(controller.accepts(currentFocus))
            XCTAssertEqual(controller.pendingFocus, Optional(currentFocus))
            XCTAssertNil(controller.primaryResolution)
            XCTAssertNil(controller.boundCanvas)
        }
        registrationReturned = true

        XCTAssertNil(operationID)
        XCTAssertEqual(cancellationCount, 1)
        XCTAssertEqual(controller.pendingFocus, Optional(currentFocus))
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)

        controller.clear()

        XCTAssertEqual(cancellationCount, 1)
        XCTAssertNil(controller.pendingFocus)
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)
    }

    func testCompletionRequiresExactOperationIDAndScopeAndMismatchRemovesNothing() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000070")
        )
        let foreignOperationID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000170")
        )
        let controller = WorkspaceWindowScopeController(
            windowSessionID: windowSessionID
        )
        let focus = controller.focus(workspaceID: "workspace-A")
        let resolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-A"
        )
        _ = controller.bind(resolution, for: focus)
        let canvas = try XCTUnwrap(controller.boundCanvas)
        let focusScope: WorkspaceScopeOperationIdentity = .focus(focus)
        let canvasScope: WorkspaceScopeOperationIdentity = .canvas(canvas)
        var cancellationCount = 0

        XCTAssertTrue(controller.accepts(focus))
        XCTAssertTrue(controller.accepts(canvas))

        let operationID = try XCTUnwrap(
            controller.registerCancellation(for: focusScope) {
                cancellationCount += 1
            }
        )

        XCTAssertFalse(
            controller.complete(
                operationID: foreignOperationID,
                for: focusScope
            )
        )
        XCTAssertFalse(
            controller.complete(
                operationID: operationID,
                for: canvasScope
            )
        )
        XCTAssertEqual(cancellationCount, 0)
        XCTAssertTrue(controller.complete(operationID: operationID, for: focusScope))
        XCTAssertFalse(controller.complete(operationID: operationID, for: focusScope))

        controller.clear()

        XCTAssertEqual(cancellationCount, 0)
        XCTAssertFalse(controller.accepts(focus))
        XCTAssertFalse(controller.accepts(canvas))
    }

    func testCompletedOperationReceivesZeroCancellationAfterLaterTransition() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000071")
        )
        let controller = WorkspaceWindowScopeController(
            windowSessionID: windowSessionID
        )
        let focusA = controller.focus(workspaceID: "workspace-A")
        let scopeA: WorkspaceScopeOperationIdentity = .focus(focusA)
        var cancellationCount = 0

        let operationID = try XCTUnwrap(
            controller.registerCancellation(for: scopeA) {
                cancellationCount += 1
            }
        )
        XCTAssertTrue(controller.complete(operationID: operationID, for: scopeA))

        let focusB = controller.focus(workspaceID: "workspace-B")

        XCTAssertEqual(cancellationCount, 0)
        XCTAssertEqual(controller.pendingFocus, Optional(focusB))
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)

        controller.clear()

        XCTAssertEqual(cancellationCount, 0)
    }

    func testFocusResolutionInvalidationAndClearDetachInstallThenCancelExactlyOnce() throws {
        let focusWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000072")
        )
        let resolutionWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000073")
        )
        let invalidationWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000074")
        )
        let clearWindowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000075")
        )

        let focusController = WorkspaceWindowScopeController(
            windowSessionID: focusWindowSessionID
        )
        let oldFocus = focusController.focus(workspaceID: "workspace-A")
        var focusCancellationCount = 0
        _ = try XCTUnwrap(
            focusController.registerCancellation(for: .focus(oldFocus)) {
                focusCancellationCount += 1
                XCTAssertFalse(focusController.accepts(oldFocus))
                XCTAssertEqual(
                    focusController.pendingFocus?.workspaceID,
                    "workspace-B"
                )
                XCTAssertNil(focusController.primaryResolution)
                XCTAssertNil(focusController.boundCanvas)
            }
        )

        let newFocus = focusController.focus(workspaceID: "workspace-B")

        XCTAssertEqual(focusCancellationCount, 1)
        XCTAssertEqual(focusController.pendingFocus, Optional(newFocus))
        focusController.clear()
        XCTAssertEqual(focusCancellationCount, 1)

        let resolutionController = WorkspaceWindowScopeController(
            windowSessionID: resolutionWindowSessionID
        )
        let resolutionFocus = resolutionController.focus(workspaceID: "workspace-A")
        let initialResolution: WorkspacePrimaryCanvasResolution = .unique(
            canvasID: "canvas-A"
        )
        _ = resolutionController.bind(initialResolution, for: resolutionFocus)
        let initialCanvas = try XCTUnwrap(resolutionController.boundCanvas)
        var resolutionCancellationCount = 0
        _ = try XCTUnwrap(
            resolutionController.registerCancellation(for: .canvas(initialCanvas)) {
                resolutionCancellationCount += 1
                XCTAssertFalse(resolutionController.accepts(initialCanvas))
                XCTAssertNotEqual(
                    resolutionController.pendingFocus,
                    Optional(resolutionFocus)
                )
                XCTAssertEqual(
                    resolutionController.primaryResolution,
                    Optional(WorkspacePrimaryCanvasResolution.missing)
                )
                XCTAssertNil(resolutionController.boundCanvas)
            }
        )

        let transitionResult = resolutionController.bind(
            .missing,
            for: resolutionFocus
        )
        let rotatedResolutionFocus = try XCTUnwrap(
            resolutionController.pendingFocus
        )

        XCTAssertEqual(resolutionCancellationCount, 1)
        XCTAssertEqual(
            transitionResult,
            WorkspaceCanvasBindingResult.unbound(
                focus: rotatedResolutionFocus,
                resolution: .missing
            )
        )
        resolutionController.clear()
        XCTAssertEqual(resolutionCancellationCount, 1)

        let invalidationController = WorkspaceWindowScopeController(
            windowSessionID: invalidationWindowSessionID
        )
        let invalidatedOldFocus = invalidationController.focus(
            workspaceID: "workspace-A"
        )
        _ = invalidationController.bind(.missing, for: invalidatedOldFocus)
        var invalidationCancellationCount = 0
        _ = try XCTUnwrap(
            invalidationController.registerCancellation(
                for: .focus(invalidatedOldFocus)
            ) {
                invalidationCancellationCount += 1
                XCTAssertFalse(
                    invalidationController.accepts(invalidatedOldFocus)
                )
                XCTAssertNotEqual(
                    invalidationController.pendingFocus,
                    Optional(invalidatedOldFocus)
                )
                XCTAssertNil(invalidationController.primaryResolution)
                XCTAssertNil(invalidationController.boundCanvas)
            }
        )

        let invalidatedNewFocus = try XCTUnwrap(
            invalidationController.invalidatePrimaryResolution(
                for: invalidatedOldFocus
            )
        )

        XCTAssertEqual(invalidationCancellationCount, 1)
        XCTAssertEqual(
            invalidationController.pendingFocus,
            Optional(invalidatedNewFocus)
        )
        invalidationController.clear()
        XCTAssertEqual(invalidationCancellationCount, 1)

        let clearController = WorkspaceWindowScopeController(
            windowSessionID: clearWindowSessionID
        )
        let clearFocus = clearController.focus(workspaceID: "workspace-A")
        _ = clearController.bind(
            .unique(canvasID: "canvas-A"),
            for: clearFocus
        )
        let clearCanvas = try XCTUnwrap(clearController.boundCanvas)
        var clearFocusCancellationCount = 0
        var clearCanvasCancellationCount = 0
        _ = try XCTUnwrap(
            clearController.registerCancellation(for: .focus(clearFocus)) {
                clearFocusCancellationCount += 1
                XCTAssertNil(clearController.pendingFocus)
                XCTAssertNil(clearController.primaryResolution)
                XCTAssertNil(clearController.boundCanvas)
            }
        )
        _ = try XCTUnwrap(
            clearController.registerCancellation(for: .canvas(clearCanvas)) {
                clearCanvasCancellationCount += 1
                XCTAssertNil(clearController.pendingFocus)
                XCTAssertNil(clearController.primaryResolution)
                XCTAssertNil(clearController.boundCanvas)
            }
        )

        clearController.clear()

        XCTAssertEqual(clearFocusCancellationCount, 1)
        XCTAssertEqual(clearCanvasCancellationCount, 1)

        clearController.clear()

        XCTAssertEqual(clearFocusCancellationCount, 1)
        XCTAssertEqual(clearCanvasCancellationCount, 1)
    }

    func testReentrantCancellationObservesOnlyInstalledStateAndCannotRerunDetachedRegistry() throws {
        let windowSessionID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000076")
        )
        let controller = WorkspaceWindowScopeController(
            windowSessionID: windowSessionID
        )
        let focusA = controller.focus(workspaceID: "workspace-A")
        var detachedCancellationCount = 0
        var reentrantCancellationCount = 0
        var callbackObservedFocus: WorkspaceFocusScopeIdentity?

        _ = try XCTUnwrap(
            controller.registerCancellation(for: .focus(focusA)) {
                detachedCancellationCount += 1
                guard let installedFocus = controller.pendingFocus else {
                    XCTFail("Expected workspace-B focus before detached callback")
                    return
                }
                callbackObservedFocus = installedFocus
                XCTAssertEqual(installedFocus.workspaceID, "workspace-B")
                XCTAssertNil(controller.primaryResolution)
                XCTAssertNil(controller.boundCanvas)
                XCTAssertFalse(controller.accepts(focusA))
                XCTAssertTrue(controller.accepts(installedFocus))

                let reentrantOperationID = controller.registerCancellation(
                    for: .focus(installedFocus)
                ) {
                    reentrantCancellationCount += 1
                    XCTAssertNil(controller.pendingFocus)
                    XCTAssertNil(controller.primaryResolution)
                    XCTAssertNil(controller.boundCanvas)
                }
                XCTAssertNotNil(reentrantOperationID)

                controller.clear()

                XCTAssertEqual(detachedCancellationCount, 1)
                XCTAssertEqual(reentrantCancellationCount, 1)
            }
        )

        let focusB = controller.focus(workspaceID: "workspace-B")

        XCTAssertEqual(callbackObservedFocus, Optional(focusB))
        XCTAssertEqual(detachedCancellationCount, 1)
        XCTAssertEqual(reentrantCancellationCount, 1)
        XCTAssertNil(controller.pendingFocus)
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)

        controller.clear()

        XCTAssertEqual(detachedCancellationCount, 1)
        XCTAssertEqual(reentrantCancellationCount, 1)
    }
}
private func propertyIsWritable<Root, Value>(
    _ root: Root,
    _ keyPath: KeyPath<Root, Value>
) -> Bool {
    false
}

private func propertyIsWritable<Root, Value>(
    _ root: Root,
    _ keyPath: WritableKeyPath<Root, Value>
) -> Bool {
    true
}
