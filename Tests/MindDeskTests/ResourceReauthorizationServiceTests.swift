import Foundation
import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class ResourceReauthorizationServiceTests: XCTestCase {
    func testReconnectingFileUpdatesItsReferenceAndAuthorization() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("minddesk-reconnect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let replacement = folder.appendingPathComponent("replacement.txt")
        try Data("fixture".utf8).write(to: replacement)
        let container = try ModelContainer(for: ResourcePinModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let resource = ResourcePinModel(title: "Reference", targetType: .file, displayPath: "/missing.txt", lastResolvedPath: "/missing.txt", scope: .global, status: .unavailable)
        container.mainContext.insert(resource)
        try container.mainContext.save()

        try ResourceReauthorizationService.applySelectedURL(replacement, to: resource, in: container.mainContext)

        XCTAssertEqual(resource.displayPath, replacement.path)
        XCTAssertEqual(resource.lastResolvedPath, replacement.path)
        XCTAssertEqual(resource.originalName, "replacement.txt")
        XCTAssertEqual(resource.status, .available)
        XCTAssertNotNil(resource.securityScopedBookmarkData)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<ResourcePinModel>()).first?.displayPath, replacement.path)
    }

    func testReconnectingWithWrongTypeLeavesExistingReferenceUnchanged() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("minddesk-reconnect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let container = try ModelContainer(for: ResourcePinModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let resource = ResourcePinModel(title: "Reference", targetType: .file, displayPath: "/missing.txt", lastResolvedPath: "/missing.txt", scope: .global, status: .unavailable)
        container.mainContext.insert(resource)
        try container.mainContext.save()

        XCTAssertThrowsError(try ResourceReauthorizationService.applySelectedURL(folder, to: resource, in: container.mainContext))
        XCTAssertEqual(resource.displayPath, "/missing.txt")
        XCTAssertEqual(resource.lastResolvedPath, "/missing.txt")
        XCTAssertEqual(resource.status, .unavailable)
        XCTAssertNil(resource.securityScopedBookmarkData)
    }
}
