#if DEBUG
import Foundation

extension OverviewRawData {
    static func phase4VisualFixture(month: OverviewMonth) -> OverviewRawData {
        let editors = [
            OverviewEditorRow(id: "editor-hai", editorCode: "hai", name: "Nguyễn Thanh Hải", shortName: "Thanh Hải", initials: "H", avatarURL: nil, colorHex: "#22C55E"),
            OverviewEditorRow(id: "editor-minh", editorCode: "minh", name: "Hoàng Hữu Lê Minh", shortName: "Hữu Minh", initials: "M", avatarURL: nil, colorHex: "#F59E0B"),
            OverviewEditorRow(id: "editor-dat", editorCode: "dat", name: "Đoàn Quốc Đạt", shortName: "Đạt Đoàn", initials: "Đ", avatarURL: nil, colorHex: "#0EA5E9")
        ]

        let orderTeams = ["DIGITAL", "BRAND", "ECOM"]
        let editorCodes = ["hai", "minh", "dat"]
        let categoryCycle = ["Video dài", "Motion", "Ads"]
        let completedDays = [1, 3, 5, 8, 8, 10, 12, 15, 15, 16, 18, 19, 20, 21, 22, 24, 25, 27, 28, 30, min(31, month.daysInMonth)]

        let tasks = (1...43).map { index in
            let day = min(((index - 1) % month.daysInMonth) + 1, month.daysInMonth)
            let isCompleted = index <= completedDays.count
            let airDay = isCompleted ? completedDays[index - 1] : day
            return OverviewTaskRow(
                id: "task-\(index)",
                title: "QA video \(index)",
                orderTeam: orderTeams[index % orderTeams.count],
                category: categoryCycle[index % categoryCycle.count],
                status: isCompleted ? OverviewAggregator.completedStatus : (index % 2 == 0 ? "Đang làm" : "Chờ"),
                resizeRequirements: index % 4 == 0 ? "9x16 & 1x1" : "",
                receiveDate: iso(month: month, day: max(1, airDay - 2)),
                returnDate: iso(month: month, day: max(1, airDay - 1)),
                airDate: iso(month: month, day: airDay),
                linkedAirDate: nil,
                resultLink: isCompleted ? "https://example.test/video-\(index)" : "",
                editorCode: editorCodes[index % editorCodes.count],
                editorProfileID: "editor-\(editorCodes[index % editorCodes.count])"
            )
        }

        let shoots = (1...21).map { index in
            let day = min(((index * 2) % month.daysInMonth) + 1, month.daysInMonth)
            let editorCode = editorCodes[index % editorCodes.count]
            return OverviewShootRow(
                id: "shoot-\(index)",
                shootDate: iso(month: month, day: day),
                type: index % 7 == 0 ? "onset" : "lichquay",
                editorCodes: [editorCode],
                editorProfileIDs: ["editor-\(editorCode)"]
            )
        }

        return OverviewRawData(tasks: tasks, shoots: shoots, editors: editors)
    }

    private static func iso(month: OverviewMonth, day: Int) -> String {
        "\(month.year)-\(String(format: "%02d", month.month))-\(String(format: "%02d", min(max(1, day), month.daysInMonth)))"
    }
}
#endif
