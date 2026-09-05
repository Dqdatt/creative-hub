import SwiftUI

struct NotificationNavigationPolicy {
    var canOpenCalendar: Bool
    var canOpenVideo: Bool
    var canOpenContent: Bool
    var canOpenMembers: Bool
}

struct NotificationsView: View {
    @ObservedObject var viewModel: NotificationViewModel
    var navigationPolicy: NotificationNavigationPolicy
    var onOpenDestination: (NotificationDestination) async -> Bool
    var onShowToast: (CHToastItem) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                Text("notifications.root")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("notifications.root")

                content
            }
            .padding(.horizontal, CHSpacing.screen)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(CHColors.appBackground.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
        .refreshable {
            if let message = await viewModel.refresh() {
                onShowToast(CHToastItem(kind: .error, message: message))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            CHStateView(kind: .loading, title: "Đang tải thông báo...")
                .frame(minHeight: 560)
                .accessibilityIdentifier("notifications.loading")
        case .failed(let message):
            CHStateView(
                kind: .error,
                title: "Không thể tải thông báo",
                message: message,
                actionTitle: "Thử lại",
                action: { Task { await viewModel.load() } }
            )
            .frame(minHeight: 560)
            .accessibilityIdentifier("notifications.load-error")
        case .loaded:
            VStack(spacing: 10) {
                summaryBar
                if viewModel.notifications.isEmpty {
                    CHCard {
                        CHStateView(
                            kind: .empty,
                            title: "Chưa có thông báo",
                            message: "Các cập nhật liên quan đến bạn sẽ xuất hiện tại đây."
                        )
                        .frame(minHeight: 430)
                    }
                    .accessibilityIdentifier("notifications.empty")
                } else {
                    LazyVStack(spacing: 9) {
                        ForEach(Array(viewModel.notifications.enumerated()), id: \.element.id) { index, notification in
                            NotificationRow(
                                notification: notification,
                                isOpened: viewModel.openedNotificationID == notification.id,
                                isLast: index == viewModel.notifications.count - 1,
                                action: {
                                    Task { await open(notification) }
                                }
                            )
                            .accessibilityIdentifier("notification.row.\(notification.id.uuidString)")
                        }
                    }
                    .accessibilityIdentifier("notifications.list")
                }
            }
        }
    }

    private var summaryBar: some View {
        CHCard {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.unreadCount > 0 ? "\(viewModel.unreadCount) chưa đọc" : "Đã đọc hết")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(CHColors.ink)
                        .accessibilityIdentifier("notifications.unread-summary")
                    Text("Thông báo gần đây của tài khoản này")
                        .font(CHTypography.micro)
                        .foregroundStyle(CHColors.muted)
                }
                Spacer(minLength: 8)
                Button {
                    Task {
                        let success = await viewModel.markAllRead()
                        if !success {
                            onShowToast(CHToastItem(kind: .error, message: viewModel.mutationError ?? "Không thể cập nhật trạng thái thông báo."))
                        }
                    }
                } label: {
                    if viewModel.isMarkingAll {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Đánh dấu đã đọc")
                    }
                }
                .buttonStyle(CHPrimaryButtonStyle())
                .disabled(viewModel.unreadCount == 0 || viewModel.isMarkingAll)
                .opacity(viewModel.unreadCount == 0 ? 0.45 : 1)
                .accessibilityIdentifier("notifications.mark-all")
            }
            .padding(12)
        }
    }

    private func open(_ notification: InternalNotification) async {
        let marked = await viewModel.markRead(notification)
        guard marked else {
            onShowToast(CHToastItem(kind: .error, message: viewModel.mutationError ?? "Không thể cập nhật trạng thái thông báo."))
            return
        }

        let destination = NotificationActionResolver.destination(for: notification)
        guard isAllowed(destination) else {
            onShowToast(CHToastItem(kind: .neutral, message: "Bạn không có quyền mở nội dung này."))
            return
        }

        switch destination {
        case .passive:
            viewModel.showSafeNotice("Thông báo này chỉ có nội dung tham khảo.")
            onShowToast(CHToastItem(kind: .neutral, message: "Thông báo này chỉ có nội dung tham khảo."))
        case .unavailable:
            viewModel.showSafeNotice("Nội dung thông báo không còn khả dụng.")
            onShowToast(CHToastItem(kind: .neutral, message: "Nội dung thông báo không còn khả dụng."))
        default:
            if !(await onOpenDestination(destination)) {
                viewModel.showSafeNotice("Nội dung thông báo không còn khả dụng.")
                onShowToast(CHToastItem(kind: .neutral, message: "Nội dung thông báo không còn khả dụng."))
            }
        }
    }

    private func isAllowed(_ destination: NotificationDestination) -> Bool {
        switch destination {
        case .calendarShoot:
            navigationPolicy.canOpenCalendar
        case .videoTask:
            navigationPolicy.canOpenVideo
        case .contentPlan:
            navigationPolicy.canOpenContent
        case .members:
            navigationPolicy.canOpenMembers
        case .overview, .passive, .unavailable:
            true
        }
    }
}

private struct NotificationRow: View {
    var notification: InternalNotification
    var isOpened: Bool
    var isLast: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CHCard {
                HStack(alignment: .top, spacing: 11) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(notification.type.accentColor.opacity(notification.isUnread ? 0.16 : 0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: notification.type.iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(notification.type.accentColor)
                            .frame(width: 40, height: 40)
                        if notification.isUnread {
                            Circle()
                                .fill(Color(hex: 0xFF4F67))
                                .frame(width: 8, height: 8)
                                .offset(x: 1, y: -1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(notification.title)
                                .font(.system(size: 14, weight: notification.isUnread ? .heavy : .bold))
                                .foregroundStyle(CHColors.ink)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Text(notification.relativeTimeText)
                                .font(CHTypography.micro)
                                .foregroundStyle(CHColors.muted)
                                .lineLimit(1)
                        }

                        if !notification.body.isEmpty {
                            Text(notification.body)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CHColors.muted)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }

                        HStack(spacing: 6) {
                            Text(notification.isUnread ? "Chưa đọc" : (isOpened ? "Đã mở" : "Đã đọc"))
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(notification.isUnread ? Color(hex: 0xFF4F67) : CHColors.muted)
                            Spacer(minLength: 0)
                            if NotificationActionResolver.destination(for: notification) != .passive {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(CHColors.muted)
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: CHRadius.large, style: .continuous)
                        .fill(notification.isUnread ? Color.white.opacity(0.64) : Color.clear)
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(notification.title)\(notification.isUnread ? ", chưa đọc" : ", đã đọc")")
        .accessibilityIdentifier(isLast ? "notification.row.last" : "notification.row.item")
    }
}
