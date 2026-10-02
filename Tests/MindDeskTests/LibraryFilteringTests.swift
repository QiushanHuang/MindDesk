import Foundation
import MindDeskCore
import XCTest
@testable import MindDesk

final class LibraryFilteringTests: XCTestCase {
    func testResourceFilteringPreservesCachedFallbackAndWorkspaceSearchSemantics() {
        let cached = resource(0, title: "Hidden title", note: "Invisible note")
        cached.searchText = "cached-only boundary"
        let fallback = resource(1, title: "Fallback title", note: "Legacy NOTE", tags: ["review-tag"])
        fallback.searchText = ""
        let folder = resource(2, title: "Folder", targetType: .folder)
        let resources = [folder, fallback, cached]
        let usage = [cached.id: [ResourceWorkspaceUsage(id: "w", title: "Research Project")]]

        func result(_ query: String, type: ResourceTargetType? = nil) -> [String] {
            ResourceListFilteringPolicy.visible(resources, targetFilter: type, searchText: query,
                                                workspaceUsageByResourceID: usage).map(\.id)
        }

        XCTAssertEqual(result(" \n CACHED-ONLY \t"), [cached.id])
        XCTAssertEqual(result("research project"), [cached.id])
        XCTAssertEqual(result("boundary research"), [cached.id], "Search can span cached text and workspace names")
        XCTAssertEqual(result("hidden title"), [], "A nonempty search cache remains authoritative")
        XCTAssertEqual(result("legacy note"), [fallback.id])
        XCTAssertEqual(result("review-tag"), [fallback.id])
        XCTAssertEqual(result("research", type: .folder), [])
        XCTAssertEqual(result("\n  ", type: .folder), [folder.id])
    }

    func testResourceFilterBeforeSortMatchesLegacyResultsForLargeLibrary() {
        let resources = (0..<2_048).map { index in
            let item = resource(index, title: index.isMultiple(of: 128) ? "Needle" : "Plan \(index % 11)",
                                targetType: index.isMultiple(of: 3) ? .folder : .file,
                                note: index.isMultiple(of: 79) ? "Review needed" : "")
            item.sortIndex = index % 7
            item.updatedAt = Date(timeIntervalSince1970: Double(index % 5))
            item.originalName = "Item \(index % 13)"
            item.customName = index.isMultiple(of: 113) ? "Alias" : ""
            item.refreshSearchText()
            if index.isMultiple(of: 17) { item.searchText = "" }
            return item
        }.reversed().map { $0 }
        let usage = Dictionary(uniqueKeysWithValues: resources.enumerated().compactMap { index, item in
            index.isMultiple(of: 19)
                ? (item.id, [ResourceWorkspaceUsage(id: "workspace", title: "Shared Research")]) : nil
        })
        for type: ResourceTargetType? in [nil, .folder, .file] {
            for query in ["", " \n ", "NEEDLE", "review", "alias", "shared research", "no match"] {
                let actual = ResourceListFilteringPolicy.visible(resources, targetFilter: type, searchText: query,
                                                                 workspaceUsageByResourceID: usage)
                let expected = legacyResources(resources, type: type, query: query, usage: usage)
                XCTAssertEqual(actual.map(\.id), expected.map(\.id), "type=\(String(describing: type)), query=\(query)")
            }
        }
        XCTAssertEqual(ResourceListFilteringPolicy.visible(resources, targetFilter: nil, searchText: "needle",
                                                            workspaceUsageByResourceID: usage).count, 16)
    }

    func testSnippetFilterBeforeProjectionMatchesLegacyScopeAndLocalizedSearch() {
        let snippets = (0..<1_024).map { index in
            SnippetModel(id: "snippet-\(index)", workspaceId: index.isMultiple(of: 3) ? "selected" : "other",
                         title: "Plan \(index % 11)", kind: index.isMultiple(of: 2) ? .prompt : .command,
                         body: index.isMultiple(of: 128) ? "Exact phrase Needle" : "ordinary body",
                         details: index.isMultiple(of: 17) ? "Résumé review" : "details",
                         scope: index.isMultiple(of: 5) ? .global : .workspace,
                         updatedAt: Date(timeIntervalSince1970: Double(index % 7)))
        }.reversed().map { $0 }
        for scope: WorkbenchScope? in [nil, .global, .workspace] {
            for workspaceID: String? in [nil, "selected", "absent"] {
                for query in ["", "NEEDLE", "Exact phrase", " résumé ", "résumé", " ", "absent"] {
                    let actual = SnippetListFilteringPolicy.visible(snippets, scope: scope, workspaceId: workspaceID, searchText: query)
                    let expected = legacySnippets(snippets, scope: scope, workspaceID: workspaceID, query: query)
                    XCTAssertEqual(actual.map(\.id), expected.map(\.id), "scope=\(String(describing: scope)), workspace=\(String(describing: workspaceID)), query=\(query)")
                }
            }
        }
        XCTAssertEqual(SnippetListFilteringPolicy.visible(snippets, scope: nil, workspaceId: nil, searchText: "Needle").count, 8)
        XCTAssertTrue(SnippetListFilteringPolicy.visible(snippets, scope: nil, workspaceId: nil, searchText: " Needle ").isEmpty,
                      "Snippet search keeps its existing significant whitespace")
    }

    private func resource(_ index: Int, title: String, targetType: ResourceTargetType = .file,
                          note: String = "", tags: [String] = []) -> ResourcePinModel {
        ResourcePinModel(id: "resource-\(index)", title: title, targetType: targetType,
                         displayPath: "/Demo/\(index)", lastResolvedPath: "/Demo/\(index)",
                         note: note, tags: tags, scope: .global, originalName: title,
                         updatedAt: Date(timeIntervalSince1970: 0))
    }

    // Keep the prior sort-then-search pipeline as an independent equivalence oracle.
    private func legacyResources(_ resources: [ResourcePinModel], type: ResourceTargetType?, query: String,
                                 usage: [String: [ResourceWorkspaceUsage]]) -> [ResourcePinModel] {
        let typed = resources.filter { resource in
            guard let type else { return true }
            return resource.targetType == type
        }
        let ordered = ResourceListOrderingPolicy.ordered(typed)
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ordered }
        return ordered.filter { resource in
            let cached = resource.searchText.isEmpty
                ? [resource.title, resource.originalName, resource.customName, resource.displayPath,
                   resource.note, resource.tagsText].joined(separator: " ").lowercased() : resource.searchText
            let workspaces = usage[resource.id, default: []].map(\.title).joined(separator: " ").lowercased()
            return "\(cached) \(workspaces)".contains(query)
        }
    }

    private func legacySnippets(_ snippets: [SnippetModel], scope: WorkbenchScope?, workspaceID: String?, query: String) -> [SnippetModel] {
        let byID = Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0) })
        let records = snippets.map {
            SnippetLibraryRecord(id: $0.id, scope: $0.scopeRaw, workspaceId: $0.workspaceId, title: $0.title, updatedAt: $0.updatedAt)
        }
        let scoped = records.filter { record in
            guard let scope else { return true }
            if scope == .global { return record.scope == "global" }
            return record.scope == "global" || record.workspaceId == workspaceID
        }
        let visible = SnippetLibraryFiltering.ordered(scoped).compactMap { byID[$0.id] }
        guard !query.isEmpty else { return visible }
        return visible.filter { $0.title.localizedCaseInsensitiveContains(query) ||
            $0.body.localizedCaseInsensitiveContains(query) || $0.details.localizedCaseInsensitiveContains(query) }
    }
}
