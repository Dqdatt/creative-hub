import SwiftUI

struct CalendarModuleView: View {
    @ObservedObject var viewModel: CalendarViewModel
    var permissions: CalendarPermissions
    var closeWithToast: (CHToastItem?) -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("calendar.module")

                if let error = viewModel.modalError {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CHColors.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(CHColors.red.opacity(0.08))
                        )
                        .accessibilityIdentifier("calendar.module.error")
                }

                VStack(alignment: .leading, spacing: 12) {
                    field("Ngày quay *") {
                        CalendarTextField(text: $viewModel.formData.date, placeholder: "YYYY-MM-DD", editable: isEditable)
                    }

                    field("Loại lịch") {
                        typePicker
                    }

                    field("Thời gian") {
                        CalendarTextField(text: $viewModel.formData.time, placeholder: "ALL MORNING", editable: isEditable)
                    }

                    field("Địa điểm *") {
                        CalendarTextField(text: $viewModel.formData.place, placeholder: "VD: SHOWROOM HÒA BÌNH", editable: isEditable)
                    }

                    field("Editor") {
                        editorPicker
                    }

                    field("Crew") {
                        CalendarTextField(text: $viewModel.formData.crew, placeholder: "VD: BUMI - LINH", editable: isEditable)
                    }

                    field("Nội dung *") {
                        CalendarMultilineField(text: $viewModel.formData.content, placeholder: "Nội dung lịch quay", editable: isEditable)
                    }

                    field("Ghi chú") {
                        CalendarMultilineField(text: $viewModel.formData.note, placeholder: "Ghi chú thêm", editable: isEditable)
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

            if viewModel.pendingDeleteShoot != nil {
                CalendarDeleteConfirmation(
                    isDeleting: viewModel.isDeleting,
                    cancel: { viewModel.cancelDelete() },
                    confirm: {
                        Task {
                            if await viewModel.confirmDelete() {
                                closeWithToast(CHToastItem(kind: .success, message: "Đã xóa lịch quay."))
                            }
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(5)
            }
        }
        .animation(.timingCurve(0.22, 0.86, 0.28, 1, duration: 0.24), value: viewModel.pendingDeleteShoot != nil)
    }

    private var isEditable: Bool {
        viewModel.moduleMode?.isEditable == true
    }

    private var isCreate: Bool {
        if case .create = viewModel.moduleMode { return true }
        return false
    }

    private var openedShoot: CalendarShoot? {
        switch viewModel.moduleMode {
        case .edit(let shoot), .readOnly(let shoot):
            shoot
        case .create, .none:
            nil
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: 0x6F7A92))
            content()
        }
    }

    private var typePicker: some View {
        Group {
            if isEditable {
                HStack(spacing: 7) {
                    ForEach(CalendarShootType.allCases) { type in
                        Button {
                            viewModel.formData.type = type
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(type.tint)
                                    .frame(width: 6, height: 6)
                                Text(type.label)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(viewModel.formData.type == type ? .white : CHColors.muted)
                            .padding(.horizontal, 9)
                            .frame(height: 32)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(viewModel.formData.type == type ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.78)))
                                    .overlay(Capsule().stroke(viewModel.formData.type == type ? Color.clear : CHColors.line, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("calendar.module.type.\(type.rawValue)")
                    }
                }
            } else {
                CalendarPassiveTypeBadge(type: viewModel.formData.type)
                    .accessibilityIdentifier("calendar.module.type.passive")
            }
        }
    }

    private var editorPicker: some View {
        Group {
            if isEditable {
                editableEditorPicker
            } else {
                readOnlyEditorList
            }
        }
    }

    private var editableEditorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                if viewModel.editorOptions.isEmpty {
                    Text("Chưa có editor để phân công.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CHColors.muted)
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                } else {
                    ForEach(viewModel.editorOptions) { editor in
                        let isSelected = viewModel.formData.editorCodes.contains(editor.editorCode)
                        Button {
                            if isSelected {
                                viewModel.formData.editorCodes.removeAll { $0 == editor.editorCode }
                            } else {
                                viewModel.formData.editorCodes.append(editor.editorCode)
                            }
                        } label: {
                            HStack(spacing: 7) {
                                CalendarEditorAvatar(initials: editor.initials, colorHex: editor.colorHex)
                                Text(editor.shortName)
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(CHColors.ink)
                                    .lineLimit(1)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(isSelected ? CHColors.purple : CHColors.muted.opacity(0.5))
                                    .accessibilityIdentifier("calendar.module.editor.selection-control")
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? CHColors.purple.opacity(0.08) : Color.white.opacity(0.78))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isSelected ? CHColors.purple.opacity(0.35) : CHColors.line, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("calendar.module.editor.\(editor.editorCode)")
                    }
                }
            }
        }
    }

    private var readOnlyEditorList: some View {
        let items = readOnlyEditors
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                if items.isEmpty {
                    Text("Chưa phân công editor.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CHColors.muted)
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                        .accessibilityIdentifier("calendar.module.editor.passive.empty")
                } else {
                    ForEach(items) { editor in
                        HStack(spacing: 7) {
                            CalendarEditorAvatar(initials: editor.initials, colorHex: editor.colorHex)
                            Text(editor.name)
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(CHColors.ink)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.62))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CHColors.line, lineWidth: 1))
                        )
                        .accessibilityIdentifier("calendar.module.editor.passive.\(editor.id)")
                    }
                }
            }
        }
    }

    private var readOnlyEditors: [PassiveCalendarEditor] {
        guard let shoot = openedShoot else { return [] }
        return shoot.editorCodes.enumerated().map { index, code in
            let option = viewModel.editorOptions.first { $0.editorCode == code }
            let fallbackLabel = index < shoot.editorLabels.count ? shoot.editorLabels[index] : code.uppercased()
            return PassiveCalendarEditor(
                id: code,
                name: option?.shortName ?? fallbackLabel,
                initials: option?.initials ?? String(fallbackLabel.prefix(1)),
                colorHex: option?.colorHex ?? CalendarProfileDTOFallback.color(seed: code)
            )
        }
    }

    private struct PassiveCalendarEditor: Identifiable {
        var id: String
        var name: String
        var initials: String
        var colorHex: String
    }

    private enum CalendarProfileDTOFallback {
        static func color(seed: String) -> String {
            let palette = ["#0EA5E9", "#22C55E", "#F59E0B", "#EF4444", "#14B8A6", "#8B5CF6", "#EC4899"]
            let total = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            return palette[total % palette.count]
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if isEditable, !isCreate, permissions.canDelete {
                Button {
                    viewModel.requestDelete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Xóa")
                    }
                }
                .buttonStyle(CalendarDangerButtonStyle())
                .disabled(viewModel.isSaving || viewModel.isDeleting)
                .accessibilityIdentifier("calendar.module.delete")
            }

            Spacer()

            if isEditable {
                Button {
                    Task {
                        if await viewModel.save() {
                            let message = isCreate ? "Đã thêm lịch quay." : "Đã lưu thay đổi lịch quay."
                            closeWithToast(CHToastItem(kind: .success, message: message))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(viewModel.isSaving ? "Đang lưu..." : (isCreate ? "Lưu lịch quay" : "Lưu thay đổi"))
                    }
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.isSaving || viewModel.isDeleting)
                .accessibilityIdentifier("calendar.module.save")
            }
        }
        .padding(.top, 2)
    }
}

private struct CalendarTextField: View {
    @Binding var text: String
    var placeholder: String
    var editable: Bool

    var body: some View {
        Group {
            if editable {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("calendar.module.editable-field")
            } else {
                Text(text.isEmpty ? "—" : text)
                    .accessibilityIdentifier("calendar.module.passive-field")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(CHColors.ink)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(CalendarFieldBackground(editable: editable))
    }
}

private struct CalendarMultilineField: View {
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
                        .accessibilityIdentifier("calendar.module.editable-field")
                }
            } else {
                Text(text.isEmpty ? "—" : text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CHColors.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                    .accessibilityIdentifier("calendar.module.passive-field")
            }
        }
        .background(CalendarFieldBackground(editable: editable))
    }
}

private struct CalendarPassiveTypeBadge: View {
    var type: CalendarShootType

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(type.tint)
                .frame(width: 7, height: 7)
            Text(type.label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(type.tint)
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(
            Capsule(style: .continuous)
                .fill(type.softBackground.opacity(0.9))
                .overlay(Capsule().stroke(type.tint.opacity(0.14), lineWidth: 1))
        )
    }
}

private struct CalendarEditorAvatar: View {
    var initials: String
    var colorHex: String

    var body: some View {
        Circle()
            .fill(Color(hexString: colorHex) ?? CHColors.purple)
            .frame(width: 26, height: 26)
            .overlay(
                Text(initials)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
            )
    }
}

private struct CalendarFieldBackground: View {
    var editable: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(editable ? 0.88 : 0.58))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CHColors.line, lineWidth: 1))
    }
}

private struct CalendarDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CHTypography.label)
            .foregroundStyle(CHColors.red)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(CHColors.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CHColors.red.opacity(0.18)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct CalendarDeleteConfirmation: View {
    var isDeleting: Bool
    var cancel: () -> Void
    var confirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(CHColors.red)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(CHColors.red.opacity(0.10)))

                VStack(spacing: 5) {
                    Text("Xóa lịch quay?")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(CHColors.ink)
                    Text("Thao tác này không thể hoàn tác.")
                        .font(CHTypography.caption)
                        .foregroundStyle(CHColors.muted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 9) {
                    Button("Hủy", action: cancel)
                        .buttonStyle(CHSecondaryButtonStyle())
                        .disabled(isDeleting)
                    Button(isDeleting ? "Đang xóa..." : "Xóa lịch quay", action: confirm)
                        .buttonStyle(CalendarDangerButtonStyle())
                        .disabled(isDeleting)
                }
            }
            .padding(18)
            .frame(maxWidth: 310)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.80), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 18, y: 12)
            )
            .padding(.horizontal, 24)
            .accessibilityIdentifier("calendar.delete.confirm")
        }
    }
}
