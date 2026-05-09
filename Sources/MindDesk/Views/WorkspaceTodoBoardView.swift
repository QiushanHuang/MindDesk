import MindDeskCore
import SwiftData
import SwiftUI

private struct MainActorUndoContext: @unchecked Sendable {
    let context: ModelContext
}

private let defaultTodoGroupTitle = "Default"

private struct TodoDeletionSnapshot {
    let id: String
    let workspaceId: String
    let groupId: String?
    let title: String
    let details: String
    let isCompleted: Bool
    let isPinned: Bool
    let sortIndex: Int
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let dueAt: Date?
    let linkedResourceId: String?

    init(_ todo: WorkspaceTodoModel) {
        id = todo.id
        workspaceId = todo.workspaceId
        groupId = todo.groupId
        title = todo.title
        details = todo.details
        isCompleted = todo.isCompleted
        isPinned = todo.isPinned
        sortIndex = todo.sortIndex
        createdAt = todo.createdAt
        updatedAt = todo.updatedAt
        completedAt = todo.completedAt
        dueAt = todo.dueAt
        linkedResourceId = todo.linkedResourceId
    }

    func makeModel() -> WorkspaceTodoModel {
        WorkspaceTodoModel(
            id: id,
            workspaceId: workspaceId,
            groupId: groupId,
            title: title,
            details: details,
            isCompleted: isCompleted,
            isPinned: isPinned,
            sortIndex: sortIndex,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            dueAt: dueAt,
            linkedResourceId: linkedResourceId
        )
    }
}

private struct TodoGroupDeletionSnapshot {
    let id: String
    let workspaceId: String
    let title: String
    let isPinned: Bool
    let sortIndex: Int
    let createdAt: Date
    let updatedAt: Date

    init(_ group: WorkspaceTodoGroupModel) {
        id = group.id
        workspaceId = group.workspaceId
        title = group.title
        isPinned = group.isPinned
        sortIndex = group.sortIndex
        createdAt = group.createdAt
        updatedAt = group.updatedAt
    }

    func makeModel() -> WorkspaceTodoGroupModel {
        WorkspaceTodoGroupModel(
            id: id,
            workspaceId: workspaceId,
            title: title,
            isPinned: isPinned,
            sortIndex: sortIndex,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct TodoGroupMembershipSnapshot {
    let todoId: String
    let groupId: String?
    let updatedAt: Date

    init(_ todo: WorkspaceTodoModel) {
        todoId = todo.id
        groupId = todo.groupId
        updatedAt = todo.updatedAt
    }
}

private func fetchTodoForUndo(id: String, in context: ModelContext) -> WorkspaceTodoModel? {
    let todoId = id
    let descriptor = FetchDescriptor<WorkspaceTodoModel>(
        predicate: #Predicate { todo in
            todo.id == todoId
        }
    )
    return try? context.fetch(descriptor).first
}

struct WorkspaceTodoBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoColumnRatio) private var columnRatio = TodoBoardColumnSplit.defaultRatio

    let workspaceId: String
    let resources: [ResourcePinModel]
    let todos: [WorkspaceTodoModel]
    let groups: [WorkspaceTodoGroupModel]
    @Binding var isOpen: Bool
    @Binding var isDoneColumnOpen: Bool
    let onStatus: (String) -> Void
    var expandedHeight: CGFloat = 300
    var collapsedHeight: CGFloat = 42

    @State private var selectedGroupId: String?
    @State private var editingGroupId: String?
    @State private var editingTodo: WorkspaceTodoModel?
    @State private var dragStartRatio: Double?

    private var openTodos: [WorkspaceTodoModel] {
        orderedTodos(todos.filter { !$0.isCompleted })
    }

    private var completedTodos: [WorkspaceTodoModel] {
        todos
            .filter(\.isCompleted)
            .sorted {
                let lhs = $0.completedAt ?? $0.updatedAt
                let rhs = $1.completedAt ?? $1.updatedAt
                if lhs != rhs { return lhs > rhs }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    private var orderedGroups: [WorkspaceTodoGroupModel] {
        let records = groups.map {
            TodoBoardOrderRecord(id: $0.id, title: $0.title, isPinned: $0.isPinned, sortIndex: $0.sortIndex)
        }
        let orderedIDs = TodoBoardOrdering.ordered(records).map(\.id)
        let byID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        return orderedIDs.compactMap { byID[$0] }
    }

    private var selectedGroup: WorkspaceTodoGroupModel? {
        if let selectedGroupId, let group = groups.first(where: { $0.id == selectedGroupId }) {
            return group
        }
        return orderedGroups.first
    }

    private var selectedOpenTodos: [WorkspaceTodoModel] {
        guard let group = selectedGroup else { return [] }
        return orderedTodos(openTodos.filter { groupId(for: $0) == group.id })
    }

    var body: some View {
        VStack(spacing: 8) {
            header

            if isOpen {
                boardBody
            }
        }
        .padding(isOpen ? 10 : 8)
        .frame(maxWidth: .infinity)
        .frame(height: isOpen ? expandedHeight : collapsedHeight)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            if let group = ensureDefaultGroup(), selectedGroupId == nil {
                selectedGroupId = group.id
            }
        }
        .sheet(item: $editingTodo) { todo in
            WorkspaceTodoDetailView(todo: todo, resources: resources, onSave: {
                save(status: "Updated task")
            })
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("Tasks", systemImage: "checklist")
                .font(.headline)
            Text("\(openTodos.count) open · \(completedTodos.count) done")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                addGroup()
            } label: {
                Label("New Group", systemImage: "folder.badge.plus")
            }
            .disabled(!isOpen)

            Button {
                addTodo()
            } label: {
                Label("New Task", systemImage: "plus")
            }
            .disabled(!isOpen)

            Button {
                isDoneColumnOpen.toggle()
            } label: {
                Label(isDoneColumnOpen ? "Hide Done" : "Show Done", systemImage: isDoneColumnOpen ? "sidebar.right" : "sidebar.leading")
            }
            .disabled(!isOpen)

            Button {
                isOpen.toggle()
            } label: {
                Label(isOpen ? "Close Tasks" : "Open Tasks", systemImage: isOpen ? "chevron.down" : "chevron.up")
            }
        }
        .buttonStyle(.bordered)
    }

    private var boardBody: some View {
        GeometryReader { proxy in
            if isDoneColumnOpen {
                let dividerWidth = 10.0
                let availableWidth = max(proxy.size.width - dividerWidth, 1)
                let ratio = TodoBoardColumnSplit.clampedRatio(columnRatio)
                let todoWidth = availableWidth * ratio

                HStack(spacing: 0) {
                    openTaskArea
                        .frame(width: todoWidth)

                    splitDivider(availableWidth: availableWidth)
                        .frame(width: dividerWidth)

                    doneColumn
                        .frame(width: availableWidth - todoWidth)
                }
            } else {
                openTaskArea
            }
        }
    }

    private var openTaskArea: some View {
        HStack(spacing: 10) {
            groupList
                .frame(width: 180)
            Divider()
            taskList(
                title: selectedGroup?.title ?? defaultTodoGroupTitle,
                items: selectedOpenTodos,
                emptyText: "No tasks in this group"
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var groupList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Groups", systemImage: "folder")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: addGroup) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New group")
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(orderedGroups) { group in
                        groupRow(group)
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private func groupRow(_ group: WorkspaceTodoGroupModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: group.isPinned ? "pin.fill" : "folder")
                .foregroundStyle(group.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            if editingGroupId == group.id {
                TextField("Group name", text: Binding(
                    get: { group.title },
                    set: {
                        group.title = $0
                        group.updatedAt = .now
                    }
                ))
                .textFieldStyle(.plain)
                .onSubmit {
                    editingGroupId = nil
                    save(status: "Renamed group")
                }
            } else {
                Text(group.title)
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        editingGroupId = group.id
                    }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background((selectedGroup?.id == group.id ? Color.accentColor.opacity(0.16) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedGroupId = group.id
        }
        .draggable("group:\(group.id)")
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first else { return false }
            if let movingID = value.removingPrefix("group:") {
                moveGroup(id: movingID, to: group.id)
                return true
            }
            return false
        }
        .contextMenu {
            Button(group.isPinned ? "Unpin Group" : "Pin Group") {
                group.isPinned.toggle()
                group.updatedAt = .now
                save(status: group.isPinned ? "Pinned group" : "Unpinned group")
            }
            Button("Rename Group") {
                editingGroupId = group.id
            }
            Button(role: .destructive) {
                deleteGroup(group)
            } label: {
                Text("Delete Group")
            }
            .disabled(group.title == defaultTodoGroupTitle && groups.count <= 1)
        }
    }

    private func taskList(title: String, items: [WorkspaceTodoModel], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Button(action: addTodo) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New task")
            }

            if items.isEmpty {
                Text(emptyText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { todo in
                            todoRow(todo)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private var doneColumn: some View {
        taskList(title: "Done", items: completedTodos, emptyText: "No completed tasks")
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    private func todoRow(_ todo: WorkspaceTodoModel) -> some View {
        HStack(spacing: 8) {
            Button {
                toggle(todo)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if todo.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(todo.title)
                        .lineLimit(1)
                        .strikethrough(todo.isCompleted)
                        .layoutPriority(1)
                    if let detail = TodoBoardTaskSummary.inlineDetail(todo.details) {
                        Text(detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                HStack(spacing: 8) {
                    if let dueAt = todo.dueAt {
                        Label(dueAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    }
                    if let resource = linkedResource(for: todo) {
                        Label(resource.displayName, systemImage: resource.targetType == .folder ? "folder" : "doc")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Button {
                editingTodo = todo
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Edit details")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingTodo = todo
        }
        .draggable("todo:\(todo.id)")
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first else { return false }
            if let movingID = value.removingPrefix("todo:") {
                moveTodo(id: movingID, to: todo.id)
                return true
            }
            return false
        }
        .contextMenu {
            Button("Edit Details") {
                editingTodo = todo
            }
            Button(todo.isPinned ? "Unpin Task" : "Pin Task") {
                todo.isPinned.toggle()
                todo.updatedAt = .now
                save(status: todo.isPinned ? "Pinned task" : "Unpinned task")
            }
            Button(todo.isCompleted ? "Move Back To Open" : "Mark Done") {
                toggle(todo)
            }
            Button(role: .destructive) {
                delete(todo)
            } label: {
                Text("Delete Task")
            }
        }
    }

    private func splitDivider(availableWidth: Double) -> some View {
        Rectangle()
            .fill(.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary.opacity(0.28))
                    .frame(width: 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartRatio == nil {
                            dragStartRatio = TodoBoardColumnSplit.clampedRatio(columnRatio)
                        }
                        let start = dragStartRatio ?? TodoBoardColumnSplit.defaultRatio
                        columnRatio = TodoBoardColumnSplit.clampedRatio(start + Double(value.translation.width) / availableWidth)
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                    }
            )
            .help("Drag to resize open and done columns")
    }

    @discardableResult
    private func ensureDefaultGroup() -> WorkspaceTodoGroupModel? {
        if let existing = groups.first(where: { $0.title == defaultTodoGroupTitle }) {
            return existing
        }
        let group = WorkspaceTodoGroupModel(workspaceId: workspaceId, title: defaultTodoGroupTitle, sortIndex: nextGroupSortIndex())
        modelContext.insert(group)
        do {
            try modelContext.save()
            return group
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
            return nil
        }
    }

    private func addGroup() {
        let group = WorkspaceTodoGroupModel(workspaceId: workspaceId, title: "New Group", sortIndex: nextGroupSortIndex())
        modelContext.insert(group)
        selectedGroupId = group.id
        editingGroupId = group.id
        save(status: "Added group")
    }

    private func addTodo() {
        guard let group = selectedGroup ?? ensureDefaultGroup() else { return }
        let todo = WorkspaceTodoModel(
            workspaceId: workspaceId,
            groupId: group.id,
            title: "New Task",
            sortIndex: nextTodoSortIndex(groupId: group.id, isCompleted: false)
        )
        modelContext.insert(todo)
        save(status: "Added task")
        editingTodo = todo
    }

    private func toggle(_ todo: WorkspaceTodoModel) {
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? .now : nil
        todo.sortIndex = nextTodoSortIndex(groupId: todo.groupId, isCompleted: todo.isCompleted)
        todo.updatedAt = .now
        save(status: todo.isCompleted ? "Marked task done" : "Moved task back")
    }

    private func delete(_ todo: WorkspaceTodoModel) {
        let snapshot = TodoDeletionSnapshot(todo)
        modelContext.delete(todo)
        if save(status: "Deleted task") {
            registerTodoDeletionUndo(snapshot)
        }
    }

    private func deleteGroup(_ group: WorkspaceTodoGroupModel) {
        guard let fallback = ensureDefaultGroup() else { return }
        let orderedIds = orderedGroups.map(\.id)
        let plan = TodoGroupDeletionPolicy.plan(
            deletingGroupId: group.id,
            defaultGroupId: fallback.id,
            orderedGroupIds: orderedIds
        )
        guard plan.deletesGroup else {
            onStatus("Default group cannot be deleted")
            return
        }
        let groupSnapshot = TodoGroupDeletionSnapshot(group)
        let membershipSnapshots = todos
            .filter { $0.groupId == group.id }
            .map(TodoGroupMembershipSnapshot.init)
        for todo in todos where todo.groupId == group.id {
            todo.groupId = plan.todoTargetGroupId
            todo.updatedAt = .now
        }
        if selectedGroupId == group.id {
            selectedGroupId = plan.nextSelectedGroupId
        }
        modelContext.delete(group)
        if save(status: "Deleted group") {
            registerTodoGroupDeletionUndo(group: groupSnapshot, memberships: membershipSnapshots)
        }
    }

    private func registerTodoDeletionUndo(_ snapshot: TodoDeletionSnapshot) {
        let undoContext = MainActorUndoContext(context: modelContext)
        undoManager?.registerUndo(withTarget: modelContext) { _ in
            MainActor.assumeIsolated {
                let context = undoContext.context
                context.insert(snapshot.makeModel())
                do {
                    try context.save()
                    onStatus("Restored task")
                } catch {
                    context.rollback()
                    onStatus("Could not undo task deletion: \(error.localizedDescription)")
                }
            }
        }
        undoManager?.setActionName("Delete Task")
    }

    private func registerTodoGroupDeletionUndo(group: TodoGroupDeletionSnapshot, memberships: [TodoGroupMembershipSnapshot]) {
        let undoContext = MainActorUndoContext(context: modelContext)
        undoManager?.registerUndo(withTarget: modelContext) { _ in
            MainActor.assumeIsolated {
                let context = undoContext.context
                context.insert(group.makeModel())
                for snapshot in memberships {
                    if let todo = fetchTodoForUndo(id: snapshot.todoId, in: context) {
                        todo.groupId = snapshot.groupId
                        todo.updatedAt = snapshot.updatedAt
                    }
                }
                do {
                    try context.save()
                    selectedGroupId = group.id
                    onStatus("Restored group")
                } catch {
                    context.rollback()
                    onStatus("Could not undo group deletion: \(error.localizedDescription)")
                }
            }
        }
        undoManager?.setActionName("Delete Group")
    }

    private func moveGroup(id movingID: String, to targetID: String) {
        let moved = TodoBoardOrdering.movedIDs(orderedGroups.map(\.id), moving: movingID, to: targetID)
        renumberGroups(ids: moved)
        save(status: "Reordered groups")
    }

    private func moveTodo(id movingID: String, to targetID: String) {
        guard let movingTodo = todos.first(where: { $0.id == movingID }),
              let targetTodo = todos.first(where: { $0.id == targetID }) else {
            return
        }
        movingTodo.groupId = targetTodo.groupId
        movingTodo.isCompleted = targetTodo.isCompleted
        let targetGroupID = groupId(for: targetTodo)
        movingTodo.groupId = targetGroupID
        let visibleIDs = orderedTodos(todos.filter { $0.isCompleted == targetTodo.isCompleted && groupId(for: $0) == targetGroupID }).map(\.id)
        let moved = TodoBoardOrdering.movedIDs(visibleIDs, moving: movingID, to: targetID)
        renumberTodos(ids: moved)
        save(status: "Reordered tasks")
    }

    private func renumberGroups(ids: [String]) {
        for (index, id) in ids.enumerated() {
            guard let group = groups.first(where: { $0.id == id }) else { continue }
            group.sortIndex = index
            group.updatedAt = .now
        }
    }

    private func renumberTodos(ids: [String]) {
        for (index, id) in ids.enumerated() {
            guard let todo = todos.first(where: { $0.id == id }) else { continue }
            todo.sortIndex = index
            todo.updatedAt = .now
        }
    }

    private func orderedTodos(_ items: [WorkspaceTodoModel]) -> [WorkspaceTodoModel] {
        let records = items.map {
            TodoBoardOrderRecord(id: $0.id, title: $0.title, isPinned: $0.isPinned, sortIndex: $0.sortIndex)
        }
        let orderedIDs = TodoBoardOrdering.ordered(records).map(\.id)
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return orderedIDs.compactMap { byID[$0] }
    }

    private func nextGroupSortIndex() -> Int {
        (groups.map(\.sortIndex).max() ?? -1) + 1
    }

    private func nextTodoSortIndex(groupId: String?, isCompleted: Bool) -> Int {
        let matching = todos.filter { self.groupId(for: $0) == groupId && $0.isCompleted == isCompleted }
        return (matching.map(\.sortIndex).max() ?? -1) + 1
    }

    private func groupId(for todo: WorkspaceTodoModel) -> String? {
        todo.groupId ?? groups.first(where: { $0.title == defaultTodoGroupTitle })?.id
    }

    private func linkedResource(for todo: WorkspaceTodoModel) -> ResourcePinModel? {
        guard let linkedResourceId = todo.linkedResourceId else { return nil }
        return resources.first { $0.id == linkedResourceId }
    }

    @discardableResult
    private func save(status: String) -> Bool {
        do {
            try modelContext.save()
            onStatus(status)
            return true
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
            return false
        }
    }
}

private struct WorkspaceTodoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let todo: WorkspaceTodoModel
    let resources: [ResourcePinModel]
    let onSave: () -> Void

    @State private var title: String
    @State private var details: String
    @State private var createdAt: Date
    @State private var hasDueDate: Bool
    @State private var dueAt: Date
    @State private var linkedResourceId: String

    init(todo: WorkspaceTodoModel, resources: [ResourcePinModel], onSave: @escaping () -> Void) {
        self.todo = todo
        self.resources = resources
        self.onSave = onSave
        _title = State(initialValue: todo.title)
        _details = State(initialValue: todo.details)
        _createdAt = State(initialValue: todo.createdAt)
        _hasDueDate = State(initialValue: todo.dueAt != nil)
        _dueAt = State(initialValue: todo.dueAt ?? .now)
        _linkedResourceId = State(initialValue: todo.linkedResourceId ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Task Details")
                .font(.title3.weight(.semibold))

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Text("Details")
                .font(.subheadline.weight(.semibold))
            TextEditor(text: $details)
                .frame(minHeight: 120)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary)
                }

            DatePicker("Created", selection: $createdAt, displayedComponents: [.date])

            Toggle("Use DDL Date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("DDL", selection: $dueAt, displayedComponents: [.date])
            }

            Picker("Linked Resource", selection: $linkedResourceId) {
                Text("None").tag("")
                ForEach(resources) { resource in
                    Text(resource.displayName).tag(resource.id)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func save() {
        todo.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Task" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.details = details
        todo.createdAt = createdAt
        todo.dueAt = hasDueDate ? dueAt : nil
        todo.linkedResourceId = linkedResourceId.isEmpty ? nil : linkedResourceId
        todo.updatedAt = .now
        onSave()
        dismiss()
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
