import AppKit
import SwiftUI
import FitBarKit

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
        SnapshotRunner.run(outputDir: args[i + 1])
        exit(0)
    }
    if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
        SnapshotRunner.renderIcon(to: args[i + 1])
        exit(0)
    }
    if args.contains("--plan-test") {
        // Live end-to-end check of the in-app Groq flow: full plan with
        // workout blocks (json_schema + fallback) and the manual-choice advice.
        let exercises = (try? ExerciseDataset.load()) ?? []
        let profile = UserProfile(nickname: "Test", heightCM: 180, weightKG: 90,
                                  gender: .male)
        let goal = UserGoal(
            heightCM: 180, weightKG: 90, targetWeightKG: 80,
            trainingGoal: .fatLoss, trainingDaysPerWeek: 3,
            trainingLocation: .home, equipmentOptions: [.bodyWeight, .dumbbell])
        Task {
            guard let apiKey = GroqKeyStore().load() else {
                print("PLAN FAILED: add a Groq API key in FitBar AI assistant settings")
                exit(1)
            }
            do {
                let client = GroqClient(apiKey: apiKey,
                                        model: AppStore.groqTextModel)
                let plan = try await client.requestFullPlan(
                    profile: profile, goal: goal, exercises: exercises, lang: "ru")
                let ids = plan.recommendedExercises.map(\.exerciseID)
                let known = Set(exercises.map(\.id))
                let badIDs = ids.filter { !known.contains($0) }
                print("PLAN OK: days=\(plan.daysToGoal) kcal=\(plan.dailyCalories) "
                      + "БЖУ=\(plan.proteinG)/\(plan.fatG)/\(plan.carbsG) "
                      + "вода=\(plan.waterTargetML) foods=\(plan.foods.count) "
                      + "tips=\(plan.tips.count) blocks=\(plan.workoutPlans.count) "
                      + "exercises=\(ids.count) badIDs=\(badIDs.count)")
                for block in plan.workoutPlans {
                    print("  block '\(block.title)' focus=\(block.focus.joined(separator: ","))"
                          + " count=\(block.exercises.count)")
                }
                print("foods: \(plan.foods.joined(separator: ", "))")
                print("assessment: \(plan.assessment)")
                if !badIDs.isEmpty { print("BAD IDS: \(badIDs)") }

                let advice = try await client.requestChoiceAdvice(
                    profile: profile, goal: goal,
                    workout: Array(exercises.prefix(4)), lang: "ru")
                print("ADVICE OK (\(advice.count) chars): "
                      + advice.prefix(160).replacingOccurrences(of: "\n", with: " "))
                exit(badIDs.isEmpty ? 0 : 1)
            } catch {
                print("PLAN FAILED: \(error.localizedDescription)")
                exit(1)
            }
        }
        RunLoop.main.run()
    }
    NSApplication.shared.setActivationPolicy(.regular)
}
FitBarApp.main()
