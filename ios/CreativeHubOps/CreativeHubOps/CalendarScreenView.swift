import SwiftUI

struct CalendarScreenView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var operations: OperationsViewModel
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 12) {
            monthControls

            DatePicker("Ngày", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .padding(10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 14, y: 2)
                .padding(.horizontal, AppSpacing.screen)

            stateContent
        }
        .padding(.top, 8)
        .onChange(of: selectedDate) { _, newValue in
            let monthValue = AppDateFormatter.monthValue(from: newValue)
            if monthValue != operations.monthRange.value {
                Task { await operations.loadMonth(containing: newValue) }
            }
        }
    }

    private var monthControls: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await operations.moveMonth(by: -1)
                    selectedDate = dateFromISO(operations.monthRange.startDate)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Tháng trước")

            Spacer()

            Text("Tháng \(operations.monthRange.value)")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(AppColors.text)

            Spacer()

            Button {
                Task {
                    await operations.moveMonth(by: 1)
                    selectedDate = dateFromISO(operations.monthRange.startDate)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Tháng sau")
        }
        .padding(.horizontal, AppSpacing.screen)
    }

    private var selectedISODate: String {
        AppDateFormatter.isoDate(from: selectedDate)
    }

    private func dateFromISO(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) ?? Date()
    }

    private var shootsForSelectedDate: [ShootSchedule] {
        operations.shoots.filter { $0.date == selectedISODate }
    }

    @ViewBuilder
    private var stateContent: some View {
        if operations.isLoading {
            AppCard {
                LoadingStateView(message: "Đang tải lịch quay...")
            }
            .padding(.horizontal, AppSpacing.screen)
        } else if let error = operations.errorMessage {
            ErrorStateView(title: "Không thể tải lịch quay", message: error) {
                Task { await operations.refresh() }
            }
            .padding(.horizontal, AppSpacing.screen)
        } else if shootsForSelectedDate.isEmpty {
            AppCard {
                EmptyStateView(title: "Không có lịch quay", message: "Ngày đã chọn chưa có buổi quay hoặc livestream.")
            }
            .padding(.horizontal, AppSpacing.screen)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(shootsForSelectedDate) { shoot in
                    Button {
                        operations.selectedShoot = shoot
                        appState.path.append(.shootDetail(shoot.id))
                    } label: {
                        shootRow(shoot)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
        }
    }

    private func shootRow(_ shoot: ShootSchedule) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: shoot.type == "livestream" ? "dot.radiowaves.left.and.right" : "video")
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 38, height: 38)
                    .background(AppColors.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(shoot.typeLabel)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(AppColors.accent)
                        Spacer()
                        Text(shoot.timeSlot.isEmpty ? "—" : shoot.timeSlot)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Text(shoot.location.isEmpty ? "Chưa có địa điểm" : shoot.location)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppColors.text)

                    Text(shoot.crew.isEmpty ? "Chưa phân công crew" : shoot.crew)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)

                    if !shoot.note.isEmpty {
                        Text(shoot.note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.75))
                            .lineLimit(3)
                    }
                }
            }
        }
    }
}
