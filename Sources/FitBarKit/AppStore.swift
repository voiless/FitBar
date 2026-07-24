import Foundation
import CryptoKit
import SwiftUI
import AppKit

public enum GroqKeyValidationState: Equatable, Sendable {
    case missing
    case unchecked
    case checking
    case valid
    case invalid
    case unavailable(String)
}

public struct GroqModelInfo: Codable, Equatable, Identifiable, Hashable {
    public var id: String
    public var ownedBy: String
    public var created: Int?
    public var contextWindow: Int?
    public var isFallback: Bool

    public init(
        id: String,
        ownedBy: String = "Groq",
        created: Int? = nil,
        contextWindow: Int? = nil,
        isFallback: Bool = false
    ) {
        self.id = id
        self.ownedBy = ownedBy
        self.created = created
        self.contextWindow = contextWindow
        self.isFallback = isFallback
    }

    private enum CodingKeys: String, CodingKey {
        case id, created
        case ownedBy = "owned_by"
        case contextWindow = "context_window"
        case isFallback
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        ownedBy = (try? c.decode(String.self, forKey: .ownedBy)) ?? "Groq"
        created = try? c.decode(Int.self, forKey: .created)
        contextWindow = try? c.decode(Int.self, forKey: .contextWindow)
        isFallback = (try? c.decode(Bool.self, forKey: .isFallback)) ?? false
    }

    public var displayName: String {
        id.split(separator: "/").last.map(String.init) ?? id
    }

    public var powerScore: Int {
        var score = largestParameterBillions * 1_000
        let lower = id.lowercased()
        if lower.contains("120b") { score += 120_000 }
        if lower.contains("70b") { score += 70_000 }
        if lower.contains("maverick") { score += 45_000 }
        if lower.contains("reason") || lower.contains("r1") { score += 20_000 }
        if lower.contains("vision") || lower.contains("scout") { score += 8_000 }
        if lower.contains("instant") { score -= 5_000 }
        return score
    }

    public var parameterSummary: String {
        let billions = largestParameterBillions
        guard billions > 0 else { return id }
        return "\(billions)B"
    }

    private var largestParameterBillions: Int {
        let lower = id.lowercased()
        let parts = lower.split { !$0.isNumber && $0 != "." }
        var best = 0
        for part in parts {
            guard lower.contains("\(part)b"),
                  let value = Double(part)
            else { continue }
            best = max(best, Int(value.rounded()))
        }
        return best
    }
}

public struct GroqModelUsage: Codable, Equatable {
    public var requestCount: Int
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int
    public var lastUsedAt: Date?
    public var lastRateLimitMessage: String?

    public init(
        requestCount: Int = 0,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        totalTokens: Int = 0,
        lastUsedAt: Date? = nil,
        lastRateLimitMessage: String? = nil
    ) {
        self.requestCount = requestCount
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.lastUsedAt = lastUsedAt
        self.lastRateLimitMessage = lastRateLimitMessage
    }

    mutating func record(_ usage: GroqUsage?) {
        requestCount += 1
        promptTokens += usage?.promptTokens ?? 0
        completionTokens += usage?.completionTokens ?? 0
        totalTokens += usage?.totalTokens ?? 0
        lastUsedAt = Date()
    }
}

@MainActor
public final class AppStore: ObservableObject {
    // Data
    @Published public private(set) var exercises: [Exercise] = []
    public private(set) var byID: [String: Exercise] = [:]

    // Browser state
    @Published public var searchText = ""
    @Published public var selectedCategory: String? = nil
    @Published public var selectedEquipment: String? = nil
    @Published public var selectedTarget: String? = nil
    @Published public var sortOrder: SortOrder = .name
    // Workout list + activity (persisted)
    @Published public private(set) var workout = WorkoutState()
    @Published public private(set) var activity = ActivityLog()
    @Published public private(set) var diary = DiaryState()

    // Account
    @Published public var profile = UserProfile() {
        didSet { persistence.save(profile, as: "profile.json") }
    }
    @Published public private(set) var groqAPIKey = ""
    @Published public private(set) var groqKeyValidationState: GroqKeyValidationState = .missing
    @Published public private(set) var groqModels: [GroqModelInfo] = []
    @Published public private(set) var selectedGroqModelID = ""
    @Published public private(set) var groqModelsUpdatedAt: Date?
    @Published public private(set) var groqModelsLoading = false
    @Published public private(set) var groqModelsError: String?
    @Published public private(set) var groqModelUsage: [String: GroqModelUsage] = [:]

    // Menu bar timer
    @Published public var timerDuration: TimeInterval = 45
    @Published public var timerEndDate: Date? = nil
    @Published public var timerPausedRemaining: TimeInterval? = nil

    // Set-based workout flow
    @Published public var runPhase: WorkoutRunPhase = .idle
    @Published public var countdownEndDate: Date? = nil
    @Published public var setStartedAt: Date? = nil
    @Published public var pendingSetDurationSeconds = 0
    @Published public var pendingReps = 10

    // Goals & nutrition plan
    @Published public var goal = UserGoal() {
        didSet { persistence.save(goal, as: "goal.json") }
    }
    @Published public private(set) var plan: SavedPlan?
    @Published public private(set) var planLoading = false
    @Published public private(set) var planError: String?

    // App language ("ru"/"en")
    @Published public var appLanguage = "ru" {
        didSet {
            saveSettings()
        }
    }

    @Published public var appTheme: AppColorTheme = .dark {
        willSet {
            FitBarTheme.currentMode = newValue
        }
        didSet {
            saveSettings()
        }
    }

    nonisolated public static let groqTextModel = "openai/gpt-oss-20b"
    nonisolated public static let groqStrongFallbackModel = "openai/gpt-oss-120b"
    nonisolated public static let groqFallbackTextModel = "llama-3.1-8b-instant"
    nonisolated public static let groqModel = groqTextModel
    nonisolated private static let groqModelCacheTTL: TimeInterval = 24 * 60 * 60

    private struct AppSettings: Codable {
        var language: String
        var theme: AppColorTheme
        var verifiedGroqKeyFingerprint: String
        var selectedGroqModelID: String
        var cachedGroqModels: [GroqModelInfo]
        var groqModelsUpdatedAt: Date?
        var groqModelUsage: [String: GroqModelUsage]

        init(
            language: String,
            theme: AppColorTheme,
            verifiedGroqKeyFingerprint: String = "",
            selectedGroqModelID: String = AppStore.groqTextModel,
            cachedGroqModels: [GroqModelInfo] = AppStore.defaultGroqModels,
            groqModelsUpdatedAt: Date? = nil,
            groqModelUsage: [String: GroqModelUsage] = [:]
        ) {
            self.language = language
            self.theme = theme
            self.verifiedGroqKeyFingerprint = verifiedGroqKeyFingerprint
            self.selectedGroqModelID = selectedGroqModelID
            self.cachedGroqModels = cachedGroqModels
            self.groqModelsUpdatedAt = groqModelsUpdatedAt
            self.groqModelUsage = groqModelUsage
        }

        private enum CodingKeys: String, CodingKey {
            case language, theme, verifiedGroqKeyFingerprint
            case selectedGroqModelID, cachedGroqModels, groqModelsUpdatedAt, groqModelUsage
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            language = (try? c.decode(String.self, forKey: .language)) ?? "ru"
            theme = (try? c.decode(AppColorTheme.self, forKey: .theme)) ?? .dark
            verifiedGroqKeyFingerprint = (try? c.decode(String.self, forKey: .verifiedGroqKeyFingerprint)) ?? ""
            selectedGroqModelID = (try? c.decode(String.self, forKey: .selectedGroqModelID))
                ?? AppStore.groqTextModel
            cachedGroqModels = (try? c.decode([GroqModelInfo].self, forKey: .cachedGroqModels))
                ?? AppStore.defaultGroqModels
            groqModelsUpdatedAt = try? c.decode(Date.self, forKey: .groqModelsUpdatedAt)
            groqModelUsage = (try? c.decode([String: GroqModelUsage].self, forKey: .groqModelUsage)) ?? [:]
        }
    }

    private struct FitBarBackup: Codable {
        var version: Int
        var exportedAt: Date
        var workout: WorkoutState
        var activity: ActivityLog
        var diary: DiaryState?
        var profile: UserProfile?
        var goal: UserGoal
        var plan: SavedPlan?
    }

    private let persistence: Persistence
    private let groqKeyStore: GroqKeyStore
    private var verifiedGroqKeyFingerprint = ""

    public init(
        persistence: Persistence = Persistence(),
        loadDataset: Bool = true,
        groqKeyStore: GroqKeyStore = GroqKeyStore()
    ) {
        self.persistence = persistence
        self.groqKeyStore = groqKeyStore
        groqAPIKey = groqKeyStore.load() ?? ""
        groqKeyValidationState = groqAPIKey.isEmpty ? .missing : .unchecked
        if loadDataset {
            do {
                exercises = try ExerciseDataset.load()
            } catch {
                NSLog("FitBar: dataset failed to load: \(error)")
            }
        }
        byID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        if var saved = persistence.load(WorkoutState.self, from: "workout.json") {
            saved.exerciseIDs = saved.exerciseIDs.filter { byID[$0] != nil }
            saved.blocks = Self.cleanBlocks(saved.blocks, byID: byID)
            saved.clampIndex()
            workout = saved
            normalizeWorkout()
        }
        if let saved = persistence.load(ActivityLog.self, from: "activity.json") {
            activity = saved
        }
        if var saved = persistence.load(DiaryState.self, from: "diary.json") {
            saved.refresh(using: activity)
            prefillTodayDiaryExerciseNotes(&saved)
            diary = saved
            persistence.save(saved, as: "diary.json")
        }
        if let saved = persistence.load(UserProfile.self, from: "profile.json") {
            profile = saved
        }
        if let saved = persistence.load(UserGoal.self, from: "goal.json") {
            goal = saved
        }
        if var saved = persistence.load(SavedPlan.self, from: "plan.json") {
            let oldPlan = saved.plan
            Self.repairTemplateNumbersIfNeeded(
                plan: &saved.plan,
                profile: saved.profile ?? profile,
                goal: saved.goal)
            plan = saved
            if saved.plan != oldPlan {
                persistence.save(saved, as: "plan.json")
            }
        }
        if let saved = persistence.load(AppSettings.self, from: "settings.json"),
           ["ru", "en"].contains(saved.language) {
            verifiedGroqKeyFingerprint = saved.verifiedGroqKeyFingerprint
            appLanguage = saved.language
            appTheme = saved.theme
            groqModels = Self.sortedGroqModels(saved.cachedGroqModels)
            selectedGroqModelID = saved.selectedGroqModelID
            groqModelsUpdatedAt = saved.groqModelsUpdatedAt
            groqModelUsage = saved.groqModelUsage
        }
        if groqModels.isEmpty {
            groqModels = Self.defaultGroqModels
        }
        if selectedGroqModelID.isEmpty {
            selectedGroqModelID = groqModels.first?.id ?? Self.groqTextModel
        }
        groqKeyValidationState = savedGroqKeyIsVerified ? .valid : (groqAPIKey.isEmpty ? .missing : .unchecked)
        FitBarTheme.currentMode = appTheme
        normalizeProfileBindingsAfterLoad()
        refreshGroqModelsIfNeeded()
    }

    // MARK: Localization helpers

    /// Picks the Russian or English variant by the current app language.
    public func tr(_ ru: String, _ en: String) -> String {
        appLanguage == "ru" ? ru : en
    }

    public func setAppTheme(_ theme: AppColorTheme) {
        FitBarTheme.currentMode = theme
        appTheme = theme
    }

    private func saveSettings() {
        persistence.save(
            AppSettings(
                language: appLanguage,
                theme: appTheme,
                verifiedGroqKeyFingerprint: verifiedGroqKeyFingerprint,
                selectedGroqModelID: selectedGroqModelID,
                cachedGroqModels: groqModels,
                groqModelsUpdatedAt: groqModelsUpdatedAt,
                groqModelUsage: groqModelUsage
            ),
            as: "settings.json"
        )
    }

    private func normalizeProfileBindingsAfterLoad() {
        if let target = profile.targetWeightKG {
            goal.targetWeightKG = target
        }
        syncCurrentPlanFromProfile()
    }

    public var hasGroqAPIKey: Bool {
        !groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasVerifiedGroqAPIKey: Bool {
        hasGroqAPIKey && savedGroqKeyIsVerified
    }

    private var savedGroqKeyIsVerified: Bool {
        let key = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && verifiedGroqKeyFingerprint == Self.groqKeyFingerprint(key)
    }

    public var maskedGroqAPIKey: String {
        guard hasGroqAPIKey else { return "" }
        let suffix = String(groqAPIKey.suffix(4))
        return "gsk_••••••••\(suffix)"
    }

    public var availableGroqModels: [GroqModelInfo] {
        Self.sortedGroqModels(groqModels.isEmpty ? Self.defaultGroqModels : groqModels)
    }

    public var selectedGroqModel: GroqModelInfo {
        availableGroqModels.first { $0.id == selectedGroqModelID }
            ?? availableGroqModels.first
            ?? GroqModelInfo(id: Self.groqTextModel, isFallback: true)
    }

    private var activeGroqModelID: String {
        selectedGroqModel.id
    }

    private var groqFallbackModelID: String? {
        availableGroqModels.first { $0.id != activeGroqModelID }?.id
            ?? (activeGroqModelID == Self.groqFallbackTextModel ? nil : Self.groqFallbackTextModel)
    }

    public func selectGroqModel(_ id: String) {
        guard availableGroqModels.contains(where: { $0.id == id }) else { return }
        selectedGroqModelID = id
        saveSettings()
    }

    public func refreshGroqModelsIfNeeded(force: Bool = false) {
        guard hasVerifiedGroqAPIKey else { return }
        if !force,
           let groqModelsUpdatedAt,
           !groqModels.isEmpty,
           Date().timeIntervalSince(groqModelsUpdatedAt) < Self.groqModelCacheTTL {
            return
        }
        refreshGroqModels(force: force)
    }

    public func refreshGroqModels(force: Bool = true) {
        guard hasVerifiedGroqAPIKey else { return }
        guard !groqModelsLoading else { return }
        let key = groqAPIKey
        groqModelsLoading = true
        groqModelsError = nil
        Task { [weak self] in
            do {
                let models = try await GroqClient.fetchAvailableModels(apiKey: key)
                await MainActor.run {
                    guard let self else { return }
                    self.applyGroqModels(models)
                    self.groqModelsLoading = false
                    self.groqModelsError = nil
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.groqModelsLoading = false
                    self.groqModelsError = error.localizedDescription
                    if self.groqModels.isEmpty {
                        self.groqModels = Self.defaultGroqModels
                    }
                    self.saveSettings()
                }
            }
        }
    }

    public func connectGroqAPIKey(_ rawValue: String) {
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            groqKeyValidationState = .missing
            return
        }
        guard groqKeyValidationState != .checking else { return }
        groqKeyValidationState = .checking
        groqModelsError = nil
        Task { [weak self] in
            do {
                let models = try await GroqClient.fetchAvailableModels(apiKey: key)
                await MainActor.run {
                    guard let self else { return }
                    do {
                        try self.saveGroqAPIKey(key, validationState: .valid)
                        self.applyGroqModels(models)
                        self.groqKeyValidationState = .valid
                    } catch {
                        self.groqKeyValidationState = .unavailable(error.localizedDescription)
                    }
                }
            } catch GroqClient.GroqError.http(let code, let message)
                where code == 401
                    || (code == 403 && message.lowercased().contains("key")) {
                await MainActor.run { self?.groqKeyValidationState = .invalid }
            } catch {
                await MainActor.run {
                    self?.groqKeyValidationState = .unavailable(error.localizedDescription)
                }
            }
        }
    }

    public func saveGroqAPIKey(
        _ rawValue: String,
        validationState: GroqKeyValidationState = .unchecked
    ) throws {
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        try groqKeyStore.save(key)
        groqAPIKey = key
        groqKeyValidationState = key.isEmpty ? .missing : validationState
        verifiedGroqKeyFingerprint = validationState == .valid && !key.isEmpty
            ? Self.groqKeyFingerprint(key)
            : ""
        if key.isEmpty {
            selectedGroqModelID = Self.groqTextModel
            groqModels = Self.defaultGroqModels
            groqModelsUpdatedAt = nil
            groqModelsError = nil
        }
        saveSettings()
    }

    private func clearGroqData() {
        do {
            try groqKeyStore.delete()
        } catch {
            NSLog("FitBar: failed to delete Groq API key: \(error.localizedDescription)")
        }
        groqAPIKey = ""
        groqKeyValidationState = .missing
        verifiedGroqKeyFingerprint = ""
        selectedGroqModelID = Self.groqTextModel
        groqModels = Self.defaultGroqModels
        groqModelsUpdatedAt = nil
        groqModelsLoading = false
        groqModelsError = nil
        groqModelUsage = [:]
    }

    public func validateCurrentGroqAPIKey() {
        validateGroqAPIKey(groqAPIKey)
    }

    public func validateGroqAPIKey(_ rawValue: String) {
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            groqKeyValidationState = .missing
            return
        }
        guard groqKeyValidationState != .checking else { return }
        groqKeyValidationState = .checking
        Task { [weak self] in
            do {
                try await GroqClient.validateAPIKey(key)
                self?.groqKeyValidationState = .valid
            } catch GroqClient.GroqError.http(let code, let message)
                where code == 401
                    || (code == 403 && message.lowercased().contains("key")) {
                self?.groqKeyValidationState = .invalid
            } catch {
                self?.groqKeyValidationState = .unavailable(error.localizedDescription)
            }
        }
    }

    public func displayName(_ ex: Exercise) -> String {
        let name = ex.displayName(lang: appLanguage)
        if appLanguage == "ru", ExerciseNamesRU.duplicateNames.contains(name) {
            return "\(name) (\(ex.name.capitalized))"
        }
        return name
    }

    private static func groqKeyFingerprint(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    nonisolated private static var defaultGroqModels: [GroqModelInfo] {
        sortedGroqModels([
            GroqModelInfo(id: groqStrongFallbackModel, isFallback: true),
            GroqModelInfo(id: groqTextModel, isFallback: true),
            GroqModelInfo(id: groqFallbackTextModel, isFallback: true),
        ])
    }

    nonisolated private static func sortedGroqModels(_ models: [GroqModelInfo]) -> [GroqModelInfo] {
        var seen = Set<String>()
        return models
            .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { seen.insert($0.id).inserted }
            .sorted {
                if $0.powerScore != $1.powerScore { return $0.powerScore > $1.powerScore }
                return $0.id.localizedStandardCompare($1.id) == .orderedAscending
            }
    }

    private func applyGroqModels(_ models: [GroqModelInfo]) {
        let sorted = Self.sortedGroqModels(models)
        groqModels = sorted.isEmpty ? Self.defaultGroqModels : sorted
        groqModelsUpdatedAt = Date()
        if !groqModels.contains(where: { $0.id == selectedGroqModelID }) {
            selectedGroqModelID = groqModels.first?.id ?? Self.groqTextModel
        }
        saveSettings()
    }

    private func recordGroqUsage(_ usage: GroqUsage?, for model: String) {
        var current = groqModelUsage[model] ?? GroqModelUsage()
        current.record(usage)
        groqModelUsage[model] = current
        saveSettings()
    }

    private func recordGroqRateLimit(_ message: String, for model: String) {
        var current = groqModelUsage[model] ?? GroqModelUsage()
        current.lastRateLimitMessage = message
        groqModelUsage[model] = current
        saveSettings()
    }

    public func categoryLabel(_ raw: String) -> String {
        appLanguage == "ru" ? RU.category(raw) : raw.capitalized
    }

    public func targetLabel(_ raw: String) -> String {
        appLanguage == "ru" ? RU.target(raw) : raw.capitalized
    }

    public func muscleLabel(_ raw: String) -> String {
        appLanguage == "ru" ? RU.muscle(raw) : raw.capitalized
    }

    public func equipmentLabel(_ raw: String) -> String {
        appLanguage == "ru" ? RU.equipment(raw) : raw.capitalized
    }

    // MARK: Nutrition plan

    public func requestPlan(photos: [GoalPhotoPayload] = []) {
        guard !planLoading else { return }
        guard hasVerifiedGroqAPIKey else {
            planError = tr("Подключите и проверьте Groq API-ключ во вкладке «ИИ-помощник».",
                           "Connect and verify a Groq API key in the AI assistant tab.")
            return
        }
        let apiKey = groqAPIKey
        goal.heightCM = profile.heightCM
        goal.weightKG = profile.weightKG
        goal.trainingGoals = [goal.trainingGoal]
        goal.physiqueGoal = goal.physiqueGoals.first ?? .leanAndAthletic
        goal.trainingExperiences = [goal.trainingExperience]
        goal.weeklyAvailabilities = [goal.weeklyAvailability]
        goal.limitations = goal.limitationOptions.first ?? .none
        if goal.requestedOutputs.isEmpty {
            goal.requestedOutputs = [.caloriesMacros]
        }
        goal.requestedWorkoutPlanCount = min(max(goal.requestedWorkoutPlanCount, 1), 3)
        if goal.trainingLocation == .home || goal.limitationOptions.contains(.homeOnly) {
            goal.equipmentOptions.removeAll { $0 == .barbell || $0 == .machines }
            if goal.equipmentOptions.isEmpty { goal.equipmentOptions = [.bodyWeight] }
        }
        goal.bodyDescription = ""
        guard goal.isValid else { return }
        planLoading = true
        planError = nil
        let model = activeGroqModelID
        let fallbackModel = groqFallbackModelID
        let goal = goal
        let profile = profile
        let exercises = exercises
        let lang = appLanguage
        Task { [weak self] in
            do {
                let result = try await Self.requestFullPlanWithFallback(
                    apiKey: apiKey,
                    model: model,
                    fallbackModel: fallbackModel,
                    profile: profile,
                    goal: goal,
                    exercises: exercises,
                    photos: photos,
                    lang: lang
                )
                var plan = result.plan
                let usedModel = result.model
                Self.repairTemplateNumbersIfNeeded(plan: &plan, profile: profile, goal: goal)
                Self.applyRequestedOutputFilters(plan: &plan, goal: goal)
                await MainActor.run {
                    guard let self else { return }
                    self.recordGroqUsage(result.usage, for: usedModel)
                    let saved = SavedPlan(
                        plan: plan, goal: goal, model: usedModel, profile: profile)
                    self.plan = saved
                    self.persistence.save(saved, as: "plan.json")
                    self.planLoading = false
                }
            } catch GroqClient.GroqError.http(let code, let message) where code == 429 {
                await MainActor.run {
                    guard let self else { return }
                    self.recordGroqRateLimit(message, for: model)
                    self.planError = GroqClient.GroqError.http(code, message).localizedDescription
                    self.planLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.planError = error.localizedDescription
                    self?.planLoading = false
                }
            }
        }
    }

    public func setPlanRecommendationsLocked(_ locked: Bool) {
        guard var saved = plan else { return }
        saved.recommendationsLocked = locked
        plan = saved
        persistence.save(saved, as: "plan.json")
    }

    public func saveRecommendedExercisesToWorkout() {
        guard let saved = plan else { return }
        let planBlocks = saved.plan.workoutPlans.isEmpty
            ? [WorkoutPlanBlock(title: tr("Сборка 1", "Plan 1"),
                                focus: saved.plan.workoutFocus,
                                exercises: saved.plan.recommendedExercises)]
            : saved.plan.workoutPlans
        var planIDs = Set<String>()
        for (index, block) in planBlocks.enumerated() {
            let ids = block.exercises.map(\.exerciseID).filter { byID[$0] != nil }
            guard !ids.isEmpty else { continue }
            let rawTitle = block.title.isEmpty
                ? tr("Сборка \(index + 1)", "Plan \(index + 1)")
                : block.title
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let settings = block.exercises.map {
                WorkoutExerciseSettings(exerciseID: $0.exerciseID,
                                        sets: $0.sets,
                                        reps: $0.reps,
                                        note: $0.note)
            }
            if let existingIndex = workout.blocks.firstIndex(where: {
                normalizedWorkoutTitle($0.title) == normalizedWorkoutTitle(title)
            }) {
                workout.blocks[existingIndex].title = title.isEmpty
                    ? defaultWorkoutBlockTitle(number: index + 1)
                    : workout.blocks[existingIndex].title
                workout.blocks[existingIndex].exerciseIDs = ids
                workout.blocks[existingIndex].settings = settings
            } else {
                workout.blocks.append(WorkoutBlock(title: uniqueWorkoutBlockTitle(title.isEmpty ? rawTitle : title),
                                                   exerciseIDs: ids,
                                                   settings: settings))
            }
            ids.forEach { planIDs.insert($0) }
        }
        for id in planIDs where !workout.exerciseIDs.contains(id) {
            workout.exerciseIDs.append(id)
        }
        workout.clampIndex()
        saveWorkout()
    }

    public func replaceRecommendedExercise(_ oldID: String, with newID: String) {
        guard var saved = plan, byID[newID] != nil else { return }
        guard let index = saved.plan.recommendedExercises.firstIndex(where: {
            $0.exerciseID == oldID
        }) else { return }
        guard !saved.plan.recommendedExercises.contains(where: {
            $0.exerciseID == newID
        }) else { return }
        var rec = saved.plan.recommendedExercises[index]
        rec.exerciseID = newID
        rec.note = tr("заменено пользователем", "replaced by user")
        saved.plan.recommendedExercises[index] = rec
        for blockIndex in saved.plan.workoutPlans.indices {
            if let recIndex = saved.plan.workoutPlans[blockIndex].exercises.firstIndex(where: {
                $0.exerciseID == oldID
            }) {
                saved.plan.workoutPlans[blockIndex].exercises[recIndex] = rec
            }
        }
        saved.recommendationsEdited = true
        plan = saved
        persistence.save(saved, as: "plan.json")
    }

    public func updateRecommendedExerciseSetting(
        exerciseID: String, sets: Int? = nil, reps: String? = nil
    ) {
        guard var saved = plan else { return }
        func update(_ rec: inout RecommendedExercisePlan) {
            if let sets {
                rec.sets = min(max(sets, 0), 12)
            }
            if let reps {
                let cleaned = reps.trimmingCharacters(in: .whitespacesAndNewlines)
                rec.reps = cleaned.isEmpty ? "0" : String(cleaned.prefix(16))
            }
        }
        if let index = saved.plan.recommendedExercises.firstIndex(where: {
            $0.exerciseID == exerciseID
        }) {
            update(&saved.plan.recommendedExercises[index])
        }
        for blockIndex in saved.plan.workoutPlans.indices {
            if let recIndex = saved.plan.workoutPlans[blockIndex].exercises.firstIndex(where: {
                $0.exerciseID == exerciseID
            }) {
                update(&saved.plan.workoutPlans[blockIndex].exercises[recIndex])
            }
        }
        saved.recommendationsEdited = true
        plan = saved
        persistence.save(saved, as: "plan.json")
    }

    public func updatePlanNutrition(
        daysToGoal: Int, dailyCalories: Int, proteinG: Int, fatG: Int,
        carbsG: Int, waterTargetML: Int, foods: [String]
    ) {
        guard var saved = plan else { return }
        saved.plan.daysToGoal = min(max(daysToGoal, 1), 3650)
        saved.plan.dailyCalories = min(max(dailyCalories, 800), 8000)
        saved.plan.proteinG = min(max(proteinG, 0), 600)
        saved.plan.fatG = min(max(fatG, 0), 400)
        saved.plan.carbsG = min(max(carbsG, 0), 1000)
        saved.plan.waterTargetML = min(max(waterTargetML, 500), 7000)
        saved.plan.foods = foods.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        saved.nutritionEdited = true
        plan = saved
        persistence.save(saved, as: "plan.json")
    }

    public func regeneratePlanFromEditedRecommendations() {
        regeneratePlanFromUserEdits(includeExercises: true, includeNutrition: false)
    }

    public func regeneratePlanFromUserEdits(includeExercises: Bool, includeNutrition: Bool) {
        guard !planLoading, let saved = plan else { return }
        guard hasVerifiedGroqAPIKey else {
            planError = tr("Подключите и проверьте Groq API-ключ во вкладке «ИИ-помощник».",
                           "Connect and verify a Groq API key in the AI assistant tab.")
            return
        }
        let apiKey = groqAPIKey
        guard (includeExercises && saved.recommendationsEdited)
                || (includeNutrition && saved.nutritionEdited)
        else { return }
        let fixedIDs = includeExercises
            ? saved.plan.recommendedExercises.map(\.exerciseID)
            : nil
        if includeExercises, fixedIDs?.isEmpty != false { return }
        let fixedNutrition = includeNutrition ? saved.plan : nil
        planLoading = true
        planError = nil
        let model = activeGroqModelID
        let fallbackModel = groqFallbackModelID
        let goal = saved.goal
        let profileSnapshot = saved.profile ?? self.profile
        let exercises = exercises
        let lang = appLanguage
        Task { [weak self] in
            do {
                let result = try await Self.requestFullPlanWithFallback(
                    apiKey: apiKey,
                    model: model,
                    fallbackModel: fallbackModel,
                    profile: profileSnapshot,
                    goal: goal,
                    exercises: exercises,
                    lang: lang,
                    fixedExerciseIDs: fixedIDs,
                    fixedNutrition: fixedNutrition
                )
                var newPlan = result.plan
                let usedModel = result.model
                if let fixedNutrition {
                    newPlan.daysToGoal = fixedNutrition.daysToGoal
                    newPlan.dailyCalories = fixedNutrition.dailyCalories
                    newPlan.proteinG = fixedNutrition.proteinG
                    newPlan.fatG = fixedNutrition.fatG
                    newPlan.carbsG = fixedNutrition.carbsG
                    newPlan.foods = fixedNutrition.foods
                    newPlan.waterTargetML = fixedNutrition.waterTargetML
                } else {
                    Self.repairTemplateNumbersIfNeeded(
                        plan: &newPlan, profile: profileSnapshot, goal: goal)
                }
                Self.applyRequestedOutputFilters(plan: &newPlan, goal: goal)
                await MainActor.run {
                    guard let self else { return }
                    self.recordGroqUsage(result.usage, for: usedModel)
                    let updated = SavedPlan(
                        plan: newPlan,
                        goal: goal,
                        model: usedModel,
                        profile: profileSnapshot,
                        recommendationsLocked: false,
                        recommendationsEdited: false,
                        nutritionEdited: false
                    )
                    self.plan = updated
                    self.persistence.save(updated, as: "plan.json")
                    self.planLoading = false
                }
            } catch GroqClient.GroqError.http(let code, let message) where code == 429 {
                await MainActor.run {
                    guard let self else { return }
                    self.recordGroqRateLimit(message, for: model)
                    self.planError = GroqClient.GroqError.http(code, message).localizedDescription
                    self.planLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.planError = error.localizedDescription
                    self?.planLoading = false
                }
            }
        }
    }

    private static func requestFullPlanWithFallback(
        apiKey: String,
        model: String,
        fallbackModel: String?,
        profile: UserProfile,
        goal: UserGoal,
        exercises: [Exercise],
        photos: [GoalPhotoPayload] = [],
        lang: String,
        fixedExerciseIDs: [String]? = nil,
        fixedNutrition: NutritionPlan? = nil
    ) async throws -> (plan: NutritionPlan, model: String, usage: GroqUsage?) {
        do {
            let client = GroqClient(apiKey: apiKey, model: model)
            let result = try await client.requestFullPlanResult(
                profile: profile, goal: goal, exercises: exercises,
                photos: photos, lang: lang, fixedExerciseIDs: fixedExerciseIDs,
                fixedNutrition: fixedNutrition)
            return (result.plan, model, result.usage)
        } catch GroqClient.GroqError.http(let code, let message) where code == 429 && fallbackModel != nil {
            let fallback = fallbackModel!
            NSLog("FitBar: Groq model \(model) hit rate limit: \(message)")
            let client = GroqClient(apiKey: apiKey, model: fallback)
            let result = try await client.requestFullPlanResult(
                profile: profile, goal: goal, exercises: exercises,
                photos: photos, lang: lang, fixedExerciseIDs: fixedExerciseIDs,
                fixedNutrition: fixedNutrition)
            return (result.plan, fallback, result.usage)
        }
    }

    private static func repairTemplateNumbersIfNeeded(
        plan: inout NutritionPlan, profile: UserProfile, goal: UserGoal
    ) {
        let copiedOldPromptExample = plan.daysToGoal == 120
            && plan.dailyCalories == 2200
            && plan.proteinG == 130
            && plan.fatG == 70
            && plan.carbsG == 240
        guard copiedOldPromptExample else { return }
        let baseline = GroqClient.baselinePlanNumbers(profile: profile, goal: goal)
        plan.daysToGoal = baseline.days
        plan.dailyCalories = baseline.calories
        plan.proteinG = baseline.protein
        plan.fatG = baseline.fat
        plan.carbsG = baseline.carbs
        plan.waterTargetML = baseline.water
    }

    private static func applyRequestedOutputFilters(plan: inout NutritionPlan, goal: UserGoal) {
        if !goal.requestedOutputs.contains(.exercises) {
            plan.workoutFocus = []
            plan.workoutPlans = []
            plan.recommendedExercises = []
        }
        if !goal.requestedOutputs.contains(.bodyAssessment)
            && !goal.requestedOutputs.contains(.faceAssessment) {
            plan.assessment = ""
        }
        if !goal.requestedOutputs.contains(.caloriesMacros) {
            plan.foods = []
            plan.tips = []
        }
    }

    public var waterTargetML: Int {
        switch selectedWaterTargetMode {
        case .standard:
            return 3000
        case .ai:
            return aiWaterTargetML ?? 3000
        case .custom:
            return min(max(profile.waterTargetML ?? 3000, 500), 7000)
        }
    }

    public var selectedWaterTargetMode: WaterTargetMode {
        profile.waterTargetMode ?? (profile.waterTargetML == nil ? .standard : .custom)
    }

    public var aiWaterTargetML: Int? {
        guard let saved = plan, saved.goal.requestedOutputs.contains(.water) else { return nil }
        return min(max(saved.plan.waterTargetML, 500), 7000)
    }

    public var needsGenderSelection: Bool {
        profile.gender == .notSet
    }

    public var effectiveTargetWeightKG: Double {
        profile.targetWeightKG ?? goal.targetWeightKG
    }

    public var effectiveDailyCalories: Int {
        profile.dailyCalories ?? plan?.plan.dailyCalories
            ?? GroqClient.baselinePlanNumbers(profile: profile, goal: goal).calories
    }

    public var effectiveProteinG: Int {
        profile.proteinG ?? plan?.plan.proteinG
            ?? GroqClient.baselinePlanNumbers(profile: profile, goal: goal).protein
    }

    public var effectiveFatG: Int {
        profile.fatG ?? plan?.plan.fatG
            ?? GroqClient.baselinePlanNumbers(profile: profile, goal: goal).fat
    }

    public var effectiveCarbsG: Int {
        profile.carbsG ?? plan?.plan.carbsG
            ?? GroqClient.baselinePlanNumbers(profile: profile, goal: goal).carbs
    }

    public var effectiveWaterTargetML: Int {
        waterTargetML
    }

    public func setProfileGender(_ gender: UserGender) {
        guard gender != .notSet else { return }
        var updated = profile
        updated.gender = gender
        profile = updated
        syncCurrentPlanFromProfile()
    }

    public func applyProfile(_ newProfile: UserProfile, theme: AppColorTheme? = nil) {
        var updated = newProfile
        updated.heightCM = min(max(updated.heightCM, 120), 230)
        updated.weightKG = min(max(updated.weightKG, 35), 300)
        if updated.gender == .notSet {
            updated.gender = profile.gender == .notSet ? .male : profile.gender
        }
        updated.targetWeightKG = updated.targetWeightKG.map { min(max($0, 35), 300) }
        updated.dailyCalories = updated.dailyCalories.map { min(max($0, 800), 8000) }
        updated.proteinG = updated.proteinG.map { min(max($0, 0), 600) }
        updated.fatG = updated.fatG.map { min(max($0, 0), 400) }
        updated.carbsG = updated.carbsG.map { min(max($0, 0), 1000) }
        updated.waterTargetML = updated.waterTargetML.map { min(max($0, 500), 7000) }
        profile = updated
        goal.heightCM = updated.heightCM
        goal.weightKG = updated.weightKG
        if let target = updated.targetWeightKG {
            goal.targetWeightKG = target
        }
        if let theme {
            setAppTheme(theme)
        }
        syncCurrentPlanFromProfile()
    }

    public func setProfileAvatar(from sourceURL: URL) throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let image = NSImage(contentsOf: sourceURL),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(
                domain: "FitBar.ProfileAvatar",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: tr(
                        "Не удалось прочитать изображение.",
                        "Could not read the image."
                    )
                ]
            )
        }

        try FileManager.default.createDirectory(
            at: persistence.directory, withIntermediateDirectories: true
        )
        let avatarURL = persistence.directory.appendingPathComponent("profile-avatar.png")
        try data.write(to: avatarURL, options: [.atomic])

        var updated = profile
        updated.avatarImagePath = avatarURL.path
        profile = updated
    }

    public func clearProfileAvatar() {
        if let path = profile.avatarImagePath, !path.isEmpty {
            try? FileManager.default.removeItem(atPath: path)
        }
        var updated = profile
        updated.avatarImagePath = nil
        profile = updated
    }

    public func updateProfileHeightCM(_ value: Double) {
        var updated = profile
        updated.heightCM = min(max(value, 120), 230)
        profile = updated
        goal.heightCM = updated.heightCM
        syncCurrentPlanFromProfile()
    }

    public func updateProfileWeightKG(_ value: Double) {
        var updated = profile
        updated.weightKG = min(max(value, 35), 300)
        profile = updated
        goal.weightKG = updated.weightKG
        syncCurrentPlanFromProfile()
    }

    public func updateProfileTargetWeightKG(_ value: Double?) {
        var updated = profile
        updated.targetWeightKG = value.map { min(max($0, 35), 300) }
        profile = updated
        if let target = updated.targetWeightKG {
            goal.targetWeightKG = target
        }
        syncCurrentPlanFromProfile()
    }

    public func updateProfileDailyCalories(_ value: Int?) {
        var updated = profile
        updated.dailyCalories = value.map { min(max($0, 800), 8000) }
        profile = updated
        syncCurrentPlanFromProfile()
    }

    public func updateProfileProteinG(_ value: Int?) {
        var updated = profile
        updated.proteinG = value.map { min(max($0, 0), 600) }
        profile = updated
        syncCurrentPlanFromProfile()
    }

    public func updateProfileFatG(_ value: Int?) {
        var updated = profile
        updated.fatG = value.map { min(max($0, 0), 400) }
        profile = updated
        syncCurrentPlanFromProfile()
    }

    public func updateProfileCarbsG(_ value: Int?) {
        var updated = profile
        updated.carbsG = value.map { min(max($0, 0), 1000) }
        profile = updated
        syncCurrentPlanFromProfile()
    }

    public func updateProfileWaterTargetML(_ value: Int?) {
        var updated = profile
        updated.waterTargetML = value.map { min(max($0, 500), 7000) }
        if value != nil { updated.waterTargetMode = .custom }
        profile = updated
        syncCurrentPlanFromProfile()
    }

    public func setWaterTargetMode(_ mode: WaterTargetMode) {
        guard mode != .ai || aiWaterTargetML != nil else { return }
        var updated = profile
        updated.waterTargetMode = mode
        profile = updated
    }

    public func setCustomWaterTargetML(_ value: Int) {
        var updated = profile
        updated.waterTargetML = min(max(value, 500), 7000)
        updated.waterTargetMode = .custom
        profile = updated
    }

    public func saveCurrentPlanNutritionToProfile() {
        guard let saved = plan else { return }
        var updated = profile
        if saved.goal.requestedOutputs.contains(.caloriesMacros) {
            updated.targetWeightKG = saved.goal.targetWeightKG
            updated.dailyCalories = saved.plan.dailyCalories
            updated.proteinG = saved.plan.proteinG
            updated.fatG = saved.plan.fatG
            updated.carbsG = saved.plan.carbsG
        }
        if saved.goal.requestedOutputs.contains(.water) {
            updated.waterTargetML = saved.plan.waterTargetML
        }
        profile = updated
        if let target = updated.targetWeightKG {
            goal.targetWeightKG = target
        }
        syncCurrentPlanFromProfile()
    }

    private func syncCurrentPlanFromProfile() {
        guard var saved = plan else { return }
        saved.profile = profile
        saved.goal.heightCM = profile.heightCM
        saved.goal.weightKG = profile.weightKG
        if let target = profile.targetWeightKG {
            saved.goal.targetWeightKG = target
        }
        if let dailyCalories = profile.dailyCalories {
            saved.plan.dailyCalories = dailyCalories
        }
        if let proteinG = profile.proteinG {
            saved.plan.proteinG = proteinG
        }
        if let fatG = profile.fatG {
            saved.plan.fatG = fatG
        }
        if let carbsG = profile.carbsG {
            saved.plan.carbsG = carbsG
        }
        plan = saved
        persistence.save(saved, as: "plan.json")
    }

    public var todayWaterML: Int {
        activity.water()
    }

    public func addWater(_ ml: Int) {
        activity.addWater(ml)
        persistence.save(activity, as: "activity.json")
        refreshDiaryForToday()
    }

    // MARK: Diary

    public func suggestedDiaryDays() -> Int {
        if let planDays = plan?.plan.daysToGoal {
            return min(max(planDays, 1), 3650)
        }
        let delta = abs(profile.weightKG - (profile.targetWeightKG ?? goal.targetWeightKG))
        if delta > 0 {
            return min(max(Int(ceil(Double(delta) / 0.5)) * 7, 14), 3650)
        }
        return 30
    }

    public func startDiary(days: Int, trainingDaysPerWeek: Int, goalText: String) {
        var next = DiaryState(
            isActive: true,
            startedAt: Date(),
            originalDays: min(max(days, 1), 3650),
            trainingDaysPerWeek: min(max(trainingDaysPerWeek, 1), 7),
            goalText: goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        next.refresh(using: activity)
        prefillTodayDiaryExerciseNotes(&next)
        diary = next
        persistence.save(diary, as: "diary.json")
    }

    public func refreshDiaryForToday() {
        guard diary.isActive else { return }
        var next = diary
        next.refresh(using: activity)
        prefillTodayDiaryExerciseNotes(&next)
        if next != diary {
            diary = next
            persistence.save(diary, as: "diary.json")
        }
    }

    public func saveDiaryEntry(_ entry: DiaryEntry) {
        var next = diary
        next.refresh(using: activity)
        prefillTodayDiaryExerciseNotes(&next)
        var merged = entry
        if Calendar.current.isDate(entry.date, inSameDayAs: Date()),
           let authoritative = next.entries[entry.dateKey] {
            merged.exerciseSets = authoritative.exerciseSets
            merged.exerciseReps = authoritative.exerciseReps
            merged.exerciseMinutes = authoritative.exerciseMinutes
            merged.waterML = authoritative.waterML
            merged.exerciseNotes = authoritative.exerciseNotes
        }
        next.save(merged)
        diary = next
        persistence.save(diary, as: "diary.json")
    }

    public func resetDiary() {
        diary = DiaryState()
        persistence.save(diary, as: "diary.json")
    }

    private func prefillTodayDiaryExerciseNotes(_ diary: inout DiaryState) {
        let today = Date()
        let key = ActivityLog.dayKey(today)
        guard var entry = diary.entries[key],
              !entry.isMissed
        else { return }
        let rows = activity.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        guard !rows.isEmpty else {
            entry.exerciseNotes = ""
            diary.entries[key] = entry
            return
        }
        let grouped = Dictionary(grouping: rows, by: \.exerciseID)
        let lines = grouped.compactMap { exerciseID, sets -> String? in
            guard let exercise = byID[exerciseID] else { return nil }
            let reps = sets.reduce(0) { $0 + $1.reps }
            let title = exercise.displayName(lang: appLanguage)
            return tr("\(title): \(sets.count) подх., \(reps) повт.",
                      "\(title): \(sets.count) sets, \(reps) reps")
        }
        guard !lines.isEmpty else { return }
        entry.exerciseNotes = lines.sorted().joined(separator: "\n")
        diary.entries[key] = entry
    }

    // MARK: Filtered view of dataset

    public var filtered: [Exercise] {
        ExerciseQuery.apply(
            exercises,
            search: searchText,
            category: selectedCategory,
            equipment: selectedEquipment,
            target: selectedTarget,
            sort: sortOrder,
            lang: appLanguage
        )
    }

    public var allEquipment: [String] {
        Array(Set(exercises.map(\.equipment)))
            .sorted { equipmentLabel($0) < equipmentLabel($1) }
    }

    public var allTargets: [String] {
        Array(Set(exercises.map(\.target)))
            .sorted { targetLabel($0) < targetLabel($1) }
    }

    public var allCategories: [(name: String, count: Int)] {
        Dictionary(grouping: exercises, by: \.category)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: Workout list

    public var workoutExercises: [Exercise] {
        workout.exerciseIDs.compactMap { byID[$0] }
    }

    public func workoutExercises(in block: WorkoutBlock) -> [Exercise] {
        block.exerciseIDs.compactMap { byID[$0] }
    }

    public func workoutSetting(blockID: UUID, exerciseID: String) -> WorkoutExerciseSettings {
        guard let block = workout.blocks.first(where: { $0.id == blockID }),
              let setting = block.settings.first(where: { $0.exerciseID == exerciseID })
        else { return WorkoutExerciseSettings(exerciseID: exerciseID) }
        return setting
    }

    public func isInWorkout(_ ex: Exercise) -> Bool {
        workout.exerciseIDs.contains(ex.id)
    }

    public func toggleWorkout(_ ex: Exercise) {
        if let i = workout.exerciseIDs.firstIndex(of: ex.id) {
            workout.exerciseIDs.remove(at: i)
            if workout.currentIndex > i { workout.currentIndex -= 1 }
            for index in workout.blocks.indices {
                workout.blocks[index].exerciseIDs.removeAll { $0 == ex.id }
            }
        } else {
            workout.exerciseIDs.append(ex.id)
            ensureWorkoutBlock()
            if !workout.blocks[0].exerciseIDs.contains(ex.id) {
                workout.blocks[0].exerciseIDs.append(ex.id)
            }
            ensureSetting(exerciseID: ex.id, in: 0)
        }
        workout.clampIndex()
        saveWorkout()
    }

    public func moveWorkout(from source: IndexSet, to destination: Int) {
        let currentID = currentExercise?.id
        workout.exerciseIDs.move(fromOffsets: source, toOffset: destination)
        if let currentID, let i = workout.exerciseIDs.firstIndex(of: currentID) {
            workout.currentIndex = i
        }
        saveWorkout()
    }

    public func removeFromWorkout(at offsets: IndexSet) {
        let currentID = currentExercise?.id
        let removedIDs = offsets.compactMap { workout.exerciseIDs.indices.contains($0) ? workout.exerciseIDs[$0] : nil }
        workout.exerciseIDs.remove(atOffsets: offsets)
        for id in removedIDs {
            for index in workout.blocks.indices {
                workout.blocks[index].exerciseIDs.removeAll { $0 == id }
            }
        }
        if let currentID, let i = workout.exerciseIDs.firstIndex(of: currentID) {
            workout.currentIndex = i
        }
        workout.clampIndex()
        saveWorkout()
    }

    public func removeFromWorkout(id: String) {
        guard let index = workout.exerciseIDs.firstIndex(of: id) else { return }
        removeFromWorkout(at: IndexSet(integer: index))
    }

    @discardableResult
    public func addWorkoutBlock(title: String? = nil) -> UUID {
        let number = workout.blocks.count + 1
        let fallback = defaultWorkoutBlockTitle(number: number)
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let blockTitle = uniqueWorkoutBlockTitle(cleanTitle?.isEmpty == false ? cleanTitle! : fallback)
        let block = WorkoutBlock(title: blockTitle)
        workout.blocks.append(block)
        saveWorkout()
        return block.id
    }

    public func nextWorkoutBlockTitle() -> String {
        var number = workout.blocks.count + 1
        while workout.blocks.contains(where: {
            normalizedWorkoutTitle($0.title) == normalizedWorkoutTitle(defaultWorkoutBlockTitle(number: number))
        }) {
            number += 1
        }
        return defaultWorkoutBlockTitle(number: number)
    }

    public func defaultWorkoutBlockTitle(number: Int) -> String {
        tr("Сборка \(number)", "Plan \(number)")
    }

    public func selectWorkoutBlock(_ id: UUID?) {
        if let id, workout.blocks.contains(where: { $0.id == id && !$0.exerciseIDs.isEmpty }) {
            workout.selectedBlockID = id
        } else {
            workout.selectedBlockID = nil
        }
        workout.currentIndex = 0
        resetTimer()
        saveWorkout()
    }

    public func ensureWorkoutBlocksForDisplay() {
        guard workout.blocks.isEmpty, !workout.exerciseIDs.isEmpty else { return }
        workout.blocks = [WorkoutBlock(title: tr("Сборка 1", "Plan 1"),
                                       exerciseIDs: workout.exerciseIDs)]
        saveWorkout()
    }

    public func renameWorkoutBlock(_ id: UUID, title: String) {
        guard let index = workout.blocks.firstIndex(where: { $0.id == id }) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.blocks[index].title = cleanTitle.isEmpty
            ? defaultWorkoutBlockTitle(number: index + 1)
            : uniqueWorkoutBlockTitle(cleanTitle, excluding: id)
        saveWorkout()
    }

    public func removeWorkoutBlock(_ id: UUID) {
        guard let index = workout.blocks.firstIndex(where: { $0.id == id }) else { return }
        let removed = Set(workout.blocks[index].exerciseIDs)
        workout.blocks.remove(at: index)
        if workout.selectedBlockID == id {
            workout.selectedBlockID = nil
            workout.currentIndex = 0
        }
        let remaining = Set(workout.blocks.flatMap(\.exerciseIDs))
        let idsToRemove = removed.subtracting(remaining)
        workout.exerciseIDs.removeAll { idsToRemove.contains($0) }
        workout.clampIndex()
        saveWorkout()
    }

    public func addExercise(_ exercise: Exercise, to blockID: UUID) {
        guard byID[exercise.id] != nil,
              let index = workout.blocks.firstIndex(where: { $0.id == blockID })
        else { return }
        if !workout.blocks[index].exerciseIDs.contains(exercise.id) {
            workout.blocks[index].exerciseIDs.append(exercise.id)
        }
        ensureSetting(exerciseID: exercise.id, in: index)
        if !workout.exerciseIDs.contains(exercise.id) {
            workout.exerciseIDs.append(exercise.id)
        }
        workout.clampIndex()
        saveWorkout()
    }

    public func removeExercise(_ exerciseID: String, from blockID: UUID) {
        guard let index = workout.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        workout.blocks[index].exerciseIDs.removeAll { $0 == exerciseID }
        workout.blocks[index].settings.removeAll { $0.exerciseID == exerciseID }
        let stillUsed = workout.blocks.contains { $0.exerciseIDs.contains(exerciseID) }
        if !stillUsed {
            workout.exerciseIDs.removeAll { $0 == exerciseID }
        }
        workout.clampIndex()
        saveWorkout()
    }

    public func updateWorkoutSetting(
        blockID: UUID, exerciseID: String, sets: Int? = nil, reps: String? = nil,
        note: String? = nil
    ) {
        guard let blockIndex = workout.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        ensureSetting(exerciseID: exerciseID, in: blockIndex)
        guard let settingIndex = workout.blocks[blockIndex].settings.firstIndex(where: {
            $0.exerciseID == exerciseID
        }) else { return }
        if let sets {
            workout.blocks[blockIndex].settings[settingIndex].sets = min(max(sets, 0), 12)
        }
        if let reps {
            let cleaned = reps.trimmingCharacters(in: .whitespacesAndNewlines)
            workout.blocks[blockIndex].settings[settingIndex].reps = cleaned.isEmpty
                ? "0"
                : String(cleaned.prefix(16))
        }
        if let note {
            workout.blocks[blockIndex].settings[settingIndex].note = note
        }
        saveWorkout()
    }

    // MARK: Menu bar session

    public var activeWorkoutIDs: [String] {
        if let selected = workout.selectedBlockID,
           let block = workout.blocks.first(where: { $0.id == selected }),
           !block.exerciseIDs.isEmpty {
            return block.exerciseIDs.filter { byID[$0] != nil }
        }
        return workout.exerciseIDs.filter { byID[$0] != nil }
    }

    public var activeWorkoutTitle: String {
        if let selected = workout.selectedBlockID,
           let block = workout.blocks.first(where: { $0.id == selected }) {
            return block.title
        }
        return tr("Все упражнения", "All exercises")
    }

    public var currentExercise: Exercise? {
        let ids = activeWorkoutIDs
        guard !ids.isEmpty,
              workout.currentIndex < ids.count
        else { return nil }
        return byID[ids[workout.currentIndex]]
    }

    public func jump(to index: Int) {
        let ids = activeWorkoutIDs
        guard !ids.isEmpty else { return }
        workout.currentIndex = min(max(0, index), ids.count - 1)
        resetTimer()
        saveWorkout()
    }

    public func advance(_ delta: Int) {
        let ids = activeWorkoutIDs
        guard !ids.isEmpty else { return }
        let n = ids.count
        workout.currentIndex = ((workout.currentIndex + delta) % n + n) % n
        resetTimer()
        saveWorkout()
    }

    /// Mark the current exercise as done, log activity, move to the next one.
    public func completeCurrent() {
        guard let ex = currentExercise else { return }
        activity.logCompletion(exerciseID: ex.id)
        persistence.save(activity, as: "activity.json")
        advance(1)
    }

    // MARK: Set-based workout session

    public var countdownRemaining: TimeInterval {
        guard let end = countdownEndDate else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    public var setElapsed: TimeInterval {
        guard let started = setStartedAt else { return 0 }
        return max(0, Date().timeIntervalSince(started))
    }

    public func startSetCountdown() {
        guard currentExercise != nil, runPhase != .countdown, runPhase != .running else {
            return
        }
        countdownEndDate = Date().addingTimeInterval(5)
        setStartedAt = nil
        pendingSetDurationSeconds = 0
        runPhase = .countdown
    }

    public func updateSetClock() {
        guard runPhase == .countdown, countdownRemaining <= 0 else { return }
        countdownEndDate = nil
        setStartedAt = Date()
        runPhase = .running
    }

    public func stopRunningSet() {
        guard runPhase == .running, let started = setStartedAt else { return }
        let rawSeconds = Int(Date().timeIntervalSince(started).rounded())
        pendingSetDurationSeconds = max(0, rawSeconds)
        setStartedAt = nil
        runPhase = .awaitingReps
    }

    public func savePendingSet(reps: Int) {
        guard runPhase == .awaitingReps, let ex = currentExercise else { return }
        activity.logSet(
            exerciseID: ex.id,
            reps: max(0, reps),
            durationSeconds: pendingSetDurationSeconds
        )
        persistence.save(activity, as: "activity.json")
        refreshDiaryForToday()
        pendingReps = max(0, reps)
        pendingSetDurationSeconds = 0
        runPhase = .idle
    }

    public func cancelCurrentSet() {
        countdownEndDate = nil
        setStartedAt = nil
        pendingSetDurationSeconds = 0
        runPhase = .idle
    }

    public func finishCurrentExercise() {
        cancelCurrentSet()
        advance(1)
    }

    // MARK: Timer

    public var timerRemaining: TimeInterval {
        if let paused = timerPausedRemaining { return paused }
        guard let end = timerEndDate else { return timerDuration }
        return max(0, end.timeIntervalSinceNow)
    }

    public var timerRunning: Bool {
        timerEndDate != nil && timerPausedRemaining == nil && timerRemaining > 0
    }

    public func startTimer() {
        if let paused = timerPausedRemaining, paused > 0 {
            timerEndDate = Date().addingTimeInterval(paused)
        } else {
            timerEndDate = Date().addingTimeInterval(timerDuration)
        }
        timerPausedRemaining = nil
    }

    public func pauseTimer() {
        guard timerRunning else { return }
        timerPausedRemaining = timerRemaining
    }

    public func resetTimer() {
        timerEndDate = nil
        timerPausedRemaining = nil
    }

    // MARK: Stats

    public var todayCount: Int { activity.count() }

    public var trainingStreak: Int {
        activity.trainingPlanStreak(requiredDaysPerWeek: goal.trainingDaysPerWeek)
    }

    public var totalWorkoutTimeSeconds: Int { activity.totalDurationSeconds }

    public var maxRepsSet: (exercise: Exercise, set: ExerciseSetLog)? {
        guard let set = activity.maxRepsSet(), let ex = byID[set.exerciseID] else {
            return nil
        }
        return (ex, set)
    }

    public var totalReps: Int { activity.totalReps }

    public var recordExercise: (exercise: Exercise, count: Int)? {
        guard let rec = activity.recordExercise(), let ex = byID[rec.id] else { return nil }
        return (ex, rec.count)
    }

    public func stats(for exerciseID: String?) -> ExerciseActivityStats? {
        guard let exerciseID else { return nil }
        return activity.stats(for: exerciseID)
    }

    public func todayStats(for exerciseID: String?) -> ExerciseActivityStats? {
        guard let exerciseID else { return nil }
        return activity.stats(for: exerciseID, on: Date())
    }

    public var allWorkoutStats: [(exercise: Exercise, stats: ExerciseActivityStats)] {
        activity.allExerciseStats()
            .compactMap { stats in
                guard let ex = byID[stats.exerciseID] else { return nil }
                return (ex, stats)
            }
    }

    // MARK: Backup / restore

    public func exportBackupData() throws -> Data {
        let backup = FitBarBackup(
            version: 1,
            exportedAt: Date(),
            workout: workout,
            activity: activity,
            diary: diary,
            profile: profile,
            goal: goal,
            plan: plan
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    public func restoreBackup(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(FitBarBackup.self, from: data)
        var restoredWorkout = backup.workout
        restoredWorkout.exerciseIDs = restoredWorkout.exerciseIDs.filter { byID[$0] != nil }
        restoredWorkout.blocks = Self.cleanBlocks(restoredWorkout.blocks, byID: byID)
        restoredWorkout.clampIndex()
        workout = restoredWorkout
        activity = backup.activity
        diary = backup.diary ?? DiaryState()
        if let restoredProfile = backup.profile {
            profile = restoredProfile
        }
        goal = backup.goal
        plan = backup.plan
        saveWorkout()
        persistence.save(activity, as: "activity.json")
        persistence.save(diary, as: "diary.json")
        persistence.save(profile, as: "profile.json")
        persistence.save(goal, as: "goal.json")
        persistence.delete("manual-plan.json")
        if let plan {
            persistence.save(plan, as: "plan.json")
        } else {
            persistence.delete("plan.json")
        }
    }

    public func clearAllUserData() {
        cancelCurrentSet()
        clearGroqData()
        workout = WorkoutState()
        activity = ActivityLog()
        diary = DiaryState()
        profile = UserProfile()
        goal = UserGoal()
        plan = nil
        saveWorkout()
        persistence.save(activity, as: "activity.json")
        persistence.save(diary, as: "diary.json")
        persistence.save(profile, as: "profile.json")
        persistence.save(goal, as: "goal.json")
        persistence.delete("manual-plan.json")
        persistence.delete("plan.json")
    }

    private func saveWorkout() {
        normalizeWorkout()
        persistence.save(workout, as: "workout.json")
    }

    private func ensureWorkoutBlock() {
        if workout.blocks.isEmpty {
            workout.blocks = [WorkoutBlock(title: defaultWorkoutBlockTitle(number: 1))]
        }
    }

    private func ensureSetting(exerciseID: String, in blockIndex: Int) {
        guard workout.blocks.indices.contains(blockIndex) else { return }
        if !workout.blocks[blockIndex].settings.contains(where: { $0.exerciseID == exerciseID }) {
            workout.blocks[blockIndex].settings.append(
                WorkoutExerciseSettings(exerciseID: exerciseID)
            )
        }
    }

    private func normalizeWorkout() {
        var seenFlat = Set<String>()
        workout.exerciseIDs = workout.exerciseIDs.filter {
            byID[$0] != nil && seenFlat.insert($0).inserted
        }
        var usedBlockTitles = Set<String>()
        workout.blocks = workout.blocks.enumerated().map { index, block in
            var seen = Set<String>()
            let ids = block.exerciseIDs.filter {
                byID[$0] != nil && seen.insert($0).inserted
            }
            let settings = ids.map { id in
                block.settings.first(where: { $0.exerciseID == id })
                    ?? WorkoutExerciseSettings(exerciseID: id)
            }
            let baseTitle = block.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? defaultWorkoutBlockTitle(number: index + 1)
                : block.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = uniqueWorkoutBlockTitle(baseTitle, usedTitles: &usedBlockTitles)
            return WorkoutBlock(
                id: block.id,
                title: title,
                exerciseIDs: ids,
                settings: settings
            )
        }
        let blockIDs = workout.blocks.flatMap(\.exerciseIDs)
        for id in blockIDs where !workout.exerciseIDs.contains(id) {
            workout.exerciseIDs.append(id)
        }
        if workout.blocks.isEmpty && !workout.exerciseIDs.isEmpty {
            workout.blocks = [WorkoutBlock(title: defaultWorkoutBlockTitle(number: 1),
                                           exerciseIDs: workout.exerciseIDs)]
        } else if !workout.exerciseIDs.isEmpty {
            let grouped = Set(workout.blocks.flatMap(\.exerciseIDs))
            let ungrouped = workout.exerciseIDs.filter { !grouped.contains($0) }
            if !ungrouped.isEmpty {
                ensureWorkoutBlock()
                workout.blocks[0].exerciseIDs.append(contentsOf: ungrouped)
                for id in ungrouped {
                    ensureSetting(exerciseID: id, in: 0)
                }
            }
        }
        if let selected = workout.selectedBlockID,
           workout.blocks.first(where: { $0.id == selected && !$0.exerciseIDs.isEmpty }) == nil {
            workout.selectedBlockID = nil
        }
        let activeCount = activeWorkoutIDs.count
        if activeCount == 0 {
            workout.currentIndex = 0
        } else {
            workout.currentIndex = min(max(0, workout.currentIndex), activeCount - 1)
        }
    }

    private func normalizedWorkoutTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    private func uniqueWorkoutBlockTitle(_ title: String, excluding id: UUID? = nil) -> String {
        var used = Set(workout.blocks.compactMap { block -> String? in
            guard block.id != id else { return nil }
            return normalizedWorkoutTitle(block.title)
        })
        return uniqueWorkoutBlockTitle(title, usedTitles: &used)
    }

    private func uniqueWorkoutBlockTitle(_ title: String, usedTitles: inout Set<String>) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = clean.isEmpty ? defaultWorkoutBlockTitle(number: usedTitles.count + 1) : clean
        var candidate = base
        var suffix = 2
        while usedTitles.contains(normalizedWorkoutTitle(candidate)) {
            candidate = "\(base) \(suffix)"
            suffix += 1
        }
        usedTitles.insert(normalizedWorkoutTitle(candidate))
        return candidate
    }

    private static func cleanBlocks(
        _ blocks: [WorkoutBlock], byID: [String: Exercise]
    ) -> [WorkoutBlock] {
        blocks.map { block in
            var seen = Set<String>()
            let ids = block.exerciseIDs.filter {
                byID[$0] != nil && seen.insert($0).inserted
            }
            let settings = ids.map { id in
                block.settings.first(where: { $0.exerciseID == id })
                    ?? WorkoutExerciseSettings(exerciseID: id)
            }
            return WorkoutBlock(id: block.id, title: block.title,
                                exerciseIDs: ids, settings: settings)
        }
    }

    /// Test/snapshot helper: inject state without touching disk.
    public func seed(workout: WorkoutState? = nil, activity: ActivityLog? = nil,
                     plan: SavedPlan? = nil) {
        if var workout {
            workout.clampIndex()
            self.workout = workout
        }
        if let activity { self.activity = activity }
        if let plan {
            self.plan = plan
            self.goal = plan.goal
        }
    }
}

public enum WorkoutRunPhase: String, Codable {
    case idle
    case countdown
    case running
    case awaitingReps
}
