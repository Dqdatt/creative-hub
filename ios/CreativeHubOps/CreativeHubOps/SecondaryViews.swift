import SwiftUI

struct AccessDeniedView: View {
    var body: some View {
        AppSecondaryScreen(title: "Không có quyền") {
            ErrorStateView(
                title: "Không có quyền truy cập",
                message: "Tài khoản của bạn chưa có quyền dùng khu vực này."
            )
        }
    }
}

struct ContentPlanView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel

    var body: some View {
        AppSecondaryScreen(title: "Content Plan", trailing: {
            if appState.can(.contentPlanCreate) {
                Button {
                    operations.selectedContentPlanItem = nil
                    appState.activeSheet = .contentPlanCreate
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Thêm lịch air")
            }
        }) {
            if operations.isLoading {
                AppCard {
                    LoadingStateView(message: "Đang tải Content Plan...")
                }
            } else if let error = operations.errorMessage {
                ErrorStateView(title: "Không thể tải Content Plan", message: error) {
                    Task { await operations.refresh() }
                }
            } else if operations.contentPlan.isEmpty {
                AppCard {
                    EmptyStateView(title: "Content Plan", message: "Chưa có kế hoạch content trong tháng này.")
                }
            } else {
                ForEach(operations.contentPlan) { item in
                    Button {
                        operations.selectedContentPlanItem = item
                        appState.path.append(.contentPlanDetail(item.id))
                    } label: {
                        contentPlanRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func contentPlanRow(_ item: ContentPlanItem) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CategoryBadge(category: item.category)
                    Spacer()
                    Text(AppDateFormatter.shortDisplay(item.airDate))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppColors.secondaryText)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(2)

                Text(editorName(for: item))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(3)
                }
            }
        }
    }

    private func editorName(for item: ContentPlanItem) -> String {
        guard let editorId = item.editorId, !editorId.isEmpty else { return "Chưa phân công editor" }
        return operations.editors.first { $0.id == editorId || $0.profileId == editorId }?.shortName ?? editorId
    }
}

struct ContentPlanEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var form = ContentPlanFormData()
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var item: ContentPlanItem? { operations.selectedContentPlanItem }
    private var isEditing: Bool { item != nil }

    var body: some View {
        AppSheetScaffold(
            title: isEditing ? "Sửa lịch air" : "Thêm lịch air",
            actionTitle: isEditing ? "Lưu" : "Thêm",
            isSaving: isSaving,
            canSubmit: canSave,
            onCancel: {
                operations.selectedContentPlanItem = nil
                dismiss()
            },
            onSubmit: {
                Task { await save() }
            }
        ) {
            AppFormSection("Lịch air") {
                AppTextFieldRow(
                    title: "Ngày Air",
                    placeholder: "YYYY-MM-DD",
                    text: $form.airDate,
                    isDisabled: isEditing && !appState.can(.contentPlanUpdate)
                )
                AppDivider()
                AppPickerRow(
                    title: "Thể loại",
                    selection: $form.category,
                    isDisabled: isEditing && !appState.can(.contentPlanUpdate)
                ) {
                    ForEach(ContentPlanCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                AppDivider()
                AppTextFieldRow(
                    title: "Tên video",
                    placeholder: "Nhập tên video",
                    text: $form.title,
                    isDisabled: isEditing && !appState.can(.contentPlanUpdate)
                )
            }

            AppFormSection("Phân công") {
                AppPickerRow(title: "Editor", selection: $form.editorCode, isDisabled: !appState.can(.contentPlanAssign)) {
                    Text("Chưa phân công").tag("")
                    ForEach(operations.editors) { editor in
                        Text(editor.shortName).tag(editor.id)
                    }
                }
            }

            AppFormSection("Chi tiết") {
                AppTextFieldRow(
                    title: "Ghi chú",
                    placeholder: "Ghi chú thêm cho lịch air",
                    text: $form.note,
                    axis: .vertical,
                    isDisabled: isEditing && !appState.can(.contentPlanUpdate)
                )
                AppDivider()
                AppTextFieldRow(
                    title: "Link thành phẩm",
                    placeholder: "https://...",
                    text: $form.link,
                    isDisabled: linkIsSynced || (isEditing && !appState.can(.contentPlanUpdate))
                )
                if linkIsSynced {
                    AppDivider()
                    Text("Link này được đồng bộ từ Video tháng.")
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
        .onAppear {
            if let item {
                form = ContentPlanFormData(item: item)
            }
        }
    }

    private var linkIsSynced: Bool {
        item?.hasLinkedTask == true
    }

    private var canSave: Bool {
        isEditing ? (appState.can(.contentPlanUpdate) || appState.can(.contentPlanAssign)) : appState.can(.contentPlanCreate)
    }

    private func save() async {
        guard canSave else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            if isEditing {
                try await operations.saveSelectedContentPlan(form, userId: appState.authSession?.id)
            } else {
                var createForm = form
                createForm.editorCode = ""
                try await operations.createContentPlan(createForm)
            }
            operations.selectedContentPlanItem = nil
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể lưu Content Plan. Vui lòng thử lại.").localizedDescription
        }
    }

    private func deleteItem() async {
        guard appState.can(.contentPlanDelete) else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await operations.deleteSelectedContentPlan()
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể xóa Content Plan. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct UsersView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var adminUsers: AdminUsersViewModel

    var body: some View {
        AppSecondaryScreen(title: "Nhân sự", trailing: {
            Button {
                adminUsers.selectedUser = nil
                adminUsers.clearMessages()
                appState.activeSheet = .adminUserCreate
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Thêm nhân sự")
        }) {
            if adminUsers.isLoading {
                AppCard { LoadingStateView(message: "Đang tải nhân sự...") }
            } else if let error = adminUsers.errorMessage {
                ErrorStateView(title: "Không thể tải nhân sự", message: error) {
                    Task { await adminUsers.load(force: true) }
                }
            } else if adminUsers.users.isEmpty {
                AppCard { EmptyStateView(title: "Nhân sự", message: "Chưa có profile để hiển thị.") }
            } else {
                if let success = adminUsers.successMessage {
                    Text(success)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColors.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppColors.success.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                }

                ForEach(adminUsers.users) { user in
                    Button {
                        adminUsers.selectedUser = user
                        appState.path.append(.userDetail(user.id))
                    } label: {
                        AppCard {
                            HStack(spacing: 12) {
                                Text(user.initials)
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(user.isActive ? AppColors.accent : AppColors.secondaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user.displayName)
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(AppColors.text)
                                    Text("\(user.roleLabel) · \(user.email)")
                                        .font(AppTypography.supporting)
                                        .foregroundStyle(AppColors.secondaryText)
                                        .lineLimit(1)
                                    Text(user.permissionSummary)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(user.permissionOverride.accessMode == .roleDefault ? AppColors.secondaryText : AppColors.warning)
                                }
                                Spacer()
                                if !user.isActive {
                                    Text("Tạm khóa")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(AppColors.danger)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppColors.secondaryText.opacity(0.55))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            await adminUsers.load()
        }
    }
}

struct NotificationsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notifications: NotificationsViewModel

    var body: some View {
        AppSecondaryScreen(title: "Thông báo") {
            Button {
                Task { await notifications.markAllRead() }
            } label: {
                Label("Đọc tất cả", systemImage: "checkmark.circle")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(notifications.unreadCount == 0 ? AppColors.secondaryText : AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .stroke(.black.opacity(0.04), lineWidth: 1)
                    }
            }
            .disabled(notifications.unreadCount == 0)

            if notifications.isLoading {
                AppCard { LoadingStateView(message: "Đang tải thông báo...") }
            } else if let error = notifications.errorMessage {
                ErrorStateView(title: "Không thể tải thông báo", message: error) {
                    Task { await notifications.load(force: true) }
                }
            } else if notifications.notifications.isEmpty {
                AppCard { EmptyStateView(title: "Thông báo", message: "Chưa có thông báo.") }
            } else {
                ForEach(notifications.notifications) { item in
                    Button {
                        Task {
                            await notifications.markRead(item)
                            if let route = route(for: item) {
                                appState.path.append(route)
                            }
                        }
                    } label: {
                        AppCard {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: notificationIcon(for: item))
                                    .foregroundStyle(item.isUnread ? AppColors.accent : AppColors.secondaryText)
                                    .frame(width: 34, height: 34)
                                    .background((item.isUnread ? AppColors.accent : AppColors.secondaryText).opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: item.isUnread ? .black : .bold))
                                            .foregroundStyle(AppColors.text)
                                            .lineLimit(2)
                                        Spacer()
                                        if item.isUnread {
                                            Circle()
                                                .fill(AppColors.accent)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    Text(item.body)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(AppColors.secondaryText)
                                        .lineLimit(3)
                                    Text(AppDateFormatter.displayDateTime(item.createdAt))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppColors.secondaryText.opacity(0.85))
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            await notifications.load()
        }
    }

    private func notificationIcon(for notification: InternalNotification) -> String {
        switch notification.entityType?.lowercased() {
        case "video_task", "video_tasks", "task":
            "video"
        case "shoot", "shoots":
            "calendar"
        case "content_plan":
            "list.bullet.rectangle"
        default:
            "bell"
        }
    }

    private func route(for notification: InternalNotification) -> AppRoute? {
        guard let entityType = notification.entityType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              let entityId = notification.entityId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !entityId.isEmpty
        else {
            return nil
        }

        switch entityType {
        case "video_task", "task", "video_tasks":
            return .taskDetail(entityId)
        case "shoot", "shoots":
            return .shootDetail(entityId)
        case "content_plan":
            return .contentPlanDetail(entityId)
        default:
            return nil
        }
    }
}

struct VideoTaskFormFields: View {
    @Binding var form: VideoTaskFormData
    let editors: [EditorProfile]
    var isLinkedTask = false

    var body: some View {
        AppFormSection("Thông tin chính") {
            AppTextFieldRow(title: "Tên video", placeholder: "Nhập tên video", text: $form.title)
            AppDivider()
            AppPickerRow(title: "Người làm", selection: $form.editorCode, isDisabled: isLinkedTask) {
                Text("Chưa phân công").tag("")
                ForEach(editors) { editor in
                    Text(editor.shortName).tag(editor.id)
                }
            }
            AppDivider()
            AppPickerRow(title: "Trạng thái", selection: $form.status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            AppDivider()
            AppPickerRow(title: "Team Order", selection: $form.orderTeam) {
                ForEach(TaskConstants.orderTeams, id: \.self) { team in
                    Text(team).tag(team)
                }
            }
            AppDivider()
            AppPickerRow(title: "Thể loại", selection: $form.category) {
                ForEach(TaskConstants.categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            AppDivider()
            AppPickerRow(title: "Độ ưu tiên", selection: $form.priority) {
                Text("Bình thường").tag("")
                Text("Gấp").tag("Gấp")
            }
        }

        AppFormSection("Timeline") {
            AppTextFieldRow(title: "Ngày nhận", placeholder: "DD/MM hoặc YYYY-MM-DD", text: $form.receiveDate)
            AppDivider()
            AppTextFieldRow(title: "Ngày trả", placeholder: "DD/MM hoặc YYYY-MM-DD", text: $form.returnDate)
            AppDivider()
            AppTextFieldRow(title: "Ngày Air", placeholder: "DD/MM hoặc YYYY-MM-DD", text: $form.airDate, isDisabled: isLinkedTask)
        }

        AppFormSection("Chi tiết") {
            AppTextFieldRow(title: "Resize", placeholder: "VD: 9x16 & 1x1", text: $form.resizeRequirements)
            AppDivider()
            AppTextFieldRow(title: "Link thành phẩm", placeholder: "https://...", text: $form.resultLink)
            AppDivider()
            AppTextFieldRow(title: "Ghi chú", placeholder: "Ghi chú thêm cho task", text: $form.notes, axis: .vertical, isDisabled: isLinkedTask)
            if isLinkedTask {
                AppDivider()
                Text("Task liên kết được quản lý một phần từ Content Plan.")
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        }
    }
}

struct TaskEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var form = VideoTaskFormData()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        AppSheetScaffold(
            title: "Thêm Video Task",
            actionTitle: "Tạo",
            isSaving: isSaving,
            canSubmit: appState.can(.videoTasksCreate),
            onCancel: { dismiss() },
            onSubmit: { Task { await save() } }
        ) {
            VideoTaskFormFields(form: $form, editors: operations.editors)

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
        .onAppear {
            if form.editorCode.isEmpty {
                form.editorCode = operations.editors.first?.id ?? ""
            }
        }
    }

    private func save() async {
        guard appState.can(.videoTasksCreate) else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await operations.createVideoTask(form, userId: appState.authSession?.id)
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể tạo video task. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct TaskDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    let taskId: String
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var task: VideoTask? {
        operations.tasks.first { $0.id == taskId } ?? (operations.selectedTask?.id == taskId ? operations.selectedTask : nil)
    }

    var body: some View {
        AppSecondaryScreen(title: "Chi tiết Task", trailing: {
            if let task {
                Menu {
                    if appState.can(.videoTasksUpdate) {
                        Button {
                            operations.selectedTask = task
                            appState.activeSheet = .taskEdit
                        } label: {
                            Label("Chỉnh sửa", systemImage: "pencil")
                        }
                    }
                    if appState.can(.videoTasksDelete) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Xóa task", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Thao tác task")
            }
        }) {
            if operations.isLoading {
                AppCard { LoadingStateView(message: "Đang tải chi tiết task...") }
            } else if let task {
                AppDetailHeroCard(title: task.title, subtitle: editorName(for: task)) {
                    HStack(spacing: 8) {
                        StatusBadge(status: task.status)
                        if task.priority == "Gấp" {
                            InfoPill(icon: "bolt.fill", text: "Gấp", tint: AppColors.danger)
                        }
                        if task.contentPlanId != nil {
                            InfoPill(icon: "link", text: "Content Plan")
                        }
                    }
                }

                AppDetailSection("Thông tin chính") {
                    AppDetailRow(title: "Editor", value: editorName(for: task), systemImage: "person")
                    AppDivider()
                    AppDetailRow(title: "Team Order", value: task.orderTeam, systemImage: "person.2")
                    AppDivider()
                    AppDetailRow(title: "Thể loại", value: task.category, systemImage: "tag")
                    AppDivider()
                    AppDetailRow(title: "Resize", value: task.resizeRequirements, systemImage: "rectangle.resize")
                }

                AppDetailSection("Timeline") {
                    AppDetailRow(title: "Ngày nhận", value: AppDateFormatter.shortDisplay(task.receiveDate), systemImage: "tray.and.arrow.down")
                    AppDivider()
                    AppDetailRow(title: "Ngày trả", value: AppDateFormatter.shortDisplay(task.returnDate), systemImage: "arrowshape.turn.up.forward")
                    AppDivider()
                    AppDetailRow(title: "Ngày Air", value: AppDateFormatter.shortDisplay(task.airDate), systemImage: "calendar")
                }

                AppDetailSection("Liên kết") {
                    if let contentPlanId = task.contentPlanId {
                        if let item = operations.contentPlan.first(where: { $0.id == contentPlanId }) {
                            Button {
                                appState.path.append(.contentPlanDetail(item.id))
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "link")
                                        .foregroundStyle(AppColors.accent)
                                        .frame(width: 24, height: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Linked Content Plan")
                                            .font(AppTypography.supporting)
                                            .foregroundStyle(AppColors.secondaryText)
                                        Text(item.title)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(AppColors.text)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(AppColors.secondaryText.opacity(0.65))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        } else {
                            AppDetailRow(title: "Content Plan", value: "Đã liên kết", systemImage: "link")
                        }
                        AppDivider()
                        Text("Task liên kết được quản lý một phần từ Content Plan.")
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    } else {
                        AppDetailRow(title: "Content Plan", value: "Không liên kết", systemImage: "link")
                    }
                    AppDivider()
                    AppDetailRow(title: "Link thành phẩm", value: task.resultLink, systemImage: "paperclip")
                }

                if !task.notes.isEmpty {
                    AppDetailSection("Ghi chú") {
                        Text(task.notes)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }

                AppDetailSection("Thao tác") {
                    if task.contentPlanId == nil, appState.can(.videoTasksUpdate) {
                        Menu {
                            ForEach(TaskStatus.allCases) { status in
                                Button(status.rawValue) {
                                    updateStatus(task, status: status)
                                }
                                .disabled(task.status == status)
                            }
                        } label: {
                            Label("Đổi trạng thái", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(AppColors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                    } else if linkedState(for: task).canAccept(task: task, currentProfile: appState.currentProfile, editors: operations.editors) {
                        linkedActionButton("Nhận Task", icon: "hand.raised") {
                            operations.selectedTask = task
                            appState.activeSheet = .linkedTaskAccept
                        }
                    } else if linkedState(for: task).canComplete(task: task, currentProfile: appState.currentProfile, editors: operations.editors) {
                        linkedActionButton("Cập nhật thực hiện", icon: "square.and.pencil") {
                            operations.selectedTask = task
                            appState.activeSheet = .linkedTaskExecution
                        }
                        AppDivider()
                        linkedActionButton("Hoàn thành", icon: "checkmark.circle") {
                            operations.selectedTask = task
                            appState.activeSheet = .linkedTaskExecution
                        }
                    } else if task.contentPlanId != nil {
                        Text(linkedTaskUnavailableMessage(task))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    } else {
                        Text("Bạn chưa có quyền cập nhật task.")
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }

                if let errorMessage {
                    AppInlineError(message: errorMessage)
                }
            } else {
                ErrorStateView(title: "Không tìm thấy task", message: "Task đã bị xóa hoặc chưa được tải trong tháng hiện tại.") {
                    Task { await operations.refresh() }
                }
            }
        }
        .alert("Xóa video task?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                Task { await deleteTask() }
            }
        } message: {
            Text("Thao tác này sẽ dùng backend/RPC hiện có để xóa task và thông báo liên quan.")
        }
    }

    private func updateStatus(_ task: VideoTask, status: TaskStatus) {
        var form = VideoTaskFormData(task: task, editors: operations.editors)
        form.status = status
        operations.selectedTask = task
        Task {
            do {
                try await operations.updateSelectedTask(form, userId: appState.authSession?.id)
            } catch {
                errorMessage = AppError.map(error, fallback: "Không thể cập nhật trạng thái.").localizedDescription
            }
        }
    }

    private func deleteTask() async {
        guard let task else { return }
        guard appState.can(.videoTasksDelete) else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            operations.selectedTask = task
            try await operations.deleteSelectedTask()
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể xóa video task. Vui lòng thử lại.").localizedDescription
        }
    }

    private func editorName(for task: VideoTask) -> String {
        guard let editorId = task.editorId, !editorId.isEmpty else { return "Chưa phân công" }
        return operations.editors.first { $0.id == editorId || $0.profileId == editorId }?.shortName ?? editorId
    }

    private func linkedState(for task: VideoTask) -> LinkedTaskState {
        LinkedTaskState(task: task)
    }

    private func linkedTaskUnavailableMessage(_ task: VideoTask) -> String {
        if task.status == .done {
            return "Task liên kết đã hoàn thành."
        }
        if task.editorId == nil {
            return "Task liên kết chưa có editor phụ trách."
        }
        return "Chỉ editor được giao và có quyền cập nhật mới thao tác được Task liên kết."
    }

    private func linkedActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(AppColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .buttonStyle(.plain)
    }
}

struct ShootDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    let shootId: String
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var shoot: ShootSchedule? {
        operations.shoots.first { $0.id == shootId } ?? (operations.selectedShoot?.id == shootId ? operations.selectedShoot : nil)
    }

    var body: some View {
        AppSecondaryScreen(title: "Chi tiết Lịch quay", trailing: {
            if let shoot {
                Menu {
                    if appState.can(.shootsUpdate) {
                        Button {
                            operations.selectedShoot = shoot
                            appState.activeSheet = .shootEdit
                        } label: {
                            Label("Chỉnh sửa", systemImage: "pencil")
                        }
                    }
                    if appState.can(.shootsDelete) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Xóa lịch quay", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Thao tác lịch quay")
            }
        }) {
            if operations.isLoading {
                AppCard { LoadingStateView(message: "Đang tải chi tiết lịch quay...") }
            } else if let shoot {
                AppDetailHeroCard(title: shoot.location.isEmpty ? shoot.typeLabel : shoot.location, subtitle: AppDateFormatter.shortDisplay(shoot.date)) {
                    InfoPill(
                        icon: shoot.type == "livestream" ? "dot.radiowaves.left.and.right" : "video",
                        text: shoot.typeLabel
                    )
                }

                AppDetailSection("Lịch quay") {
                    AppDetailRow(title: "Ngày", value: AppDateFormatter.shortDisplay(shoot.date), systemImage: "calendar")
                    AppDivider()
                    AppDetailRow(title: "Thời gian", value: shoot.timeSlot, systemImage: "clock")
                    AppDivider()
                    AppDetailRow(title: "Địa điểm", value: shoot.location, systemImage: "mappin.and.ellipse")
                    AppDivider()
                    AppDetailRow(title: "Crew", value: shoot.crew, systemImage: "person.3")
                }

                AppDetailSection("Editor phụ trách") {
                    if shoot.editorIds.isEmpty {
                        Text("Chưa phân công editor.")
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    } else {
                        ForEach(Array(shoot.editorIds.enumerated()), id: \.element) { index, editorId in
                            AppDetailRow(title: "Editor \(index + 1)", value: editorName(editorId), systemImage: "person")
                            if index < shoot.editorIds.count - 1 {
                                AppDivider()
                            }
                        }
                    }
                }

                if !shoot.note.isEmpty {
                    AppDetailSection("Ghi chú") {
                        Text(shoot.note)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }

                if let errorMessage {
                    AppInlineError(message: errorMessage)
                }
            } else {
                ErrorStateView(title: "Không tìm thấy lịch quay", message: "Lịch quay đã bị xóa hoặc chưa được tải trong tháng hiện tại.") {
                    Task { await operations.refresh() }
                }
            }
        }
        .alert("Xóa lịch quay?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                Task { await deleteShoot() }
            }
        } message: {
            Text("Thao tác này sẽ dùng RPC backend hiện có để xóa lịch quay và thông báo liên quan.")
        }
    }

    private func deleteShoot() async {
        guard let shoot else { return }
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            operations.selectedShoot = shoot
            try await operations.deleteSelectedShoot()
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể xóa lịch quay. Vui lòng thử lại.").localizedDescription
        }
    }

    private func editorName(_ editorId: String) -> String {
        operations.editors.first { $0.id == editorId || $0.profileId == editorId }?.shortName ?? editorId
    }
}

struct ContentPlanDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    let itemId: String
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var item: ContentPlanItem? {
        operations.contentPlan.first { $0.id == itemId } ?? (operations.selectedContentPlanItem?.id == itemId ? operations.selectedContentPlanItem : nil)
    }

    private var linkedTask: VideoTask? {
        operations.tasks.first { $0.contentPlanId == itemId }
    }

    var body: some View {
        AppSecondaryScreen(title: "Chi tiết Content", trailing: {
            if let item {
                Menu {
                    if appState.can(.contentPlanUpdate) || appState.can(.contentPlanAssign) {
                        Button {
                            operations.selectedContentPlanItem = item
                            appState.activeSheet = .contentPlanEdit
                        } label: {
                            Label("Chỉnh sửa", systemImage: "pencil")
                        }
                    }
                    if appState.can(.contentPlanDelete) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Xóa Content Plan", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Thao tác Content Plan")
            }
        }) {
            if operations.isLoading {
                AppCard { LoadingStateView(message: "Đang tải chi tiết Content Plan...") }
            } else if let item {
                AppDetailHeroCard(title: item.title, subtitle: editorName(for: item)) {
                    HStack(spacing: 8) {
                        CategoryBadge(category: item.category)
                        if item.hasLinkedTask {
                            InfoPill(icon: "link", text: "Đã sinh Task")
                        }
                    }
                }

                AppDetailSection("Thông tin") {
                    AppDetailRow(title: "Ngày Air", value: AppDateFormatter.shortDisplay(item.airDate), systemImage: "calendar")
                    AppDivider()
                    AppDetailRow(title: "Thể loại", value: item.category.rawValue, systemImage: "tag")
                    AppDivider()
                    AppDetailRow(title: "Editor", value: editorName(for: item), systemImage: "person")
                    AppDivider()
                    AppDetailRow(title: "Link", value: item.link, systemImage: "paperclip")
                }

                if !item.note.isEmpty {
                    AppDetailSection("Ghi chú") {
                        Text(item.note)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }

                AppDetailSection("Video Task liên kết") {
                    if let linkedTask {
                        Button {
                            appState.path.append(.taskDetail(linkedTask.id))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "video")
                                    .foregroundStyle(AppColors.accent)
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(linkedTask.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(AppColors.text)
                                        .lineLimit(2)
                                    Text(linkedTask.status.rawValue)
                                        .font(AppTypography.supporting)
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppColors.secondaryText.opacity(0.65))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(item.hasLinkedTask ? "Task liên kết chưa nằm trong tháng đang tải." : "Chưa sinh Video Task.")
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }

                if let errorMessage {
                    AppInlineError(message: errorMessage)
                }
            } else {
                ErrorStateView(title: "Không tìm thấy Content Plan", message: "Dòng lịch air đã bị xóa hoặc chưa được tải trong tháng hiện tại.") {
                    Task { await operations.refresh() }
                }
            }
        }
        .alert("Xóa kế hoạch content?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                Task { await deleteItem() }
            }
        } message: {
            Text("Nếu dòng đã sinh Video Task, task liên kết cũng sẽ bị xóa.")
        }
    }

    private func deleteItem() async {
        guard let item else { return }
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            operations.selectedContentPlanItem = item
            try await operations.deleteSelectedContentPlan()
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể xóa Content Plan. Vui lòng thử lại.").localizedDescription
        }
    }

    private func editorName(for item: ContentPlanItem) -> String {
        guard let editorId = item.editorId, !editorId.isEmpty else { return "Chưa phân công" }
        return operations.editors.first { $0.id == editorId || $0.profileId == editorId }?.shortName ?? editorId
    }
}

struct UserDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var adminUsers: AdminUsersViewModel
    let userId: String
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var user: ManagedUserProfile? {
        adminUsers.users.first { $0.id == userId } ?? (adminUsers.selectedUser?.id == userId ? adminUsers.selectedUser : nil)
    }

    var body: some View {
        AppSecondaryScreen(title: "Chi tiết Nhân sự", trailing: {
            if let user {
                Menu {
                    Button {
                        adminUsers.selectedUser = user
                        adminUsers.clearMessages()
                        appState.activeSheet = .adminUserEdit
                    } label: {
                        Label("Chỉnh sửa", systemImage: "pencil")
                    }
                    Button {
                        adminUsers.selectedUser = user
                        adminUsers.clearMessages()
                        appState.activeSheet = .adminPasswordReset
                    } label: {
                        Label("Đặt lại mật khẩu", systemImage: "key")
                    }
                    Button(role: .destructive) {
                        adminUsers.selectedUser = user
                        showDeleteConfirmation = true
                    } label: {
                        Label("Xóa tài khoản", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Thao tác nhân sự")
            }
        }) {
            if let user {
                AppDetailHeroCard(title: user.displayName, subtitle: user.roleLabel) {
                    HStack(spacing: 10) {
                        Text(user.initials)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(user.isActive ? AppColors.accent : AppColors.secondaryText)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.email)
                                .font(.system(size: 13.5, weight: .black))
                                .foregroundStyle(AppColors.text)
                            Text(user.isActive ? "Đang hoạt động" : "Tạm khóa")
                                .font(AppTypography.supporting)
                                .foregroundStyle(user.isActive ? AppColors.success : AppColors.danger)
                        }
                        Spacer()
                    }
                }

                AppDetailSection("Thông tin") {
                    AppDetailRow(title: "Họ và tên", value: user.fullName, systemImage: "person.text.rectangle")
                    AppDivider()
                    AppDetailRow(title: "Email", value: user.email, systemImage: "envelope")
                    AppDivider()
                    AppDetailRow(title: "Phòng ban", value: user.department, systemImage: "building.2")
                    AppDivider()
                    AppDetailRow(title: "Profile ID", value: user.id, systemImage: "person.crop.circle.badge.checkmark")
                }

                AppDetailSection("Editor") {
                    AppDetailRow(title: "Editor member", value: user.isEditorMember ? "Có" : "Không", systemImage: "video.badge.checkmark")
                    AppDivider()
                    AppDetailRow(title: "Editor code", value: user.editorCode, systemImage: "number")
                    AppDivider()
                    AppDetailRow(title: "Crew key", value: user.crewKey, systemImage: "person.3")
                }

                AppDetailSection("Quyền") {
                    AppDetailRow(title: "Chế độ", value: user.permissionSummary, systemImage: "lock.shield")
                    AppDivider()
                    AppDetailRow(title: "Vai trò", value: user.roleLabel, systemImage: "person.badge.key")
                }

                if let errorMessage {
                    AppInlineError(message: errorMessage)
                }
            } else {
                ErrorStateView(title: "Không tìm thấy nhân sự", message: "Danh sách nhân sự chưa tải hoặc thành viên không còn tồn tại.") {
                    Task { await adminUsers.load() }
                }
            }
        }
        .task {
            if adminUsers.users.isEmpty {
                await adminUsers.load()
            }
        }
        .alert("Xóa tài khoản?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                Task { await deleteUser() }
            }
        } message: {
            Text("Edge Function sẽ kiểm tra quyền admin, không cho xóa chính bạn hoặc admin cuối cùng.")
        }
    }

    private func deleteUser() async {
        errorMessage = nil

        do {
            try await adminUsers.deleteSelectedUser()
            appState.path.removeAll()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể xóa tài khoản. Vui lòng thử lại.").localizedDescription
        }
    }
}

enum AdminUserEditorMode {
    case create
    case edit
}

struct AdminUserEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var adminUsers: AdminUsersViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: AdminUserEditorMode
    @State private var form = AdminUserFormData()
    @State private var errorMessage: String?

    private var isEditing: Bool { mode == .edit }

    var body: some View {
        AppSheetScaffold(
            title: isEditing ? "Sửa nhân sự" : "Thêm nhân sự",
            actionTitle: isEditing ? "Lưu" : "Tạo",
            isSaving: adminUsers.isSaving,
            canSubmit: canSubmit,
            onCancel: { dismiss() },
            onSubmit: { Task { await save() } }
        ) {
            AppFormSection("Tài khoản") {
                AppTextFieldRow(title: "Email", placeholder: "name@company.com", text: $form.email)
                if !isEditing {
                    AppDivider()
                    AppSecureFieldRow(title: "Mật khẩu tạm thời", placeholder: "Tối thiểu 6 ký tự", text: $form.password)
                }
                AppDivider()
                AppPickerRow(title: "Vai trò", selection: $form.role) {
                    ForEach(AppRole.allCases) { role in
                        Text(role.label).tag(role)
                    }
                }
                AppDivider()
                Toggle("Đang hoạt động", isOn: $form.isActive)
                    .font(AppTypography.rowLabel)
                    .foregroundStyle(AppColors.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }

            AppFormSection("Hồ sơ") {
                AppTextFieldRow(title: "Họ và tên", placeholder: "Nhập họ và tên", text: $form.fullName)
                AppDivider()
                AppTextFieldRow(title: "Tên hiển thị", placeholder: "Tên dùng trong app", text: $form.displayName)
                AppDivider()
                AppTextFieldRow(title: "Số điện thoại", placeholder: "Số điện thoại", text: $form.phone)
                AppDivider()
                AppTextFieldRow(title: "Phòng ban", placeholder: "Team Marketing", text: $form.department)
            }

            AppFormSection("Editor") {
                Toggle("Là editor member", isOn: $form.isEditorMember)
                    .font(AppTypography.rowLabel)
                    .foregroundStyle(AppColors.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                AppDivider()
                AppTextFieldRow(title: "Editor code", placeholder: "vd: dat", text: $form.editorCode, isDisabled: !form.isEditorMember)
                AppDivider()
                AppTextFieldRow(title: "Crew key", placeholder: "vd: DAT", text: $form.crewKey)
            }

            AppFormSection("Quyền sử dụng") {
                AppPickerRow(title: "Chế độ", selection: $form.permissionMode) {
                    Text("Theo vai trò").tag(PermissionAccessMode.roleDefault)
                    Text("Chỉ xem").tag(PermissionAccessMode.viewOnly)
                    Text("Tùy chỉnh").tag(PermissionAccessMode.custom)
                }

                if form.permissionMode == .custom {
                    AppDivider()
                    permissionToggle("Dashboard", isOn: $form.dashboardView)
                    AppDivider()
                    permissionToggle("Lịch quay", isOn: $form.calendarView)
                    AppDivider()
                    permissionToggle("Sửa lịch quay", isOn: $form.calendarEdit)
                    AppDivider()
                    permissionToggle("Video task", isOn: $form.tasksView)
                    AppDivider()
                    permissionToggle("Sửa video task", isOn: $form.tasksEdit)
                    AppDivider()
                    permissionToggle("Content Plan", isOn: $form.contentPlanView)
                    AppDivider()
                    permissionToggle("Sửa Content Plan", isOn: $form.contentPlanEditContent)
                    AppDivider()
                    permissionToggle("Phân công editor", isOn: $form.contentPlanAssignEditor)
                    AppDivider()
                    permissionToggle("Quản lý user", isOn: $form.usersManage)
                    AppDivider()
                    permissionToggle("Sửa hồ sơ cá nhân", isOn: $form.profileEditSelf)
                }
            }

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
        .onAppear {
            if isEditing, let profile = adminUsers.selectedUser {
                form = AdminUserFormData(profile: profile)
            }
        }
    }

    @ViewBuilder
    private func permissionToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(AppTypography.rowLabel)
            .foregroundStyle(AppColors.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
    }

    private var canSubmit: Bool {
        isEditing ? appState.can(.userManagementUpdate) : appState.can(.userManagementCreate)
    }

    private func save() async {
        guard canSubmit else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil

        do {
            if isEditing {
                try await adminUsers.updateSelectedUser(form, actorId: appState.currentProfile?.id)
            } else {
                try await adminUsers.createUser(form, actorId: appState.currentProfile?.id)
            }
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể lưu nhân sự. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct AdminPasswordResetSheet: View {
    @EnvironmentObject private var adminUsers: AdminUsersViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?

    var body: some View {
        AppSheetScaffold(
            title: "Đặt lại mật khẩu",
            actionTitle: "Lưu",
            isSaving: adminUsers.isSaving,
            canSubmit: adminUsers.selectedUser != nil,
            onCancel: { dismiss() },
            onSubmit: { Task { await resetPassword() } }
        ) {
            if let user = adminUsers.selectedUser {
                AppDetailSection("Tài khoản") {
                    AppDetailRow(title: "Thành viên", value: user.displayName, systemImage: "person")
                    AppDivider()
                    AppDetailRow(title: "Email", value: user.email, systemImage: "envelope")
                }
            }

            AppFormSection("Mật khẩu mới") {
                AppSecureFieldRow(title: "Mật khẩu", placeholder: "Tối thiểu 6 ký tự", text: $password)
                AppDivider()
                AppSecureFieldRow(title: "Xác nhận", placeholder: "Nhập lại mật khẩu", text: $confirmation)
            }

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
    }

    private func resetPassword() async {
        guard password == confirmation else {
            errorMessage = "Xác nhận mật khẩu chưa khớp."
            return
        }

        errorMessage = nil

        do {
            try await adminUsers.resetSelectedPassword(password)
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể đặt lại mật khẩu. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct LinkedTaskAcceptSheet: View {
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var form = LinkedTaskAcceptFormData()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        AppSheetScaffold(
            title: "Nhận Task",
            actionTitle: "Nhận",
            isSaving: isSaving,
            canSubmit: operations.selectedTask != nil,
            onCancel: { dismiss() },
            onSubmit: { Task { await acceptTask() } }
        ) {
            AppFormSection("Timeline") {
                AppTextFieldRow(title: "Ngày nhận", placeholder: "DD/MM hoặc YYYY-MM-DD", text: $form.receiveDate)
                AppDivider()
                AppTextFieldRow(title: "Ngày trả", placeholder: "DD/MM hoặc YYYY-MM-DD", text: $form.returnDate)
            }

            if let task = operations.selectedTask {
                AppDetailSection("Task liên kết") {
                    AppDetailRow(title: "Video", value: task.title, systemImage: "video")
                    AppDivider()
                    AppDetailRow(title: "Ngày Air", value: AppDateFormatter.shortDisplay(task.airDate), systemImage: "calendar")
                }
            }

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
        .onAppear {
            if let task = operations.selectedTask {
                form = LinkedTaskAcceptFormData(task: task)
            }
        }
    }

    private func acceptTask() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await operations.acceptSelectedLinkedTask(form)
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể nhận Task. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct LinkedTaskExecutionSheet: View {
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var form = LinkedTaskExecutionFormData()
    @State private var isSaving = false
    @State private var isCompleting = false
    @State private var errorMessage: String?

    var body: some View {
        AppSheetScaffold(
            title: "Thực hiện Task",
            actionTitle: "Lưu",
            isSaving: isSaving || isCompleting,
            canSubmit: operations.selectedTask != nil,
            onCancel: { dismiss() },
            onSubmit: { Task { await saveExecution() } }
        ) {
            AppFormSection("Thông tin thực hiện") {
                AppPickerRow(title: "Team Order", selection: $form.orderTeam) {
                    ForEach(TaskConstants.orderTeams, id: \.self) { team in
                        Text(team).tag(team)
                    }
                }
                AppDivider()
                AppPickerRow(title: "Độ ưu tiên", selection: $form.priority) {
                    Text("Bình thường").tag("")
                    Text("Gấp").tag("Gấp")
                }
                AppDivider()
                AppTextFieldRow(title: "Resize", placeholder: "VD: 9x16 & 1x1", text: $form.resizeRequirements)
            }

            AppFormSection("Timeline") {
                AppTextFieldRow(title: "Ngày nhận", placeholder: "DD/MM hoặc YYYY-MM-DD", text: $form.receiveDate)
                AppDivider()
                AppTextFieldRow(title: "Ngày trả", placeholder: "DD/MM hoặc YYYY-MM-DD", text: $form.returnDate)
            }

            AppFormSection("Link thành phẩm") {
                AppTextFieldRow(title: "Link", placeholder: "https://...", text: $form.resultLink)
            }

            Button {
                Task { await completeTask() }
            } label: {
                if isCompleting {
                    ProgressView()
                        .tint(AppColors.success)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                } else {
                    Label("Hoàn thành Task", systemImage: "checkmark.circle")
                        .font(.system(size: 13, weight: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.success)
            .disabled(isSaving || isCompleting || operations.selectedTask == nil)

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
        .onAppear {
            if let task = operations.selectedTask {
                form = LinkedTaskExecutionFormData(task: task)
            }
        }
    }

    private func saveExecution() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await operations.updateSelectedLinkedTaskExecution(form)
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể lưu thông tin thực hiện Task. Vui lòng thử lại.").localizedDescription
        }
    }

    private func completeTask() async {
        errorMessage = nil
        isCompleting = true
        defer { isCompleting = false }

        do {
            try await operations.completeSelectedLinkedTask(form)
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể hoàn thành Task. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct TaskEditSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var editForm = VideoTaskFormData()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        AppSheetScaffold(
            title: "Sửa Video Task",
            actionTitle: "Lưu",
            isSaving: isSaving,
            canSubmit: appState.can(.videoTasksUpdate),
            onCancel: {
                operations.selectedTask = nil
                dismiss()
            },
            onSubmit: { Task { await saveEdit() } }
        ) {
            if let task = operations.selectedTask {
                VideoTaskFormFields(
                    form: $editForm,
                    editors: operations.editors,
                    isLinkedTask: task.contentPlanId != nil
                )

                if appState.can(.videoTasksDelete) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(isDeleting ? "Đang xóa..." : "Xóa video task", systemImage: "trash")
                            .font(.system(size: 13, weight: .black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.danger)
                    .disabled(isSaving || isDeleting)
                }

                if let errorMessage {
                    AppInlineError(message: errorMessage)
                }
            } else {
                AppCard {
                    EmptyStateView(title: "Không tìm thấy task", message: "Task đã được làm mới hoặc không còn tồn tại.")
                }
            }
        }
        .onAppear {
            if let task = operations.selectedTask {
                editForm = VideoTaskFormData(task: task, editors: operations.editors)
            }
        }
        .alert("Xóa video task?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                Task { await deleteTask() }
            }
        } message: {
            Text("Thao tác này sẽ dùng backend/RPC hiện có để xóa task và thông báo liên quan.")
        }
    }

    private func deleteTask() async {
        guard appState.can(.videoTasksDelete) else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await operations.deleteSelectedTask()
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể xóa video task. Vui lòng thử lại.").localizedDescription
        }
    }

    private func saveEdit() async {
        guard appState.can(.videoTasksUpdate) else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await operations.updateSelectedTask(editForm, userId: appState.authSession?.id)
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể cập nhật video task. Vui lòng thử lại.").localizedDescription
        }
    }

    private func editorName(for task: VideoTask) -> String {
        guard let editorId = task.editorId, !editorId.isEmpty else { return "Chưa phân công" }
        return operations.editors.first { $0.id == editorId || $0.profileId == editorId }?.shortName ?? editorId
    }
}

struct ShootEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var form = ShootFormData()
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var shoot: ShootSchedule? { operations.selectedShoot }
    private var isEditing: Bool { shoot != nil }

    var body: some View {
        AppSheetScaffold(
            title: isEditing ? "Cập nhật lịch quay" : "Tạo buổi quay mới",
            cancelTitle: "Đóng",
            actionTitle: "Lưu",
            isSaving: isSaving,
            canSubmit: canSave,
            onCancel: {
                operations.selectedShoot = nil
                dismiss()
            },
            onSubmit: { Task { await save() } }
        ) {
            AppFormSection("Lịch quay") {
                AppTextFieldRow(title: "Ngày quay", placeholder: "YYYY-MM-DD", text: $form.date)
                AppDivider()
                AppPickerRow(title: "Loại lịch", selection: $form.type) {
                    ForEach(ShootType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                AppDivider()
                AppTextFieldRow(title: "Địa điểm", placeholder: "Nhập địa điểm", text: $form.place)
                AppDivider()
                AppTextFieldRow(title: "Thời gian", placeholder: "VD: 09:00-11:00", text: $form.time)
                AppDivider()
                AppTextFieldRow(title: "Crew", placeholder: "Tên crew phụ trách", text: $form.crew)
                AppDivider()
                AppTextFieldRow(title: "Ghi chú nội dung", placeholder: "Ghi chú thêm cho buổi quay", text: $form.note, axis: .vertical)
            }

            AppFormSection("Editor phụ trách") {
                if operations.editors.isEmpty {
                    Text("Chưa tải được danh sách editor.")
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(Array(operations.editors.enumerated()), id: \.element.id) { index, editor in
                        Toggle(isOn: editorBinding(editor.id)) {
                            Text(editor.shortName)
                                .font(AppTypography.rowValue)
                                .foregroundStyle(AppColors.text)
                        }
                        .tint(AppColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if index < operations.editors.count - 1 {
                            AppDivider()
                        }
                    }
                }
            }

            if isEditing, appState.can(.shootsDelete) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(isDeleting ? "Đang xóa..." : "Xóa lịch quay", systemImage: "trash")
                        .font(.system(size: 13, weight: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.danger)
                .disabled(isSaving || isDeleting)
            }

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
        .onAppear {
            if let shoot {
                form = ShootFormData(shoot: shoot)
            }
        }
        .alert("Xóa lịch quay?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                Task { await deleteShoot() }
            }
        } message: {
            Text("Thao tác này sẽ dùng RPC backend hiện có để xóa lịch quay và thông báo liên quan.")
        }
    }

    private var canSave: Bool {
        isEditing ? appState.can(.shootsUpdate) : appState.can(.shootsCreate)
    }

    private func editorBinding(_ editorId: String) -> Binding<Bool> {
        Binding {
            form.editorIds.contains(editorId)
        } set: { isSelected in
            if isSelected {
                form.editorIds.insert(editorId)
            } else {
                form.editorIds.remove(editorId)
            }
        }
    }

    private func save() async {
        guard canSave else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            if isEditing {
                try await operations.updateSelectedShoot(form)
            } else {
                try await operations.createShoot(form)
            }
            operations.selectedShoot = nil
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể lưu lịch quay. Vui lòng thử lại.").localizedDescription
        }
    }

    private func deleteShoot() async {
        guard appState.can(.shootsDelete) else {
            errorMessage = AppError.permissionDenied.localizedDescription
            return
        }

        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await operations.deleteSelectedShoot()
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể xóa lịch quay. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct ProfileEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var form = ProfileFormData()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        AppSheetScaffold(
            title: "Cập nhật hồ sơ",
            actionTitle: "Lưu",
            isSaving: isSaving,
            onCancel: { dismiss() },
            onSubmit: { Task { await save() } }
        ) {
            AppFormSection("Hồ sơ") {
                AppTextFieldRow(title: "Họ và tên", placeholder: "Nhập họ và tên", text: $form.fullName)
                AppDivider()
                AppTextFieldRow(title: "Tên hiển thị", placeholder: "Tên dùng trong app", text: $form.displayName)
                AppDivider()
                AppTextFieldRow(title: "Số điện thoại", placeholder: "Số điện thoại", text: $form.phone)
                AppDivider()
                AppTextFieldRow(title: "Phòng ban", placeholder: "Phòng ban", text: $form.department)
            }

            if let errorMessage {
                AppInlineError(message: errorMessage)
            }
        }
        .onAppear {
            if let profile = appState.currentProfile {
                form = ProfileFormData(
                    fullName: profile.fullName,
                    displayName: profile.displayName,
                    phone: profile.phone,
                    department: profile.department
                )
            }
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await authViewModel.updateProfile(data: form, appState: appState)
            dismiss()
        } catch {
            errorMessage = AppError.map(error, fallback: "Không thể cập nhật hồ sơ. Vui lòng thử lại.").localizedDescription
        }
    }
}

struct PasswordEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var message: String?
    @State private var isSuccess = false

    var body: some View {
        AppSheetScaffold(
            title: "Đổi mật khẩu",
            cancelTitle: "Đóng",
            actionTitle: "Lưu",
            isSaving: isSaving,
            onCancel: { dismiss() },
            onSubmit: { Task { await save() } }
        ) {
            AppFormSection("Đổi mật khẩu") {
                AppSecureFieldRow(title: "Mật khẩu hiện tại", placeholder: "Nhập mật khẩu hiện tại", text: $currentPassword)
                AppDivider()
                AppSecureFieldRow(title: "Mật khẩu mới", placeholder: "Nhập mật khẩu mới", text: $newPassword)
                AppDivider()
                AppSecureFieldRow(title: "Xác nhận mật khẩu mới", placeholder: "Nhập lại mật khẩu mới", text: $confirmation)
            }

            if let message {
                Text(message)
                    .font(AppTypography.supporting)
                    .foregroundStyle(isSuccess ? AppColors.success : AppColors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background((isSuccess ? AppColors.success : AppColors.danger).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            }
        }
    }

    private func save() async {
        guard appState.can(.profileEditSelf) else {
            message = AppError.permissionDenied.localizedDescription
            isSuccess = false
            return
        }

        message = nil
        isSuccess = false
        isSaving = true
        defer { isSaving = false }

        do {
            try await authViewModel.updatePassword(
                email: appState.currentProfile?.email ?? appState.authSession?.email ?? "",
                currentPassword: currentPassword,
                newPassword: newPassword,
                confirmation: confirmation
            )
            currentPassword = ""
            newPassword = ""
            confirmation = ""
            message = "Đã cập nhật mật khẩu."
            isSuccess = true
        } catch {
            message = AppError.map(error, fallback: "Không thể cập nhật mật khẩu. Vui lòng thử lại.").localizedDescription
            isSuccess = false
        }
    }
}
