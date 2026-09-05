import Foundation

enum OverviewAggregator {
    static let completedStatus = "Đã xong"
    static let orderTeamPriority = ["BRAND", "DIGITAL", "ECOM", "HR", "ISD", "IT", "CS", "GT", "PUR"]

    static func aggregate(rawData: OverviewRawData, month: OverviewMonth) -> OverviewDashboard {
        let monthTasks = rawData.tasks.filter { isTaskInDashboardMonth($0, month: month) }
        let countedShoots = rawData.shoots
            .filter { isISODateInMonth($0.shootDate, month: month) }
            .filter { $0.type != "livestream" }
        let completedTasks = monthTasks.filter { $0.status == completedStatus }

        let teamOrders = makeTeamOrders(from: monthTasks)
        let editorWorkload = makeEditorWorkload(
            editors: rawData.editors,
            tasks: monthTasks,
            shoots: countedShoots,
            month: month
        )
        let chartPoints = makeChartPoints(tasks: completedTasks, month: month)

        return OverviewDashboard(
            month: month,
            totalVideos: monthTasks.count,
            completedVideos: completedTasks.count,
            shootCount: countedShoots.count,
            teamOrders: teamOrders,
            editorWorkload: editorWorkload,
            chartPoints: chartPoints,
            shootLoadTrack: .neutral
        )
    }

    static func isTaskInDashboardMonth(_ task: OverviewTaskRow, month: OverviewMonth) -> Bool {
        guard let airDate = task.effectiveAirDate else { return false }
        return isISODateInMonth(airDate, month: month)
    }

    static func isISODateInMonth(_ value: String?, month: OverviewMonth) -> Bool {
        guard let value else { return false }
        return value >= month.startISODate && value <= month.endISODate
    }

    static func makeTeamOrders(from tasks: [OverviewTaskRow]) -> [OverviewTeamOrder] {
        let counts = Dictionary(grouping: tasks.compactMap { $0.orderTeam.nonEmpty?.uppercased() }, by: { $0 })
            .mapValues(\.count)

        let sortedLabels = counts.keys.sorted { lhs, rhs in
            if counts[lhs, default: 0] != counts[rhs, default: 0] {
                return counts[lhs, default: 0] > counts[rhs, default: 0]
            }
            let lhsIndex = orderTeamPriority.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = orderTeamPriority.firstIndex(of: rhs) ?? Int.max
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs < rhs
        }

        return sortedLabels.map { OverviewTeamOrder(label: $0, count: counts[$0, default: 0]) }
    }

    static func makeEditorWorkload(
        editors: [OverviewEditorRow],
        tasks: [OverviewTaskRow],
        shoots: [OverviewShootRow],
        month: OverviewMonth
    ) -> [OverviewEditorWorkload] {
        var knownEditors = Dictionary(uniqueKeysWithValues: editors.map { ($0.editorCode.lowercased(), $0) })

        tasks
            .filter { !$0.editorCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .forEach { task in
                let key = task.editorCode.lowercased()
                if knownEditors[key] == nil {
                    knownEditors[key] = OverviewEditorRow(
                        id: task.editorProfileID ?? key,
                        editorCode: key,
                        name: task.editorCode.uppercased(),
                        shortName: task.editorCode.uppercased(),
                        initials: String(task.editorCode.prefix(1)).uppercased(),
                        avatarURL: nil,
                        colorHex: fallbackColor(seed: key)
                    )
                }
            }

        shoots.flatMap(\.editorCodes)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .forEach { code in
                let key = code.lowercased()
                if knownEditors[key] == nil {
                    knownEditors[key] = OverviewEditorRow(
                        id: key,
                        editorCode: key,
                        name: key.uppercased(),
                        shortName: key.uppercased(),
                        initials: String(key.prefix(1)).uppercased(),
                        avatarURL: nil,
                        colorHex: fallbackColor(seed: key)
                    )
                }
            }

        return knownEditors.values
            .map { editor in
                let key = editor.editorCode.lowercased()
                let profileKey = editor.id.lowercased()
                let editorTasks = tasks.filter { $0.editorCode.lowercased() == key || ($0.editorProfileID?.lowercased() == profileKey) }
                let editorShoots = shoots.filter { shoot in
                    shoot.editorCodes.map { $0.lowercased() }.contains(key) ||
                    shoot.editorProfileIDs.map { $0.lowercased() }.contains(profileKey)
                }
                let buckets = makeWorkloadBuckets(tasks: editorTasks, shoots: editorShoots, month: month)
                let taskCount = editorTasks.count + editorShoots.count
                return OverviewEditorWorkload(
                    id: editor.id,
                    name: editor.name,
                    shortName: editor.shortName,
                    initials: editor.initials,
                    avatarURL: editor.avatarURL,
                    colorHex: editor.colorHex,
                    taskCount: taskCount,
                    buckets: buckets
                )
            }
            .filter { $0.taskCount > 0 }
            .sorted {
                if $0.taskCount != $1.taskCount { return $0.taskCount > $1.taskCount }
                return $0.shortName.localizedCompare($1.shortName) == .orderedAscending
            }
    }

    static func makeWorkloadBuckets(tasks: [OverviewTaskRow], shoots: [OverviewShootRow], month: OverviewMonth) -> [Int] {
        var buckets = Array(repeating: 0, count: 5)
        let monthDays = max(1, month.daysInMonth)

        func add(dateValue: String?) {
            guard let dateValue, let day = OverviewMonth.displayDateToDay(dateValue) else { return }
            let clampedDay = min(max(day, 1), monthDays)
            let index = min(4, Int(Double(clampedDay - 1) / Double(monthDays) * 5.0))
            buckets[index] += 1
        }

        tasks.forEach { add(dateValue: $0.effectiveAirDate) }
        shoots.forEach { add(dateValue: $0.shootDate) }
        return buckets
    }

    static func makeChartPoints(tasks: [OverviewTaskRow], month: OverviewMonth) -> [OverviewChartPoint] {
        var completionsByDay = Array(repeating: 0, count: month.daysInMonth + 1)
        for task in tasks {
            guard let date = task.effectiveAirDate, let day = OverviewMonth.displayDateToDay(date), day >= 1, day <= month.daysInMonth else {
                continue
            }
            completionsByDay[day] += 1
        }

        var runningTotal = 0
        return (1...month.daysInMonth).map { day in
            runningTotal += completionsByDay[day]
            return OverviewChartPoint(day: day, value: runningTotal)
        }
    }

    static func fallbackColor(seed: String) -> String {
        let palette = ["#0EA5E9", "#22C55E", "#F59E0B", "#EF4444", "#14B8A6", "#8B5CF6", "#EC4899"]
        let index = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count
        return palette[index]
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
