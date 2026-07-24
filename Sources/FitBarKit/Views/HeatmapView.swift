import SwiftUI

/// GitHub-style activity heatmap: columns are weeks, rows are Mon...Sun.
struct HeatmapView: View {
    @EnvironmentObject private var store: AppStore
    let activity: ActivityLog
    var weeks: Int = 16
    var cell: CGFloat = 11
    var spacing: CGFloat = 3
    var showLegend: Bool = true
    var fillWidth: Bool = false
    var lang: String = "ru"

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // Monday
        return c
    }

    /// Dates arranged per week column; last column ends today.
    private func columns(weeks: Int) -> [[Date]] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // 0 = Monday ... 6 = Sunday
        let mondayOffset = (weekday - calendar.firstWeekday + 7) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -mondayOffset, to: today)
        else { return [] }

        return (0..<weeks).map { w in
            let weekStart = calendar.date(
                byAdding: .day, value: -7 * (weeks - 1 - w), to: thisMonday
            )!
            return (0..<7).compactMap { d in
                let day = calendar.date(byAdding: .day, value: d, to: weekStart)!
                return day <= today ? day : nil
            }
        }
    }

    static func color(level: Int) -> Color {
        if FitBarTheme.isMonochrome {
            switch level {
            case 0: return .white
            case 1: return Color(white: 0.78)
            case 2: return Color(white: 0.54)
            case 3: return Color(white: 0.30)
            default: return .black
            }
        }
        switch level {
        case 0: return FitBarTheme.faintFill(0.08)
        case 1: return FitBarTheme.semanticFill(.green, opacity: 0.35)
        case 2: return FitBarTheme.semanticFill(.green, opacity: 0.55)
        case 3: return FitBarTheme.semanticFill(.green, opacity: 0.78)
        default: return FitBarTheme.semantic(.green)
        }
    }

    var body: some View {
        let _ = store.appTheme
        if fillWidth {
            GeometryReader { proxy in
                let dynamicWeeks = max(
                    weeks,
                    Int((proxy.size.width + spacing) / max(1, cell + spacing))
                )
                content(columns: columns(weeks: dynamicWeeks))
            }
            .frame(height: heatmapHeight)
        } else {
            content(columns: columns(weeks: weeks))
        }
    }

    private var heatmapHeight: CGFloat {
        cell * 7 + spacing * 6 + 14 + (showLegend ? 23 : 0)
    }

    private func content(columns: [[Date]]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: spacing) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            let n = activity.count(on: day)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Self.color(level: ActivityLog.level(for: n)))
                                .frame(width: cell, height: cell)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .strokeBorder(FitBarTheme.isMonochrome ? Color.black : Color.clear,
                                                      lineWidth: FitBarTheme.isMonochrome ? 1 : 0)
                                )
                                .help("\(Self.dayLabel(day, lang: lang)): \(n)")
                        }
                    }
                }
            }
            monthLabels(columns: columns)
            if showLegend {
                HStack(spacing: 5) {
                    Text(legendLess)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(FitBarTheme.textMuted)
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Self.color(level: level))
                            .frame(width: 10, height: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(FitBarTheme.isMonochrome ? Color.black : Color.clear,
                                                  lineWidth: FitBarTheme.isMonochrome ? 1 : 0)
                            )
                    }
                    Text(legendMore)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(FitBarTheme.faintFill(0.035), in: Capsule())
            }
        }
    }

    private func monthLabels(columns: [[Date]]) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, week in
                let label = monthLabel(for: week, previous: index > 0 ? columns[index - 1] : [])
                Text(label)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(FitBarTheme.textFaint)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: cell, height: 11, alignment: .leading)
                    .help(monthHelp(for: week))
            }
        }
        .frame(height: 12, alignment: .topLeading)
    }

    private func monthLabel(for week: [Date], previous: [Date]) -> String {
        guard let first = week.first else { return "" }
        let month = calendar.component(.month, from: first)
        let previousMonth = previous.first.map { calendar.component(.month, from: $0) }
        guard previousMonth == nil || previousMonth != month else { return "" }
        return Self.shortMonth(month, lang: lang)
    }

    private func monthHelp(for week: [Date]) -> String {
        guard let first = week.first else { return "" }
        return Self.fullMonth(first, lang: lang)
    }

    private var legendLess: String {
        lang == "ru" ? "Меньше" : "Less"
    }

    private var legendMore: String {
        lang == "ru" ? "Больше" : "More"
    }

    private static func formatter(lang: String, dateFormat: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang == "ru" ? "ru_RU" : "en_US")
        f.dateFormat = dateFormat
        return f
    }

    static func dayLabel(_ date: Date, lang: String = "ru") -> String {
        formatter(lang: lang, dateFormat: "d MMMM").string(from: date)
    }

    private static func fullMonth(_ date: Date, lang: String) -> String {
        formatter(lang: lang, dateFormat: "LLLL").string(from: date)
    }

    private static func shortMonth(_ month: Int, lang: String) -> String {
        let ru = ["Янв", "Фев", "Мар", "Апр", "Май", "Июн",
                  "Июл", "Авг", "Сен", "Окт", "Ноя", "Дек"]
        let en = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard (1...12).contains(month) else { return "" }
        return (lang == "ru" ? ru : en)[month - 1]
    }
}
