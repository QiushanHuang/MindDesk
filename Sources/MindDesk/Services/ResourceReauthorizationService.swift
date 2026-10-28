import Foundation
import MindDeskCore
import SwiftData

@MainActor
enum ResourceReauthorizationService {
    static func chooseReplacement(for resource: ResourcePinModel, in context: ModelContext, onStatus: (String) -> Void) {
        guard let url = FileDialogs.chooseResource() else { return }
        do {
            try applySelectedURL(url, to: resource, in: context)
            onStatus("Reauthorized \(url.path)")
        } catch {
            onStatus(error.localizedDescription)
        }
    }

    static func applySelectedURL(_ url: URL, to resource: ResourcePinModel, in context: ModelContext) throws {
        let selectedType = ResourceImportService.targetType(for: url)
        guard ResourceAuthorizationPolicy.acceptsReauthorization(
            existingTargetType: resource.targetTypeRaw,
            selectedTargetType: selectedType.rawValue
        ) else {
            throw WorkbenchError.resourceTypeMismatch(expected: resource.targetTypeRaw, selected: selectedType.rawValue)
        }
        let bookmarkData = try BookmarkService().makeBookmark(for: url)
        resource.securityScopedBookmarkData = bookmarkData
        resource.displayPath = url.path
        resource.lastResolvedPath = url.path
        resource.originalName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        resource.status = .available
        resource.updatedAt = .now
        resource.refreshSearchText()
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
