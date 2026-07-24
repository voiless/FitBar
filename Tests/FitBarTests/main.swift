import Foundation
import FitBarKit

// Minimal test harness (XCTest/Testing are unavailable without Xcode).

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("  ✗ FAIL (line \(line)): \(message)")
    }
}

func suite(_ name: String, _ body: () -> Void) {
    print("— \(name)")
    body()
}

@MainActor
func runAllTests() {
    let exercises: [Exercise] = (try? ExerciseDataset.load()) ?? []

    suite("Dataset") {
        expect(exercises.count == 1324, "dataset loads all 1324, got \(exercises.count)")
        expect(Set(exercises.map(\.id)).count == exercises.count, "ids are unique")

        var missingRU = 0, missingEN = 0
        for ex in exercises {
            if ex.steps(lang: "ru").isEmpty { missingRU += 1 }
            if ex.steps(lang: "en").isEmpty { missingEN += 1 }
        }
        expect(missingRU == 0, "\(missingRU) exercises missing ru steps")
        expect(missingEN == 0, "\(missingEN) exercises missing en steps")

        let ex = exercises[0]
        expect(ex.steps(lang: "xx") == ex.steps(lang: "en"),
               "unknown language falls back to English")

        for c in Set(exercises.map(\.category)) {
            expect(RU.categories[c] != nil, "no RU label for category \(c)")
            expect(BodyPartStyle.icon(c) != "figure.mixed.cardio",
                   "no dedicated icon for category \(c)")
        }
        for e in Set(exercises.map(\.equipment)) {
            expect(RU.equipmentMap[e] != nil, "no RU label for equipment \(e)")
        }
        for t in Set(exercises.map(\.target)) {
            expect(RU.targets[t] != nil, "no RU label for target \(t)")
        }
    }

    suite("Query: filter/search/sort") {
        let chest = ExerciseQuery.apply(exercises, category: "chest")
        expect(chest.count == 163, "chest = 163, got \(chest.count)")
        expect(chest.allSatisfy { $0.category == "chest" }, "category filter strict")

        let combo = ExerciseQuery.apply(exercises, equipment: "barbell", target: "quads")
        expect(!combo.isEmpty, "barbell+quads not empty")
        expect(combo.allSatisfy { $0.equipment == "barbell" && $0.target == "quads" },
               "combined filters strict")

        let pullups = ExerciseQuery.apply(exercises, search: "pull-up")
        expect(!pullups.isEmpty, "search pull-up finds results")
        expect(pullups.allSatisfy { $0.name.lowercased().contains("pull-up") },
               "search matches name")

        let a = ExerciseQuery.apply(exercises, search: "BARBELL squat")
        let b = ExerciseQuery.apply(exercises, search: "barbell squat")
        expect(a.map(\.id) == b.map(\.id) && !a.isEmpty, "search case-insensitive, multi-term")

        let ru = ExerciseQuery.apply(exercises, search: "гантели")
        expect(!ru.isEmpty && ru.allSatisfy { $0.equipment == "dumbbell" },
               "Russian search works (гантели → dumbbell)")

        let byName = ExerciseQuery.apply(exercises, sort: .name).map(\.name)
        expect(
            zip(byName, byName.dropFirst()).allSatisfy {
                $0.localizedStandardCompare($1) != .orderedDescending
            },
            "sort by name is non-descending")

        let byCat = ExerciseQuery.apply(exercises, sort: .category).map(\.category)
        expect(byCat == byCat.sorted(), "sort by category groups")

        expect(ExerciseQuery.apply(exercises, search: "   ").count == exercises.count,
               "blank search returns everything")
    }

    suite("ActivityLog") {
        var log = ActivityLog()
        let day = Date()
        log.logCompletion(exerciseID: "0001", on: day)
        log.logCompletion(exerciseID: "0001", on: day)
        log.logCompletion(exerciseID: "0002", on: day)
        expect(log.count(on: day) == 3, "3 completions today")
        expect(log.perExercise["0001"] == 2, "per-exercise count")
        expect(log.totalCompletions == 3, "total completions")

        log.logSet(exerciseID: "0001", reps: 12, durationSeconds: 45, on: day)
        expect(log.count(on: day) == 4, "set logging increments day count")
        expect(log.totalReps == 12, "set reps total")
        expect(log.totalDurationSeconds == 45, "set duration total")
        expect(log.maxRepsSet()?.reps == 12, "max reps set stored")
        let stats = log.stats(for: "0001")
        expect(stats.setCount == 1 && stats.totalReps == 12,
               "per-exercise set stats")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        log.logSet(exerciseID: "0001", reps: 40, durationSeconds: 90, on: yesterday)
        let todayStats = log.stats(for: "0001", on: day)
        expect(todayStats.setCount == 1
               && todayStats.totalReps == 12
               && todayStats.totalDurationSeconds == 45,
               "daily exercise stats exclude earlier days")
        log.addWater(250, on: day)
        log.addWater(100, on: day)
        expect(log.water(on: day) == 350, "water logging sums milliliters")
        expect(log.count(on: day) == 4, "water does not affect workout day count")

        var diary = DiaryState(isActive: true, startedAt: day)
        diary.refresh(using: ActivityLog(), today: day)
        let diaryKey = ActivityLog.dayKey(day)
        let emptyEntry = diary.entries[diaryKey]!
        diary.save(emptyEntry)
        expect(diary.entries[diaryKey]?.isSaved == true
               && diary.entries[diaryKey]?.hasMeaningfulData == false,
               "an intentionally empty diary day can be saved")

        var rec = ActivityLog()
        for _ in 0..<5 { rec.logCompletion(exerciseID: "a") }
        for _ in 0..<9 { rec.logCompletion(exerciseID: "b") }
        expect(rec.recordExercise()?.id == "b" && rec.recordExercise()?.count == 9,
               "record exercise picks max")
        expect(ActivityLog().recordExercise() == nil, "empty record is nil")

        expect(ActivityLog.level(for: 0) == 0, "level 0")
        expect(ActivityLog.level(for: 1) == 1 && ActivityLog.level(for: 2) == 1, "level 1")
        expect(ActivityLog.level(for: 3) == 2 && ActivityLog.level(for: 5) == 2, "level 2")
        expect(ActivityLog.level(for: 6) == 3 && ActivityLog.level(for: 9) == 3, "level 3")
        expect(ActivityLog.level(for: 10) == 4 && ActivityLog.level(for: 99) == 4, "level 4")

        let cal = Calendar.current
        let today = Date()
        var s = ActivityLog()
        for back in 0..<4 {
            s.logCompletion(exerciseID: "x",
                            on: cal.date(byAdding: .day, value: -back, to: today)!)
        }
        expect(s.streak(today: today) == 4, "streak counts consecutive days")

        var s2 = ActivityLog()
        for back in 1...3 {
            s2.logCompletion(exerciseID: "x",
                             on: cal.date(byAdding: .day, value: -back, to: today)!)
        }
        expect(s2.streak(today: today) == 3, "streak survives empty today")

        var s3 = ActivityLog()
        s3.logCompletion(exerciseID: "x", on: today)
        s3.logCompletion(exerciseID: "x",
                         on: cal.date(byAdding: .day, value: -2, to: today)!)
        expect(s3.streak(today: today) == 1, "streak broken by gap")

        let anchor = cal.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        var weekly = ActivityLog()
        weekly.logCompletion(exerciseID: "x", on: anchor)
        expect(weekly.trainingPlanStreak(
            requiredDaysPerWeek: 2,
            today: cal.date(byAdding: .day, value: 3, to: anchor)!) == 1,
               "weekly streak starts after first workout in current window")
        weekly.logCompletion(exerciseID: "x",
                             on: cal.date(byAdding: .day, value: 5, to: anchor)!)
        weekly.logCompletion(exerciseID: "x",
                             on: cal.date(byAdding: .day, value: 7, to: anchor)!)
        expect(weekly.trainingPlanStreak(
            requiredDaysPerWeek: 2,
            today: cal.date(byAdding: .day, value: 8, to: anchor)!) == 2,
               "weekly streak continues when previous 7-day window met quota")

        // A failed week breaks the run but must not zero the streak forever:
        // week 0 fails quota (1 of 2), weeks 1-2 meet it, current week active.
        var recovered = ActivityLog()
        recovered.logCompletion(exerciseID: "x", on: anchor) // week 0: only 1 day
        for dayOffset in [7, 9, 14, 17, 21] { // weeks 1-2 meet quota, week 3 current
            recovered.logCompletion(
                exerciseID: "x", on: cal.date(byAdding: .day, value: dayOffset, to: anchor)!)
        }
        expect(recovered.trainingPlanStreak(
            requiredDaysPerWeek: 2,
            today: cal.date(byAdding: .day, value: 22, to: anchor)!) == 3,
               "streak recovers after an old failed week (2 good weeks + current)")

        // Daily (7/week) frequency falls back to the strict daily streak.
        var daily = ActivityLog()
        for back in 0..<5 {
            daily.logCompletion(exerciseID: "x",
                                on: cal.date(byAdding: .day, value: -back, to: today)!)
        }
        expect(daily.trainingPlanStreak(requiredDaysPerWeek: 7, today: today) == 5,
               "7-per-week streak equals daily streak")

        // Empty current window keeps previous completed weeks.
        var pausedWeek = ActivityLog()
        for dayOffset in [0, 2, 7, 9] {
            pausedWeek.logCompletion(
                exerciseID: "x", on: cal.date(byAdding: .day, value: dayOffset, to: anchor)!)
        }
        expect(pausedWeek.trainingPlanStreak(
            requiredDaysPerWeek: 2,
            today: cal.date(byAdding: .day, value: 15, to: anchor)!) == 2,
               "empty current window does not reset previous weeks")

        let comps = DateComponents(year: 2026, month: 7, day: 2)
        expect(ActivityLog.dayKey(Calendar.current.date(from: comps)!) == "2026-07-02",
               "day key format")
    }

    suite("Russian names & language") {
        expect(ExerciseNamesRU.byID.count == 1324,
               "all 1324 names translated, got \(ExerciseNamesRU.byID.count)")
        let untranslated = exercises.filter { ExerciseNamesRU.byID[$0.id] == nil }
        expect(untranslated.isEmpty, "no exercise without RU name")
        let noCyrillic = ExerciseNamesRU.byID.values.filter {
            $0.range(of: "[а-яА-ЯёЁ]", options: .regularExpression) == nil
        }
        expect(noCyrillic.isEmpty, "all RU names contain Cyrillic: \(noCyrillic.prefix(3))")

        // No mixed-script words (like "Бiceps") or Ukrainian letters
        var mixed: [String] = []
        for v in ExerciseNamesRU.byID.values {
            if v.range(of: "[іїєґўІЇЄҐЎ]", options: .regularExpression) != nil {
                mixed.append(v)
                continue
            }
            for word in v.split(whereSeparator: { " /(),".contains($0) }) {
                let w = String(word)
                if w.range(of: "[а-яА-ЯёЁ]", options: .regularExpression) != nil,
                   w.range(of: "[a-zA-Z]{2,}", options: .regularExpression) != nil {
                    mixed.append(v)
                    break
                }
            }
        }
        expect(mixed.isEmpty, "no mixed-script RU names: \(mixed.prefix(3))")

        let ex = exercises[0]
        expect(ex.displayName(lang: "en") == ex.name.capitalized,
               "EN display name is capitalized original")
        expect(ex.displayName(lang: "ru") == ExerciseNamesRU.byID[ex.id],
               "RU display name comes from translations")
        expect(ExerciseNamesRU.duplicateNames.contains("Подтягивания"),
               "duplicate RU names are detected")
        let store = AppStore(loadDataset: true)
        let chin = store.exercises.first { $0.name == "chin-up" }
        let pull = store.exercises.first { $0.name == "pull-up" }
        if let chin, let pull {
            expect(store.displayName(chin) != store.displayName(pull),
                   "AppStore disambiguates duplicate RU names")
        } else {
            expect(false, "chin-up and pull-up exist")
        }

        // Search by Russian translated name
        let pullups = exercises.first { $0.name == "pull-up" }
        if let pullups, let ru = ExerciseNamesRU.byID[pullups.id] {
            let firstWord = ru.split(separator: " ").first.map(String.init) ?? ru
            let found = ExerciseQuery.apply(exercises, search: firstWord)
            expect(found.contains { $0.id == pullups.id },
                   "search by RU name '\(firstWord)' finds pull-up")
        }

        // RU sort uses RU names
        let ruSorted = ExerciseQuery.apply(exercises, sort: .name, lang: "ru")
            .map { $0.displayName(lang: "ru") }
        expect(
            zip(ruSorted, ruSorted.dropFirst()).allSatisfy {
                $0.localizedStandardCompare($1) != .orderedDescending
            },
            "RU sort is non-descending by RU names")

        expect(SortOrder.name.title(lang: "ru") == "По названию", "RU sort label")
        expect(SortOrder.name.title(lang: "en") == "By name", "EN sort label")
    }

    suite("Goals & nutrition plan") {
        var goal = UserGoal(heightCM: 180, weightKG: 90, targetWeightKG: 80)
        expect(goal.isLosing, "90→80 is losing")
        expect(goal.estimatedDays == 154, "10 kg ≈ 154 days, got \(goal.estimatedDays)")
        goal.targetWeightKG = 96
        expect(!goal.isLosing, "90→96 is gaining")
        expect(goal.estimatedDays == 92, "6 kg gain ≈ 92 days, got \(goal.estimatedDays)")
        goal.targetWeightKG = 90
        expect(goal.estimatedDays == 0, "no delta → 0 days")
        expect(goal.isValid, "sane goal is valid")
        goal.heightCM = 20
        expect(!goal.isValid, "absurd height rejected")

        // Envelope + plan parsing from a real captured Groq response shape
        let envelope = """
        {"choices":[{"message":{"content":"{\\n \\"days_to_goal\\": 120,\\n \
        \\"daily_calories\\": 2200,\\n \\"protein_g\\": 120, \\"fat_g\\": 70,\\n \
        \\"carbs_g\\": 250, \\"foods\\": [\\"Куриная грудка\\", \\"Рыба\\"],\\n \
        \\"tips\\": [\\"Пейте воду\\"]}"}}]}
        """
        if let plan = try? GroqClient.parsePlan(from: Data(envelope.utf8)) {
            expect(plan.daysToGoal == 120 && plan.dailyCalories == 2200,
                   "plan numbers parsed")
            expect(plan.proteinG == 120 && plan.fatG == 70 && plan.carbsG == 250,
                   "macros parsed")
            expect(plan.foods == ["Куриная грудка", "Рыба"], "foods parsed")
            expect(plan.tips == ["Пейте воду"], "tips parsed")
        } else {
            expect(false, "real-shape Groq envelope failed to parse")
        }

        let fullEnvelope = """
        {"choices":[{"message":{"content":"{\\n \\"assessment\\": \\"Нужно снижать вес постепенно\\",\\n \
        \\"days_to_goal\\": 130, \\"daily_calories\\": 2100, \\"protein_g\\": 140,\\n \
        \\"fat_g\\": 65, \\"carbs_g\\": 220, \\"foods\\": [\\"рыба\\"],\\n \
        \\"meal_plan\\": [{\\"title\\": \\"Завтрак\\", \\"time\\": \\"08:00\\",\\n \
        \\"calories\\": 500, \\"foods\\": [\\"овсянка 70 г\\", \\"яйца 2 шт\\"]}],\\n \
        \\"water_target_ml\\": 2400,\\n \
        \\"tips\\": [\\"спите достаточно\\"], \\"workout_focus\\": [\\"спина\\"],\\n \
        \\"recommended_exercises\\": [{\\"exercise_id\\": \\"0652\\", \\"sets\\": 4,\\n \
        \\"reps\\": \\"6-10\\", \\"note\\": \\"развивает широчайшие\\"}]}"}}]}
        """
        if let plan = try? GroqClient.parsePlan(from: Data(fullEnvelope.utf8)) {
            expect(plan.assessment.contains("снижать"), "assessment parsed")
            expect(plan.workoutFocus == ["спина"], "workout focus parsed")
            expect(plan.waterTargetML == 2400, "water target parsed")
            expect(plan.recommendedExercises.first?.exerciseID == "0652",
                   "recommended exercise id parsed")
            expect(plan.recommendedExercises.first?.sets == 4,
                   "recommended exercise sets parsed")
            expect(plan.foods == ["рыба"], "foods still parse when old meal_plan is present")
        } else {
            expect(false, "full plan envelope failed to parse")
        }

        // Lenient parsing: numbers as strings, code fences, missing optionals
        let messy = """
        {"choices":[{"message":{"content":"```json\\n{\\"days_to_goal\\": \\"90\\", \
        \\"daily_calories\\": 2500.7}\\n```"}}]}
        """
        if let plan = try? GroqClient.parsePlan(from: Data(messy.utf8)) {
            expect(plan.daysToGoal == 90, "string number coerced")
            expect(plan.dailyCalories == 2501, "float rounded")
            expect(plan.foods.isEmpty && plan.tips.isEmpty, "missing arrays → empty")
            expect(plan.waterTargetML == 2000, "missing water target defaults")
        } else {
            expect(false, "lenient plan parse failed")
        }

        expect((try? GroqClient.parsePlan(from: Data("{}".utf8))) == nil,
               "empty envelope throws")
        expect(GroqClient.apiErrorMessage(
            Data(#"{"error":{"message":"Invalid API Key"}}"#.utf8))
            == "Invalid API Key", "api error extracted")

        // Prompt includes goal direction and workout
        let messages = GroqClient.buildMessages(
            goal: UserGoal(heightCM: 180, weightKG: 90, targetWeightKG: 80),
            exercises: Array(exercises.prefix(2)))
        let userMsg = messages.last?["content"] ?? ""
        expect(userMsg.contains("похудение"), "prompt mentions losing direction")
        expect(userMsg.contains("180"), "prompt mentions height")
        let gainMsg = GroqClient.buildMessages(
            goal: UserGoal(heightCM: 180, weightKG: 70, targetWeightKG: 80),
            exercises: []).last?["content"] ?? ""
        expect(gainMsg.contains("набор массы"), "prompt mentions gaining direction")
        let enMsg = GroqClient.buildMessages(
            goal: UserGoal(heightCM: 180, weightKG: 90, targetWeightKG: 80),
            exercises: [], lang: "en").last?["content"] ?? ""
        expect(enMsg.contains("weight loss"), "EN prompt mentions weight loss")

        let fullMessages = GroqClient.buildFullPlanMessages(
            profile: UserProfile(nickname: "A", heightCM: 181, weightKG: 91,
                                 gender: .male),
            goal: UserGoal(targetWeightKG: 82,
                           physiqueGoals: [.vShape, .leanAndAthletic]),
            exercises: Array(exercises.prefix(3)))
        let fullUser = fullMessages.last?["content"] as? String ?? ""
        expect(fullUser.contains("181"), "full prompt includes profile height")
        expect(fullUser.contains("V-форма") && fullUser.contains("Суше"),
               "full prompt includes selected physique options")
        expect(fullUser.contains("0001|"), "full prompt includes exercise catalog")

        let candidates = ExercisePlanCatalog.candidates(
            profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male),
            goal: UserGoal(targetWeightKG: 82,
                           physiqueGoals: [.vShape, .leanAndAthletic],
                           trainingLocation: .home,
                           limitationOptions: [.knees, .lowImpact],
                           equipmentOptions: [.bodyWeight, .band],
                           bodyDescription: "хочу V-форму, плечи и спину"),
            exercises: exercises)
        expect(candidates.count <= 60, "AI catalog is compact")
        expect(Set(candidates.map(\.category)).count >= 5,
               "AI catalog keeps category variety")
        expect(candidates.contains { $0.name == "pull-up" },
               "AI catalog keeps relevant back exercise")
        expect(candidates.contains { $0.target == "delts" },
               "AI catalog reacts to shoulder goal")
        let homeBackSafe = ExercisePlanCatalog.candidates(
            profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male),
            goal: UserGoal(targetWeightKG: 82,
                           trainingLocation: .home,
                           limitationOptions: [.homeOnly, .back],
                           equipmentOptions: [.bodyWeight, .band]),
            exercises: exercises)
        let forbiddenHomeEquipment: Set<String> = [
            "barbell", "ez barbell", "olympic barbell", "trap bar", "cable",
            "leverage machine", "smith machine",
        ]
        expect(homeBackSafe.allSatisfy { !forbiddenHomeEquipment.contains($0.equipment) },
               "home/back-safe catalog excludes gym and barbell equipment")
        let compactMessages = GroqClient.buildFullPlanMessages(
            profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male),
            goal: UserGoal(targetWeightKG: 82,
                           trainingLocation: .home,
                           limitationOptions: [.homeOnly, .back],
                           equipmentOptions: [.bodyWeight, .band]),
            exercises: exercises)
        let compactSystem = compactMessages.first?["content"] as? String ?? ""
        let compactUser = compactMessages.last?["content"] as? String ?? ""
        let catalogLineCount = compactUser.split(separator: "\n")
            .filter { line in
                line.contains("|") && line.first.map(\.isNumber) == true
            }.count
        expect(catalogLineCount <= 180,
               "full prompt sends compact candidate catalog, got \(catalogLineCount)")
        expect(!compactUser.contains("id|name|category|target|equipment"),
               "full prompt does not send category column")
        expect(compactUser.contains("id|name|target|equipment"),
               "full prompt documents compact catalog columns")
        expect(compactUser.contains("дневные калории")
               && compactUser.contains("предпочтительное БЖУ")
               && !compactUser.contains("режим питания")
               && !compactUser.contains("meal_plan"),
               "full prompt asks for nutrition summary without meal plan")
        expect(compactUser.contains("Место тренировок")
               && compactUser.contains("Доступный инвентарь"),
               "full prompt includes location and equipment constraints")
        expect(compactUser.contains("Дома") && compactUser.contains("Свой вес")
               && compactUser.contains("Резинки") && compactUser.contains("Беречь спину"),
               "full prompt includes parsed selected answers")
        expect(compactUser.contains("Частота тренировок: 3")
               && compactSystem.contains("workout_plans"),
               "full prompt includes slider frequency and workout plan blocks")
        expect(compactSystem.contains("только на русском")
               && !compactSystem.contains("\"daily_calories\": 2200")
               && !compactSystem.lowercased().contains("breakfast"),
               "RU prompt forces Russian output and avoids copyable numeric examples")
        expect(!compactSystem.contains("meal_plan")
               && !compactSystem.contains("точно равняться daily_calories"),
               "prompt no longer requests meal plan calories")
        let baseline = GroqClient.baselinePlanNumbers(
            profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male),
            goal: UserGoal(targetWeightKG: 82))
        expect(baseline.calories != 2200
               || baseline.protein != 130
               || baseline.days != 120,
               "baseline varies from old static prompt example")
        let fixedMessages = GroqClient.buildFullPlanMessages(
            profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male),
            goal: UserGoal(targetWeightKG: 82),
            exercises: exercises,
            fixedExerciseIDs: Array(exercises.prefix(3).map(\.id)))
        let fixedUser = fixedMessages.last?["content"] as? String ?? ""
        expect(fixedUser.contains("ровно эти exercise_id"),
               "fixed exercise prompt forbids changing edited list")
        let fixedLineCount = fixedUser.split(separator: "\n")
            .filter { $0.contains("|") && $0.first.map(\.isNumber) == true }
            .count
        expect(fixedLineCount == 3, "fixed prompt sends only edited exercises")
        let editedNutrition = NutritionPlan(
            daysToGoal: 77, dailyCalories: 1875, proteinG: 140,
            fatG: 65, carbsG: 180, foods: ["гречка", "курица"],
            waterTargetML: 2400, tips: ["a"])
        let nutritionMessages = GroqClient.buildFullPlanMessages(
            profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male),
            goal: UserGoal(targetWeightKG: 82),
            exercises: exercises,
            fixedNutrition: editedNutrition)
        let nutritionUser = nutritionMessages.last?["content"] as? String ?? ""
        expect(nutritionUser.contains("daily_calories=1875")
               && nutritionUser.contains("protein_g=140")
               && nutritionUser.contains("foods: гречка, курица")
               && !nutritionUser.contains("meal_plan"),
               "fixed nutrition prompt includes edited calories, macros and foods")
        let responseFormat = GroqClient.fullPlanResponseFormat()
        expect(responseFormat["type"] as? String == "json_schema",
               "full plan uses json_schema response format")
        let fallbackFormat = GroqClient.fullPlanResponseFormat(useSchema: false)
        expect(fallbackFormat["type"] as? String == "json_object",
               "full plan has json_object fallback format")
        let body = GroqClient.fullPlanRequestBody(
            model: "m",
            profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male),
            goal: UserGoal(targetWeightKG: 82,
                           trainingGoals: [.fatLoss, .recomposition],
                           physiqueGoals: [.vShape, .leanAndAthletic],
                           limitationOptions: [.knees, .lowImpact]),
            exercises: exercises)
        expect(body["temperature"] as? Double == 0.25,
               "full plan uses lower temperature")
        expect(body["max_completion_tokens"] as? Int == 1500,
               "full plan limits completion tokens")
        expect(body["service_tier"] == nil,
               "full plan omits org-restricted service tier")
        expect(JSONSerialization.isValidJSONObject(body),
               "full plan request body is valid JSON")

        let oldGoalJSON = #"{"heightCM":180,"weightKG":90,"targetWeightKG":80}"#
        if let decoded = try? JSONDecoder().decode(UserGoal.self, from: Data(oldGoalJSON.utf8)) {
            expect(decoded.trainingGoal == .fatLoss, "old goal files decode with defaults")
            expect(decoded.trainingGoals == [.fatLoss],
                   "old goal files migrate to multi-select defaults")
            expect(decoded.trainingLocation == .home,
                   "old goal files default to home training location")
            expect(decoded.equipmentOptions == [.bodyWeight],
                   "old goal files default to bodyweight equipment")
        } else {
            expect(false, "old goal JSON should decode")
        }
        let multiGoal = UserGoal(trainingGoals: [.fatLoss, .recomposition],
                                 physiqueGoals: [.vShape, .leanAndAthletic],
                                 limitationOptions: [.knees, .lowImpact])
        let multiSummary = multiGoal.promptSummary(lang: "ru")
        expect(multiSummary.contains("Похудение")
               && multiSummary.contains("Рельеф и рекомпозиция"),
               "prompt includes multiple selected training goals")
        expect(!multiSummary.contains("Дополнительно"),
               "prompt no longer includes extra notes")

        // SavedPlan persistence round trip
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbar-plan-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let p = Persistence(directory: dir)
        let saved = SavedPlan(
            plan: NutritionPlan(daysToGoal: 1, dailyCalories: 2, proteinG: 3,
                                fatG: 4, carbsG: 5, foods: ["a"], tips: ["b"]),
            goal: UserGoal(), model: "m", recommendationsEdited: true)
        p.save(saved, as: "plan.json")
        expect(p.load(SavedPlan.self, from: "plan.json") == saved,
               "saved plan round trip")
    }

    suite("Muscle map") {
        for t in Set(exercises.map(\.target)) {
            expect(!MuscleMap.regions(for: t).isEmpty,
                   "target \(t) maps to body regions")
        }
        var unmapped = Set<String>()
        for ex in exercises {
            for m in ex.secondaryMuscles where MuscleMap.regions(for: m).isEmpty {
                unmapped.insert(m)
            }
        }
        expect(unmapped.isEmpty,
               "all secondary muscles map to regions, unmapped: \(unmapped)")
        expect(MuscleMap.dominantSide(target: "lats") == .back,
               "lats shown from the back")
        expect(MuscleMap.dominantSide(target: "pectorals") == .front,
               "pectorals shown from the front")
        expect(MuscleMap.dominantSide(target: "glutes") == .back,
               "glutes shown from the back")
    }

    suite("Health facts") {
        expect(HealthFacts.factsRU.count == 130, "130 RU health facts")
        expect(HealthFacts.factsEN.count == 130, "130 EN health facts")
        expect(HealthFacts.facts.count == 130, "130 bilingual facts")
        expect(!HealthFacts.random(lang: "en").contains("Силовые"),
               "EN random fact is English")
    }

    suite("Exercise visuals") {
        let run = exercises.first { $0.name == "run" || $0.name.contains("run") }
        let pull = exercises.first { $0.name == "pull-up" }
        let plank = exercises.first { $0.name.contains("plank") }
        if let run {
            expect(ExerciseVisualStyle.icon(run) == "figure.run",
                   "running exercise gets run icon")
        }
        if let pull {
            expect(ExerciseVisualStyle.icon(pull) == "figure.strengthtraining.traditional",
                   "pull-up gets strength icon")
        }
        if let plank {
            expect(ExerciseVisualStyle.icon(plank) == "figure.core.training",
                   "plank gets core icon")
        }
        if let pull {
            expect(!ExerciseVisualStyle.muscleLine(pull, lang: "ru").isEmpty,
                   "muscle line is generated")
            expect(!ExerciseVisualStyle.muscleLine(pull, lang: "ru").contains("Core"),
                   "RU muscle line avoids English aliases")
        }
    }

    suite("Persistence") {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbar-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let p = Persistence(directory: dir)
        var log = ActivityLog()
        log.logCompletion(exerciseID: "0042")
        p.save(log, as: "activity.json")
        expect(p.load(ActivityLog.self, from: "activity.json") == log, "round trip")
        expect(p.load(ActivityLog.self, from: "nope.json") == nil, "missing file → nil")
    }

    suite("AppStore") {
        @MainActor func withStore(
            _ name: String,
            _ body: @MainActor (URL, @MainActor () -> AppStore) -> Void
        ) {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("fitbar-store-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: dir) }
            body(dir, { AppStore(persistence: Persistence(directory: dir)) })
        }

        withStore("toggle") { _, make in
            let store = make()
            let ex = store.exercises[0]
            store.toggleWorkout(ex)
            expect(store.isInWorkout(ex), "toggle adds")
            store.toggleWorkout(ex)
            expect(!store.isInWorkout(ex), "toggle removes")
        }

        withStore("persist workout") { _, make in
            let store = make()
            store.toggleWorkout(store.exercises[0])
            store.toggleWorkout(store.exercises[5])
            let store2 = make()
            expect(store2.workout.exerciseIDs
                   == [store.exercises[0].id, store.exercises[5].id],
                   "workout persists across stores")
        }

        withStore("complete") { _, make in
            let store = make()
            store.toggleWorkout(store.exercises[0])
            store.toggleWorkout(store.exercises[1])
            expect(store.currentExercise?.id == store.exercises[0].id, "current = first")
            store.completeCurrent()
            expect(store.todayCount == 1, "today count = 1 after complete")
            expect(store.currentExercise?.id == store.exercises[1].id, "advanced to next")
            expect(store.recordExercise?.exercise.id == store.exercises[0].id,
                   "record exercise set")
            store.completeCurrent()
            expect(store.currentExercise?.id == store.exercises[0].id, "wraps around")
            expect(store.todayCount == 2, "today count = 2")
        }

        withStore("persist activity") { _, make in
            let store = make()
            store.toggleWorkout(store.exercises[0])
            store.completeCurrent()
            let store2 = make()
            expect(store2.todayCount == 1, "activity persists")
        }

        withStore("profile") { _, make in
            let store = make()
            store.profile.nickname = "Alex"
            store.profile.heightCM = 182
            store.profile.weightKG = 81
            store.profile.gender = .male
            let store2 = make()
            expect(store2.profile.nickname == "Alex", "profile nickname persists")
            expect(store2.profile.heightCM == 182, "profile height persists")
            expect(store2.profile.weightKG == 81, "profile weight persists")
            expect(store2.profile.gender == .male, "profile gender persists")
        }

        withStore("replace recommended exercise") { _, make in
            let store = make()
            let first = store.exercises[0].id
            let second = store.exercises[1].id
            let third = store.exercises[2].id
            let saved = SavedPlan(
                plan: NutritionPlan(
                    daysToGoal: 1, dailyCalories: 2, proteinG: 3, fatG: 4,
                    carbsG: 5, foods: ["a"], tips: ["b"],
                    recommendedExercises: [
                        RecommendedExercisePlan(exerciseID: first, sets: 3,
                                                reps: "8-12", note: "old"),
                        RecommendedExercisePlan(exerciseID: second, sets: 3,
                                                reps: "8-12", note: "old"),
                    ]),
                goal: UserGoal(), model: "m")
            store.seed(plan: saved)
            store.replaceRecommendedExercise(first, with: third)
            expect(store.plan?.recommendationsEdited == true,
                   "replacement marks recommendations edited")
            expect(store.plan?.plan.recommendedExercises.first?.exerciseID == third,
                   "replacement updates exercise id")
            store.replaceRecommendedExercise(second, with: third)
            expect(store.plan?.plan.recommendedExercises.map(\.exerciseID)
                   == [third, second],
                   "replacement refuses duplicate recommendation")
        }

        withStore("edit plan nutrition") { _, make in
            let store = make()
            let saved = SavedPlan(
                plan: NutritionPlan(
                    daysToGoal: 120, dailyCalories: 2200, proteinG: 130,
                    fatG: 70, carbsG: 240, foods: ["a"], tips: ["b"]),
                goal: UserGoal(), model: "m")
            store.seed(plan: saved)
            store.updatePlanNutrition(
                daysToGoal: 80,
                dailyCalories: 1900,
                proteinG: 150,
                fatG: 60,
                carbsG: 170,
                waterTargetML: 2300,
                foods: ["гречка", "рыба"])
            expect(store.plan?.nutritionEdited == true,
                   "nutrition edit marks plan edited")
            expect(store.plan?.plan.dailyCalories == 1900
                   && store.plan?.plan.proteinG == 150
                   && store.plan?.plan.waterTargetML == 2300
                   && store.plan?.plan.foods == ["гречка", "рыба"],
                   "nutrition edit updates metrics, water and foods")
        }

        withStore("water target modes") { _, make in
            let store = make()
            expect(store.waterTargetML == 3000,
                   "new profile uses standard three-liter water target")
            var waterGoal = UserGoal()
            waterGoal.requestedOutputs = [.water]
            store.seed(plan: SavedPlan(
                plan: NutritionPlan(
                    daysToGoal: 30, dailyCalories: 2000, proteinG: 120,
                    fatG: 70, carbsG: 220, foods: [], waterTargetML: 2650,
                    tips: []),
                goal: waterGoal,
                model: "m"))
            store.setWaterTargetMode(.ai)
            expect(store.waterTargetML == 2650,
                   "AI water mode uses generated target")
            store.setCustomWaterTargetML(1850)
            expect(store.waterTargetML == 1850
                   && store.selectedWaterTargetMode == .custom,
                   "custom water mode persists its own target")
            store.setWaterTargetMode(.standard)
            expect(store.waterTargetML == 3000,
                   "standard water mode returns to three liters")
        }

        withStore("repair old static plan on load") { dir, make in
            let stale = SavedPlan(
                plan: NutritionPlan(
                    daysToGoal: 120, dailyCalories: 2200, proteinG: 130,
                    fatG: 70, carbsG: 240, foods: ["a"], tips: ["b"]),
                goal: UserGoal(targetWeightKG: 82),
                model: "m",
                profile: UserProfile(heightCM: 181, weightKG: 91, gender: .male))
            Persistence(directory: dir).save(stale, as: "plan.json")
            let store = make()
            expect(store.plan?.plan.dailyCalories != 2200
                   || store.plan?.plan.proteinG != 130
                   || store.plan?.plan.daysToGoal != 120,
                   "old static plan metrics are repaired on load")
        }

        withStore("advance wrap") { _, make in
            let store = make()
            for i in 0..<3 { store.toggleWorkout(store.exercises[i]) }
            store.advance(-1)
            expect(store.workout.currentIndex == 2, "advance -1 wraps to end")
            store.advance(1)
            expect(store.workout.currentIndex == 0, "advance +1 wraps to start")
        }

        withStore("remove current") { _, make in
            let store = make()
            for i in 0..<2 { store.toggleWorkout(store.exercises[i]) }
            store.jump(to: 1)
            store.toggleWorkout(store.exercises[1])
            expect(store.workout.currentIndex == 0, "index clamped after removing current")
            expect(store.currentExercise != nil, "current exists after removal")
        }

        withStore("remove before current") { _, make in
            let store = make()
            for i in 0..<3 { store.toggleWorkout(store.exercises[i]) }
            store.jump(to: 2)
            let currentID = store.currentExercise!.id
            store.toggleWorkout(store.exercises[0])
            expect(store.currentExercise?.id == currentID,
                   "pointer stays on same exercise after removing earlier item")
        }

        withStore("move keeps current") { _, make in
            let store = make()
            for i in 0..<3 { store.toggleWorkout(store.exercises[i]) }
            store.jump(to: 0)
            let currentID = store.currentExercise!.id
            store.moveWorkout(from: IndexSet(integer: 0), to: 3)
            expect(store.currentExercise?.id == currentID, "move keeps current exercise")
            expect(store.workout.currentIndex == 2, "index follows moved item")
        }

        withStore("stale ids") { dir, make in
            let p = Persistence(directory: dir)
            var w = WorkoutState()
            w.exerciseIDs = ["0001", "not-an-id", "0002"]
            w.currentIndex = 2
            p.save(w, as: "workout.json")
            let store = make()
            expect(store.workout.exerciseIDs == ["0001", "0002"],
                   "stale ids dropped on load")
            expect(store.workout.currentIndex < 2, "index clamped after dropping stale ids")
        }

        withStore("timer") { _, make in
            let store = make()
            store.timerDuration = 45
            expect(!store.timerRunning, "timer initially stopped")
            expect(abs(store.timerRemaining - 45) < 0.01, "remaining = duration initially")
            store.startTimer()
            expect(store.timerRunning, "timer runs after start")
            expect(store.timerRemaining <= 45, "remaining <= duration")
            store.pauseTimer()
            expect(!store.timerRunning, "paused")
            expect(store.timerRemaining > 40, "paused remaining kept")
            store.startTimer()
            expect(store.timerRunning, "resumes")
            store.resetTimer()
            expect(!store.timerRunning, "reset stops")
            expect(abs(store.timerRemaining - 45) < 0.01, "reset restores duration")
        }

        withStore("set flow") { _, make in
            let store = make()
            store.toggleWorkout(store.exercises[0])
            store.runPhase = .running
            store.setStartedAt = Date().addingTimeInterval(-12)
            store.stopRunningSet()
            expect(store.runPhase == .awaitingReps, "stop asks for reps")
            expect((11...13).contains(store.pendingSetDurationSeconds),
                   "stop keeps elapsed stopwatch time")
            store.savePendingSet(reps: 11)
            expect(store.runPhase == .idle, "saving returns to idle")
            expect(store.activity.totalReps == 11, "saved reps")
            expect(store.activity.totalCompletions == 1, "saved set count")
        }

        withStore("backup restore") { _, make in
            let store = make()
            store.toggleWorkout(store.exercises[0])
            store.runPhase = .running
            store.setStartedAt = Date().addingTimeInterval(-20)
            store.stopRunningSet()
            store.savePendingSet(reps: 15)
            let data = try? store.exportBackupData()
            store.clearAllUserData()
            expect(store.activity.totalReps == 0, "clear removes reps")
            if let data {
                try? store.restoreBackup(from: data)
                expect(store.activity.totalReps == 15, "restore brings reps back")
                expect(store.workout.exerciseIDs == [store.exercises[0].id],
                       "restore brings workout back")
            } else {
                expect(false, "backup data encoded")
            }
        }
    }

    print("")
    if failed == 0 {
        print("ALL TESTS PASSED (\(passed) checks)")
        exit(0)
    } else {
        print("FAILED: \(failed) of \(passed + failed) checks")
        exit(1)
    }
}

MainActor.assumeIsolated { runAllTests() }
