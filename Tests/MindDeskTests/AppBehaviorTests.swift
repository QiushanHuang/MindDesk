import XCTest
@testable import MindDesk

final class AppBehaviorTests: XCTestCase {
    func testResourceTagsPreserveCommaContainingValues() {
        let resource = ResourcePinModel(
            title: "Paper",
            targetType: .file,
            displayPath: "/tmp/Paper.pdf",
            lastResolvedPath: "/tmp/Paper.pdf",
            tags: ["research, 2026", "draft"],
            scope: .global
        )

        XCTAssertEqual(resource.tags, ["research, 2026", "draft"])

        resource.tags = ["field, notes", "archive"]

        XCTAssertEqual(resource.tags, ["field, notes", "archive"])
    }

    func testSnippetTagsPreserveCommaContainingValues() {
        let snippet = SnippetModel(
            title: "Prompt",
            kind: .prompt,
            body: "Summarize",
            tags: ["llm, review", "writing"],
            scope: .global
        )

        XCTAssertEqual(snippet.tags, ["llm, review", "writing"])

        snippet.tags = ["analysis, qa", "saved"]

        XCTAssertEqual(snippet.tags, ["analysis, qa", "saved"])
    }

    func testResourceRenameApplicationPreservesClearedCustomName() {
        let resource = ResourcePinModel(
            title: "Docs",
            targetType: .folder,
            displayPath: "/tmp/Docs",
            lastResolvedPath: "/tmp/Docs",
            scope: .global,
            originalName: "Docs",
            customName: "Project Docs"
        )

        resource.applyRename(titleInput: "   ", note: "Keep note")

        XCTAssertEqual(resource.title, "Docs")
        XCTAssertEqual(resource.customName, "")
        XCTAssertEqual(resource.note, "Keep note")
    }
}
