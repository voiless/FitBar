import Foundation

// MARK: - Exercise

public struct Exercise: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let category: String
    public let bodyPart: String
    public let equipment: String
    public let instructions: [String: String]
    public let instructionSteps: [String: [String]]
    public let muscleGroup: String
    public let secondaryMuscles: [String]
    public let target: String
    public let mediaID: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, equipment, instructions, target
        case bodyPart = "body_part"
        case instructionSteps = "instruction_steps"
        case muscleGroup = "muscle_group"
        case secondaryMuscles = "secondary_muscles"
        case mediaID = "media_id"
    }

    public func steps(lang: String) -> [String] {
        let supportedLang = lang == "ru" ? "ru" : "en"
        return instructionSteps[supportedLang] ?? instructionSteps["en"] ?? []
    }

    /// Localized display name: Russian translation when lang == "ru",
    /// capitalized original otherwise.
    public func displayName(lang: String) -> String {
        if lang == "ru", let ru = ExerciseNamesRU.byID[id] { return ru }
        return name.capitalized
    }
}

/// Bundled Russian exercise-name overrides from names_ru.json.
public enum ExerciseNamesRU {
    public static let byID: [String: String] = {
        guard let url = Bundle.module.url(forResource: "names_ru", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict.mapValues(normalize)
    }()

    private static func normalize(_ raw: String) -> String {
        var s = raw
        let replacements: [(String, String)] = [
            ("Сид-ап", "Скручивание"),
            ("Русский скручивание", "Русские скручивания"),
            ("Доска Баланса", "Планка на баланс"),
            ("Жим Штанги Лежа", "Жим штанги лёжа"),
            ("Жим штанги лежа", "Жим штанги лёжа"),
            ("В Наклоне", "в наклоне"),
            ("На Наклонной Скамье", "на наклонной скамье"),
            ("С Узким Хватом", "узким хватом"),
            ("С Широким Хватом", "широким хватом"),
            ("С Обратным Хватом", "обратным хватом"),
            ("С Низким Хватом", "низким положением штанги"),
            ("С Высоким Хватом", "высоким положением штанги"),
            ("С Штангой", "со штангой"),
            ("Штанги", "штанги"),
            ("Приседания С", "Приседания с"),
            ("Сгибание Рук", "Сгибание рук"),
            ("Разгибание Рук", "Разгибание рук"),
            ("Разгибание Трицепсов", "Разгибание на трицепс"),
            ("Подъем", "Подъём"),
            ("Подъемы", "Подъёмы"),
            ("Тяга В", "Тяга в"),
            ("Выпад С", "Выпад с"),
            ("Выпады С", "Выпады с"),
            ("На Скамье", "на скамье"),
            ("На Полу", "на полу"),
            ("С Одной Рукой", "одной рукой"),
            ("На Одной Ноге", "на одной ноге"),
            ("Над Головой", "над головой"),
            ("В Стоячем Положении", "стоя"),
            ("В Лежачем Положении", "лёжа"),
            ("В Сидячем Положении", "сидя"),
            ("С Помощью", "с ассистентом"),
            ("с помощью", "с ассистентом"),
            ("Квадрицепсов", "квадрицепса"),
            ("Пречера", "Скотта"),
            ("Гуд Манинга", "гудморнинг"),
            ("Хак-Сквоте", "хак-приседе"),
            ("Армбластером", "арм-бластером"),
            ("Джи-Эм", "JM"),
            ("Зерхеровской Схеме", "Зерхера"),
            ("Давлением На Череп", "skull crusher"),
            ("Ладонями Вниз", "ладонями вниз"),
            ("Ладонями Вверх", "ладонями вверх"),
            ("Вид Сзади", "вид сзади"),
            ("Вид С Боку", "вид сбоку"),
        ]
        for (from, to) in replacements {
            s = s.replacingOccurrences(of: from, with: to)
        }
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s
    }

    public static let duplicateNames: Set<String> = {
        let grouped = Dictionary(grouping: byID.values) { $0 }
        return Set(grouped.compactMap { $0.value.count > 1 ? $0.key : nil })
    }()
}

// MARK: - Dataset loading

public enum ExerciseDataset {
    public static func load() throws -> [Exercise] {
        guard let url = Bundle.module.url(forResource: "exercises", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Exercise].self, from: data)
    }
}

// MARK: - Sorting / filtering (pure, testable)

public enum SortOrder: String, CaseIterable, Codable {
    case name, category, target, equipment

    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.name, "ru"): return "По названию"
        case (.category, "ru"): return "По части тела"
        case (.target, "ru"): return "По целевой мышце"
        case (.equipment, "ru"): return "По инвентарю"
        case (.name, _): return "By name"
        case (.category, _): return "By body part"
        case (.target, _): return "By target muscle"
        case (.equipment, _): return "By equipment"
        }
    }
}

public enum ExerciseQuery {
    public static func apply(
        _ exercises: [Exercise],
        search: String = "",
        category: String? = nil,
        equipment: String? = nil,
        target: String? = nil,
        sort: SortOrder = .name,
        lang: String = "en"
    ) -> [Exercise] {
        var result = exercises
        if let category { result = result.filter { $0.category == category } }
        if let equipment { result = result.filter { $0.equipment == equipment } }
        if let target { result = result.filter { $0.target == target } }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            let terms = query.split(separator: " ").map(String.init)
            result = result.filter { ex in
                let haystack = [
                    ex.name, ex.target, ex.equipment, ex.muscleGroup, ex.category,
                    ExerciseNamesRU.byID[ex.id] ?? "",
                    RU.target(ex.target), RU.equipment(ex.equipment), RU.category(ex.category),
                ].joined(separator: " ").lowercased()
                return terms.allSatisfy { haystack.contains($0) }
            }
        }

        switch sort {
        case .name:
            result.sort {
                $0.displayName(lang: lang)
                    .localizedStandardCompare($1.displayName(lang: lang))
                    == .orderedAscending
            }
        case .category:
            result.sort {
                ($0.category, $0.name.lowercased()) < ($1.category, $1.name.lowercased())
            }
        case .target:
            result.sort {
                ($0.target, $0.name.lowercased()) < ($1.target, $1.name.lowercased())
            }
        case .equipment:
            result.sort {
                ($0.equipment, $0.name.lowercased()) < ($1.equipment, $1.name.lowercased())
            }
        }
        return result
    }
}

// MARK: - Russian labels

public enum RU {
    public static let categories: [String: String] = [
        "back": "Спина",
        "cardio": "Кардио",
        "chest": "Грудь",
        "lower arms": "Предплечья",
        "lower legs": "Голени",
        "neck": "Шея",
        "shoulders": "Плечи",
        "upper arms": "Руки",
        "upper legs": "Бёдра",
        "waist": "Кор",
    ]

    public static let equipmentMap: [String: String] = [
        "body weight": "Свой вес",
        "dumbbell": "Гантели",
        "cable": "Блок",
        "barbell": "Штанга",
        "leverage machine": "Рычажный тренажёр",
        "band": "Резинка",
        "smith machine": "Машина Смита",
        "kettlebell": "Гиря",
        "weighted": "С отягощением",
        "stability ball": "Фитбол",
        "ez barbell": "EZ-штанга",
        "assisted": "С поддержкой",
        "sled machine": "Тренажёр-салазки",
        "medicine ball": "Медбол",
        "rope": "Канат",
        "roller": "Ролик",
        "resistance band": "Эспандер",
        "bosu ball": "Босу",
        "olympic barbell": "Олимпийская штанга",
        "wheel roller": "Ролик для пресса",
        "upper body ergometer": "Эргометр",
        "skierg machine": "SkiErg",
        "hammer": "Кувалда",
        "stationary bike": "Велотренажёр",
        "tire": "Покрышка",
        "trap bar": "Трэп-гриф",
        "elliptical machine": "Эллипсоид",
        "stepmill machine": "Степмилл",
    ]

    public static let targets: [String: String] = [
        "abs": "Пресс",
        "pectorals": "Грудные",
        "biceps": "Бицепсы",
        "glutes": "Ягодицы",
        "delts": "Дельты",
        "triceps": "Трицепсы",
        "upper back": "Верх спины",
        "lats": "Широчайшие",
        "calves": "Икры",
        "quads": "Квадрицепсы",
        "forearms": "Предплечья",
        "cardiovascular system": "Сердце и сосуды",
        "hamstrings": "Бицепсы бедра",
        "spine": "Разгибатели спины",
        "traps": "Трапеции",
        "adductors": "Приводящие",
        "serratus anterior": "Зубчатые",
        "abductors": "Отводящие",
        "levator scapulae": "Мышцы лопатки",
    ]

    public static let muscles: [String: String] = targets.merging([
        "abdominals": "Пресс",
        "ankle stabilizers": "Стабилизаторы голеностопа",
        "ankles": "Голеностоп",
        "back": "Спина",
        "brachialis": "Плечевая мышца",
        "chest": "Грудь",
        "core": "Кор",
        "deltoids": "Дельты",
        "feet": "Стопы",
        "grip muscles": "Мышцы хвата",
        "groin": "Паховая область",
        "hands": "Кисти",
        "hip flexors": "Сгибатели бедра",
        "inner thighs": "Внутренняя поверхность бедра",
        "latissimus dorsi": "Широчайшие",
        "lower abs": "Нижний пресс",
        "lower back": "Поясница",
        "obliques": "Косые мышцы",
        "quadriceps": "Квадрицепсы",
        "rear deltoids": "Задние дельты",
        "rhomboids": "Ромбовидные",
        "rotator cuff": "Ротаторная манжета",
        "shins": "Передняя поверхность голени",
        "shoulders": "Плечи",
        "soleus": "Камбаловидная",
        "sternocleidomastoid": "Грудино-ключично-сосцевидная",
        "trapezius": "Трапеции",
        "upper chest": "Верх груди",
        "wrist extensors": "Разгибатели запястья",
        "wrist flexors": "Сгибатели запястья",
        "wrists": "Запястья",
    ]) { current, _ in current }

    public static func category(_ raw: String) -> String { categories[raw] ?? raw.capitalized }
    public static func equipment(_ raw: String) -> String { equipmentMap[raw] ?? raw.capitalized }
    public static func target(_ raw: String) -> String { targets[raw] ?? raw.capitalized }
    public static func muscle(_ raw: String) -> String { muscles[raw] ?? raw.capitalized }
}

// MARK: - Body-part styling (icon + hue)

public enum BodyPartStyle {
    public static func icon(_ category: String) -> String {
        switch category {
        case "back": return "figure.rower"
        case "cardio": return "figure.run"
        case "chest": return "figure.arms.open"
        case "lower arms": return "hand.raised.fill"
        case "lower legs": return "figure.walk"
        case "neck": return "person.bust"
        case "shoulders": return "figure.boxing"
        case "upper arms": return "figure.strengthtraining.traditional"
        case "upper legs": return "figure.step.training"
        case "waist": return "figure.core.training"
        default: return "figure.mixed.cardio"
        }
    }

    /// Stable hue (0...1) per body part, used to build accent colors.
    public static func hue(_ category: String) -> Double {
        switch category {
        case "back": return 0.58        // blue
        case "cardio": return 0.98      // red-pink
        case "chest": return 0.03       // orange-red
        case "lower arms": return 0.12  // amber
        case "lower legs": return 0.45  // teal
        case "neck": return 0.75        // purple
        case "shoulders": return 0.66   // indigo
        case "upper arms": return 0.08  // orange
        case "upper legs": return 0.35  // green
        case "waist": return 0.52       // cyan
        default: return 0.6
        }
    }
}

// MARK: - Exercise-specific visual styling

public enum ExerciseVisualStyle {
    public static func icon(_ exercise: Exercise) -> String {
        let name = exercise.name.lowercased()
        let equipment = exercise.equipment.lowercased()
        let target = exercise.target.lowercased()

        if name.contains("run") || name.contains("jog") || name.contains("sprint")
            || name.contains("burpee") || name.contains("mountain climber") {
            return "figure.run"
        }
        if name.contains("walk") || name.contains("step") {
            return "figure.walk"
        }
        if name.contains("bike") || name.contains("bicycle") || name.contains("cycle") {
            return "bicycle"
        }
        if name.contains("row") || name.contains("rowing") {
            return "figure.rower"
        }
        if name.contains("jump") || name.contains("hop") {
            return "figure.jumprope"
        }
        if name.contains("punch") || name.contains("boxing") {
            return "figure.boxing"
        }
        if name.contains("plank") || name.contains("crunch") || name.contains("sit-up")
            || name.contains("leg raise") || target == "abs" {
            return "figure.core.training"
        }
        if name.contains("squat") || name.contains("lunge") || name.contains("leg press") {
            return "figure.step.training"
        }
        if name.contains("pull-up") || name.contains("chin-up") || name.contains("pulldown") {
            return "figure.strengthtraining.traditional"
        }
        if name.contains("push-up") || name.contains("dip") || name.contains("press") {
            return "figure.arms.open"
        }
        if name.contains("curl") || target == "biceps" || target == "triceps" {
            return "dumbbell.fill"
        }
        if name.contains("raise") && (target == "delts" || exercise.category == "shoulders") {
            return "figure.boxing"
        }
        if name.contains("calf") || target == "calves" {
            return "figure.walk"
        }
        if name.contains("neck") || exercise.category == "neck" {
            return "person.bust"
        }
        if equipment.contains("dumbbell") || equipment.contains("barbell")
            || equipment.contains("kettlebell") || equipment.contains("weighted") {
            return "dumbbell.fill"
        }
        if equipment.contains("bike") {
            return "bicycle"
        }
        return BodyPartStyle.icon(exercise.category)
    }

    public static func muscleLine(_ exercise: Exercise, lang: String) -> String {
        let primary = lang == "ru" ? RU.muscle(exercise.target) : exercise.target.capitalized
        var seen = Set<String>()
        let secondary = exercise.secondaryMuscles
            .filter { $0 != exercise.target && seen.insert($0).inserted }
            .prefix(2)
            .map { lang == "ru" ? RU.muscle($0) : $0.capitalized }
        if secondary.isEmpty { return primary }
        return ([primary] + secondary).joined(separator: " + ")
    }
}

public enum UserGender: String, CaseIterable, Codable, Identifiable {
    case notSet
    case male
    case female

    public var id: String { rawValue }

    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.notSet, "ru"): return "Не указан"
        case (.male, "ru"): return "Мужской"
        case (.female, "ru"): return "Женский"
        case (.notSet, _): return "Not set"
        case (.male, _): return "Male"
        case (.female, _): return "Female"
        }
    }
}

public enum AppColorTheme: String, CaseIterable, Codable, Identifiable {
    case dark
    case monochrome

    public var id: String { rawValue }

    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.dark, "ru"): return "Тёмная"
        case (.monochrome, "ru"): return "Ч/Б"
        case (.dark, _): return "Dark"
        case (.monochrome, _): return "B/W"
        }
    }
}

public enum WaterTargetMode: String, CaseIterable, Codable, Identifiable {
    case standard
    case ai
    case custom

    public var id: String { rawValue }

    public func title(lang: String) -> String {
        switch (self, lang) {
        case (.standard, "ru"): return "Стандарт"
        case (.ai, "ru"): return "Норма ИИ"
        case (.custom, "ru"): return "Своя норма"
        case (.standard, _): return "Standard"
        case (.ai, _): return "AI target"
        case (.custom, _): return "Custom target"
        }
    }
}

public struct UserProfile: Codable, Equatable {
    public var nickname: String
    public var heightCM: Double
    public var weightKG: Double
    public var gender: UserGender
    public var targetWeightKG: Double?
    public var dailyCalories: Int?
    public var proteinG: Int?
    public var fatG: Int?
    public var carbsG: Int?
    public var waterTargetML: Int?
    public var waterTargetMode: WaterTargetMode?
    public var avatarImagePath: String?

    public init(
        nickname: String = "FitBar User",
        heightCM: Double = 175,
        weightKG: Double = 75,
        gender: UserGender = .notSet,
        targetWeightKG: Double? = nil,
        dailyCalories: Int? = nil,
        proteinG: Int? = nil,
        fatG: Int? = nil,
        carbsG: Int? = nil,
        waterTargetML: Int? = nil,
        waterTargetMode: WaterTargetMode? = nil,
        avatarImagePath: String? = nil
    ) {
        self.nickname = nickname
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.gender = gender
        self.targetWeightKG = targetWeightKG
        self.dailyCalories = dailyCalories
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.waterTargetML = waterTargetML
        self.waterTargetMode = waterTargetMode
        self.avatarImagePath = avatarImagePath
    }
}
