import MindDeskCore
import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class LegacyReviewImportRejectionTests: XCTestCase {
    func testInLimitProposalEnvelopeAndValidationReportUsePermanentLockAndNeutralManifestError() {
        for format in [
            "minddesk.proposal.envelope",
            "minddesk.validation.report"
        ] {
            assertManifestImportError(neutralLegacyImportMessage) {
                try ImportExportService().decodeManifest(from: rawLegacyDocument(format: format))
            }
        }
    }

    func testInLimitLegacyReviewDocumentCannotImportAsManifestOrCreateRecords() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let unsavedSentinel = WorkspaceModel(id: "unsaved-sentinel", title: "Unsaved sentinel")
        context.insert(unsavedSentinel)
        let recordCountsBefore = try recordCounts(in: context)
        let insertedModelsBefore = context.insertedModelsArray.count
        let changedModelsBefore = context.changedModelsArray.count
        let deletedModelsBefore = context.deletedModelsArray.count
        XCTAssertTrue(context.hasChanges)

        let importBoundarySpy = OperationInvocationSpy()
        let willSaveSpy = OperationInvocationSpy()
        let didSaveSpy = OperationInvocationSpy()
        let notificationCenter = NotificationCenter.default
        let willSaveObserver = notificationCenter.addObserver(
            forName: ModelContext.willSave,
            object: context,
            queue: nil
        ) { _ in
            willSaveSpy.record()
        }
        let didSaveObserver = notificationCenter.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: nil
        ) { _ in
            didSaveSpy.record()
        }
        defer {
            notificationCenter.removeObserver(willSaveObserver)
            notificationCenter.removeObserver(didSaveObserver)
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minddesk-legacy-rejection-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixtureURL = directory.appendingPathComponent("legacy-review.json")
        let legacyData = rawLegacyDocument(format: "minddesk.interchange.package")
        try legacyData.write(to: fixtureURL)
        let directoryBefore = try directorySnapshot(at: directory)

        assertManifestImportError(neutralLegacyImportMessage) {
            let manifest = try ImportExportService().decodeManifest(from: fixtureURL)
            importBoundarySpy.record()
            return try ManifestImportService().importRecords(from: manifest, into: context)
        }

        XCTAssertEqual(importBoundarySpy.count, 0)
        XCTAssertEqual(willSaveSpy.count, 0)
        XCTAssertEqual(didSaveSpy.count, 0)
        XCTAssertEqual(try directorySnapshot(at: directory), directoryBefore)
        XCTAssertEqual(try recordCounts(in: context), recordCountsBefore)
        XCTAssertEqual(context.insertedModelsArray.count, insertedModelsBefore)
        XCTAssertEqual(context.changedModelsArray.count, changedModelsBefore)
        XCTAssertEqual(context.deletedModelsArray.count, deletedModelsBefore)
        XCTAssertTrue(context.hasChanges)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<WorkspaceModel>()).map(\.id),
            [unsavedSentinel.id]
        )
    }

    func testAmbiguousFormatMarkersRejectWithoutEnteringCapabilityLock() {
        let cases = [
            Data("{\"format\":\"minddesk.interchange.package\",\"format\":\"minddesk.interchange.package\"}".utf8),
            Data("{\"format\":\"minddesk.proposal.envelope\",\"format\":\"minddesk.future.document\"}".utf8),
            Data("{\"format\":null,\"schemaVersion\":2}".utf8),
            Data("{\"format\":false,\"schemaVersion\":2}".utf8),
            Data("{\"format\":42,\"schemaVersion\":2}".utf8),
            Data("{\"format\":[],\"schemaVersion\":2}".utf8),
            Data("{\"format\":{\"value\":\"minddesk.validation.report\"},\"schemaVersion\":2}".utf8)
        ]

        for data in cases {
            let classification = MindDeskJSONDocumentClassifier.classify(data)
            XCTAssertEqual(classification.kind, .unknown)
            XCTAssertTrue(classification.hasTopLevelFormat)
            assertManifestImportError(formattedNonManifestMessage) {
                try ImportExportService().decodeManifest(from: data)
            }
        }
    }

    func testNestedHistoricalMarkersRejectWithoutEnteringCapabilityLock() throws {
        for historicalFormat in [
            "minddesk.interchange.package",
            "minddesk.proposal.envelope",
            "minddesk.validation.report"
        ] {
            let unknownFormatted = Data(
                "{\"format\":\"minddesk.future.document\",\"payload\":{\"format\":\"\(historicalFormat)\"}}".utf8
            )
            assertManifestImportError(formattedNonManifestMessage) {
                try ImportExportService().decodeManifest(from: unknownFormatted)
            }

            let schemaOnlyManifest = legacyManifestWithNestedFormat(historicalFormat)
            let classification = MindDeskJSONDocumentClassifier.classify(schemaOnlyManifest)
            XCTAssertEqual(classification.kind, .manifest)
            XCTAssertFalse(classification.hasTopLevelFormat)
            let decoded = try ImportExportService().decodeManifest(from: schemaOnlyManifest)
            XCTAssertEqual(decoded.schemaVersion, 2)
            XCTAssertTrue(decoded.workspaces.isEmpty)
        }
    }

    func testInvalidAndTrailingJSONRejectWithoutEnteringCapabilityLock() {
        var invalidUTF8 = Data("{\"format\":\"minddesk.interchange.package\",\"payload\":\"".utf8)
        invalidUTF8.append(0xFF)
        invalidUTF8.append(Data("\"}".utf8))
        let cases: [(data: Data, expected: InvalidJSONRejection)] = [
            (Data("{\"format\":\"minddesk.interchange.package\"".utf8), .decodingError),
            (Data("{\"format\":\"minddesk.proposal.envelope\"} {}".utf8), .decodingError),
            (invalidUTF8, .formattedNonManifest)
        ]

        for testCase in cases {
            let classification = MindDeskJSONDocumentClassifier.classify(testCase.data)
            XCTAssertEqual(classification.kind, .unknown)
            XCTAssertFalse(classification.hasTopLevelFormat)
            XCTAssertThrowsError(try ImportExportService().decodeManifest(from: testCase.data)) { error in
                XCTAssertFalse(error is CanvasReviewCapabilityError)
                switch testCase.expected {
                case .decodingError:
                    XCTAssertTrue(error is DecodingError, "Expected ordinary JSON decode failure, got \(error)")
                case .formattedNonManifest:
                    guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                        return XCTFail("Expected ordinary formatted rejection, got \(error)")
                    }
                    XCTAssertEqual(message, formattedNonManifestMessage)
                }
            }
        }
    }

    func testPrivateLegacyRejectionBranchCallsOnlyPermanentLockWithoutHistoricalDecode() throws {
        let serviceSource = try repositorySource("Sources/MindDesk/Services/SystemServices.swift")
        let rejectionSource = try functionSource(
            startingWith: "private func rejectLegacyReviewDocument()",
            in: serviceSource
        )
        XCTAssertEqual(
            normalizedSource(rejectionSource),
            normalizedSource("""
            private func rejectLegacyReviewDocument() throws -> Never {
                try CanvasReviewCapabilityLock.requireEnabled()
            }
            """)
        )

        let decoderSource = try functionSource(
            startingWith: "func decodeManifest(from data: Data)",
            in: serviceSource
        )
        let sizeGuard = try XCTUnwrap(decoderSource.range(of: "guard data.count"))
        let classifier = try XCTUnwrap(
            decoderSource.range(of: "MindDeskJSONDocumentClassifier.classify(data)")
        )
        let rejectionCall = try XCTUnwrap(decoderSource.range(of: "try rejectLegacyReviewDocument()"))
        let ordinaryDecoder = try XCTUnwrap(decoderSource.range(of: "JSONDecoder.minddesk"))
        XCTAssertLessThan(sizeGuard.lowerBound, classifier.lowerBound)
        XCTAssertLessThan(classifier.lowerBound, rejectionCall.lowerBound)
        XCTAssertLessThan(rejectionCall.lowerBound, ordinaryDecoder.lowerBound)
        XCTAssertTrue(
            decoderSource.contains("case .interchangePackage, .proposalEnvelope, .validationReport:")
        )
        for forbidden in [
            "MindDeskInterchangePackage",
            "MindDeskProposalEnvelope",
            "MindDeskValidationReport",
            "decodeProposal",
            "JSONSerialization",
            "FileDialogs",
            "ClipboardService",
            "Process",
            "Terminal",
            "ModelContext",
            "ManifestImportService",
            "pending",
            "sheet"
        ] {
            XCTAssertFalse(decoderSource.contains(forbidden), "Legacy rejection reached forbidden symbol \(forbidden)")
        }
    }

    private var neutralLegacyImportMessage: String {
        "This JSON document is not supported by this version of MindDesk and cannot be imported as a manifest."
    }

    private var formattedNonManifestMessage: String {
        "MindDesk formatted JSON files that are not manifests cannot be imported as manifests."
    }

    private func rawLegacyDocument(format: String) -> Data {
        Data("{\"format\":\"\(format)\"}".utf8)
    }

    private func legacyManifestWithNestedFormat(_ format: String) -> Data {
        Data("""
        {
          "schemaVersion": 2,
          "exportedAt": "1970-01-01T00:00:00Z",
          "workspaces": [],
          "resources": [],
          "snippets": [],
          "canvases": [],
          "nodes": [],
          "edges": [],
          "aliases": [],
          "nested": {"format": "\(format)"}
        }
        """.utf8)
    }

    private func assertManifestImportError<T>(
        _ expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () throws -> T
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                return XCTFail("Expected invalid manifest references error, got \(error)", file: file, line: line)
            }
            XCTAssertEqual(message, expectedMessage, file: file, line: line)
        }
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            WorkspaceModel.self,
            ResourcePinModel.self,
            SnippetModel.self,
            WorkspaceTodoModel.self,
            WorkspaceTodoGroupModel.self,
            CanvasModel.self,
            CanvasNodeModel.self,
            CanvasEdgeModel.self,
            FinderAliasRecordModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func recordCounts(in context: ModelContext) throws -> [Int] {
        [
            try context.fetchCount(FetchDescriptor<WorkspaceModel>()),
            try context.fetchCount(FetchDescriptor<ResourcePinModel>()),
            try context.fetchCount(FetchDescriptor<SnippetModel>()),
            try context.fetchCount(FetchDescriptor<CanvasModel>()),
            try context.fetchCount(FetchDescriptor<CanvasNodeModel>()),
            try context.fetchCount(FetchDescriptor<CanvasEdgeModel>()),
            try context.fetchCount(FetchDescriptor<FinderAliasRecordModel>()),
            try context.fetchCount(FetchDescriptor<WorkspaceTodoGroupModel>()),
            try context.fetchCount(FetchDescriptor<WorkspaceTodoModel>())
        ]
    }

    private func directorySnapshot(at directory: URL) throws -> [String: Data] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return try Dictionary(uniqueKeysWithValues: urls.map { url in
            (url.lastPathComponent, try Data(contentsOf: url))
        })
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func functionSource(startingWith signature: String, in source: String) throws -> String {
        guard let signatureRange = source.range(of: signature),
              let openingBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
            throw SourceTestError.functionNotFound(signature)
        }
        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[signatureRange.lowerBound...cursor])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }
        throw SourceTestError.unbalancedFunction(signature)
    }

    private func normalizedSource(_ source: String) -> String {
        source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private enum SourceTestError: Error {
        case functionNotFound(String)
        case unbalancedFunction(String)
    }

    private enum InvalidJSONRejection {
        case decodingError
        case formattedNonManifest
    }
}

private final class OperationInvocationSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var invocationCount = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return invocationCount
    }

    func record() {
        lock.lock()
        invocationCount += 1
        lock.unlock()
    }
}
