import Foundation
import MindDeskCore
import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class WorkspacePrimaryCanvasIntegrationTests: XCTestCase {
    func testLookupDescriptorUsesExactWorkspaceStableSortAndFetchLimitTwo() throws {
        let schema = Schema([CanvasModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let requestedWorkspaceID = "workspace-requested"

        for canvas in [
            CanvasModel(id: "canvas-20", workspaceId: requestedWorkspaceID),
            CanvasModel(id: "canvas-2", workspaceId: requestedWorkspaceID),
            CanvasModel(id: "canvas-10", workspaceId: requestedWorkspaceID),
            CanvasModel(id: "canvas-0", workspaceId: "workspace-requested-other"),
            CanvasModel(id: "canvas-15", workspaceId: "workspace")
        ] {
            context.insert(canvas)
        }
        try context.save()

        let canvases = try context.fetch(
            WorkspaceCanvasLookup.descriptor(for: requestedWorkspaceID)
        )

        XCTAssertEqual(canvases.count, 2)
        XCTAssertEqual(canvases.map(\.id), ["canvas-10", "canvas-2"])
        XCTAssertEqual(canvases.map(\.workspaceId), [requestedWorkspaceID, requestedWorkspaceID])
    }

    func testLookupExcludesForeignWorkspacesAndMapsScopedIDsThroughResolver() throws {
        let schema = Schema([CanvasModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        for canvas in [
            CanvasModel(id: " canvas-0-foreign ", workspaceId: "workspace-foreign"),
            CanvasModel(id: " canvas-unique ", workspaceId: "workspace-unique"),
            CanvasModel(id: "canvas-a", workspaceId: "workspace-duplicate"),
            CanvasModel(id: " canvas-b ", workspaceId: "workspace-duplicate")
        ] {
            context.insert(canvas)
        }
        try context.save()

        let missing = try WorkspaceCanvasLookup.resolve(for: "workspace-missing", in: context)
        let unique = try WorkspaceCanvasLookup.resolve(for: "workspace-unique", in: context)
        let duplicate = try WorkspaceCanvasLookup.resolve(for: "workspace-duplicate", in: context)

        XCTAssertEqual(missing, .missing)
        XCTAssertEqual(unique, .unique(canvasID: " canvas-unique "))
        XCTAssertEqual(duplicate, .duplicate(canvasIDs: [" canvas-b ", "canvas-a"]))
    }

    func testFingerprintIsOrderIndependentAndEncodesRecordCountAndByteLengths() throws {
        let forwardInput = ["A", "\u{00E9}", "e\u{301}"]
        let reverseInput = Array(forwardInput.reversed())
        let forwardRawBytes = forwardInput.map { Array($0.utf8) }
        let reverseRawBytes = reverseInput.map { Array($0.utf8) }
        let expectedForwardRawBytes: [[UInt8]] = [
            [0x41],
            [0xC3, 0xA9],
            [0x65, 0xCC, 0x81]
        ]

        XCTAssertEqual(forwardInput[1], forwardInput[2])
        XCTAssertNotEqual(forwardRawBytes[1], forwardRawBytes[2])
        XCTAssertEqual(forwardRawBytes, expectedForwardRawBytes)
        XCTAssertEqual(reverseRawBytes, Array(expectedForwardRawBytes.reversed()))

        let forwardFingerprint: String = WorkspacePrimaryCanvasFingerprint.make(
            canvasIDs: forwardInput
        )
        let reverseFingerprint: String = WorkspacePrimaryCanvasFingerprint.make(
            canvasIDs: reverseInput
        )

        XCTAssertEqual(forwardFingerprint, reverseFingerprint)
        let decodedPayload = try XCTUnwrap(Data(base64Encoded: forwardFingerprint))
        let expectedPayload = expectedFingerprintPayload(canvasIDs: forwardInput)
        XCTAssertEqual(decodedPayload, expectedPayload)
        XCTAssertEqual(decodedPayload.count, expectedPayload.count)
        XCTAssertEqual(forwardInput.map { Array($0.utf8) }, forwardRawBytes)
        XCTAssertEqual(reverseInput.map { Array($0.utf8) }, reverseRawBytes)
    }

    func testFingerprintDistinguishesSingleRepeatedAndBlankCanvasIDs() {
        let namedCases: [(name: String, canvasIDs: [String])] = [
            ("zeroRecords", []),
            ("oneEmpty", [""]),
            ("oneWhitespace", [" "]),
            ("oneA", ["A"]),
            ("repeatedA", ["A", "A"]),
            ("repeatedEmpty", ["", ""])
        ]
        let fingerprints = namedCases.map { testCase in
            (
                name: testCase.name,
                value: WorkspacePrimaryCanvasFingerprint.make(canvasIDs: testCase.canvasIDs)
            )
        }

        for leftIndex in fingerprints.indices {
            for rightIndex in fingerprints.indices where rightIndex > leftIndex {
                XCTAssertNotEqual(
                    fingerprints[leftIndex].value,
                    fingerprints[rightIndex].value,
                    "\(fingerprints[leftIndex].name) and \(fingerprints[rightIndex].name) must differ"
                )
            }
        }

        XCTAssertEqual(
            fingerprints[3].value,
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["A"])
        )
    }

    func testFingerprintDistinguishesConcatenationCollisions() {
        let acuteThenDotBelow = "a\u{301}\u{323}"
        let dotBelowThenAcute = "a\u{323}\u{301}"
        let acuteThenDotBelowBytes = Array(acuteThenDotBelow.utf8)
        let dotBelowThenAcuteBytes = Array(dotBelowThenAcute.utf8)

        XCTAssertEqual(acuteThenDotBelow, dotBelowThenAcute)
        XCTAssertNotEqual(acuteThenDotBelowBytes, dotBelowThenAcuteBytes)
        XCTAssertEqual(acuteThenDotBelowBytes.count, dotBelowThenAcuteBytes.count)

        XCTAssertNotEqual(
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["A"]),
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["AA"])
        )
        XCTAssertNotEqual(
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["AB", "C"]),
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["A", "BC"])
        )
        XCTAssertNotEqual(
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: [acuteThenDotBelow]),
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: [dotBelowThenAcute])
        )
    }

    func testFingerprintChangesWhenOnlyThirdCanvasChangesBeyondLookupFetchLimit() {
        let firstInput = ["A", "B", "C"]
        let secondInput = ["A", "B", "D"]
        let firstSortedRawBytes = firstInput.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }.map { Array($0.utf8) }
        let secondSortedRawBytes = secondInput.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }.map { Array($0.utf8) }
        let expectedPrefix: [[UInt8]] = [[0x41], [0x42]]

        XCTAssertEqual(firstSortedRawBytes.count, 3)
        XCTAssertEqual(secondSortedRawBytes.count, 3)
        XCTAssertEqual(Array(firstSortedRawBytes.prefix(2)), expectedPrefix)
        XCTAssertEqual(Array(secondSortedRawBytes.prefix(2)), expectedPrefix)

        let firstFingerprint = WorkspacePrimaryCanvasFingerprint.make(canvasIDs: firstInput)
        let secondFingerprint = WorkspacePrimaryCanvasFingerprint.make(canvasIDs: secondInput)

        XCTAssertEqual(
            firstFingerprint,
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: Array(firstInput.reversed()))
        )
        XCTAssertEqual(
            secondFingerprint,
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: Array(secondInput.reversed()))
        )
        XCTAssertNotEqual(firstFingerprint, secondFingerprint)
    }

    func testLaunchInstallsOneSlotBeforeZeroLatencyWorkerCanCommit() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let observation = ResolutionWorkerObservation()

        let operationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A"
            ) { [weak controller] attempt, operationID in
                observation.recordCommit(
                    slotWasInstalled: controller?.primaryCanvasResolutionSlot?.attempt
                        == attempt
                        && controller?.primaryCanvasResolutionSlot?.operationID
                        == operationID
                )
            }
        )
        let slot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)

        XCTAssertEqual(slot.operationID, operationID)
        XCTAssertEqual(slot.attempt.focus, focus)
        XCTAssertEqual(slot.attempt.fingerprint, "fingerprint-A")
        XCTAssertEqual(slot.attempt.phase, .initialLookup)
        await slot.task.value
        XCTAssertEqual(observation.commitCount, 1)
        XCTAssertTrue(observation.slotWasInstalledAtCommit)

        controller.clear()
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
    }

    func testRegistrationFailureCancelsWorkerFinishesStartGateAndInstallsNoSlot() async {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let observation = ResolutionWorkerObservation()
        let registration = ResolutionRegistrationObservation()

        let operationID = controller.startPrimaryCanvasResolution(
            for: focus,
            fingerprint: "fingerprint-A",
            registerCancellation: { scope, cancel in
                registration.record(scope: scope, cancel: cancel)
                return nil
            }
        ) { _, _ in
            observation.recordCommit(slotWasInstalled: false)
        }

        XCTAssertNil(operationID)
        XCTAssertEqual(registration.registrationCount, 1)
        XCTAssertEqual(registration.lastScope, .focus(focus))
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
        await allowResolutionTasksToSettle()
        XCTAssertEqual(observation.commitCount, 0)
        XCTAssertEqual(registration.cancellationCount, 0)
    }

    func testImmediatelyStaleRegistrationCallbackLetsWorkerTerminateWithoutLeak() async {
        let controller = WorkspaceWindowScopeController()
        let staleFocus = controller.focus(workspaceID: "workspace-A")
        _ = controller.focus(workspaceID: "workspace-B")
        let observation = ResolutionWorkerObservation()
        var lifetimeToken: ResolutionTaskLifetimeToken? = ResolutionTaskLifetimeToken()
        weak let weakLifetimeToken = lifetimeToken

        let operationID = controller.startPrimaryCanvasResolution(
            for: staleFocus,
            fingerprint: "fingerprint-stale"
        ) { [lifetimeToken] _, _ in
            _ = lifetimeToken
            observation.recordCommit(slotWasInstalled: false)
        }
        lifetimeToken = nil

        XCTAssertNil(operationID)
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
        await allowResolutionTasksToSettle()
        XCTAssertEqual(observation.commitCount, 0)
        XCTAssertNil(weakLifetimeToken)
    }

    func testInvalidationBeforeStartGateOpensLeavesNoTaskSlotOrRegistration() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let observation = ResolutionWorkerObservation()

        let operationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A"
            ) { _, _ in
                observation.recordCommit(slotWasInstalled: false)
            }
        )
        let installedTask = try XCTUnwrap(
            controller.primaryCanvasResolutionSlot?.task
        )

        let rotatedFocus = try XCTUnwrap(
            controller.invalidatePrimaryResolution(for: focus)
        )

        await installedTask.value
        XCTAssertEqual(observation.commitCount, 0)
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
        XCTAssertFalse(
            controller.complete(operationID: operationID, for: .focus(focus))
        )
        XCTAssertEqual(controller.pendingFocus, rotatedFocus)
    }

    func testFingerprintInvalidationCancelsExactSlotOnceAndLaunchesOneFreshInitialAttempt() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let oldWorker = SuspendedResolutionWorker()
        let newWorker = SuspendedResolutionWorker()

        let oldOperationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: oldWorker.run
            )
        )
        let oldSlot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await oldWorker.waitUntilStarted()

        let newOperationID = try XCTUnwrap(
            controller.invalidatePrimaryCanvasResolutionAndStart(
                for: focus,
                fingerprint: "fingerprint-B",
                worker: newWorker.run
            )
        )
        let newSlot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await newWorker.waitUntilStarted()

        XCTAssertNotEqual(oldOperationID, newOperationID)
        XCTAssertNotEqual(oldSlot.attempt.requestID, newSlot.attempt.requestID)
        XCTAssertEqual(newSlot.attempt.phase, .initialLookup)
        XCTAssertEqual(newSlot.attempt.fingerprint, "fingerprint-B")
        XCTAssertFalse(
            controller.complete(operationID: oldOperationID, for: .focus(focus))
        )

        oldWorker.resume()
        await oldSlot.task.value
        XCTAssertEqual(oldWorker.cancellationObservationCount, 1)
        XCTAssertEqual(controller.primaryCanvasResolutionSlot?.operationID, newOperationID)

        let freshFocus = newSlot.attempt.focus
        _ = controller.invalidatePrimaryResolution(for: freshFocus)
        newWorker.resume()
        await newSlot.task.value
        XCTAssertEqual(newWorker.cancellationObservationCount, 1)
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
    }

    func testAToBToAUsesFreshRequestIDsAndOldAttemptCannotTouchCurrentSlot() async throws {
        let controller = WorkspaceWindowScopeController()
        let workerA1 = SuspendedResolutionWorker()
        let workerB = SuspendedResolutionWorker()
        let workerA2 = SuspendedResolutionWorker()

        let focusA1 = controller.focus(workspaceID: "workspace-A")
        let operationA1 = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focusA1,
                fingerprint: "fingerprint-A",
                worker: workerA1.run
            )
        )
        let slotA1 = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await workerA1.waitUntilStarted()

        let focusB = controller.focus(workspaceID: "workspace-B")
        let operationB = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focusB,
                fingerprint: "fingerprint-B",
                worker: workerB.run
            )
        )
        let slotB = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await workerB.waitUntilStarted()

        let focusA2 = controller.focus(workspaceID: "workspace-A")
        let operationA2 = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focusA2,
                fingerprint: "fingerprint-A",
                worker: workerA2.run
            )
        )
        let slotA2 = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await workerA2.waitUntilStarted()

        XCTAssertEqual(Set([
            slotA1.attempt.requestID,
            slotB.attempt.requestID,
            slotA2.attempt.requestID,
        ]).count, 3)
        XCTAssertEqual(Set([operationA1, operationB, operationA2]).count, 3)
        XCTAssertNil(
            controller.finishPrimaryCanvasResolution(
                attempt: slotA1.attempt,
                operationID: operationA1,
                resolution: .unique(canvasID: "canvas-stale")
            )
        )
        XCTAssertEqual(controller.primaryCanvasResolutionSlot?.operationID, operationA2)
        XCTAssertNil(controller.primaryResolution)

        workerA1.resume()
        workerB.resume()
        workerA2.resume()
        await slotA1.task.value
        await slotB.task.value
        await slotA2.task.value
        controller.clear()
    }

    func testSameFingerprintReplacementCancelsDisplacedTaskOnceCompletesOldRegistrationAndPreservesReplacement() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let displacedWorker = SuspendedResolutionWorker()
        let replacementWorker = SuspendedResolutionWorker()

        let displacedOperationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: displacedWorker.run
            )
        )
        let displacedSlot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await displacedWorker.waitUntilStarted()

        let replacementOperationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: replacementWorker.run
            )
        )
        let replacementSlot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await replacementWorker.waitUntilStarted()

        displacedWorker.resume()
        await displacedSlot.task.value
        XCTAssertEqual(displacedWorker.cancellationObservationCount, 1)
        XCTAssertFalse(
            controller.complete(
                operationID: displacedOperationID,
                for: .focus(focus)
            )
        )
        XCTAssertEqual(
            controller.primaryCanvasResolutionSlot?.operationID,
            replacementOperationID
        )
        XCTAssertEqual(replacementWorker.cancellationObservationCount, 0)

        _ = controller.invalidatePrimaryResolution(for: focus)
        replacementWorker.resume()
        await replacementSlot.task.value
        XCTAssertEqual(replacementWorker.cancellationObservationCount, 1)
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
    }

    func testFailedReplacementPreservesExistingSlot() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let existingWorker = SuspendedResolutionWorker()
        let rejectedWorker = ResolutionWorkerObservation()

        let existingOperationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: existingWorker.run
            )
        )
        let existingAttempt = try XCTUnwrap(
            controller.primaryCanvasResolutionSlot?.attempt
        )
        await existingWorker.waitUntilStarted()

        let rejectedOperationID = controller.startPrimaryCanvasResolution(
            for: focus,
            fingerprint: "fingerprint-A",
            registerCancellation: { _, _ in nil }
        ) { _, _ in
            rejectedWorker.recordCommit(slotWasInstalled: false)
        }

        XCTAssertNil(rejectedOperationID)
        XCTAssertEqual(controller.primaryCanvasResolutionSlot?.operationID, existingOperationID)
        XCTAssertEqual(controller.primaryCanvasResolutionSlot?.attempt, existingAttempt)
        XCTAssertEqual(existingWorker.cancellationObservationCount, 0)
        await allowResolutionTasksToSettle()
        XCTAssertEqual(rejectedWorker.commitCount, 0)

        let existingTask = try XCTUnwrap(controller.primaryCanvasResolutionSlot?.task)
        _ = controller.invalidatePrimaryResolution(for: focus)
        existingWorker.resume()
        await existingTask.value
        XCTAssertEqual(existingWorker.cancellationObservationCount, 1)
    }

    func testSupersededAndFailedCompletionCannotBindCancelOrClearReplacement() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let oldWorker = SuspendedResolutionWorker()
        let replacementWorker = SuspendedResolutionWorker()

        let oldOperationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: oldWorker.run
            )
        )
        let oldAttempt = try XCTUnwrap(controller.primaryCanvasResolutionSlot?.attempt)
        await oldWorker.waitUntilStarted()
        let replacementOperationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: replacementWorker.run
            )
        )
        let replacementSlot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await replacementWorker.waitUntilStarted()

        XCTAssertNil(
            controller.finishPrimaryCanvasResolution(
                attempt: oldAttempt,
                operationID: oldOperationID,
                resolution: .unique(canvasID: "canvas-old")
            )
        )
        XCTAssertEqual(controller.primaryCanvasResolutionSlot?.operationID, replacementOperationID)
        XCTAssertNil(controller.primaryResolution)
        XCTAssertEqual(replacementWorker.cancellationObservationCount, 0)

        XCTAssertTrue(
            controller.complete(
                operationID: replacementOperationID,
                for: .focus(focus)
            )
        )
        XCTAssertNil(
            controller.finishPrimaryCanvasResolution(
                attempt: replacementSlot.attempt,
                operationID: replacementOperationID,
                resolution: .unique(canvasID: "canvas-replacement")
            )
        )
        XCTAssertEqual(controller.primaryCanvasResolutionSlot?.operationID, replacementOperationID)
        XCTAssertNil(controller.primaryResolution)
        XCTAssertEqual(replacementWorker.cancellationObservationCount, 0)

        oldWorker.resume()
        replacementWorker.resume()
        await replacementSlot.task.value
    }

    func testTerminalSuccessCompletesThenClearsThenBindsWithoutSuspension() async throws {
        let controller = WorkspaceWindowScopeController()
        let initialFocus = controller.focus(workspaceID: "workspace-A")
        _ = controller.bind(.missing, for: initialFocus)
        let focus = try XCTUnwrap(controller.pendingFocus)
        let worker = SuspendedResolutionWorker()
        let callbackObservation = ResolutionTerminalOrderObservation()

        let operationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: worker.run
            )
        )
        let slot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await worker.waitUntilStarted()
        let sentinelID = try XCTUnwrap(
            controller.registerCancellation(for: .focus(focus)) { [weak controller] in
                callbackObservation.record(
                    slotWasClear: controller?.primaryCanvasResolutionSlot == nil,
                    reportingRegistrationWasComplete: controller?.complete(
                        operationID: operationID,
                        for: .focus(focus)
                    ) == false,
                    installedResolution: controller?.primaryResolution
                )
            }
        )

        let result = try XCTUnwrap(
            controller.finishPrimaryCanvasResolution(
                attempt: slot.attempt,
                operationID: operationID,
                resolution: .unique(canvasID: "canvas-A")
            )
        )

        XCTAssertEqual(callbackObservation.callbackCount, 1)
        XCTAssertTrue(callbackObservation.slotWasClear)
        XCTAssertTrue(callbackObservation.reportingRegistrationWasComplete)
        XCTAssertEqual(
            callbackObservation.installedResolution,
            .unique(canvasID: "canvas-A")
        )
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
        XCTAssertFalse(controller.complete(operationID: sentinelID, for: .focus(focus)))
        guard case let .bound(canvas) = result else {
            return XCTFail("Expected terminal unique result to bind")
        }
        XCTAssertEqual(canvas.canvasID, "canvas-A")

        worker.resume()
        await slot.task.value
        XCTAssertEqual(worker.cancellationObservationCount, 0)
    }

    func testPreInsertToPostSaveHandoffKeepsOperationTaskAndRegistrationWithFreshRequestID() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let worker = SuspendedResolutionWorker()

        let operationID = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                phase: .preInsertRecheck,
                worker: worker.run
            )
        )
        let preInsertSlot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)
        await worker.waitUntilStarted()

        let postSaveAttempt = try XCTUnwrap(
            controller.handoffPrimaryCanvasResolution(
                attempt: preInsertSlot.attempt,
                operationID: operationID,
                to: .postSaveRecheck
            )
        )
        let postSaveSlot = try XCTUnwrap(controller.primaryCanvasResolutionSlot)

        XCTAssertNotEqual(postSaveAttempt.requestID, preInsertSlot.attempt.requestID)
        XCTAssertEqual(postSaveAttempt.focus, preInsertSlot.attempt.focus)
        XCTAssertEqual(postSaveAttempt.fingerprint, preInsertSlot.attempt.fingerprint)
        XCTAssertEqual(postSaveAttempt.phase, .postSaveRecheck)
        XCTAssertEqual(postSaveSlot.attempt, postSaveAttempt)
        XCTAssertEqual(postSaveSlot.operationID, operationID)
        XCTAssertFalse(postSaveSlot.task.isCancelled)
        XCTAssertEqual(worker.startCount, 1)
        XCTAssertEqual(worker.cancellationObservationCount, 0)

        _ = controller.invalidatePrimaryResolution(for: focus)
        worker.resume()
        await preInsertSlot.task.value
        XCTAssertEqual(worker.cancellationObservationCount, 1)
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
    }

    func testSlotTaskAndCancellationCallbackDoNotRetainController() async throws {
        var controller: WorkspaceWindowScopeController? = WorkspaceWindowScopeController()
        weak let weakController = controller
        let worker = SuspendedResolutionWorker()
        let focus = try XCTUnwrap(controller).focus(workspaceID: "workspace-A")

        _ = try XCTUnwrap(
            controller?.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: worker.run
            )
        )
        let task = try XCTUnwrap(controller?.primaryCanvasResolutionSlot?.task)
        await worker.waitUntilStarted()

        controller = nil
        XCTAssertNil(weakController)
        worker.resume()
        await task.value

        let coordinatorSource = try integrationRepositorySource(
            "Sources/MindDesk/Models/WorkspacePrimaryCanvasResolutionCoordinator.swift"
        )
        let controllerSource = try integrationRepositorySource(
            "Sources/MindDesk/Models/WorkspaceWindowScopeController.swift"
        )
        XCTAssertEqual(
            coordinatorSource.components(
                separatedBy: "Task { @MainActor [weak controller] in"
            ).count - 1,
            1
        )
        XCTAssertFalse(coordinatorSource.contains("Task.detached"))
        XCTAssertFalse(coordinatorSource.contains("ModelContext"))
        XCTAssertFalse(coordinatorSource.contains("@Model"))
        XCTAssertTrue(
            controllerSource.contains(
                "private(set) var primaryCanvasResolutionSlot: WorkspacePrimaryCanvasResolutionSlot?"
            )
        )
    }

    private func expectedFingerprintPayload(canvasIDs: [String]) -> Data {
        let sortedCanvasIDs = canvasIDs.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }
        var payload = Data()

        func appendBigEndian(_ value: UInt64) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { bytes in
                payload.append(contentsOf: bytes)
            }
        }

        appendBigEndian(UInt64(sortedCanvasIDs.count))
        for canvasID in sortedCanvasIDs {
            let bytes = Array(canvasID.utf8)
            appendBigEndian(UInt64(bytes.count))
            payload.append(contentsOf: bytes)
        }
        return payload
    }
}

@MainActor
private final class ResolutionWorkerObservation {
    private(set) var commitCount = 0
    private(set) var slotWasInstalledAtCommit = false

    func recordCommit(slotWasInstalled: Bool) {
        commitCount += 1
        slotWasInstalledAtCommit = slotWasInstalled
    }
}

@MainActor
private final class ResolutionRegistrationObservation {
    private(set) var registrationCount = 0
    private(set) var cancellationCount = 0
    private(set) var lastScope: WorkspaceScopeOperationIdentity?

    func record(
        scope: WorkspaceScopeOperationIdentity,
        cancel: @escaping @MainActor @Sendable () -> Void
    ) {
        registrationCount += 1
        lastScope = scope
        _ = cancel
    }
}

@MainActor
private final class ResolutionTerminalOrderObservation {
    private(set) var callbackCount = 0
    private(set) var slotWasClear = false
    private(set) var reportingRegistrationWasComplete = false
    private(set) var installedResolution: WorkspacePrimaryCanvasResolution?

    func record(
        slotWasClear: Bool,
        reportingRegistrationWasComplete: Bool,
        installedResolution: WorkspacePrimaryCanvasResolution?
    ) {
        callbackCount += 1
        self.slotWasClear = slotWasClear
        self.reportingRegistrationWasComplete = reportingRegistrationWasComplete
        self.installedResolution = installedResolution
    }
}

@MainActor
private final class SuspendedResolutionWorker {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var startCount = 0
    private(set) var cancellationObservationCount = 0

    func run(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: UUID
    ) async {
        _ = attempt
        _ = operationID
        startCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        if Task.isCancelled {
            cancellationObservationCount += 1
        }
    }

    func waitUntilStarted() async {
        for _ in 0..<1_000 {
            if continuation != nil {
                return
            }
            await Task.yield()
        }
        XCTFail("Resolution worker did not reach its controlled suspension")
    }

    func resume() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}

private final class ResolutionTaskLifetimeToken {}

@MainActor
private func allowResolutionTasksToSettle() async {
    for _ in 0..<20 {
        await Task.yield()
    }
}

private func integrationRepositorySource(
    _ relativePath: String,
    file: StaticString = #filePath
) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: repositoryRoot.appendingPathComponent(relativePath)
    )
    return String(decoding: data, as: UTF8.self)
}
