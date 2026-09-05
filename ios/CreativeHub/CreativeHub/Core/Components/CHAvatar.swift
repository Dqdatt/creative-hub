import SwiftUI

struct CHAvatar: View {
    var initials: String = "CH"
    var imageName: String?
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: max(9, size * 0.32), weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CHColors.primaryGradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(CHColors.purple.opacity(0.45), lineWidth: max(1, size * 0.04)))
        .shadow(color: Color(red: 76 / 255, green: 55 / 255, blue: 189 / 255).opacity(0.15), radius: 8, y: 5)
    }
}
