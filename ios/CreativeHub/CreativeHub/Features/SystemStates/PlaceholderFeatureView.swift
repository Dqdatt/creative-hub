import SwiftUI

struct PlaceholderFeatureView: View {
    var title: String
    var subtitle: String
    var iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CHCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(CHColors.purple.opacity(0.10))
                                .frame(width: 44, height: 44)
                            Image(systemName: iconName)
                                .foregroundStyle(CHColors.purple)
                                .font(.system(size: 20, weight: .bold))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(CHTypography.headline)
                                .foregroundStyle(CHColors.ink)
                            Text(subtitle)
                                .font(CHTypography.caption)
                                .foregroundStyle(CHColors.muted)
                        }
                    }

                    RoundedRectangle(cornerRadius: 999)
                        .fill(CHColors.line)
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999)
                                .fill(CHColors.primaryGradient)
                                .frame(width: 148)
                        }
                }
                .padding(16)
            }

            CHStateView(kind: .empty, title: "Chưa có dữ liệu", message: "Nội dung thật chưa được triển khai trong Phase 1.")
                .frame(height: 240)
                .background(
                    RoundedRectangle(cornerRadius: CHRadius.large, style: .continuous)
                        .fill(CHColors.card.opacity(0.55))
                )
        }
    }
}
