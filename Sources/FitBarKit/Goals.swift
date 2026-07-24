import Foundation

// MARK: - User goal

public struct UserGoal: Codable, Equatable {
    public var heightCM: Double
    public var weightKG: Double
    public var targetWeightKG: Double
    public var trainingGoal: TrainingGoal
    public var trainingGoals: [TrainingGoal]
    public var physiqueGoal: PhysiqueGoal
    public var physiqueGoals: [PhysiqueGoal]
    public var trainingExperience: TrainingExperience
    public var trainingExperiences: [TrainingExperience]
    public var weeklyAvailability: WeeklyAvailability
    public var weeklyAvailabilities: [WeeklyAvailability]
    public var trainingDaysPerWeek: Int
    public var trainingLocation: TrainingLocation
    public var limitations: TrainingLimitations
    public var limitationOptions: [TrainingLimitations]
    public var equipmentOptions: [EquipmentAccess]
    public var requestedOutputs: [GoalOutputOption]
    public var requestedWorkoutPlanCount: Int
    public var bodyDescription: String

    enum CodingKeys: String, CodingKey {
        case heightCM, weightKG, targetWeightKG
        case trainingGoal, trainingGoals, physiqueGoal, physiqueGoals
        case trainingExperience, trainingExperiences
        case weeklyAvailability, weeklyAvailabilities
        case trainingDaysPerWeek
        case trainingLocation, limitations, limitationOptions
        case equipmentOptions, requestedOutputs, requestedWorkoutPlanCount, bodyDescription
    }

    public init(
        heightCM: Double = 175, weightKG: Double = 75, targetWeightKG: Double = 70,
        trainingGoal: TrainingGoal = .fatLoss, trainingGoals: [TrainingGoal]? = nil,
        physiqueGoal: PhysiqueGoal = .leanAndAthletic, physiqueGoals: [PhysiqueGoal]? = nil,
        trainingExperience: TrainingExperience = .beginner,
        trainingExperiences: [TrainingExperience]? = nil,
        weeklyAvailability: WeeklyAvailability = .threeDays,
        weeklyAvailabilities: [WeeklyAvailability]? = nil,
        trainingDaysPerWeek: Int? = nil,
        trainingLocation: TrainingLocation = .home,
        limitations: TrainingLimitations = .none,
        limitationOptions: [TrainingLimitations]? = nil,
        equipmentOptions: [EquipmentAccess]? = nil,
        requestedOutputs: [GoalOutputOption]? = nil,
        requestedWorkoutPlanCount: Int = 2,
        bodyDescription: String = ""
    ) {
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.targetWeightKG = targetWeightKG
        self.trainingGoal = trainingGoal
        self.trainingGoals = Self.clean(trainingGoals ?? [trainingGoal], fallback: trainingGoal)
        self.physiqueGoal = physiqueGoal
        self.physiqueGoals = Self.clean(physiqueGoals ?? [physiqueGoal], fallback: physiqueGoal)
        self.trainingExperience = trainingExperience
        self.trainingExperiences = Self.clean(trainingExperiences ?? [trainingExperience],
                                             fallback: trainingExperience)
        self.weeklyAvailability = weeklyAvailability
        self.weeklyAvailabilities = Self.clean(weeklyAvailabilities ?? [weeklyAvailability],
                                               fallback: weeklyAvailability)
        self.trainingDaysPerWeek = Self.cleanDays(trainingDaysPerWeek
            ?? weeklyAvailability.defaultDaysPerWeek)
        self.trainingLocation = trainingLocation
        self.limitations = limitations
        self.limitationOptions = Self.clean(limitationOptions ?? [limitations], fallback: limitations)
        self.equipmentOptions = Self.clean(equipmentOptions ?? [.bodyWeight], fallback: .bodyWeight)
        self.requestedOutputs = Self.clean(requestedOutputs ?? [.caloriesMacros, .water, .exercises],
                                           fallback: .caloriesMacros)
        self.requestedWorkoutPlanCount = Self.cleanPlanCount(requestedWorkoutPlanCount)
        self.bodyDescription = bodyDescription
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        heightCM = (try? c.decode(Double.self, forKey: .heightCM)) ?? 175
        weightKG = (try? c.decode(Double.self, forKey: .weightKG)) ?? 75
        targetWeightKG = (try? c.decode(Double.self, forKey: .targetWeightKG)) ?? 70
        trainingGoal = (try? c.decode(TrainingGoal.self, forKey: .trainingGoal)) ?? .fatLoss
        trainingGoals = Self.clean(
            (try? c.decode([TrainingGoal].self, forKey: .trainingGoals)) ?? [trainingGoal],
            fallback: trainingGoal)
        trainingGoal = trainingGoals.first ?? trainingGoal
        physiqueGoal = (try? c.decode(PhysiqueGoal.self, forKey: .physiqueGoal)) ?? .leanAndAthletic
        physiqueGoals = Self.clean(
            (try? c.decode([PhysiqueGoal].self, forKey: .physiqueGoals)) ?? [physiqueGoal],
            fallback: physiqueGoal)
        physiqueGoal = physiqueGoals.first ?? physiqueGoal
        trainingExperience = (try? c.decode(TrainingExperience.self, forKey: .trainingExperience)) ?? .beginner
        trainingExperiences = Self.clean(
            (try? c.decode([TrainingExperience].self, forKey: .trainingExperiences)) ?? [trainingExperience],
            fallback: trainingExperience)
        trainingExperience = trainingExperiences.first ?? trainingExperience
        weeklyAvailability = (try? c.decode(WeeklyAvailability.self, forKey: .weeklyAvailability)) ?? .threeDays
        weeklyAvailabilities = Self.clean(
            (try? c.decode([WeeklyAvailability].self, forKey: .weeklyAvailabilities)) ?? [weeklyAvailability],
            fallback: weeklyAvailability)
        weeklyAvailability = weeklyAvailabilities.first ?? weeklyAvailability
        trainingDaysPerWeek = Self.cleanDays(
            (try? c.decode(Int.self, forKey: .trainingDaysPerWeek))
            ?? weeklyAvailability.defaultDaysPerWeek)
        trainingLocation = (try? c.decode(TrainingLocation.self, forKey: .trainingLocation)) ?? .home
        limitations = (try? c.decode(TrainingLimitations.self, forKey: .limitations)) ?? .none
        limitationOptions = Self.clean(
            (try? c.decode([TrainingLimitations].self, forKey: .limitationOptions)) ?? [limitations],
            fallback: limitations)
        limitations = limitationOptions.first ?? limitations
        equipmentOptions = Self.clean(
            (try? c.decode([EquipmentAccess].self, forKey: .equipmentOptions)) ?? [.bodyWeight],
            fallback: .bodyWeight)
        requestedOutputs = Self.clean(
            (try? c.decode([GoalOutputOption].self, forKey: .requestedOutputs))
                ?? [.caloriesMacros, .water, .exercises],
            fallback: .caloriesMacros)
        requestedWorkoutPlanCount = Self.cleanPlanCount(
            (try? c.decode(Int.self, forKey: .requestedWorkoutPlanCount)) ?? 2)
        bodyDescription = (try? c.decode(String.self, forKey: .bodyDescription)) ?? ""
    }

    public var deltaKG: Double { targetWeightKG - weightKG }
    public var isLosing: Bool { deltaKG < 0 }

    /// Rough local estimate: 7700 kcal per kg of body fat, safe
    /// deficit/surplus of ~500 kcal per day.
    public var estimatedDays: Int {
        Int((abs(deltaKG) * 7700 / 500).rounded())
    }

    public var isValid: Bool {
        (120...230).contains(heightCM)
            && (35...300).contains(weightKG)
            && (35...300).contains(targetWeightKG)
    }

    public func promptSummary(lang: String) -> String {
        let lines = [
            promptList(lang == "ru" ? "Цели тренировок" : "Training goals",
                       trainingGoals.map { $0.title(lang: lang) }),
            promptList(lang == "ru" ? "Желаемый внешний вид" : "Desired physique",
                       physiqueGoals.map { $0.title(lang: lang) }),
            promptList(lang == "ru" ? "Опыт" : "Experience",
                       trainingExperiences.map { $0.title(lang: lang) }),
            lang == "ru"
                ? "Частота тренировок: \(trainingDaysPerWeek) раз(а) в неделю"
                : "Training frequency: \(trainingDaysPerWeek) sessions per week",
            trainingLocation.promptTitle(lang: lang),
            promptList(lang == "ru" ? "Ограничения" : "Limitations",
                       limitationOptions.map { $0.title(lang: lang) }),
            promptList(lang == "ru" ? "Доступный инвентарь" : "Available equipment",
                       equipmentOptions.map { $0.title(lang: lang) }),
            promptList(lang == "ru" ? "Запрошенные разделы ответа" : "Requested response sections",
                       requestedOutputs.map { $0.title(lang: lang) }),
            lang == "ru"
                ? "Количество тренировочных сборок: \(requestedWorkoutPlanCount)"
                : "Workout block count: \(requestedWorkoutPlanCount)",
        ]
        return lines.joined(separator: "; ")
    }

    private static func clean<T: Hashable>(_ values: [T], fallback: T) -> [T] {
        var seen = Set<T>()
        let cleaned = values.filter { seen.insert($0).inserted }
        return cleaned.isEmpty ? [fallback] : cleaned
    }

    private static func cleanDays(_ value: Int) -> Int {
        min(max(value, 1), 7)
    }

    private static func cleanPlanCount(_ value: Int) -> Int {
        min(max(value, 1), 3)
    }

    private func promptList(_ title: String, _ values: [String]) -> String {
        "\(title): \(values.joined(separator: ", "))"
    }
}

public enum GoalOutputOption: String, CaseIterable, Codable, Identifiable, Hashable {
    case caloriesMacros
    case water
    case exercises
    case bodyAssessment
    case faceAssessment

    public var id: String { rawValue }

    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.caloriesMacros, "ru"): return "Калории + БЖУ"
        case (.water, "ru"): return "Сколько пить воды"
        case (.exercises, "ru"): return "Упражнения"
        case (.bodyAssessment, "ru"): return "Мнение о фигуре"
        case (.faceAssessment, "ru"): return "Мнение о лице"
        case (.caloriesMacros, _): return "Calories + macros"
        case (.water, _): return "Water target"
        case (.exercises, _): return "Exercises"
        case (.bodyAssessment, _): return "Body assessment"
        case (.faceAssessment, _): return "Face assessment"
        }
    }
}

public enum TrainingLocation: String, CaseIterable, Codable, Identifiable {
    case home, gym, mixed, outdoor
    public var id: String { rawValue }
    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.home, "ru"): return "Дома"
        case (.gym, "ru"): return "В зале"
        case (.mixed, "ru"): return "Дом + зал"
        case (.outdoor, "ru"): return "На улице"
        case (.home, _): return "Home"
        case (.gym, _): return "Gym"
        case (.mixed, _): return "Home + gym"
        case (.outdoor, _): return "Outdoor"
        }
    }
    public func promptTitle(lang: String) -> String {
        (lang == "ru" ? "Место тренировок: " : "Training location: ") + title(lang: lang)
    }
}

public enum EquipmentAccess: String, CaseIterable, Codable, Identifiable, Hashable {
    case bodyWeight, dumbbell, band, kettlebell, pullUpBar, barbell, machines
    public var id: String { rawValue }
    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.bodyWeight, "ru"): return "Свой вес"
        case (.dumbbell, "ru"): return "Гантели"
        case (.band, "ru"): return "Резинки"
        case (.kettlebell, "ru"): return "Гиря"
        case (.pullUpBar, "ru"): return "Турник"
        case (.barbell, "ru"): return "Штанга"
        case (.machines, "ru"): return "Тренажёры"
        case (.bodyWeight, _): return "Body weight"
        case (.dumbbell, _): return "Dumbbells"
        case (.band, _): return "Bands"
        case (.kettlebell, _): return "Kettlebell"
        case (.pullUpBar, _): return "Pull-up bar"
        case (.barbell, _): return "Barbell"
        case (.machines, _): return "Machines"
        }
    }

    public var exerciseEquipment: Set<String> {
        switch self {
        case .bodyWeight: return ["body weight"]
        case .dumbbell: return ["dumbbell"]
        case .band: return ["band", "resistance band"]
        case .kettlebell: return ["kettlebell"]
        case .pullUpBar: return ["body weight", "assisted"]
        case .barbell: return ["barbell", "ez barbell", "olympic barbell", "trap bar"]
        case .machines: return ["cable", "leverage machine", "smith machine", "assisted"]
        }
    }
}

public enum TrainingGoal: String, CaseIterable, Codable, Identifiable {
    case fatLoss, muscleGain, recomposition, endurance, strength
    public var id: String { rawValue }
    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.fatLoss, "ru"): return "Похудение"
        case (.muscleGain, "ru"): return "Набор мышц"
        case (.recomposition, "ru"): return "Рельеф и рекомпозиция"
        case (.endurance, "ru"): return "Выносливость"
        case (.strength, "ru"): return "Сила"
        case (.fatLoss, _): return "Weight loss"
        case (.muscleGain, _): return "Muscle gain"
        case (.recomposition, _): return "Definition & recomposition"
        case (.endurance, _): return "Endurance"
        case (.strength, _): return "Strength"
        }
    }
    public func promptTitle(lang: String) -> String {
        (lang == "ru" ? "Цель тренировок: " : "Training goal: ") + title(lang: lang)
    }
}

public enum PhysiqueGoal: String, CaseIterable, Codable, Identifiable {
    case leanAndAthletic, vShape, biggerUpperBody, strongerLegsGlutes, balancedHealth
    public var id: String { rawValue }
    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.leanAndAthletic, "ru"): return "Суше и атлетичнее"
        case (.vShape, "ru"): return "V-форма: спина и плечи"
        case (.biggerUpperBody, "ru"): return "Больше грудь, плечи и руки"
        case (.strongerLegsGlutes, "ru"): return "Сильнее ноги и ягодицы"
        case (.balancedHealth, "ru"): return "Баланс здоровья и тонуса"
        case (.leanAndAthletic, _): return "Leaner and athletic"
        case (.vShape, _): return "V-shape: back and shoulders"
        case (.biggerUpperBody, _): return "Bigger chest, shoulders and arms"
        case (.strongerLegsGlutes, _): return "Stronger legs and glutes"
        case (.balancedHealth, _): return "Health and tone balance"
        }
    }
    public func promptTitle(lang: String) -> String {
        (lang == "ru" ? "Желаемый внешний вид: " : "Desired physique: ") + title(lang: lang)
    }
}

public enum TrainingExperience: String, CaseIterable, Codable, Identifiable {
    case none, beginner, intermittent, regular, advanced
    public var id: String { rawValue }
    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.none, "ru"): return "Не занимался"
        case (.beginner, "ru"): return "Новичок"
        case (.intermittent, "ru"): return "Был опыт с перерывами"
        case (.regular, "ru"): return "Занимался регулярно"
        case (.advanced, "ru"): return "Опытный"
        case (.none, _): return "No previous training"
        case (.beginner, _): return "Beginner"
        case (.intermittent, _): return "Some experience with breaks"
        case (.regular, _): return "Trained regularly"
        case (.advanced, _): return "Advanced"
        }
    }
    public func promptTitle(lang: String) -> String {
        (lang == "ru" ? "Опыт: " : "Experience: ") + title(lang: lang)
    }
}

public enum WeeklyAvailability: String, CaseIterable, Codable, Identifiable {
    case twoDays, threeDays, fourDays, fivePlusDays, shortDaily
    public var id: String { rawValue }
    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.twoDays, "ru"): return "2 дня в неделю"
        case (.threeDays, "ru"): return "3 дня в неделю"
        case (.fourDays, "ru"): return "4 дня в неделю"
        case (.fivePlusDays, "ru"): return "5+ дней в неделю"
        case (.shortDaily, "ru"): return "Коротко каждый день"
        case (.twoDays, _): return "2 days per week"
        case (.threeDays, _): return "3 days per week"
        case (.fourDays, _): return "4 days per week"
        case (.fivePlusDays, _): return "5+ days per week"
        case (.shortDaily, _): return "Short daily sessions"
        }
    }
    public func promptTitle(lang: String) -> String {
        (lang == "ru" ? "Доступность: " : "Availability: ") + title(lang: lang)
    }

    public var defaultDaysPerWeek: Int {
        switch self {
        case .twoDays: return 2
        case .threeDays: return 3
        case .fourDays: return 4
        case .fivePlusDays: return 5
        case .shortDaily: return 7
        }
    }
}

public enum TrainingLimitations: String, CaseIterable, Codable, Identifiable {
    case none, knees, back, shoulders, homeOnly, lowImpact
    public var id: String { rawValue }
    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.none, "ru"): return "Без ограничений"
        case (.knees, "ru"): return "Беречь колени"
        case (.back, "ru"): return "Беречь спину"
        case (.shoulders, "ru"): return "Беречь плечи"
        case (.homeOnly, "ru"): return "Только дома"
        case (.lowImpact, "ru"): return "Без прыжков"
        case (.none, _): return "No limitations"
        case (.knees, _): return "Protect knees"
        case (.back, _): return "Protect back"
        case (.shoulders, _): return "Protect shoulders"
        case (.homeOnly, _): return "Home only"
        case (.lowImpact, _): return "Low impact only"
        }
    }
    public func promptTitle(lang: String) -> String {
        (lang == "ru" ? "Ограничения: " : "Limitations: ") + title(lang: lang)
    }
}

// MARK: - Nutrition plan (Groq output)

public struct NutritionPlan: Codable, Equatable {
    public var daysToGoal: Int
    public var dailyCalories: Int
    public var proteinG: Int
    public var fatG: Int
    public var carbsG: Int
    public var assessment: String
    public var foods: [String]
    public var waterTargetML: Int
    public var tips: [String]
    public var workoutFocus: [String]
    public var recommendedExercises: [RecommendedExercisePlan]
    public var workoutPlans: [WorkoutPlanBlock]

    enum CodingKeys: String, CodingKey {
        case daysToGoal = "days_to_goal"
        case dailyCalories = "daily_calories"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case carbsG = "carbs_g"
        case assessment, foods, tips
        case waterTargetML = "water_target_ml"
        case workoutFocus = "workout_focus"
        case recommendedExercises = "recommended_exercises"
        case workoutPlans = "workout_plans"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        daysToGoal = (try? Self.int(c, .daysToGoal)) ?? 120
        dailyCalories = (try? Self.int(c, .dailyCalories)) ?? 2000
        proteinG = (try? Self.int(c, .proteinG)) ?? 0
        fatG = (try? Self.int(c, .fatG)) ?? 0
        carbsG = (try? Self.int(c, .carbsG)) ?? 0
        assessment = (try? c.decode(String.self, forKey: .assessment)) ?? ""
        foods = (try? c.decode([String].self, forKey: .foods)) ?? []
        waterTargetML = (try? Self.int(c, .waterTargetML)) ?? 2000
        tips = (try? c.decode([String].self, forKey: .tips)) ?? []
        workoutFocus = (try? c.decode([String].self, forKey: .workoutFocus)) ?? []
        recommendedExercises = (try? c.decode(
            [RecommendedExercisePlan].self, forKey: .recommendedExercises)) ?? []
        workoutPlans = (try? c.decode([WorkoutPlanBlock].self, forKey: .workoutPlans)) ?? []
        if recommendedExercises.isEmpty {
            recommendedExercises = workoutPlans.flatMap(\.exercises)
        }
        if workoutPlans.isEmpty, !recommendedExercises.isEmpty {
            workoutPlans = [
                WorkoutPlanBlock(title: "", focus: workoutFocus, exercises: recommendedExercises),
            ]
        }
    }

    /// External responses may encode numbers as strings or floats.
    private static func int(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) throws -> Int {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let v = try? c.decode(Double.self, forKey: key) { return Int(v.rounded()) }
        if let s = try? c.decode(String.self, forKey: key),
           let v = Double(s.filter { "0123456789.".contains($0) }) {
            return Int(v.rounded())
        }
        throw DecodingError.keyNotFound(
            key, .init(codingPath: [key], debugDescription: "missing numeric \(key)"))
    }

    public init(daysToGoal: Int, dailyCalories: Int, proteinG: Int, fatG: Int,
                carbsG: Int, assessment: String = "", foods: [String],
                waterTargetML: Int = 2000,
                tips: [String], workoutFocus: [String] = [],
                recommendedExercises: [RecommendedExercisePlan] = [],
                workoutPlans: [WorkoutPlanBlock] = []) {
        self.daysToGoal = daysToGoal
        self.dailyCalories = dailyCalories
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.assessment = assessment
        self.foods = foods
        self.waterTargetML = waterTargetML
        self.tips = tips
        self.workoutFocus = workoutFocus
        self.recommendedExercises = recommendedExercises
        self.workoutPlans = workoutPlans.isEmpty && !recommendedExercises.isEmpty
            ? [WorkoutPlanBlock(title: "", focus: workoutFocus, exercises: recommendedExercises)]
            : workoutPlans
    }
}

public struct WorkoutPlanBlock: Codable, Equatable, Identifiable, Hashable {
    public var id: String { title + exercises.map(\.exerciseID).joined() }
    public var title: String
    public var focus: [String]
    public var exercises: [RecommendedExercisePlan]

    enum CodingKeys: String, CodingKey {
        case title, focus, exercises
    }

    public init(title: String, focus: [String], exercises: [RecommendedExercisePlan]) {
        self.title = title
        self.focus = focus
        self.exercises = exercises
    }
}

public struct RecommendedExercisePlan: Codable, Equatable, Identifiable, Hashable {
    public var id: String { exerciseID }
    public var exerciseID: String
    public var sets: Int
    public var reps: String
    public var note: String

    enum CodingKeys: String, CodingKey {
        case exerciseID = "exercise_id"
        case sets, reps, note
    }

    public init(exerciseID: String, sets: Int, reps: String, note: String) {
        self.exerciseID = exerciseID
        self.sets = sets
        self.reps = reps
        self.note = note
    }
}

/// Plan together with the inputs it was computed for.
public struct SavedPlan: Codable, Equatable {
    public var plan: NutritionPlan
    public var goal: UserGoal
    public var profile: UserProfile?
    public var createdAt: Date
    public var model: String
    public var recommendationsLocked: Bool
    public var recommendationsEdited: Bool
    public var nutritionEdited: Bool

    enum CodingKeys: String, CodingKey {
        case plan, goal, profile, createdAt, model
        case recommendationsLocked, recommendationsEdited, nutritionEdited
    }

    public init(plan: NutritionPlan, goal: UserGoal, createdAt: Date = Date(),
                model: String, profile: UserProfile? = nil,
                recommendationsLocked: Bool = false,
                recommendationsEdited: Bool = false,
                nutritionEdited: Bool = false) {
        self.plan = plan
        self.goal = goal
        self.profile = profile
        self.createdAt = createdAt
        self.model = model
        self.recommendationsLocked = recommendationsLocked
        self.recommendationsEdited = recommendationsEdited
        self.nutritionEdited = nutritionEdited
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plan = try c.decode(NutritionPlan.self, forKey: .plan)
        goal = try c.decode(UserGoal.self, forKey: .goal)
        profile = try? c.decode(UserProfile.self, forKey: .profile)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        model = (try? c.decode(String.self, forKey: .model)) ?? "unknown"
        recommendationsLocked = (try? c.decode(Bool.self, forKey: .recommendationsLocked)) ?? false
        recommendationsEdited = (try? c.decode(Bool.self, forKey: .recommendationsEdited)) ?? false
        nutritionEdited = (try? c.decode(Bool.self, forKey: .nutritionEdited)) ?? false
    }
}

public struct GoalPhotoPayload: Equatable {
    public var mimeType: String
    public var data: Data

    public init(mimeType: String, data: Data) {
        self.mimeType = mimeType
        self.data = data
    }
}

public struct GroqUsage: Codable, Equatable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int

    public init(promptTokens: Int = 0, completionTokens: Int = 0, totalTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

public struct GroqPlanResponse: Equatable {
    public var plan: NutritionPlan
    public var usage: GroqUsage?
}

public struct GroqTextResponse: Equatable {
    public var text: String
    public var usage: GroqUsage?
}

// MARK: - Exercise catalog sent to Groq

public enum ExercisePlanCatalog {
    public static func candidates(
        profile: UserProfile, goal: UserGoal, exercises: [Exercise],
        limit: Int = 60
    ) -> [Exercise] {
        let text = (goal.bodyDescription + " " + goal.promptSummary(lang: "ru")
            + " " + goal.promptSummary(lang: "en")).lowercased()
        let allowedEquipment = Self.allowedEquipment(for: goal)
        let pool = exercises.filter { allowedEquipment.contains($0.equipment) }
        let source = pool.isEmpty ? exercises : pool
        guard source.count > limit else { return source }

        let wantedTargets = targetsMentioned(in: text)
        let preferredEquipment = allowedEquipment
        let baseTargets: Set<String> = goal.isLosing
            ? ["quads", "glutes", "hamstrings", "lats", "pectorals", "abs",
               "delts", "cardiovascular system"]
            : ["pectorals", "lats", "delts", "biceps", "triceps", "quads",
               "glutes", "hamstrings"]
        let compoundWords = [
            "squat", "press", "push-up", "pull-up", "row", "deadlift", "lunge",
            "plank", "burpee", "curl", "extension", "raise", "dip", "crunch",
            "run", "walk", "bike",
        ]

        let scored = source.map { exercise -> (Exercise, Int) in
            let name = exercise.name.lowercased()
            var score = 0
            if wantedTargets.contains(exercise.target) { score += 36 }
            if wantedTargets.contains(exercise.category) { score += 24 }
            if baseTargets.contains(exercise.target) { score += 16 }
            if preferredEquipment.contains(exercise.equipment) { score += 12 }
            if exercise.equipment == "body weight" { score += 5 }
            if compoundWords.contains(where: { name.contains($0) }) { score += 10 }
            score += min(10, exercise.secondaryMuscles.count * 2)
            if exercise.target == "cardiovascular system", !goal.isLosing { score -= 8 }
            if goal.limitationOptions.contains(.back) {
                if name.contains("deadlift") || name.contains("good morning") { score -= 40 }
                if exercise.target == "spine" || exercise.target == "lower back" { score -= 24 }
            }
            if goal.limitationOptions.contains(.knees),
               name.contains("jump") || name.contains("burpee") {
                score -= 24
            }
            if exercise.equipment.contains("machine") { score -= 2 }
            return (exercise, score)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
        }

        var selected: [Exercise] = []
        var perCategory: [String: Int] = [:]
        var perTarget: [String: Int] = [:]

        func append(_ exercise: Exercise, categoryLimit: Int, targetLimit: Int) {
            guard selected.count < limit,
                  !selected.contains(where: { $0.id == exercise.id }),
                  (perCategory[exercise.category] ?? 0) < categoryLimit,
                  (perTarget[exercise.target] ?? 0) < targetLimit
            else { return }
            selected.append(exercise)
            perCategory[exercise.category, default: 0] += 1
            perTarget[exercise.target, default: 0] += 1
        }

        let essentialNames: Set<String> = [
            "push-up", "pull-up", "chin-up", "squat", "plank", "burpee",
            "dumbbell curl", "dumbbell lunge", "barbell bench press",
            "barbell deadlift", "barbell squat", "jump squat",
        ]
        for exercise in source where essentialNames.contains(exercise.name) {
            append(exercise, categoryLimit: 36, targetLimit: 24)
        }
        for (exercise, _) in scored {
            append(exercise, categoryLimit: 24, targetLimit: 18)
        }
        if selected.count < min(limit, 90) {
            for (exercise, _) in scored {
                append(exercise, categoryLimit: 60, targetLimit: 44)
            }
        }
        return selected
    }

    private static func allowedEquipment(for goal: UserGoal) -> Set<String> {
        let strictHome = goal.trainingLocation == .home
            || goal.limitationOptions.contains(.homeOnly)
        let strictOutdoor = goal.trainingLocation == .outdoor
        var selected = Set(goal.equipmentOptions.flatMap(\.exerciseEquipment))
        if selected.isEmpty { selected = ["body weight"] }

        if strictOutdoor {
            selected = selected.intersection(["body weight", "band", "resistance band"])
            selected.insert("body weight")
            return selected
        }

        if strictHome {
            let homeAllowed: Set<String> = [
                "body weight", "dumbbell", "band", "resistance band", "kettlebell",
            ]
            selected = selected.intersection(homeAllowed)
            selected.insert("body weight")
            return selected
        }

        if goal.trainingLocation == .gym {
            selected.formUnion(["body weight", "cable", "leverage machine", "smith machine",
                                "assisted"])
            return selected
        }

        selected.insert("body weight")
        return selected
    }

    private static func targetsMentioned(in text: String) -> Set<String> {
        var result = Set<String>()
        let groups: [(targets: [String], words: [String])] = [
            (["lats", "upper back", "traps"], ["спин", "широч", "осанк", "v-", "v форму", "v-форм", "back"]),
            (["delts"], ["плеч", "дельт", "shoulder"]),
            (["pectorals"], ["груд", "chest"]),
            (["abs"], ["живот", "пресс", "тал", "кор", "abs", "core", "belly"]),
            (["glutes"], ["ягод", "glute"]),
            (["quads", "hamstrings", "adductors", "abductors"], ["ног", "бедр", "leg", "thigh"]),
            (["biceps", "triceps", "forearms"], ["рук", "бицеп", "трицеп", "предплеч", "arm"]),
            (["cardiovascular system"], ["кардио", "вынослив", "cardio", "endurance"]),
        ]
        for group in groups where group.words.contains(where: { text.contains($0) }) {
            result.formUnion(group.targets)
        }
        return result
    }
}

// MARK: - Groq client

public struct GroqClient {
    public var apiKey: String
    public var model: String

    public init(apiKey: String, model: String = "llama-3.3-70b-versatile") {
        self.apiKey = apiKey
        self.model = model
    }

    public enum GroqError: LocalizedError {
        case http(Int, String)
        case emptyResponse
        case badPlanJSON(String)

        public var errorDescription: String? {
            switch self {
            case .http(let code, let message):
                return "Groq API: HTTP \(code). \(message)"
            case .emptyResponse:
                return "Groq API вернул пустой ответ."
            case .badPlanJSON:
                return "ИИ вернул неполный или неверный JSON-план. Попробуйте составить план ещё раз."
            }
        }
    }

    /// Checks the credential without spending completion tokens.
    public static func validateAPIKey(_ apiKey: String) async throws {
        _ = try await fetchAvailableModels(apiKey: apiKey)
    }

    /// Loads all active Groq models available for the supplied key.
    public static func fetchAvailableModels(apiKey: String) async throws -> [GroqModelInfo] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GroqError.http(401, "API key is empty") }
        var request = URLRequest(
            url: URL(string: "https://api.groq.com/openai/v1/models")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let message = apiErrorMessage(data) ?? String(decoding: data, as: UTF8.self)
            throw GroqError.http(code, String(message.prefix(200)))
        }
        struct Envelope: Decodable {
            let data: [GroqModelInfo]
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            throw GroqError.emptyResponse
        }
        return envelope.data
    }

    public static func buildMessages(
        goal: UserGoal, exercises: [Exercise], lang: String = "ru"
    ) -> [[String: String]] {
        let list = exercises.prefix(30)
            .map { "\($0.name) (\($0.target), \($0.equipment))" }
            .joined(separator: "; ")
        if lang == "ru" {
            let direction = goal.isLosing ? "похудение" : "набор массы"
            let workoutLine = list.isEmpty
                ? "Пока без силовых тренировок — учитывай только питание и бытовую активность."
                : "Тренировки из списка пользователя: \(list)."
            let system = """
            Ты спортивный нутрициолог. Отвечай строго JSON-объектом с полями: \
            days_to_goal (int, реалистичное число дней до цели при безопасном темпе), \
            daily_calories (int, ккал/день), protein_g (int), fat_g (int), carbs_g (int), \
            foods (массив из 5-8 строк на русском — приоритетные продукты для этой цели), \
            tips (массив из 2-4 коротких советов на русском). Никакого markdown, только JSON.
            """
            let user = """
            Рост \(Int(goal.heightCM)) см, текущий вес \(fmt(goal.weightKG)) кг, \
            желаемый вес \(fmt(goal.targetWeightKG)) кг (цель — \(direction), \
            разница \(fmt(abs(goal.deltaKG))) кг). \(workoutLine) Рассчитай план.
            """
            return [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ]
        }
        let direction = goal.isLosing ? "weight loss" : "weight gain"
        let workoutLine = list.isEmpty
            ? "No strength training yet — consider nutrition and daily activity only."
            : "The user's workout list: \(list)."
        let system = """
        You are a sports nutritionist. Reply strictly with a JSON object with fields: \
        days_to_goal (int, realistic number of days at a safe pace), \
        daily_calories (int), protein_g (int), fat_g (int), carbs_g (int), \
        foods (array of 5-8 strings in English — priority foods for this goal), \
        tips (array of 2-4 short tips in English). No markdown, JSON only.
        """
        let user = """
        Height \(Int(goal.heightCM)) cm, current weight \(fmt(goal.weightKG)) kg, \
        target weight \(fmt(goal.targetWeightKG)) kg (goal — \(direction), \
        difference \(fmt(abs(goal.deltaKG))) kg). \(workoutLine) Compute the plan.
        """
        return [
            ["role": "system", "content": system],
            ["role": "user", "content": user],
        ]
    }

    public static func buildFullPlanMessages(
        profile: UserProfile, goal: UserGoal, exercises: [Exercise],
        photos: [GoalPhotoPayload] = [], lang: String = "ru",
        fixedExerciseIDs: [String]? = nil,
        fixedNutrition: NutritionPlan? = nil
    ) -> [[String: Any]] {
        let fixedExercises = fixedExerciseIDs.map { ids in
            ids.compactMap { id in exercises.first { $0.id == id } }
        }
        let candidates = fixedExercises ?? ExercisePlanCatalog.candidates(
            profile: profile, goal: goal, exercises: exercises, limit: 180)
        let catalog = candidates.map {
            "\($0.id)|\($0.name)|\($0.target)|\($0.equipment)"
        }.joined(separator: "\n")
        let gender = profile.gender.title(lang: lang)
        let baseline = Self.baselinePlanNumbers(profile: profile, goal: goal)
        let wantsCalories = goal.requestedOutputs.contains(.caloriesMacros)
        let wantsWater = goal.requestedOutputs.contains(.water)
        let wantsExercises = goal.requestedOutputs.contains(.exercises)
        let wantsBodyAssessment = goal.requestedOutputs.contains(.bodyAssessment)
        let wantsFaceAssessment = goal.requestedOutputs.contains(.faceAssessment)
        let planCount = wantsExercises ? goal.requestedWorkoutPlanCount : 0
        let outputLineRU = goal.requestedOutputs.map { $0.title(lang: "ru") }.joined(separator: ", ")
        let outputLineEN = goal.requestedOutputs.map { $0.title(lang: "en") }.joined(separator: ", ")
        let fixedInstructionRU = fixedExercises == nil ? "" : """

            ВАЖНО: список упражнений уже изменён пользователем. В поле
            recommended_exercises используй ровно эти exercise_id из каталога ниже,
            не добавляй и не удаляй упражнения. Можно изменить только sets, reps и note.
            """
        let fixedInstructionEN = fixedExercises == nil ? "" : """

            IMPORTANT: the exercise list has already been edited by the user. In
            recommended_exercises use exactly these exercise_id values from the catalog below;
            do not add or remove exercises. You may only adjust sets, reps and note.
            """
        let fixedNutritionRU = fixedNutrition.map { plan in
            return """

                ВАЖНО: пользователь вручную изменил питание. Используй эти значения как
                фиксированные входные данные и верни их без изменения:
                days_to_goal=\(plan.daysToGoal), daily_calories=\(plan.dailyCalories),
                protein_g=\(plan.proteinG), fat_g=\(plan.fatG), carbs_g=\(plan.carbsG),
                water_target_ml=\(plan.waterTargetML).
                foods: \(plan.foods.joined(separator: ", "))
                Остальные поля адаптируй под эти значения.
                """
        } ?? ""
        let fixedNutritionEN = fixedNutrition.map { plan in
            return """

                IMPORTANT: the user manually edited nutrition. Treat these values as fixed
                input and return them unchanged:
                days_to_goal=\(plan.daysToGoal), daily_calories=\(plan.dailyCalories),
                protein_g=\(plan.proteinG), fat_g=\(plan.fatG), carbs_g=\(plan.carbsG),
                water_target_ml=\(plan.waterTargetML).
                foods: \(plan.foods.joined(separator: ", "))
                Adapt the remaining fields around these values.
                """
        } ?? ""

        let fieldSpecRU = """
        Обязательные поля JSON:
        assessment string; days_to_goal integer; daily_calories integer;
        protein_g integer; fat_g integer; carbs_g integer;
        foods array of 5-8 strings; water_target_ml integer; tips array of 2-4 strings;
        workout_focus array; workout_plans array of \(planCount)
        objects if упражнения запрошены, otherwise empty array. Each object:
        {title string, focus array of strings, exercises array of 5-6 objects
        {exercise_id string, sets integer, reps string, note string}};
        recommended_exercises array with the same exercises flattened.
        Никогда не пропускай ключи days_to_goal, daily_calories, protein_g,
        fat_g, carbs_g, water_target_ml. Даже если раздел не запрошен,
        числовые ключи верни с расчётным или базовым значением.
        Если раздел не запрошен пользователем, оставь его содержимое пустым:
        assessment empty string unless requested; foods/tips empty arrays unless calories/macros
        requested; workout arrays empty unless exercises requested.
        """
        let fieldSpecEN = """
        Required JSON fields:
        assessment string; days_to_goal integer; daily_calories integer;
        protein_g integer; fat_g integer; carbs_g integer;
        foods array; water_target_ml integer; tips array;
        workout_focus array; workout_plans array of \(planCount)
        objects if exercises are requested, otherwise an empty array. Each object:
        {title string, focus array of strings, exercises array of 5-6 objects
        {exercise_id string, sets integer, reps string, note string}};
        recommended_exercises array with the same exercises flattened.
        Never omit days_to_goal, daily_calories, protein_g, fat_g, carbs_g,
        water_target_ml. Even if a section was not requested, return numeric
        keys with a calculated or baseline value.
        If a section was not requested, keep its content empty:
        assessment empty string unless requested; foods/tips empty arrays unless calories/macros
        requested; workout arrays empty unless exercises requested.
        """

        let system: String
        let userText: String
        if lang == "ru" {
            system = """
            Ты спортивный нутрициолог и тренер. Отвечай строго JSON-объектом без markdown.
            Все пользовательские текстовые значения в JSON должны быть только на русском:
            assessment, foods, tips, workout_focus,
            recommended_exercises.note. Не используй английские названия еды и приёмов пищи.
            Числа days_to_goal, daily_calories, protein_g, fat_g, carbs_g и
            water_target_ml всегда возвращай. Если раздел не запрошен,
            используй расчётный ориентир приложения, но не пропускай ключи.
            Не используй шаблонные значения по умолчанию для запрошенных разделов.
            Если упражнения запрошены, используй только exercise_id из каталога кандидатов.
            Составь \(planCount) тренировочную сборку/сборки. В каждой сборке 5-6 упражнений.
            Если сборок больше одной, разделяй их по разным мышечным акцентам и
            равномерно распределяй нагрузку по целям пользователя.
            Не ставь медицинский диагноз. Если есть фотографии, оценивай только общую
            композицию тела, осанку и очевидные тренировочные акценты без категоричных выводов.
            Если запрошено мнение о лице, не оценивай привлекательность и не ставь диагноз:
            дай только осторожные наблюдения по фото, ракурсу, выражению и общему виду.
            Отвечай кратко. Поле assessment должно быть коротким и реалистичным.
            Поле note у каждого упражнения — максимум 8 слов.
            \(fieldSpecRU)
            """
            userText = """
            Профиль: рост \(Int(profile.heightCM)) см, текущий вес \(fmt(profile.weightKG)) кг,
            пол: \(gender), желаемый вес \(fmt(goal.targetWeightKG)) кг.
            Пользователь хочет получить от ИИ только: \(outputLineRU).
            Ответы пользователя: \(goal.promptSummary(lang: lang))
            Расчётный ориентир приложения: \(baseline.days) дней до цели,
            \(baseline.calories) ккал/день, Б/Ж/У \(baseline.protein)/\(baseline.fat)/\(baseline.carbs) г,
            вода \(baseline.water) мл. Используй это как стартовую оценку, но адаптируй
            только для запрошенных разделов под ответы пользователя, фото и выбранные упражнения.

            Каталог ниже выбран приложением из всей библиотеки \(exercises.count) упражнений
            как наиболее релевантный и разнообразный набор кандидатов.

            Важно:
            - используй только exercise_id из списка ниже;
            - не придумывай новые exercise_id;
            - если упражнения не запрошены, верни workout_focus, workout_plans и
              recommended_exercises пустыми массивами;
            - если упражнения запрошены, выбери 5-6 упражнений в каждую сборку;
            - количество сборок: \(planCount);
            - упражнения должны подходить цели пользователя;
            - строго учитывай место тренировок и доступный инвентарь;
            - если выбрано «Дома» или «Только дома», не выбирай штангу, тренажёры,
              Смит-машину, кабельные и рычажные тренажёры, если они явно не указаны
              в доступном инвентаре;
            - если выбрано «Беречь спину», избегай осевой нагрузки, тяжёлых тяг
              и упражнений, где целевая мышца spine/lower back;
            - не выбирай слишком много похожих упражнений;
            - если цель — похудение, добавь больше базовых и энергозатратных упражнений;
            - если цель — набор массы, добавь больше силовых упражнений;
            - если цель — рельеф, сочетай силовые и упражнения на корпус/выносливость.

            Каждая строка: id|name|target|equipment.
            \(catalog)

            Составь только запрошенные пользователем разделы. Не добавляй лишние блоки.
            Калории/БЖУ запрошены: \(wantsCalories ? "да" : "нет").
            Если калории/БЖУ запрошены, верни дневные калории, предпочтительное БЖУ
            и короткий список еды без режима питания по часам.
            Вода запрошена: \(wantsWater ? "да" : "нет").
            Упражнения запрошены: \(wantsExercises ? "да" : "нет").
            Оценка фигуры запрошена: \(wantsBodyAssessment ? "да" : "нет").
            Оценка лица запрошена: \(wantsFaceAssessment ? "да" : "нет").
            \(fixedInstructionRU)
            \(fixedNutritionRU)
            """
        } else {
            system = """
            You are a sports nutritionist and trainer. Reply strictly as a JSON object, no markdown.
            All user-facing text values in JSON must be English: assessment, foods,
            tips, workout_focus and recommended_exercises.note.
            Always return days_to_goal, daily_calories, protein_g, fat_g,
            carbs_g and water_target_ml. If a section was not requested, use
            the app baseline, but do not omit the keys.
            Do not use default template values for requested sections.
            If exercises are requested, use only exercise_id values from the candidate catalog.
            Build \(planCount) workout plan block(s). Each block must contain 5-6 exercises. If there is
            more than one block, split them by different muscle priorities and distribute
            load evenly according to the user's goals.
            Do not diagnose medical conditions. If photos are attached, assess only broad body
            composition, posture and training priorities without categorical claims.
            If face assessment is requested, do not rate attractiveness and do not diagnose:
            give only cautious observations about photo angle, expression and general appearance.
            Keep the answer concise. The assessment field must be short and realistic.
            Each exercise note must be 8 words or fewer.
            \(fieldSpecEN)
            """
            userText = """
            Profile: height \(Int(profile.heightCM)) cm, current weight \(fmt(profile.weightKG)) kg,
            gender: \(gender), target weight \(fmt(goal.targetWeightKG)) kg.
            The user wants only these AI sections: \(outputLineEN).
            User answers: \(goal.promptSummary(lang: lang))
            App baseline estimate: \(baseline.days) days to goal,
            \(baseline.calories) kcal/day, P/F/C \(baseline.protein)/\(baseline.fat)/\(baseline.carbs) g,
            water \(baseline.water) ml. Use this as a starting point only for requested
            sections, adapting to the user's answers, photos and selected exercises.

            The catalog below was selected by the app from the full library of \(exercises.count)
            exercises as the most relevant and diverse candidate set.

            Important:
            - use only exercise_id values from the list below;
            - do not invent new exercise_id values;
            - if exercises are not requested, return workout_focus, workout_plans and
              recommended_exercises as empty arrays;
            - if exercises are requested, choose 5-6 exercises per workout block;
            - number of workout blocks: \(planCount);
            - exercises must match the user's goal;
            - strictly respect training location and available equipment;
            - if Home or Home only is selected, do not choose barbell, gym machines,
              Smith machine, cable or leverage-machine exercises unless that equipment
              is explicitly available;
            - if Protect back is selected, avoid axial loading, heavy deadlift patterns
              and exercises targeting spine/lower back;
            - avoid too many similar exercises;
            - if the goal is weight loss, include more compound and energy-demanding exercises;
            - if the goal is muscle gain, include more strength exercises;
            - if the goal is definition, combine strength with core/endurance exercises.

            Each line is id|name|target|equipment.
            \(catalog)

            Build only the sections requested by the user. Do not add unnecessary blocks.
            Calories/macros requested: \(wantsCalories ? "yes" : "no").
            Water requested: \(wantsWater ? "yes" : "no").
            Exercises requested: \(wantsExercises ? "yes" : "no").
            Body assessment requested: \(wantsBodyAssessment ? "yes" : "no").
            Face assessment requested: \(wantsFaceAssessment ? "yes" : "no").
            \(fixedInstructionEN)
            \(fixedNutritionEN)
            """
        }

        var userContent: Any = userText
        if !photos.isEmpty {
            var parts: [[String: Any]] = [["type": "text", "text": userText]]
            for photo in photos.prefix(4) {
                let base64 = photo.data.base64EncodedString()
                parts.append([
                    "type": "image_url",
                    "image_url": ["url": "data:\(photo.mimeType);base64,\(base64)"],
                ])
            }
            userContent = parts
        }

        return [
            ["role": "system", "content": system],
            ["role": "user", "content": userContent],
        ]
    }

    public static func fullPlanResponseFormat(useSchema: Bool = true) -> [String: Any] {
        guard useSchema else { return ["type": "json_object"] }
        return [
            "type": "json_schema",
            "json_schema": [
                "name": "fitness_goal_plan",
                "strict": false,
                "schema": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": [
                        "assessment", "days_to_goal", "daily_calories",
                        "protein_g", "fat_g", "carbs_g", "foods", "tips",
                        "water_target_ml", "workout_focus", "workout_plans",
                        "recommended_exercises",
                    ],
                    "properties": [
                        "assessment": ["type": "string"],
                        "days_to_goal": ["type": "integer"],
                        "daily_calories": ["type": "integer"],
                        "protein_g": ["type": "integer"],
                        "fat_g": ["type": "integer"],
                        "carbs_g": ["type": "integer"],
                        "foods": [
                            "type": "array",
                            "maxItems": 8,
                            "items": ["type": "string"],
                        ],
                        "water_target_ml": [
                            "type": "integer",
                            "minimum": 1200,
                            "maximum": 5000,
                        ],
                        "tips": [
                            "type": "array",
                            "maxItems": 4,
                            "items": ["type": "string"],
                        ],
                        "workout_focus": [
                            "type": "array",
                            "maxItems": 6,
                            "items": ["type": "string"],
                        ],
                        "workout_plans": [
                            "type": "array",
                            "maxItems": 3,
                            "items": [
                                "type": "object",
                                "additionalProperties": false,
                                "required": ["title", "focus", "exercises"],
                                "properties": [
                                    "title": ["type": "string"],
                                    "focus": [
                                        "type": "array",
                                        "maxItems": 4,
                                        "items": ["type": "string"],
                                    ],
                                    "exercises": [
                                        "type": "array",
                                        "minItems": 5,
                                        "maxItems": 6,
                                        "items": [
                                            "type": "object",
                                            "additionalProperties": false,
                                            "required": ["exercise_id", "sets", "reps", "note"],
                                            "properties": [
                                                "exercise_id": ["type": "string"],
                                                "sets": ["type": "integer"],
                                                "reps": ["type": "string"],
                                                "note": ["type": "string"],
                                            ],
                                        ],
                                    ],
                                ],
                            ],
                        ],
                        "recommended_exercises": [
                            "type": "array",
                            "maxItems": 18,
                            "items": [
                                "type": "object",
                                "additionalProperties": false,
                                "required": ["exercise_id", "sets", "reps", "note"],
                                "properties": [
                                    "exercise_id": ["type": "string"],
                                    "sets": ["type": "integer"],
                                    "reps": ["type": "string"],
                                    "note": ["type": "string"],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    public static func fullPlanRequestBody(
        model: String, profile: UserProfile, goal: UserGoal, exercises: [Exercise],
        photos: [GoalPhotoPayload] = [], lang: String = "ru", useSchema: Bool = true,
        fixedExerciseIDs: [String]? = nil,
        fixedNutrition: NutritionPlan? = nil
    ) -> [String: Any] {
        [
            "model": model,
            "temperature": 0.25,
            "max_completion_tokens": 1500,
            "response_format": fullPlanResponseFormat(useSchema: useSchema),
            "messages": buildFullPlanMessages(
                profile: profile, goal: goal, exercises: exercises,
                photos: photos, lang: lang, fixedExerciseIDs: fixedExerciseIDs,
                fixedNutrition: fixedNutrition),
        ]
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    public static func baselinePlanNumbers(
        profile: UserProfile, goal: UserGoal
    ) -> (days: Int, calories: Int, protein: Int, fat: Int, carbs: Int, water: Int) {
        let assumedAge = 30.0
        let genderTerm: Double
        switch profile.gender {
        case .female: genderTerm = -161
        case .male: genderTerm = 5
        case .notSet: genderTerm = -78
        }
        let bmr = 10 * profile.weightKG + 6.25 * profile.heightCM - 5 * assumedAge + genderTerm
        let activityFactor: Double
        switch goal.trainingDaysPerWeek {
        case 1...2: activityFactor = 1.35
        case 3: activityFactor = 1.45
        case 4: activityFactor = 1.55
        default: activityFactor = 1.65
        }
        let tdee = bmr * activityFactor
        let delta = goal.targetWeightKG - profile.weightKG
        let weeklyRate: Double = delta < 0 ? -0.55 : 0.35
        let days = max(21, Int((abs(delta) / abs(weeklyRate) * 7).rounded()))
        let calorieShift = delta < 0 ? -450.0 : delta > 0 ? 300.0 : 0.0
        let calories = Int((min(max(tdee + calorieShift, 1300), 4200) / 25).rounded() * 25)
        let proteinMultiplier = goal.trainingGoals.contains(.muscleGain)
            || goal.trainingGoals.contains(.strength) ? 2.0 : 1.7
        let protein = Int((profile.weightKG * proteinMultiplier).rounded())
        let fat = Int(max(45, (Double(calories) * 0.25 / 9).rounded()))
        let carbs = max(60, Int(((Double(calories) - Double(protein * 4 + fat * 9)) / 4).rounded()))
        let water = Int((min(max(profile.weightKG * 32, 1800), 4500) / 50).rounded() * 50)
        return (days, calories, protein, fat, carbs, water)
    }

    public func requestPlan(
        goal: UserGoal, exercises: [Exercise], lang: String = "ru"
    ) async throws -> NutritionPlan {
        var request = URLRequest(
            url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.3,
            "response_format": ["type": "json_object"],
            "messages": Self.buildMessages(goal: goal, exercises: exercises, lang: lang),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let msg = Self.apiErrorMessage(data) ?? String(decoding: data, as: UTF8.self)
            throw GroqError.http(code, String(msg.prefix(200)))
        }
        return try Self.parsePlan(from: data)
    }

    public func requestFullPlan(
        profile: UserProfile, goal: UserGoal, exercises: [Exercise],
        photos: [GoalPhotoPayload] = [], lang: String = "ru",
        fixedExerciseIDs: [String]? = nil,
        fixedNutrition: NutritionPlan? = nil
    ) async throws -> NutritionPlan {
        try await requestFullPlanResult(
            profile: profile, goal: goal, exercises: exercises,
            photos: photos, lang: lang, fixedExerciseIDs: fixedExerciseIDs,
            fixedNutrition: fixedNutrition
        ).plan
    }

    public func requestFullPlanResult(
        profile: UserProfile, goal: UserGoal, exercises: [Exercise],
        photos: [GoalPhotoPayload] = [], lang: String = "ru",
        fixedExerciseIDs: [String]? = nil,
        fixedNutrition: NutritionPlan? = nil
    ) async throws -> GroqPlanResponse {
        let body = Self.fullPlanRequestBody(
            model: model, profile: profile, goal: goal, exercises: exercises,
            photos: photos, lang: lang, useSchema: true,
            fixedExerciseIDs: fixedExerciseIDs, fixedNutrition: fixedNutrition)
        do {
            return try await sendPlanRequestWithUsage(body: body, timeout: 180)
        } catch GroqError.http(let code, _) where code == 400 {
            let fallbackBody = Self.fullPlanRequestBody(
                model: model, profile: profile, goal: goal, exercises: exercises,
                photos: photos, lang: lang, useSchema: false,
                fixedExerciseIDs: fixedExerciseIDs, fixedNutrition: fixedNutrition)
            return try await sendPlanRequestWithUsage(body: fallbackBody, timeout: 180)
        }
    }

    public func requestChoiceAdvice(
        profile: UserProfile, goal: UserGoal, workout: [Exercise], lang: String = "ru"
    ) async throws -> String {
        try await requestChoiceAdviceResult(
            profile: profile, goal: goal, workout: workout, lang: lang
        ).text
    }

    public func requestChoiceAdviceResult(
        profile: UserProfile, goal: UserGoal, workout: [Exercise], lang: String = "ru"
    ) async throws -> GroqTextResponse {
        let selected = workout.prefix(60).map {
            "\($0.name)|\($0.target)|\($0.equipment)"
        }.joined(separator: "\n")
        let baseline = Self.baselinePlanNumbers(profile: profile, goal: goal)
        let system: String
        let user: String
        if lang == "ru" {
            system = """
            Ты опытный фитнес-тренер. Ответь только на русском, без markdown.
            Оцени ручной выбор пользователя: цель, ограничения, частоту тренировок и
            выбранный список упражнений. Не составляй новый полный план.
            Дай короткий вывод: что хорошо, что рискованно, что поменять в первую очередь.
            Если список упражнений пустой, честно скажи, каких типов упражнений не хватает.
            Максимум 10 коротких строк.
            """
            user = """
            Профиль: рост \(Int(profile.heightCM)) см, вес \(Self.fmt(profile.weightKG)) кг,
            пол \(profile.gender.title(lang: lang)), желаемый вес \(Self.fmt(goal.targetWeightKG)) кг.
            Ответы: \(goal.promptSummary(lang: lang)).
            Ориентир приложения: \(baseline.days) дней, \(baseline.calories) ккал,
            БЖУ \(baseline.protein)/\(baseline.fat)/\(baseline.carbs), вода \(baseline.water) мл.
            Ручной список упражнений:
            \(selected.isEmpty ? "пустой" : selected)
            """
        } else {
            system = """
            You are an experienced fitness coach. Reply only in English, no markdown.
            Review the user's manual choices: goal, limitations, training frequency and
            selected exercise list. Do not create a full new plan.
            Give a short verdict: what is good, what is risky, what to change first.
            If the exercise list is empty, say which exercise types are missing.
            Maximum 10 short lines.
            """
            user = """
            Profile: height \(Int(profile.heightCM)) cm, weight \(Self.fmt(profile.weightKG)) kg,
            gender \(profile.gender.title(lang: lang)), target weight \(Self.fmt(goal.targetWeightKG)) kg.
            Answers: \(goal.promptSummary(lang: lang)).
            App estimate: \(baseline.days) days, \(baseline.calories) kcal,
            P/F/C \(baseline.protein)/\(baseline.fat)/\(baseline.carbs), water \(baseline.water) ml.
            Manual exercise list:
            \(selected.isEmpty ? "empty" : selected)
            """
        }
        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "max_completion_tokens": 650,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        return try await sendTextRequestWithUsage(body: body, timeout: 75)
    }

    private func sendPlanRequest(
        body: [String: Any], timeout: TimeInterval
    ) async throws -> NutritionPlan {
        try await sendPlanRequestWithUsage(body: body, timeout: timeout).plan
    }

    private func sendPlanRequestWithUsage(
        body: [String: Any], timeout: TimeInterval
    ) async throws -> GroqPlanResponse {
        var request = URLRequest(
            url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let msg = Self.apiErrorMessage(data) ?? String(decoding: data, as: UTF8.self)
            throw GroqError.http(code, String(msg.prefix(200)))
        }
        return GroqPlanResponse(
            plan: try Self.parsePlan(from: data),
            usage: Self.parseUsage(from: data)
        )
    }

    private func sendTextRequest(body: [String: Any], timeout: TimeInterval) async throws -> String {
        try await sendTextRequestWithUsage(body: body, timeout: timeout).text
    }

    private func sendTextRequestWithUsage(
        body: [String: Any], timeout: TimeInterval
    ) async throws -> GroqTextResponse {
        var request = URLRequest(
            url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let msg = Self.apiErrorMessage(data) ?? String(decoding: data, as: UTF8.self)
            throw GroqError.http(code, String(msg.prefix(200)))
        }
        return GroqTextResponse(
            text: try Self.parseText(from: data),
            usage: Self.parseUsage(from: data)
        )
    }

    public static func apiErrorMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any]
        else { return nil }
        return error["message"] as? String
    }

    /// Extracts choices[0].message.content and decodes the plan JSON inside it.
    public static func parsePlan(from data: Data) throws -> NutritionPlan {
        let text = try parseText(from: data)
        let candidates = [text, extractJSONObject(from: text)].compactMap { $0 }
        for candidate in candidates {
            guard let planData = candidate.data(using: .utf8) else { continue }
            if let plan = try? JSONDecoder().decode(NutritionPlan.self, from: planData) {
                return plan
            }
        }
        throw GroqError.badPlanJSON(text)
    }

    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = start

        while index < text.endIndex {
            let char = text[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = inString
            } else if char == "\"" {
                inString.toggle()
            } else if !inString {
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[start ... index])
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    public static func parseText(from data: Data) throws -> String {
        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let content = envelope.choices.first?.message.content
        else { throw GroqError.emptyResponse }

        // Trim occasional code fences despite json_object mode.
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    public static func parseUsage(from data: Data) -> GroqUsage? {
        struct Envelope: Decodable {
            struct Usage: Decodable {
                let promptTokens: Int?
                let completionTokens: Int?
                let totalTokens: Int?

                enum CodingKeys: String, CodingKey {
                    case promptTokens = "prompt_tokens"
                    case completionTokens = "completion_tokens"
                    case totalTokens = "total_tokens"
                }
            }
            let usage: Usage?
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let usage = envelope.usage
        else { return nil }
        return GroqUsage(
            promptTokens: usage.promptTokens ?? 0,
            completionTokens: usage.completionTokens ?? 0,
            totalTokens: usage.totalTokens ?? 0
        )
    }
}
