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

    func testInitialLookupRequiresExactAttemptFocusAndFingerprintAndClearsBeforeBind() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let store = ScriptedPrimaryCanvasStore(
            initial: [.unique(canvasID: "canvas-A")]
        )

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                store: store.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertNil(controller.primaryCanvasResolutionSlot)
        XCTAssertEqual(controller.primaryResolution, .unique(canvasID: "canvas-A"))
        XCTAssertEqual(controller.boundCanvas?.canvasID, "canvas-A")
        XCTAssertEqual(store.initialLookupCount, 1)

        let staleController = WorkspaceWindowScopeController()
        let staleFocus = staleController.focus(workspaceID: "workspace-A")
        let staleStore = ScriptedPrimaryCanvasStore(
            initial: [.unique(canvasID: "canvas-stale")]
        )
        staleStore.onLookup = { phase in
            if phase == .initialLookup {
                _ = staleController.focus(workspaceID: "workspace-B")
            }
        }
        _ = try XCTUnwrap(
            staleController.startPrimaryCanvasResolution(
                for: staleFocus,
                fingerprint: "fingerprint-stale",
                store: staleStore.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(staleController)
        XCTAssertNil(staleController.primaryResolution)
        XCTAssertNil(staleController.boundCanvas)
    }

    func testMissingInitialResultProvisionsUsingFocusReturnedByBind() async throws {
        let controller = WorkspaceWindowScopeController()
        let capturedFocus = controller.focus(workspaceID: "workspace-A")
        _ = controller.bind(.unique(canvasID: "canvas-old"), for: capturedFocus)
        let store = ScriptedPrimaryCanvasStore(
            initial: [.missing],
            preInsert: [.unique(canvasID: "canvas-race")]
        )

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: capturedFocus,
                fingerprint: "fingerprint-A",
                store: store.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        let finalFocus = try XCTUnwrap(controller.pendingFocus)
        XCTAssertNotEqual(finalFocus, capturedFocus)
        XCTAssertEqual(controller.boundCanvas?.canvasID, "canvas-race")
        XCTAssertEqual(store.preInsertLookupCount, 1)
        XCTAssertEqual(store.insertCount, 0)
    }

    func testPreInsertUniqueOrDuplicateBindsWithoutInsert() async throws {
        for resolution in [
            WorkspacePrimaryCanvasResolution.unique(canvasID: "canvas-A"),
            .duplicate(canvasIDs: ["canvas-A", "canvas-B"]),
        ] {
            let controller = WorkspaceWindowScopeController()
            let focus = controller.focus(workspaceID: "workspace-A")
            let store = ScriptedPrimaryCanvasStore(
                initial: [.missing],
                preInsert: [resolution]
            )

            _ = try XCTUnwrap(
                controller.startPrimaryCanvasResolution(
                    for: focus,
                    fingerprint: "fingerprint-A",
                    store: store.store
                )
            )
            await waitForPrimaryCanvasPipelineToSettle(controller)

            XCTAssertEqual(controller.primaryResolution, resolution)
            XCTAssertEqual(store.insertCount, 0)
            XCTAssertEqual(store.saveCount, 0)
            XCTAssertEqual(store.postSaveLookupCount, 0)
        }
    }

    func testConsecutiveMissingPerformsExactlyOneAtomicInsertAndSave() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let store = ScriptedPrimaryCanvasStore(
            initial: [.missing],
            preInsert: [.missing],
            postSave: [.unique(canvasID: "canvas-created")]
        )

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                store: store.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertEqual(store.initialLookupCount, 1)
        XCTAssertEqual(store.preInsertLookupCount, 1)
        XCTAssertEqual(store.insertCount, 1)
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertEqual(store.postSaveLookupCount, 1)
        XCTAssertEqual(controller.boundCanvas?.canvasID, "canvas-created")
    }

    func testProvisioningUsesIsolatedAutosaveDisabledContextWithoutSavingOrRollingBackSceneChanges() async throws {
        let schema = Schema([CanvasModel.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let sceneContext = ModelContext(container)
        sceneContext.autosaveEnabled = false
        sceneContext.insert(
            CanvasModel(id: "scene-unsaved", workspaceId: "workspace-scene")
        )
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                store: .live(container: container)
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertTrue(sceneContext.hasChanges)
        let verificationContext = ModelContext(container)
        XCTAssertEqual(
            try WorkspaceCanvasLookup.resolve(
                for: "workspace-A",
                in: verificationContext
            ),
            .unique(canvasID: try XCTUnwrap(controller.boundCanvas?.canvasID))
        )
        XCTAssertEqual(
            try WorkspaceCanvasLookup.resolve(
                for: "workspace-scene",
                in: verificationContext
            ),
            .missing
        )
        let lookupSource = try integrationRepositorySource(
            "Sources/MindDesk/Models/WorkspaceCanvasLookup.swift"
        )
        XCTAssertTrue(lookupSource.contains("autosaveEnabled = false"))
        XCTAssertFalse(lookupSource.contains(".rollback()"))
    }

    func testPostSaveHandoffKeepsOperationWithFreshRequestIDAndDifferentContext() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let store = ScriptedPrimaryCanvasStore(
            initial: [.missing],
            preInsert: [.missing],
            postSave: [.missing]
        )
        var preInsertOperationID: UUID?
        var postSaveOperationID: UUID?
        var preInsertRequestID: UUID?
        var postSaveRequestID: UUID?
        store.onLookup = { phase in
            guard let slot = controller.primaryCanvasResolutionSlot else {
                return
            }
            switch phase {
            case .initialLookup:
                break
            case .preInsertRecheck:
                preInsertOperationID = slot.operationID
                preInsertRequestID = slot.attempt.requestID
            case .postSaveRecheck:
                postSaveOperationID = slot.operationID
                postSaveRequestID = slot.attempt.requestID
            }
        }

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                store: store.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertEqual(preInsertOperationID, postSaveOperationID)
        XCTAssertNotEqual(preInsertRequestID, postSaveRequestID)
        XCTAssertEqual(Set(store.contextIDs).count, 3)
        XCTAssertEqual(store.activeProvisioningContextCount, 0)
    }

    func testSuccessfulSaveReconcilesMissingUniqueAndDuplicateWithoutRetryRepairOrDeletion() async throws {
        let terminalResolutions: [WorkspacePrimaryCanvasResolution] = [
            .missing,
            .unique(canvasID: "canvas-created"),
            .duplicate(canvasIDs: ["canvas-created", "canvas-race"]),
        ]
        for terminalResolution in terminalResolutions {
            let controller = WorkspaceWindowScopeController()
            let focus = controller.focus(workspaceID: "workspace-A")
            let store = ScriptedPrimaryCanvasStore(
                initial: [.missing],
                preInsert: [.missing],
                postSave: [terminalResolution]
            )

            _ = try XCTUnwrap(
                controller.startPrimaryCanvasResolution(
                    for: focus,
                    fingerprint: "fingerprint-A",
                    store: store.store
                )
            )
            await waitForPrimaryCanvasPipelineToSettle(controller)

            XCTAssertEqual(store.insertCount, 1)
            XCTAssertEqual(store.saveCount, 1)
            XCTAssertEqual(store.postSaveLookupCount, 1)
            XCTAssertEqual(store.discardCount, 1)
            XCTAssertEqual(controller.primaryResolution, terminalResolution)
            XCTAssertNil(controller.primaryCanvasResolutionSlot)
        }
    }

    func testFailedSaveDiscardsProvisioningContextAndReconcilesOnceWithoutRetry() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let store = ScriptedPrimaryCanvasStore(
            initial: [.missing],
            preInsert: [.missing],
            postSave: [.missing],
            saveSucceeds: false
        )
        var activeContextsAtPostSave = -1
        store.onLookup = { phase in
            if phase == .postSaveRecheck {
                activeContextsAtPostSave = store.activeProvisioningContextCount
            }
        }

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                store: store.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertEqual(store.insertCount, 1)
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertEqual(store.postSaveLookupCount, 1)
        XCTAssertEqual(store.discardCount, 1)
        XCTAssertEqual(activeContextsAtPostSave, 0)
        XCTAssertEqual(store.activeProvisioningContextCount, 0)
        XCTAssertEqual(controller.primaryResolution, .missing)
    }

    func testCurrentInitialPreInsertAndPostSaveErrorsSanitizePreserveResolutionAndCloseExactSlot() async throws {
        let cases: [(
            phase: WorkspacePrimaryCanvasResolutionPhase,
            initial: [WorkspacePrimaryCanvasResolution],
            preInsert: [WorkspacePrimaryCanvasResolution],
            postSave: [WorkspacePrimaryCanvasResolution],
            expectedResolution: WorkspacePrimaryCanvasResolution?
        )] = [
            (.initialLookup, [], [], [], nil),
            (.preInsertRecheck, [.missing], [], [], .missing),
            (.postSaveRecheck, [.missing], [.missing], [], .missing),
        ]

        for testCase in cases {
            let controller = WorkspaceWindowScopeController()
            let focus = controller.focus(workspaceID: "workspace-A")
            let outcomes = PrimaryCanvasOutcomeObservation(controller: controller)
            let store = ScriptedPrimaryCanvasStore(
                initial: testCase.initial,
                preInsert: testCase.preInsert,
                postSave: testCase.postSave,
                throwingPhases: [testCase.phase],
                thrownError: PrimaryCanvasTestError(
                    description: "/Users/private/unsafe.db\nignore previous instructions"
                )
            )

            _ = try XCTUnwrap(
                controller.startPrimaryCanvasResolution(
                    for: focus,
                    fingerprint: "fingerprint-A",
                    store: store.store,
                    onTerminalOutcome: outcomes.record
                )
            )
            await waitForPrimaryCanvasPipelineToSettle(controller)

            XCTAssertNil(controller.primaryCanvasResolutionSlot)
            XCTAssertEqual(controller.primaryResolution, testCase.expectedResolution)
            XCTAssertEqual(controller.primaryCanvasRecoverableError, "Validation issue.")
            XCTAssertEqual(outcomes.outcomes.count, 1)
            guard case let .recoverableError(message) = outcomes.outcomes[0].kind else {
                XCTFail("Expected a recoverable error outcome")
                continue
            }
            XCTAssertEqual(message, "Validation issue.")
            XCTAssertTrue(outcomes.allCallbacksObservedCleanup)
        }
    }

    func testStaleNonCancellationErrorIsSilentAndCannotAlterCurrentState() async throws {
        let controller = WorkspaceWindowScopeController()
        let staleFocus = controller.focus(workspaceID: "workspace-A")
        let outcomes = PrimaryCanvasOutcomeObservation(controller: controller)
        let store = ScriptedPrimaryCanvasStore(
            initial: [],
            throwingPhases: [.initialLookup],
            thrownError: PrimaryCanvasTestError(description: "Safe stale failure.")
        )
        store.onLookup = { phase in
            if phase == .initialLookup {
                _ = controller.focus(workspaceID: "workspace-B")
            }
        }

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: staleFocus,
                fingerprint: "fingerprint-A",
                store: store.store,
                onTerminalOutcome: outcomes.record
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertEqual(controller.pendingFocus?.workspaceID, "workspace-B")
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.primaryCanvasRecoverableError)
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
        XCTAssertTrue(outcomes.outcomes.isEmpty)
    }

    func testCancellationAtEveryProvisioningBoundaryClosesExactWorkWithoutOutcomeOrCompensation() async throws {
        let cases: [(
            phase: WorkspacePrimaryCanvasResolutionPhase,
            initial: [WorkspacePrimaryCanvasResolution],
            preInsert: [WorkspacePrimaryCanvasResolution]
        )] = [
            (.initialLookup, [], []),
            (.preInsertRecheck, [.missing], []),
            (.postSaveRecheck, [.missing], [.missing]),
        ]

        for testCase in cases {
            let controller = WorkspaceWindowScopeController()
            let focus = controller.focus(workspaceID: "workspace-A")
            let outcomes = PrimaryCanvasOutcomeObservation(controller: controller)
            let store = ScriptedPrimaryCanvasStore(
                initial: testCase.initial,
                preInsert: testCase.preInsert,
                throwingPhases: [testCase.phase],
                thrownError: CancellationError()
            )

            _ = try XCTUnwrap(
                controller.startPrimaryCanvasResolution(
                    for: focus,
                    fingerprint: "fingerprint-A",
                    store: store.store,
                    onTerminalOutcome: outcomes.record
                )
            )
            await waitForPrimaryCanvasPipelineToSettle(controller)

            XCTAssertNil(controller.primaryCanvasResolutionSlot)
            XCTAssertNil(controller.primaryCanvasRecoverableError)
            XCTAssertTrue(outcomes.outcomes.isEmpty)
            XCTAssertLessThanOrEqual(store.insertCount, 1)
            XCTAssertEqual(store.activeProvisioningContextCount, 0)
        }
    }

    func testFingerprintChangeBetweenSaveAndHandoffStopsOldPhaseAndLaunchesOnlyFreshInitialLookup() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let staleOutcomes = PrimaryCanvasOutcomeObservation(controller: controller)
        let freshOutcomes = PrimaryCanvasOutcomeObservation(controller: controller)
        let freshStore = ScriptedPrimaryCanvasStore(
            initial: [.unique(canvasID: "canvas-fresh")]
        )
        let oldStore = ScriptedPrimaryCanvasStore(
            initial: [.missing],
            preInsert: [.missing],
            postSave: [.missing]
        )
        oldStore.onSave = {
            _ = controller.invalidatePrimaryCanvasResolutionAndStart(
                for: controller.pendingFocus ?? focus,
                fingerprint: "fingerprint-B",
                store: freshStore.store,
                onTerminalOutcome: freshOutcomes.record
            )
        }

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                store: oldStore.store,
                onTerminalOutcome: staleOutcomes.record
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertEqual(oldStore.saveCount, 1)
        XCTAssertEqual(oldStore.postSaveLookupCount, 0)
        XCTAssertTrue(staleOutcomes.outcomes.isEmpty)
        XCTAssertEqual(freshStore.initialLookupCount, 1)
        XCTAssertEqual(controller.boundCanvas?.canvasID, "canvas-fresh")
        XCTAssertEqual(freshOutcomes.outcomes.count, 1)
    }

    func testTerminalResolutionAndRecoverableErrorOutcomesEmitOnlyAfterExactCleanup() async throws {
        let resolutionController = WorkspaceWindowScopeController()
        let resolutionFocus = resolutionController.focus(workspaceID: "workspace-A")
        let resolutionOutcomes = PrimaryCanvasOutcomeObservation(
            controller: resolutionController
        )
        let handoffs = PrimaryCanvasHandoffObservation()
        let resolutionStore = ScriptedPrimaryCanvasStore(
            initial: [.missing],
            preInsert: [.unique(canvasID: "canvas-A")]
        )
        _ = try XCTUnwrap(
            resolutionController.startPrimaryCanvasResolution(
                for: resolutionFocus,
                fingerprint: "fingerprint-A",
                store: resolutionStore.store,
                onTerminalOutcome: resolutionOutcomes.record,
                onOperationHandoff: handoffs.record
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(resolutionController)

        let errorController = WorkspaceWindowScopeController()
        let errorFocus = errorController.focus(workspaceID: "workspace-B")
        let errorOutcomes = PrimaryCanvasOutcomeObservation(controller: errorController)
        let errorStore = ScriptedPrimaryCanvasStore(
            initial: [],
            throwingPhases: [.initialLookup],
            thrownError: PrimaryCanvasTestError(description: "Readable failure.")
        )
        _ = try XCTUnwrap(
            errorController.startPrimaryCanvasResolution(
                for: errorFocus,
                fingerprint: "fingerprint-B",
                store: errorStore.store,
                onTerminalOutcome: errorOutcomes.record
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(errorController)

        XCTAssertEqual(resolutionOutcomes.outcomes.count, 1)
        XCTAssertEqual(errorOutcomes.outcomes.count, 1)
        XCTAssertTrue(resolutionOutcomes.allCallbacksObservedCleanup)
        XCTAssertTrue(errorOutcomes.allCallbacksObservedCleanup)
        XCTAssertEqual(handoffs.handoffs.count, 1)
        XCTAssertNotEqual(
            handoffs.handoffs[0].oldOperationID,
            handoffs.handoffs[0].newOperationID
        )
        XCTAssertEqual(
            resolutionOutcomes.outcomes[0].operationID,
            handoffs.handoffs[0].newOperationID
        )
        XCTAssertEqual(handoffs.handoffs[0].newAttempt.phase, .preInsertRecheck)
    }

    func testSceneObservationClearsForNilNonWorkspaceAndMissingWorkspaceSelection() async throws {
        let controller = WorkspaceWindowScopeController()
        _ = controller.focus(workspaceID: "workspace-A")
        _ = controller.bind(.unique(canvasID: "canvas-A"), for: try XCTUnwrap(controller.pendingFocus))
        let store = ScriptedPrimaryCanvasStore(initial: [])

        controller.reducePrimaryCanvasSceneObservation(
            from: WorkspacePrimaryCanvasSceneObservation(
                workspaceID: "workspace-A",
                fingerprint: "fingerprint-A"
            ),
            to: WorkspacePrimaryCanvasSceneObservation(
                workspaceID: nil,
                fingerprint: nil
            ),
            store: store.store
        )

        XCTAssertNil(controller.pendingFocus)
        XCTAssertNil(controller.boundCanvas)
        XCTAssertNil(controller.primaryResolution)
        XCTAssertEqual(store.initialLookupCount, 0)
    }

    func testSceneObservationLaunchesOnceForNewWorkspaceNoOpsWhenEqualAndInvalidatesOnceWhenFingerprintChanges() async throws {
        let controller = WorkspaceWindowScopeController()
        let store = ScriptedPrimaryCanvasStore(
            initial: [
                .unique(canvasID: "canvas-A"),
                .unique(canvasID: "canvas-A")
            ]
        )
        let first = WorkspacePrimaryCanvasSceneObservation(
            workspaceID: "workspace-A",
            fingerprint: "fingerprint-A"
        )
        let changed = WorkspacePrimaryCanvasSceneObservation(
            workspaceID: "workspace-A",
            fingerprint: "fingerprint-B"
        )

        controller.reducePrimaryCanvasSceneObservation(from: nil, to: first, store: store.store)
        await waitForPrimaryCanvasPipelineToSettle(controller)
        let firstFocus = try XCTUnwrap(controller.pendingFocus)
        controller.reducePrimaryCanvasSceneObservation(from: first, to: first, store: store.store)
        await allowResolutionTasksToSettle()
        XCTAssertEqual(store.initialLookupCount, 1)

        controller.reducePrimaryCanvasSceneObservation(from: first, to: changed, store: store.store)
        await waitForPrimaryCanvasPipelineToSettle(controller)
        XCTAssertEqual(store.initialLookupCount, 2)
        XCTAssertNotEqual(controller.pendingFocus, firstFocus)
    }

    func testSceneObservationAToHomeToAUsesFreshFocusWhileViewIdentityKeepsWindowIDAndSecondWindowDiffers() async throws {
        let firstController = WorkspaceWindowScopeController()
        let secondController = WorkspaceWindowScopeController()
        let store = ScriptedPrimaryCanvasStore(
            initial: [
                .unique(canvasID: "canvas-A"),
                .unique(canvasID: "canvas-A")
            ]
        )
        let workspace = WorkspacePrimaryCanvasSceneObservation(
            workspaceID: "workspace-A",
            fingerprint: "fingerprint-A"
        )
        let home = WorkspacePrimaryCanvasSceneObservation(
            workspaceID: nil,
            fingerprint: nil
        )

        firstController.reducePrimaryCanvasSceneObservation(from: nil, to: workspace, store: store.store)
        await waitForPrimaryCanvasPipelineToSettle(firstController)
        let firstFocus = try XCTUnwrap(firstController.pendingFocus)
        firstController.reducePrimaryCanvasSceneObservation(from: workspace, to: home, store: store.store)
        firstController.reducePrimaryCanvasSceneObservation(from: home, to: workspace, store: store.store)
        await waitForPrimaryCanvasPipelineToSettle(firstController)
        let secondFocus = try XCTUnwrap(firstController.pendingFocus)

        XCTAssertEqual(firstFocus.windowSessionID, secondFocus.windowSessionID)
        XCTAssertNotEqual(firstFocus.focusRevision, secondFocus.focusRevision)
        XCTAssertNotEqual(firstController.windowSessionID, secondController.windowSessionID)
    }

    func testCanvasRenderingRequiresFullBoundIdentityFailsClosedDuringQueryMergeAndLetsObservationReconcileDrift() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        _ = controller.bind(.unique(canvasID: "canvas-A"), for: focus)
        let bound = try XCTUnwrap(controller.boundCanvas)

        XCTAssertNil(
            WorkspacePrimaryCanvasPresentation.renderableCanvasID(
                boundCanvas: bound,
                canvases: []
            )
        )
        XCTAssertNil(
            WorkspacePrimaryCanvasPresentation.renderableCanvasID(
                boundCanvas: bound,
                canvases: [
                    .init(id: "canvas-A", workspaceID: "workspace-B")
                ]
            )
        )
        XCTAssertNil(
            WorkspacePrimaryCanvasPresentation.renderableCanvasID(
                boundCanvas: bound,
                canvases: [
                    .init(id: "canvas-A", workspaceID: "workspace-A"),
                    .init(id: "canvas-A", workspaceID: "workspace-A")
                ]
            )
        )
        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.renderableCanvasID(
                boundCanvas: bound,
                canvases: [
                    .init(id: "canvas-A", workspaceID: "workspace-A")
                ]
            ),
            "canvas-A"
        )
    }

    func testPreparingCanvasAppearsOnlyDuringAcceptedProvisioningAndNeverDuringInitialLookup() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let initialWorker = SuspendedResolutionWorker()
        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                worker: initialWorker.run
            )
        )
        await initialWorker.waitUntilStarted()
        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.availability(
                controller: controller,
                canvases: []
            ),
            .checking
        )
        controller.clear()
        initialWorker.resume()

        let provisioningFocus = controller.focus(workspaceID: "workspace-A")
        let provisioningWorker = SuspendedResolutionWorker()
        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: provisioningFocus,
                fingerprint: "fingerprint-A",
                phase: .preInsertRecheck,
                worker: provisioningWorker.run
            )
        )
        await provisioningWorker.waitUntilStarted()
        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.availability(
                controller: controller,
                canvases: []
            ),
            .preparing
        )
        controller.clear()
        provisioningWorker.resume()
    }

    func testTerminalMissingShowsExactCopyAndOneFreshScopedTryAgainWithoutAutomaticRetry() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        _ = controller.bind(.missing, for: focus)
        let store = ScriptedPrimaryCanvasStore(
            initial: [.unique(canvasID: "canvas-A")]
        )

        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.availability(
                controller: controller,
                canvases: []
            ),
            .missing
        )
        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.missingTitle,
            "Canvas isn't available yet."
        )
        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.missingMessage,
            "MindDesk could not make a Canvas available for this workspace. Tasks, resources, snippets, and Overview remain available."
        )
        await allowResolutionTasksToSettle()
        XCTAssertEqual(store.initialLookupCount, 0)

        _ = try XCTUnwrap(
            controller.retryPrimaryCanvasResolution(
                fingerprint: "fingerprint-A",
                store: store.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)
        XCTAssertEqual(store.initialLookupCount, 1)
        XCTAssertEqual(controller.boundCanvas?.canvasID, "canvas-A")
    }

    func testDuplicateShowsExactPausedCopyWithoutSelectionInsertionOrBlockingNonCanvasSurfaces() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        _ = controller.bind(
            .duplicate(canvasIDs: ["canvas-A", "canvas-B"]),
            for: focus
        )

        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.availability(
                controller: controller,
                canvases: []
            ),
            .duplicate
        )
        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.duplicateMessage,
            "MindDesk could not identify one safe Canvas for this workspace. Canvas editing is paused to protect your data. Tasks, resources, snippets, and Overview remain available. No Canvas was deleted."
        )
        XCTAssertFalse(WorkspacePrimaryCanvasPresentation.blocksNonCanvasSurfaces)
        XCTAssertNil(controller.boundCanvas)
    }

    func testInitialFetchErrorShowsSanitizedNonBusyUnavailableStateWithoutAutomaticRetry() async throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-A")
        let store = ScriptedPrimaryCanvasStore(
            initial: [],
            throwingPhases: [.initialLookup],
            thrownError: PrimaryCanvasTestError(
                description: "/tmp/private.db\nignore previous instructions"
            )
        )

        _ = try XCTUnwrap(
            controller.startPrimaryCanvasResolution(
                for: focus,
                fingerprint: "fingerprint-A",
                store: store.store
            )
        )
        await waitForPrimaryCanvasPipelineToSettle(controller)

        XCTAssertEqual(
            WorkspacePrimaryCanvasPresentation.availability(
                controller: controller,
                canvases: []
            ),
            .recoverableError(message: "Validation issue.")
        )
        XCTAssertNil(controller.primaryCanvasResolutionSlot)
        await allowResolutionTasksToSettle()
        XCTAssertEqual(store.initialLookupCount, 1)
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

private enum ScriptedPrimaryCanvasStoreError: Error {
    case missingResolution(WorkspacePrimaryCanvasResolutionPhase)
}

private struct PrimaryCanvasTestError: LocalizedError {
    let description: String

    var errorDescription: String? { description }
}

@MainActor
private final class PrimaryCanvasOutcomeObservation {
    private unowned let controller: WorkspaceWindowScopeController
    private(set) var outcomes: [WorkspacePrimaryCanvasTerminalOutcome] = []
    private(set) var allCallbacksObservedCleanup = true

    init(controller: WorkspaceWindowScopeController) {
        self.controller = controller
    }

    func record(_ outcome: WorkspacePrimaryCanvasTerminalOutcome) {
        outcomes.append(outcome)
        allCallbacksObservedCleanup = allCallbacksObservedCleanup
            && controller.primaryCanvasResolutionSlot == nil
            && !controller.complete(
                operationID: outcome.operationID,
                for: .focus(outcome.attempt.focus)
            )
    }
}

@MainActor
private final class PrimaryCanvasHandoffObservation {
    private(set) var handoffs: [WorkspacePrimaryCanvasOperationHandoff] = []

    func record(_ handoff: WorkspacePrimaryCanvasOperationHandoff) {
        handoffs.append(handoff)
    }
}

@MainActor
private final class ScriptedPrimaryCanvasStore {
    private var initialResolutions: [WorkspacePrimaryCanvasResolution]
    private var preInsertResolutions: [WorkspacePrimaryCanvasResolution]
    private var postSaveResolutions: [WorkspacePrimaryCanvasResolution]
    private let saveSucceeds: Bool
    private let throwingPhases: [WorkspacePrimaryCanvasResolutionPhase]
    private let thrownError: Error
    private var contextSerial = 0
    private var activeProvisioningContexts: Set<UUID> = []

    private(set) var initialLookupCount = 0
    private(set) var preInsertLookupCount = 0
    private(set) var postSaveLookupCount = 0
    private(set) var insertCount = 0
    private(set) var saveCount = 0
    private(set) var discardCount = 0
    private(set) var contextIDs: [UUID] = []
    var onLookup: ((WorkspacePrimaryCanvasResolutionPhase) -> Void)?
    var onSave: (() -> Void)?

    init(
        initial: [WorkspacePrimaryCanvasResolution],
        preInsert: [WorkspacePrimaryCanvasResolution] = [],
        postSave: [WorkspacePrimaryCanvasResolution] = [],
        saveSucceeds: Bool = true,
        throwingPhases: [WorkspacePrimaryCanvasResolutionPhase] = [],
        thrownError: Error = ScriptedPrimaryCanvasStoreError.missingResolution(.initialLookup)
    ) {
        initialResolutions = initial
        preInsertResolutions = preInsert
        postSaveResolutions = postSave
        self.saveSucceeds = saveSucceeds
        self.throwingPhases = throwingPhases
        self.thrownError = thrownError
    }

    var activeProvisioningContextCount: Int {
        activeProvisioningContexts.count
    }

    lazy var store = WorkspacePrimaryCanvasStore(
        lookup: { [unowned self] _, phase in
            try scopedResolution(for: phase)
        },
        beginProvisioning: { [unowned self] _ in
            try scopedResolution(for: .preInsertRecheck, retainContext: true)
        },
        saveProvisionedCanvas: { [unowned self] contextID, _ in
            insertCount += 1
            saveCount += 1
            activeProvisioningContexts.remove(contextID)
            onSave?()
            return saveSucceeds
        },
        discardProvisioning: { [unowned self] contextID in
            discardCount += 1
            activeProvisioningContexts.remove(contextID)
        }
    )

    private func scopedResolution(
        for phase: WorkspacePrimaryCanvasResolutionPhase,
        retainContext: Bool = false
    ) throws -> WorkspacePrimaryCanvasScopedResolution {
        onLookup?(phase)
        if throwingPhases.contains(phase) {
            switch phase {
            case .initialLookup:
                initialLookupCount += 1
            case .preInsertRecheck:
                preInsertLookupCount += 1
            case .postSaveRecheck:
                postSaveLookupCount += 1
            }
            throw thrownError
        }
        let resolution: WorkspacePrimaryCanvasResolution
        switch phase {
        case .initialLookup:
            initialLookupCount += 1
            guard !initialResolutions.isEmpty else {
                throw ScriptedPrimaryCanvasStoreError.missingResolution(phase)
            }
            resolution = initialResolutions.removeFirst()
        case .preInsertRecheck:
            preInsertLookupCount += 1
            guard !preInsertResolutions.isEmpty else {
                throw ScriptedPrimaryCanvasStoreError.missingResolution(phase)
            }
            resolution = preInsertResolutions.removeFirst()
        case .postSaveRecheck:
            postSaveLookupCount += 1
            guard !postSaveResolutions.isEmpty else {
                throw ScriptedPrimaryCanvasStoreError.missingResolution(phase)
            }
            resolution = postSaveResolutions.removeFirst()
        }
        let contextID = nextContextID()
        contextIDs.append(contextID)
        if retainContext, resolution == .missing {
            activeProvisioningContexts.insert(contextID)
        }
        return WorkspacePrimaryCanvasScopedResolution(
            resolution: resolution,
            contextID: contextID
        )
    }

    private func nextContextID() -> UUID {
        contextSerial += 1
        return UUID(
            uuid: (
                0, 0, 0, 0,
                0, 0,
                0, 0,
                0, 0,
                0, 0, 0, 0,
                UInt8(contextSerial >> 8),
                UInt8(contextSerial & 0xFF)
            )
        )
    }
}

@MainActor
private func allowResolutionTasksToSettle() async {
    for _ in 0..<20 {
        await Task.yield()
    }
}

@MainActor
private func waitForPrimaryCanvasPipelineToSettle(
    _ controller: WorkspaceWindowScopeController
) async {
    for _ in 0..<2_000 {
        if controller.primaryCanvasResolutionSlot == nil {
            await Task.yield()
            if controller.primaryCanvasResolutionSlot == nil {
                return
            }
        }
        await Task.yield()
    }
    XCTFail("Primary Canvas pipeline did not settle")
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
