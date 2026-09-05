import SwiftUI

struct ContentPlanModuleView: View {
    @ObservedObject var viewModel: ContentPlanViewModel
    var permissions: ContentPlanPermissions
    var closeWithToast: (CHToastItem?) -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("content.module")

                if let error = viewModel.modalError {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CHColors.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(CHColors.red.opacity(0.08)))
                        .accessibilityIdentifier("content.module.error")
                }

                linkedTaskIndicator

                VStack(alignment: .leading, spacing: 12) {
                    field("Ngày Air *") {
                        ContentPlanTextField(text: $viewModel.formData.airDate, placeholder: "YYYY-MM-DD", editable: fieldState.canEditAirDate)
                            .accessibilityIdentifier(fieldState.canEditAirDate ? "content.module.air-date" : "content.module.air-date.passive")
                    }

                    field("Thể loại") {
                        categoryPicker
                    }

                    field("Tên video *") {
                        ContentPlanTextField(text: $viewModel.formData.title, placeholder: "Nhập tên video...", editable: fieldState.canEditTitle)
                            .accessibilityIdentifier(fieldState.canEditTitle ? "content.module.title" : "content.module.title.passive")
                    }

                    field("Editor") {
                        editorPicker
                    }

                    field("Ghi chú") {
                        ContentPlanMultilineField(text: $viewModel.formData.note, placeholder: "Ghi chú thêm cho lịch air...", editable: fieldState.canEditNote)
                            .accessibilityIdentifier(fieldState.canEditNote ? "content.module.note" : "content.module.note.passive")
                    }

                    field("Link thành phẩm") {
                        VStack(alignment: .leading, spacing: 6) {
                            ContentPlanTextField(text: $viewModel.formData.link, placeholder: "https://...", editable: fieldState.canEditLink)
                                .accessibilityIdentifier(fieldState.canEditLink ? "content.module.link" : "content.module.link.passive")
                            if openedItem?.hasLinkedTask == true {
                                Text("Link này được đồng bộ từ Video tháng.")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(CHColors.muted)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.76), lineWidth: 1))
                        .shadow(color: CHShadow.softColor, radius: 16, y: 11)
                )

                actionBar
            }

            if viewModel.pendingDeleteItem != nil {
                ContentPlanDeleteConfirmation(
                    isDeleting: viewModel.isDeleting,
                    hasLinkedTask: openedItem?.hasLinkedTask == true,
                    cancel: { viewModel.cancelDelete() },
                    confirm: {
                        Task {
                            if await viewModel.confirmDelete(permissions: permissions) {
                                closeWithToast(CHToastItem(kind: .success, message: "Đã xóa dòng lịch air."))
                            }
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(5)
            }
        }
        .animation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.24), value: viewModel.pendingDeleteItem != nil)
    }

    private var fieldState: ContentPlanFieldState {
        viewModel.fieldState(permissions: permissions)
    }

    private var isCreate: Bool {
        viewModel.moduleMode?.isCreate == true
    }

    private var openedItem: ContentPlanItem? {
        viewModel.moduleMode?.item
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: 0x6F7A92))
            content()
        }
    }

    private var categoryPicker: some View {
        Group {
            if fieldState.canEditCategory {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(ContentPlanCategory.allCases) { category in
                                Button {
                                    viewModel.formData.category = category
                                } label: {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(category.tint)
                                            .frame(width: 6, height: 6)
                                        Text(category.rawValue)
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(viewModel.formData.category == category ? .white : CHColors.muted)
                                    .padding(.horizontal, 9)
                                    .frame(height: 32)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(viewModel.formData.category == category ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.78)))
                                            .overlay(Capsule().stroke(viewModel.formData.category == category ? Color.clear : CHColors.line, lineWidth: 1))
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(category)
                                .accessibilityIdentifier("content.module.category.\(category.rawValue)")
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(viewModel.formData.category, anchor: .leading)
                    }
                    .onChange(of: viewModel.formData.category) { _, category in
                        withAnimation(.timingCurve(0.2, 0.75, 0.25, 1, duration: 0.22)) {
                            proxy.scrollTo(category, anchor: .leading)
                        }
                    }
                }
            } else {
                Text(viewModel.formData.category.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(viewModel.formData.category.tint)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .background(ContentPlanFieldBackground(editable: false))
                    .accessibilityIdentifier("content.module.category.passive")
            }
        }
    }

    private var editorPicker: some View {
        Group {
            if fieldState.canEditEditor {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        Button {
                            viewModel.formData.editorCode = ""
                        } label: {
                            editorChip(title: "Chưa phân công", initials: "-", selected: viewModel.formData.editorCode.isEmpty)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("content.module.editor.none")

                        ForEach(viewModel.editorOptions) { editor in
                            Button {
                                viewModel.formData.editorCode = editor.editorCode
                            } label: {
                                editorChip(title: editor.shortName, initials: editor.initials, selected: viewModel.formData.editorCode == editor.editorCode)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("content.module.editor.\(editor.editorCode)")
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(openedItem?.editorDisplayName ?? "Chưa phân công")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CHColors.ink)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                        .background(ContentPlanFieldBackground(editable: false))
                        .accessibilityIdentifier("content.module.editor.passive")

                    if openedItem?.isLinkedTaskStarted == true {
                        Text("Không thể đổi Editor vì Task đã được bắt đầu.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CHColors.muted)
                            .accessibilityIdentifier("content.module.editor.locked-reason")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var linkedTaskIndicator: some View {
        if let item = openedItem, item.hasLinkedTask {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(CHColors.green)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(hex: 0xE6F8EF)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Đã liên kết Video Task")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(CHColors.ink)
                    Text(linkedTaskDetail(item))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CHColors.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("content.module.linked-status")
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: 0xCBEFDB), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 10, y: 7)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("content.module.linked-indicator")
        }
    }

    private func linkedTaskDetail(_ item: ContentPlanItem) -> String {
        let status = item.normalizedLinkedTaskStatus ?? "Chưa rõ"
        return "Trạng thái: \(status) · Editor: \(item.editorDisplayName)"
    }

    private func editorChip(title: String, initials: String, selected: Bool) -> some View {
        HStack(spacing: 7) {
            Text(initials)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(selected ? .white : CHColors.purple)
                .frame(width: 22, height: 22)
                .background(Circle().fill(selected ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.86))))
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(CHColors.ink)
                .lineLimit(1)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(selected ? CHColors.purple : CHColors.muted.opacity(0.5))
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? CHColors.purple.opacity(0.08) : Color.white.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selected ? CHColors.purple.opacity(0.35) : CHColors.line, lineWidth: 1))
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if !isCreate, permissions.canDelete, openedItem != nil {
                Button {
                    viewModel.requestDelete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Xóa")
                    }
                }
                .buttonStyle(ContentPlanDangerButtonStyle())
                .disabled(viewModel.isSaving || viewModel.isDeleting)
                .accessibilityIdentifier("content.module.delete")
            }

            Spacer()

            if fieldState.canSave {
                Button {
                    Task {
                        if await viewModel.save(permissions: permissions) {
                            let message = saveToastMessage
                            closeWithToast(CHToastItem(kind: .success, message: message))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(viewModel.isSaving ? "Đang lưu..." : saveButtonTitle)
                    }
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.isSaving || viewModel.isDeleting)
                .accessibilityIdentifier("content.module.save")
            }
        }
        .padding(.top, 2)
    }

    private var saveButtonTitle: String {
        switch viewModel.moduleMode {
        case .create: "Thêm dòng"
        case .assign: "Lưu phân công"
        default: "Lưu thay đổi"
        }
    }

    private var saveToastMessage: String {
        switch viewModel.moduleMode {
        case .assign: "Đã phân công editor."
        default: "Đã lưu lịch air."
        }
    }
}

private struct ContentPlanTextField: View {
    @Binding var text: String
    var placeholder: String
    var editable: Bool

    var body: some View {
        Group {
            if editable {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                Text(text.isEmpty ? "—" : text)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(CHColors.ink)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(ContentPlanFieldBackground(editable: editable))
    }
}

private struct ContentPlanMultilineField: View {
    @Binding var text: String
    var placeholder: String
    var editable: Bool

    var body: some View {
        Group {
            if editable {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CHColors.muted.opacity(0.72))
                            .padding(.horizontal, 12)
                            .padding(.top, 11)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CHColors.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(minHeight: 72)
                        .background(Color.clear)
                }
            } else {
                Text(text.isEmpty ? "—" : text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CHColors.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
        }
        .background(ContentPlanFieldBackground(editable: editable))
    }
}

private struct ContentPlanFieldBackground: View {
    var editable: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(editable ? Color.white.opacity(0.88) : Color(hex: 0xF6F7FB))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(editable ? CHColors.line : CHColors.line.opacity(0.55), lineWidth: 1))
    }
}

private struct ContentPlanDeleteConfirmation: View {
    var isDeleting: Bool
    var hasLinkedTask: Bool
    var cancel: () -> Void
    var confirm: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(CHColors.red)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color(hex: 0xFFE9EC)))
                Text("Xóa kế hoạch content?")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                Text(hasLinkedTask ? "Thao tác này không thể hoàn tác. Task Video liên kết cũng sẽ bị xóa theo Content Plan." : "Thao tác này không thể hoàn tác.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CHColors.muted)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button("Hủy", action: cancel)
                    .buttonStyle(ContentPlanSecondaryButtonStyle())
                    .disabled(isDeleting)
                    .accessibilityIdentifier("content.delete.cancel")
                Button(isDeleting ? "Đang xóa..." : "Xóa dòng", action: confirm)
                    .buttonStyle(ContentPlanDangerButtonStyle())
                    .disabled(isDeleting)
                    .accessibilityIdentifier("content.delete.confirm")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.76), lineWidth: 1))
                .shadow(color: CHShadow.softColor, radius: 18, y: 12)
        )
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.16).ignoresSafeArea())
        .accessibilityIdentifier("content.delete.confirmation")
    }
}

private struct ContentPlanDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(CHColors.red, in: Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct ContentPlanSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(CHColors.ink)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color.white.opacity(0.86), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(CHColors.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
