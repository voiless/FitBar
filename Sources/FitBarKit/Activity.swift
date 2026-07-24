import Foundation

// MARK: - Activity log (GitHub-style)

public struct ActivityLog: Codable, Equatable {
    /// "yyyy-MM-dd" -> number of exercise completions that day
    public var days: [String: Int] = [:]
    /// exercise id -> total completions ever
    public var perExercise: [String: Int] = [:]
    /// Detailed history: one row per finished set.
    public var sets: [ExerciseSetLog] = []
    /// "yyyy-MM-dd" -> water consumed that day in milliliters.
    public var waterML: [String: Int] = [:]

    public init() {}

    enum CodingKeys: String, CodingKey {
        case days, perExercise, sets, waterML
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = (try? c.decode([String: Int].self, forKey: .days)) ?? [:]
        perExercise = (try? c.decode([String: Int].self, forKey: .perExercise)) ?? [:]
        sets = (try? c.decode([ExerciseSetLog].self, forKey: .sets)) ?? []
        waterML = (try? c.decode([String: Int].self, forKey: .waterML)) ?? [:]
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public mutating func logCompletion(exerciseID: String, on date: Date = Date()) {
        let key = Self.dayKey(date)
        days[key, default: 0] += 1
        perExercise[exerciseID, default: 0] += 1
    }

    public mutating func logSet(
        exerciseID: String, reps: Int, durationSeconds: Int, on date: Date = Date()
    ) {
        let cleanReps = max(0, reps)
        let cleanDuration = max(0, durationSeconds)
        sets.append(ExerciseSetLog(
            exerciseID: exerciseID,
            date: date,
            reps: cleanReps,
            durationSeconds: cleanDuration
        ))
        logCompletion(exerciseID: exerciseID, on: date)
    }

    public func count(on date: Date = Date()) -> Int {
        days[Self.dayKey(date)] ?? 0
    }

    public mutating func addWater(_ ml: Int, on date: Date = Date()) {
        waterML[Self.dayKey(date), default: 0] += max(0, ml)
    }

    public func water(on date: Date = Date()) -> Int {
        waterML[Self.dayKey(date)] ?? 0
    }

    /// (exerciseID, count) with the highest all-time completion count.
    public func recordExercise() -> (id: String, count: Int)? {
        guard let best = perExercise.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })
        else { return nil }
        return (best.key, best.value)
    }

    public var totalCompletions: Int { days.values.reduce(0, +) }

    public var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }

    public var totalDurationSeconds: Int {
        sets.reduce(0) { $0 + $1.durationSeconds }
    }

    public func maxRepsSet() -> ExerciseSetLog? {
        sets.max {
            if $0.reps == $1.reps {
                return $0.date < $1.date
            }
            return $0.reps < $1.reps
        }
    }

    public func stats(for exerciseID: String) -> ExerciseActivityStats {
        let rows = sets.filter { $0.exerciseID == exerciseID }
        return ExerciseActivityStats(exerciseID: exerciseID, sets: rows)
    }

    public func stats(
        for exerciseID: String,
        on date: Date,
        calendar: Calendar = .current
    ) -> ExerciseActivityStats {
        let rows = sets.filter {
            $0.exerciseID == exerciseID && calendar.isDate($0.date, inSameDayAs: date)
        }
        return ExerciseActivityStats(exerciseID: exerciseID, sets: rows)
    }

    public func allExerciseStats() -> [ExerciseActivityStats] {
        Dictionary(grouping: sets, by: \.exerciseID)
            .map { ExerciseActivityStats(exerciseID: $0.key, sets: $0.value) }
            .sorted {
                if $0.totalReps != $1.totalReps {
                    return $0.totalReps > $1.totalReps
                }
                if $0.setCount != $1.setCount {
                    return $0.setCount > $1.setCount
                }
                return $0.exerciseID < $1.exerciseID
            }
    }

    /// Consecutive days ending today (or yesterday if today is empty) with activity.
    public func streak(today: Date = Date(), calendar: Calendar = .current) -> Int {
        var day = today
        if count(on: day) == 0 {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = prev
        }
        var run = 0
        while count(on: day) > 0 {
            run += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return run
    }

    /// Training-plan streak based on the selected weekly frequency.
    /// For 7 sessions/week it is a strict daily streak. For 1...6 it counts
    /// consecutive 7-day training windows ending at the current one: the
    /// current (still incomplete) window earns a flame as soon as it has any
    /// workout, every earlier window must reach the required number of
    /// training days. A failed week breaks the run but the streak restarts
    /// with the next workout — it is not lost forever.
    public func trainingPlanStreak(
        requiredDaysPerWeek: Int, today: Date = Date(), calendar: Calendar = .current
    ) -> Int {
        let required = min(max(requiredDaysPerWeek, 1), 7)
        if required >= 7 {
            return streak(today: today, calendar: calendar)
        }
        let activeKeys = Set(days.filter { $0.value > 0 }.map(\.key))
        guard !activeKeys.isEmpty else { return 0 }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let activeDays = Set(
            activeKeys.compactMap { formatter.date(from: $0) }
                .map { calendar.startOfDay(for: $0) })
        guard let first = activeDays.min() else { return 0 }
        let start = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: today)
        guard end >= start else { return 0 }
        let elapsedDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let currentWindow = elapsedDays / 7

        func activeCount(inWindow window: Int) -> Int {
            guard let windowStart = calendar.date(byAdding: .day, value: window * 7,
                                                  to: start),
                  let windowEnd = calendar.date(byAdding: .day, value: 6, to: windowStart)
            else { return 0 }
            return activeDays.filter { $0 >= windowStart && $0 <= windowEnd }.count
        }

        var streakWindows = 0
        if activeCount(inWindow: currentWindow) > 0 {
            streakWindows += 1
        }
        var window = currentWindow - 1
        while window >= 0, activeCount(inWindow: window) >= required {
            streakWindows += 1
            window -= 1
        }
        return streakWindows
    }

    /// Bucket a day count into 0...4 intensity levels (like GitHub).
    public static func level(for count: Int) -> Int {
        switch count {
        case ..<1: return 0
        case 1...2: return 1
        case 3...5: return 2
        case 6...9: return 3
        default: return 4
        }
    }
}

public struct ExerciseSetLog: Codable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var exerciseID: String
    public var date: Date
    public var reps: Int
    public var durationSeconds: Int

    public init(
        id: UUID = UUID(), exerciseID: String, date: Date = Date(),
        reps: Int, durationSeconds: Int
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.date = date
        self.reps = reps
        self.durationSeconds = durationSeconds
    }
}

public struct ExerciseActivityStats: Equatable, Identifiable {
    public var id: String { exerciseID }
    public let exerciseID: String
    public let setCount: Int
    public let totalReps: Int
    public let totalDurationSeconds: Int
    public let maxReps: Int
    public let lastDate: Date?

    public init(exerciseID: String, sets: [ExerciseSetLog]) {
        self.exerciseID = exerciseID
        setCount = sets.count
        totalReps = sets.reduce(0) { $0 + $1.reps }
        totalDurationSeconds = sets.reduce(0) { $0 + $1.durationSeconds }
        maxReps = sets.map(\.reps).max() ?? 0
        lastDate = sets.map(\.date).max()
    }
}

// MARK: - Goal diary

public struct DiaryEntry: Codable, Equatable, Identifiable {
    public var id: String { dateKey }
    public var dateKey: String
    public var date: Date
    public var dayNumber: Int
    public var exerciseNotes: String
    public var exerciseSets: Int
    public var exerciseReps: Int
    public var exerciseMinutes: Int
    public var waterML: Int
    public var calories: Int
    public var proteinG: Int
    public var fatG: Int
    public var carbsG: Int
    public var isRestDay: Bool
    public var thoughts: String
    public var isMissed: Bool
    public var isSaved: Bool

    private enum CodingKeys: String, CodingKey {
        case dateKey, date, dayNumber, exerciseNotes, exerciseSets, exerciseReps
        case exerciseMinutes, waterML, calories, proteinG, fatG, carbsG
        case isRestDay, thoughts, isMissed, isSaved
    }

    public init(
        dateKey: String,
        date: Date,
        dayNumber: Int,
        exerciseNotes: String = "",
        exerciseSets: Int = 0,
        exerciseReps: Int = 0,
        exerciseMinutes: Int = 0,
        waterML: Int = 0,
        calories: Int = 0,
        proteinG: Int = 0,
        fatG: Int = 0,
        carbsG: Int = 0,
        isRestDay: Bool = false,
        thoughts: String = "",
        isMissed: Bool = false,
        isSaved: Bool = false
    ) {
        self.dateKey = dateKey
        self.date = date
        self.dayNumber = dayNumber
        self.exerciseNotes = exerciseNotes
        self.exerciseSets = exerciseSets
        self.exerciseReps = exerciseReps
        self.exerciseMinutes = exerciseMinutes
        self.waterML = waterML
        self.calories = calories
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.isRestDay = isRestDay
        self.thoughts = thoughts
        self.isMissed = isMissed
        self.isSaved = isSaved
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = (try? c.decode(String.self, forKey: .dateKey)) ?? ""
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        dayNumber = (try? c.decode(Int.self, forKey: .dayNumber)) ?? 1
        exerciseNotes = (try? c.decode(String.self, forKey: .exerciseNotes)) ?? ""
        exerciseSets = (try? c.decode(Int.self, forKey: .exerciseSets)) ?? 0
        exerciseReps = (try? c.decode(Int.self, forKey: .exerciseReps)) ?? 0
        exerciseMinutes = (try? c.decode(Int.self, forKey: .exerciseMinutes)) ?? 0
        waterML = (try? c.decode(Int.self, forKey: .waterML)) ?? 0
        calories = (try? c.decode(Int.self, forKey: .calories)) ?? 0
        proteinG = (try? c.decode(Int.self, forKey: .proteinG)) ?? 0
        fatG = (try? c.decode(Int.self, forKey: .fatG)) ?? 0
        carbsG = (try? c.decode(Int.self, forKey: .carbsG)) ?? 0
        isRestDay = (try? c.decode(Bool.self, forKey: .isRestDay)) ?? false
        thoughts = (try? c.decode(String.self, forKey: .thoughts)) ?? ""
        isMissed = (try? c.decode(Bool.self, forKey: .isMissed)) ?? false
        isSaved = (try? c.decode(Bool.self, forKey: .isSaved)) ?? false
    }

    public var hasMeaningfulData: Bool {
        isRestDay
            || !exerciseNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || exerciseSets > 0
            || exerciseReps > 0
            || exerciseMinutes > 0
            || waterML > 0
            || calories > 0
            || proteinG > 0
            || fatG > 0
            || carbsG > 0
            || !thoughts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public mutating func prefill(from activity: ActivityLog, calendar: Calendar = .current) {
        guard !isMissed else { return }
        let setRows = activity.sets.filter { calendar.isDate($0.date, inSameDayAs: date) }
        exerciseSets = setRows.isEmpty ? activity.count(on: date) : setRows.count
        exerciseReps = setRows.reduce(0) { $0 + $1.reps }
        let seconds = setRows.reduce(0) { $0 + $1.durationSeconds }
        exerciseMinutes = seconds > 0 ? Int(ceil(Double(seconds) / 60.0)) : 0
        waterML = activity.water(on: date)
    }
}

public struct DiaryState: Codable, Equatable {
    public var isActive: Bool
    public var startedAt: Date
    public var originalDays: Int
    public var extraDays: Int
    public var trainingDaysPerWeek: Int
    public var goalText: String
    public var entries: [String: DiaryEntry]

    public init(
        isActive: Bool = false,
        startedAt: Date = Date(),
        originalDays: Int = 30,
        extraDays: Int = 0,
        trainingDaysPerWeek: Int = 3,
        goalText: String = "",
        entries: [String: DiaryEntry] = [:]
    ) {
        self.isActive = isActive
        self.startedAt = startedAt
        self.originalDays = max(1, originalDays)
        self.extraDays = max(0, extraDays)
        self.trainingDaysPerWeek = min(max(trainingDaysPerWeek, 1), 7)
        self.goalText = goalText
        self.entries = entries
    }

    public var totalDays: Int { max(1, originalDays + extraDays) }

    public func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: startedAt)
        let day = calendar.startOfDay(for: date)
        return max(1, (calendar.dateComponents([.day], from: start, to: day).day ?? 0) + 1)
    }

    public func targetDate(calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: startedAt)
        return calendar.date(byAdding: .day, value: totalDays - 1, to: start) ?? start
    }

    public func daysLeft(today: Date = Date(), calendar: Calendar = .current) -> Int {
        let target = calendar.startOfDay(for: targetDate(calendar: calendar))
        let current = calendar.startOfDay(for: today)
        return max(0, calendar.dateComponents([.day], from: current, to: target).day ?? 0)
    }

    public func sortedEntries() -> [DiaryEntry] {
        entries.values.sorted {
            if $0.date == $1.date { return $0.dateKey < $1.dateKey }
            return $0.date < $1.date
        }
    }

    public func isReadOnly(_ entry: DiaryEntry, today: Date = Date(),
                           calendar: Calendar = .current) -> Bool {
        !calendar.isDate(entry.date, inSameDayAs: today)
    }

    public mutating func refresh(using activity: ActivityLog, today: Date = Date(),
                                 calendar: Calendar = .current) {
        guard isActive else { return }
        let start = calendar.startOfDay(for: startedAt)
        let current = calendar.startOfDay(for: today)
        guard current >= start else { return }

        var day = start
        while day <= current {
            let key = ActivityLog.dayKey(day, calendar: calendar)
            let number = dayNumber(for: day, calendar: calendar)
            var entry = entries[key] ?? DiaryEntry(dateKey: key, date: day, dayNumber: number)
            entry.date = day
            entry.dayNumber = number
            if calendar.isDate(day, inSameDayAs: current) {
                entry.prefill(from: activity, calendar: calendar)
            } else if !entry.hasMeaningfulData && !entry.isMissed {
                entry.isMissed = true
                extraDays += 1
            }
            entries[key] = entry
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
    }

    public mutating func save(_ entry: DiaryEntry) {
        var saved = entry
        saved.isSaved = true
        saved.isMissed = false
        entries[saved.dateKey] = saved
    }
}

// MARK: - Persisted app state

public struct WorkoutExerciseSettings: Codable, Equatable, Hashable {
    public var exerciseID: String
    public var sets: Int
    public var reps: String
    public var note: String

    public init(exerciseID: String, sets: Int = 0, reps: String = "0", note: String = "") {
        self.exerciseID = exerciseID
        self.sets = sets
        self.reps = reps
        self.note = note
    }
}

public struct WorkoutBlock: Codable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var exerciseIDs: [String]
    public var settings: [WorkoutExerciseSettings]

    enum CodingKeys: String, CodingKey {
        case id, title, exerciseIDs, settings
    }

    public init(
        id: UUID = UUID(), title: String, exerciseIDs: [String] = [],
        settings: [WorkoutExerciseSettings] = []
    ) {
        self.id = id
        self.title = title
        self.exerciseIDs = exerciseIDs
        self.settings = settings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        exerciseIDs = (try? c.decode([String].self, forKey: .exerciseIDs)) ?? []
        settings = (try? c.decode([WorkoutExerciseSettings].self, forKey: .settings)) ?? []
        for exerciseID in exerciseIDs where !settings.contains(where: { $0.exerciseID == exerciseID }) {
            settings.append(WorkoutExerciseSettings(exerciseID: exerciseID))
        }
    }
}

public struct WorkoutState: Codable, Equatable {
    /// Ordered exercise ids in "my list"
    public var exerciseIDs: [String] = []
    /// Index of the exercise currently shown in the menu bar
    public var currentIndex: Int = 0
    /// User-defined workout assemblies shown in Goals → Manual.
    public var blocks: [WorkoutBlock] = []
    /// Selected workout assembly for the menu bar. Nil means all exercises.
    public var selectedBlockID: UUID? = nil

    public init() {}

    enum CodingKeys: String, CodingKey {
        case exerciseIDs, currentIndex, blocks, selectedBlockID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exerciseIDs = (try? c.decode([String].self, forKey: .exerciseIDs)) ?? []
        currentIndex = (try? c.decode(Int.self, forKey: .currentIndex)) ?? 0
        blocks = (try? c.decode([WorkoutBlock].self, forKey: .blocks)) ?? []
        selectedBlockID = try? c.decode(UUID.self, forKey: .selectedBlockID)
        clampIndex()
    }

    public mutating func clampIndex() {
        if exerciseIDs.isEmpty { currentIndex = 0 }
        else { currentIndex = min(max(0, currentIndex), exerciseIDs.count - 1) }
    }
}

// MARK: - Disk persistence

public struct Persistence {
    public let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )[0]
            self.directory = base.appendingPathComponent("FitBar", isDirectory: true)
        }
    }

    private func url(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    public func save<T: Encodable>(_ value: T, as name: String) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: url(name), options: .atomic)
        } catch {
            NSLog("FitBar: failed to save \(name): \(error)")
        }
    }

    public func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    public func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }
}
