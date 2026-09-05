import SwiftUI

struct VideoTaskModuleView: View {
    @ObservedObject var viewModel: VideoTaskViewModel
    var permissions: VideoTaskPermissions
    var closeWithToast: (CHToastItem?) -> Void

    private var fieldState: VideoTaskFieldState {
        viewModel.fieldState(permissions: permissions)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("video.module")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("video.module")

            VStack(alignment: .leading, spacing: 11) {
                if fieldState.isLinkedTask {
                    HStack(spacing: 7) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Linked Content Plan")
                            .font(CHTypography.caption)
                    }
                    .foregroundStyle(CHColors.purple)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(Color(hex: 0xF0EAFF)))
                    .accessibilityIdentifier("video.module.linked-badge")
                }

                VideoTaskTextField(label: "Tên video *", text: $viewModel.formData.title, editable: fieldState.canEditTitle, identifier: "video.module.title")

                HStack(spacing: 10) {
                    VideoTaskMenuField(
                        label: "Người làm",
                        value: editorName(viewModel.formData.editorCode),
                        editable: fieldState.canEditEditor,
                        identifier: "video.module.editor"
                    ) {
                        Button("Chưa phân công") { viewModel.formData.editorCode = "" }
                        ForEach(viewModel.editorOptions) { editor in
                            Button(editor.shortName) { viewModel.formData.editorCode = editor.editorCode }
                        }
                    }
                    VideoTaskMenuField(
                        label: "Trạng thái",
                        value: viewModel.formData.status.rawValue,
                        editable: fieldState.canEditStatus,
                        identifier: "video.module.status"
                    ) {
                        ForEach(VideoTaskStatus.allCases) { status in
                            Button(status.rawValue) { viewModel.formData.status = status }
                        }
                    }
                }

                HStack(spacing: 10) {
                    VideoTaskMenuField(
                        label: "Team Order",
                        value: viewModel.formData.orderTeam.isEmpty ? "-" : viewModel.formData.orderTeam,
                        editable: fieldState.canEditOrderTeam,
                        identifier: "video.module.order"
                    ) {
                        ForEach(VideoTaskConstants.orderTeams, id: \.self) { team in
                            Button(team) { viewModel.formData.orderTeam = team }
                        }
                    }
                    VideoTaskMenuField(
                        label: "Thể loại",
                        value: viewModel.formData.category.rawValue,
                        editable: fieldState.canEditCategory,
                        identifier: "video.module.category"
                    ) {
                        ForEach(VideoTaskCategory.allCases) { category in
                            Button(category.rawValue) { viewModel.formData.category = category }
                        }
                    }
                }

                HStack(spacing: 10) {
                    VideoTaskMenuField(
                        label: "Độ ưu tiên",
                        value: viewModel.formData.priority.label,
                        editable: fieldState.canEditPriority,
                        identifier: "video.module.priority"
                    ) {
                        ForEach(VideoTaskPriority.allCases) { priority in
                            Button(priority.label) { viewModel.formData.priority = priority }
                        }
                    }
                    VideoTaskTextField(label: "Resize", text: $viewModel.formData.resize, editable: fieldState.canEditResize, identifier: "video.module.resize")
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        VideoTaskTextField(
                            label: "Ngày nhận",
                            text: bindingForReceiveDate,
                            editable: fieldState.canEditReceiveDate,
                            placeholder: "YYYY-MM-DD",
                            identifier: "video.module.receive-date"
                        )
                        VideoTaskTextField(
                            label: "Ngày trả",
                            text: bindingForReturnDate,
                            editable: fieldState.canEditReturnDate,
                            placeholder: "YYYY-MM-DD",
                            identifier: "video.module.return-date"
                        )
                    }
                    VideoTaskTextField(label: "Ngày Air", text: $viewModel.formData.airDate, editable: fieldState.canEditAirDate, placeholder: "YYYY-MM-DD", identifier: "video.module.air-date")
                }
                    .padding(.top, 2)

                VideoTaskTextField(label: "Link thành phẩm", text: $viewModel.formData.resultLink, editable: fieldState.canEditResultLink, placeholder: "https://...", identifier: "video.module.result-link")
                VideoTaskMultilineField(label: "Ghi chú", text: $viewModel.formData.note, editable: fieldState.canEditNote, identifier: "video.module.note")

                if let message = viewModel.modalError {
                    Text(message)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CHColors.red)
                        .accessibilityIdentifier("video.module.error")
                }

                actionRow
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.84))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.78), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 18, y: 12)
            )
            .overlay {
                if viewModel.pendingDeleteTask != nil {
                    VideoTaskDeleteConfirmation(
                        task: viewModel.pendingDeleteTask!,
                        isDeleting: viewModel.isDeleting,
                        onCancel: { viewModel.cancelDelete() },
                        onConfirm: {
                            Task {
                                if await viewModel.confirmDelete(permissions: permissions) {
                                    closeWithToast(CHToastItem(kind: .success, message: "Đã xóa video task."))
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            if let task = viewModel.moduleMode?.task, permissions.canDelete {
                Button {
                    viewModel.pendingDeleteTask = task
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Xóa Task")
                    }
                }
                .buttonStyle(VideoTaskDangerButtonStyle())
                .disabled(viewModel.isSaving || viewModel.isDeleting)
                .accessibilityIdentifier("video.module.delete")
            }

            Spacer(minLength: 0)

            if fieldState.canSaveExecution {
                Button {
                    Task {
                        if await viewModel.saveExecution(permissions: permissions) {
                            closeWithToast(CHToastItem(kind: .success, message: "Đã lưu thông tin thực hiện Task."))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                        Text("Lưu thay đổi")
                    }
                }
                .buttonStyle(CHSecondaryButtonStyle())
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("video.module.save-execution")
            }

            if fieldState.canAccept {
                Button {
                    Task {
                        if await viewModel.accept(permissions: permissions) {
                            closeWithToast(CHToastItem(kind: .success, message: "Đã nhận Task."))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Nhận Task")
                    }
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("video.module.accept")
            } else if fieldState.canComplete {
                Button {
                    Task {
                        if await viewModel.complete(permissions: permissions) {
                            closeWithToast(CHToastItem(kind: .success, message: "Đã hoàn thành Task."))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Hoàn thành")
                    }
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("video.module.complete")
            } else if fieldState.canUseGenericSave {
                Button {
                    Task {
                        let creating = viewModel.moduleMode == .create
                        if await viewModel.save(permissions: permissions) {
                            closeWithToast(CHToastItem(kind: .success, message: creating ? "Đã thêm video task." : "Đã lưu thay đổi video task."))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Lưu thay đổi")
                    }
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("video.module.save")
            }
        }
        .padding(.top, 4)
    }

    private var bindingForReceiveDate: Binding<String> {
        Binding(
            get: {
                fieldState.canAccept ? viewModel.acceptData.receiveDate : viewModel.formData.receiveDate
            },
            set: { value in
                if fieldState.canAccept {
                    viewModel.acceptData.receiveDate = value
                } else {
                    viewModel.formData.receiveDate = value
                }
            }
        )
    }

    private var bindingForReturnDate: Binding<String> {
        Binding(
            get: {
                fieldState.canAccept ? viewModel.acceptData.returnDate : viewModel.formData.returnDate
            },
            set: { value in
                if fieldState.canAccept {
                    viewModel.acceptData.returnDate = value
                } else {
                    viewModel.formData.returnDate = value
                }
            }
        )
    }

    private func editorName(_ code: String) -> String {
        viewModel.editorOptions.first { $0.editorCode == code }?.shortName ?? "Chưa phân công"
    }
}

private struct VideoTaskTextField: View {
    var label: String
    @Binding var text: String
    var editable: Bool
    var placeholder = ""
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(CHTypography.micro)
                .foregroundStyle(CHColors.muted)
            if editable {
                TextField(placeholder, text: $text)
                    .font(CHTypography.body)
                    .foregroundStyle(CHColors.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(fieldBackground)
                    .accessibilityIdentifier(identifier)
            } else {
                Text(text.isEmpty ? "-" : text)
                    .font(CHTypography.body)
                    .foregroundStyle(CHColors.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(passiveBackground)
                    .accessibilityIdentifier("\(identifier).passive")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line, lineWidth: 1))
    }

    private var passiveBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(hex: 0xF6F7FB).opacity(0.88))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line.opacity(0.70), lineWidth: 1))
    }
}

private struct VideoTaskMultilineField: View {
    var label: String
    @Binding var text: String
    var editable: Bool
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(CHTypography.micro)
                .foregroundStyle(CHColors.muted)
            if editable {
                TextEditor(text: $text)
                    .font(CHTypography.body)
                    .foregroundStyle(CHColors.ink)
                    .frame(minHeight: 66)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.92)).overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line)))
                    .accessibilityIdentifier(identifier)
            } else {
                Text(text.isEmpty ? "-" : text)
                    .font(CHTypography.body)
                    .foregroundStyle(CHColors.ink)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: 0xF6F7FB).opacity(0.88)).overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line.opacity(0.70))))
                    .accessibilityIdentifier("\(identifier).passive")
            }
        }
    }
}

private struct VideoTaskMenuField<Content: View>: View {
    var label: String
    var value: String
    var editable: Bool
    var identifier: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(CHTypography.micro)
                .foregroundStyle(CHColors.muted)
            if editable {
                Menu {
                    content
                } label: {
                    HStack {
                        Text(value)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .font(CHTypography.body)
                    .foregroundStyle(CHColors.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.92)).overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line)))
                }
                .accessibilityIdentifier(identifier)
            } else {
                Text(value)
                    .font(CHTypography.body)
                    .foregroundStyle(CHColors.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: 0xF6F7FB).opacity(0.88)).overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CHColors.line.opacity(0.70))))
                    .accessibilityIdentifier("\(identifier).passive")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VideoTaskDeleteConfirmation: View {
    var task: VideoTask
    var isDeleting: Bool
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.white.opacity(0.72)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            VStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(CHColors.red)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color(hex: 0xFFF1F2)))
                Text("Xóa video task?")
                    .font(CHTypography.headline)
                    .foregroundStyle(CHColors.ink)
                Text(task.isLinked
                    ? "Task này được tạo từ Content Plan. Thao tác xóa sẽ gỡ task khỏi Video tháng nhưng không xóa dòng Content Plan."
                    : "Thao tác này không thể hoàn tác.")
                    .font(CHTypography.caption)
                    .foregroundStyle(CHColors.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button("Hủy", action: onCancel)
                        .buttonStyle(CHSecondaryButtonStyle())
                        .accessibilityIdentifier("video.delete.cancel")
                    Button("Xóa Task", action: onConfirm)
                        .buttonStyle(VideoTaskDangerButtonStyle())
                        .disabled(isDeleting)
                        .accessibilityIdentifier("video.delete.confirm")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.82), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 18, y: 12)
            )
            .padding(.horizontal, 20)
        }
    }
}

private struct VideoTaskDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CHTypography.label)
            .foregroundStyle(CHColors.red)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color(hex: 0xFFF1F2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CHColors.red.opacity(0.18)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
