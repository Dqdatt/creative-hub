import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    var isFiltersOpen: Bool
    var permissions: CalendarPermissions
    var openModule: (ModuleDestination) -> Void

    var body: some View {
        VStack(spacing: 10) {
            CalendarTimeNavigator(viewModel: viewModel)

            if isFiltersOpen {
                CalendarFilterRevealPanel(
                    isOpen: isFiltersOpen,
                    selected: $viewModel.filter
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            calendarContent
        }
        .overlay(alignment: .topLeading) {
            Text("calendar.root")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("calendar.root")
            Text(isFiltersOpen ? "open" : "closed")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("tool-reveal.state.calendar.\(isFiltersOpen ? "open" : "closed")")
        }
        .task {
            if case .idle = viewModel.loadState {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            CHStateView(kind: .loading, title: "Đang tải lịch quay...")
                .frame(minHeight: 420)
                .accessibilityIdentifier("calendar.loading")
        case .failed(let message, _):
            CHStateView(
                kind: .error,
                title: "Không thể tải lịch quay",
                message: message,
                actionTitle: "Thử lại",
                action: { Task { await viewModel.retry() } }
            )
            .frame(minHeight: 420)
            .accessibilityIdentifier("calendar.load-error")
        case .loaded:
            VStack(spacing: 9) {
                HStack(alignment: .center) {
                    Text(viewModel.periodTitle)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(CHColors.ink)
                    Spacer()
                    if permissions.canCreate {
                        Button {
                            viewModel.openCreate()
                            openModule(.shootCreate)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .heavy))
                                Text("Thêm lịch")
                            }
                        }
                        .buttonStyle(CalendarAddButtonStyle())
                        .accessibilityIdentifier("calendar.add")
                    }
                }
                .padding(.top, 1)

                if viewModel.visibleShoots.isEmpty {
                    if viewModel.monthHasShoots {
                        CalendarInlineEmpty(message: "Không có lịch phù hợp bộ lọc.")
                            .accessibilityIdentifier("calendar.filter-empty")
                    } else {
                        CalendarInlineEmpty(
                            message: permissions.canCreate
                                ? "\(viewModel.periodEmptyMessage) Bấm + Thêm lịch để tạo lịch mới."
                                : viewModel.periodEmptyMessage
                        )
                        .accessibilityIdentifier("calendar.month-empty")
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.visibleShoots) { shoot in
                            Button {
                                viewModel.open(shoot: shoot, canUpdate: permissions.canUpdate)
                                openModule(.shootEdit(id: shoot.id.uuidString))
                            } label: {
                                CalendarAgendaCard(shoot: shoot)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("calendar.agenda.\(shoot.id.uuidString)")
                        }
                    }
                    .accessibilityIdentifier("calendar.agenda-list")
                }
            }
        }
    }
}

struct CalendarPermissions: Equatable {
    var canCreate: Bool
    var canUpdate: Bool
    var canDelete: Bool
}

private struct CalendarTimeNavigator: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        CHTimeScopeNavigator(
            scope: viewModel.timeScope,
            monthLabel: viewModel.selectedMonthLabel,
            weekDays: viewModel.weekDays,
            accessibilityPrefix: "calendar",
            onPrevious: {
                Task {
                    if viewModel.timeScope == .month {
                        await viewModel.shiftMonth(-1)
                    } else {
                        await viewModel.shiftWeek(-1)
                    }
                }
            },
            onNext: {
                Task {
                    if viewModel.timeScope == .month {
                        await viewModel.shiftMonth(1)
                    } else {
                        await viewModel.shiftWeek(1)
                    }
                }
            },
            onSelectScope: { scope in
                Task { await viewModel.selectScope(scope) }
            },
            onSelectDay: { day in
                Task { await viewModel.selectDay(day) }
            }
        )
    }
}

private struct CalendarFilterRevealPanel: View {
    var isOpen: Bool
    @Binding var selected: CalendarShootFilter

    var body: some View {
        VStack(spacing: 0) {
            Text(isOpen ? "open" : "closed")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("tool-reveal.state.calendar.\(isOpen ? "open" : "closed")")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(CalendarShootFilter.allCases) { filter in
                        Button {
                            selected = filter
                        } label: {
                            HStack(spacing: 6) {
                                if let type = filter.type {
                                    Circle()
                                        .fill(type.tint)
                                        .frame(width: 7, height: 7)
                                }
                                Text(filter.label)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(selected == filter ? .white : CHColors.muted)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selected == filter ? AnyShapeStyle(CHColors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.74)))
                                    .overlay(Capsule().stroke(selected == filter ? Color.clear : CHColors.line, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("calendar.filter.\(filter.rawValue)")
                    }
                }
                .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.46))
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.52), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 10, y: 7)
            )
            .frame(maxHeight: isOpen ? nil : 0, alignment: .top)
            .opacity(isOpen ? 1 : 0)
            .offset(y: isOpen ? 0 : -7)
            .clipped()
            .allowsHitTesting(isOpen)
            .accessibilityHidden(!isOpen)
            .accessibilityIdentifier("calendar.filter-strip")
        }
        .padding(.bottom, isOpen ? 8 : 0)
        .animation(.timingCurve(0.2, 0.75, 0.25, 1, duration: 0.26), value: isOpen)
    }
}

private struct CalendarAgendaCard: View {
    var shoot: CalendarShoot

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 1) {
                Text(CalendarDateFormatter.weekdayLabel(from: shoot.date))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: 0x707B94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Text(String(CalendarDateFormatter.businessCalendar.component(.day, from: shoot.date)))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(CHColors.ink)
                Text(CalendarDateFormatter.monthLabel(from: shoot.date))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(CHColors.purple)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 58)
            .padding(.top, 2)
            .padding(.trailing, 8)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(CHColors.line)
                    .frame(width: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(shoot.content.isEmpty ? "Chưa có nội dung" : shoot.content)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CHColors.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                meta(systemName: "person.2.fill", text: shoot.displayCrew.isEmpty ? "Chưa có crew" : shoot.displayCrew)
                meta(systemName: "mappin.and.ellipse", text: shoot.place.isEmpty ? "Chưa có địa điểm" : shoot.place)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .minimumScaleFactor(0.9)

            VStack(alignment: .trailing, spacing: 7) {
                Text(shoot.type.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(shoot.type.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 9)
                    .frame(height: 27)
                    .background(Capsule(style: .continuous).fill(shoot.type.softBackground))
                Text(shoot.time.isEmpty ? "—" : shoot.time)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x78839A))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .frame(width: 82, alignment: .trailing)
            .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.84))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.76), lineWidth: 1))
                .shadow(color: CHShadow.softColor, radius: 13, y: 8)
        )
    }

    private func meta(systemName: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(CHColors.muted)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0x69758D))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

private struct CalendarInlineEmpty: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(CHColors.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.78))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.72), lineWidth: 1))
                    .shadow(color: CHShadow.softColor, radius: 12, y: 8)
            )
    }
}

private struct CalendarAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(CHColors.primaryGradient, in: Capsule(style: .continuous))
            .shadow(color: CHColors.purple.opacity(0.20), radius: 9, y: 7)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
