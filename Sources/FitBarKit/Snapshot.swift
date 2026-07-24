import SwiftUI
import AppKit

/// Renders the real views inside offscreen NSWindows and captures them to PNG.
/// Used by `FitBar --snapshot <dir>` for visual verification: unlike
/// ImageRenderer this draws native controls (TextField, Menu, Picker) and
/// lazy containers correctly, and needs no screen-recording permission.
@MainActor
public enum SnapshotRunner {
    public static func run(outputDir: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let dir = URL(fileURLWithPath: outputDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbar-snapshot-\(UUID().uuidString)")
        let store = AppStore(persistence: Persistence(directory: tmp))
        seed(store)

        // Browser, light + dark
        capture(MainWindowView().environmentObject(store),
                size: NSSize(width: 1180, height: 760),
                appearance: .aqua, to: dir.appendingPathComponent("main-light.png"))
        capture(MainWindowView().environmentObject(store),
                size: NSSize(width: 1180, height: 760),
                appearance: .darkAqua, to: dir.appendingPathComponent("main-dark.png"))

        // English UI
        store.appLanguage = "en"
        capture(MainWindowView().environmentObject(store),
                size: NSSize(width: 1180, height: 760),
                appearance: .aqua, to: dir.appendingPathComponent("main-english.png"))
        store.appLanguage = "ru"

        // Browser with active search + filter
        store.searchText = "curl"
        store.selectedEquipment = "dumbbell"
        capture(MainWindowView().environmentObject(store),
                size: NSSize(width: 1180, height: 760),
                appearance: .aqua, to: dir.appendingPathComponent("main-filtered.png"))
        store.searchText = ""
        store.selectedEquipment = nil

        // Activity page and workout list (rendered standalone)
        capture(ActivityView().environmentObject(store),
                size: NSSize(width: 970, height: 760),
                appearance: .aqua, to: dir.appendingPathComponent("activity-light.png"))
        capture(WorkoutListView(detailExercise: .constant(nil)).environmentObject(store),
                size: NSSize(width: 970, height: 500),
                appearance: .aqua, to: dir.appendingPathComponent("workout-light.png"))
        capture(AccountView().environmentObject(store),
                size: NSSize(width: 970, height: 520),
                appearance: .aqua, to: dir.appendingPathComponent("account-light.png"))

        // Goals page (with a canned plan so the result layout is visible)
        store.profile = UserProfile(nickname: "Alex", heightCM: 180, weightKG: 90,
                                    gender: .male)
        let preferredExerciseNames = [
            "push-up", "pull-up", "squat", "plank", "dumbbell curl", "burpee",
            "dumbbell lunge",
        ]
        let preferredIDs = preferredExerciseNames.compactMap { name in
            store.exercises.first { $0.name == name }?.id
        }
        var seenRecommendedIDs = Set<String>()
        let recommendedIDs = Array((preferredIDs + store.exercises.prefix(12).map(\.id))
            .filter { seenRecommendedIDs.insert($0).inserted }
            .prefix(6))
        store.seed(plan: SavedPlan(
            plan: NutritionPlan(
                daysToGoal: 120, dailyCalories: 2200, proteinG: 130, fatG: 70,
                carbsG: 240,
                assessment: "Есть запас для спокойного снижения веса: главный акцент — регулярная силовая нагрузка, контроль калорий и сохранение мышц.",
                foods: ["Куриная грудка", "Рыба", "Творог", "Овощи", "Гречка",
                        "Яйца", "Ягоды"],
                waterTargetML: 2400,
                tips: ["Пейте не менее 2 л воды в день",
                       "Ешьте белок в каждом приёме пищи",
                       "Избегайте сладких напитков"],
                workoutFocus: ["спина и плечи", "ноги", "кор", "умеренное кардио"],
                recommendedExercises: recommendedIDs.enumerated().map { index, id in
                    RecommendedExercisePlan(
                        exerciseID: id,
                        sets: [4, 4, 3, 3, 3, 3][min(index, 5)],
                        reps: ["6-10", "8-12", "10-15", "30-45 сек", "10-12", "8-10"][min(index, 5)],
                        note: [
                            "поможет удержать мышцы верха тела",
                            "база для спины и осанки",
                            "даёт крупную силовую нагрузку",
                            "укрепляет корпус",
                            "добавляет объём рукам",
                            "поднимает расход энергии",
                        ][min(index, 5)])
                }),
            goal: UserGoal(
                heightCM: 180, weightKG: 90, targetWeightKG: 80,
                bodyDescription: "Хочу выглядеть суше, убрать живот, сохранить плечи. Раньше занимался в зале нерегулярно."),
            model: AppStore.groqModel,
            profile: store.profile))
        capture(GoalsView().environmentObject(store),
                size: NSSize(width: 970, height: 980),
                appearance: .aqua, to: dir.appendingPathComponent("goals-light.png"))
        // Menu bar popover, dark + light
        capture(MenuBarView().environmentObject(store),
                size: NSSize(width: 590, height: 560),
                appearance: .darkAqua, to: dir.appendingPathComponent("menubar-dark.png"))
        capture(MenuBarView().environmentObject(store),
                size: NSSize(width: 590, height: 560),
                appearance: .aqua, to: dir.appendingPathComponent("menubar-light.png"))

        // Detail sheet
        if store.exercises.count > 42 {
            capture(ExerciseDetailView(exercise: store.exercises[42])
                        .environmentObject(store),
                    size: NSSize(width: 620, height: 640),
                    appearance: .aqua, to: dir.appendingPathComponent("detail-light.png"))
        }

        store.setAppTheme(.monochrome)
        FitBarTheme.currentMode = .monochrome
        capture(MainWindowView().environmentObject(store),
                size: NSSize(width: 1180, height: 760),
                appearance: .aqua, to: dir.appendingPathComponent("main-monochrome.png"))
        capture(AccountView().environmentObject(store),
                size: NSSize(width: 970, height: 520),
                appearance: .aqua, to: dir.appendingPathComponent("account-monochrome.png"))
        capture(GoalsView().environmentObject(store),
                size: NSSize(width: 970, height: 980),
                appearance: .aqua, to: dir.appendingPathComponent("goals-monochrome.png"))
        capture(MenuBarView().environmentObject(store),
                size: NSSize(width: 590, height: 560),
                appearance: .aqua, to: dir.appendingPathComponent("menubar-monochrome.png"))
        if store.exercises.count > 42 {
            capture(ExerciseDetailView(exercise: store.exercises[42])
                        .environmentObject(store),
                    size: NSSize(width: 620, height: 640),
                    appearance: .aqua, to: dir.appendingPathComponent("detail-monochrome.png"))
        }
        store.setAppTheme(.dark)
        FitBarTheme.currentMode = .dark

        print("Snapshots written to \(dir.path)")
    }

    /// Renders the app icon artwork to a 1024x1024 PNG (used to build the .icns).
    public static func renderIcon(to path: String) {
        _ = NSApplication.shared
        let icon = AppIconView().frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            print("FAILED to render icon")
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("icon written to \(path)")
    }

    struct AppIconView: View {
        var body: some View {
            ZStack {
                Color.clear
                ZStack {
                    FitBarArtworkImage(artwork: .app)
                        .frame(width: 820, height: 820)
                        .clipShape(RoundedRectangle(cornerRadius: 180,
                                                    style: .continuous))
                    RoundedRectangle(cornerRadius: 180,
                                     style: .continuous)
                        .strokeBorder(Color.black.opacity(0.10),
                                      lineWidth: 10)
                        .frame(width: 820, height: 820)
                }
                .offset(x: 24)
            }
            .frame(width: 1024, height: 1024)
        }
    }

    private static func seed(_ store: AppStore) {
        var workout = WorkoutState()
        let wanted = ["push-up", "pull-up", "squat", "plank", "dumbbell curl", "burpee"]
        workout.exerciseIDs = store.exercises
            .filter { wanted.contains($0.name) }
            .map(\.id)
        if workout.exerciseIDs.isEmpty {
            workout.exerciseIDs = store.exercises.prefix(6).map(\.id)
        }
        workout.currentIndex = min(1, max(0, workout.exerciseIDs.count - 1))

        var activity = ActivityLog()
        let cal = Calendar.current
        for back in 0..<(16 * 7) {
            guard let day = cal.date(byAdding: .day, value: -back, to: Date())
            else { continue }
            if Int.random(in: 0..<10) < 6 {
                for _ in 0..<Int.random(in: 1...11) {
                    let ex = store.exercises[
                        Int.random(in: 0..<min(40, store.exercises.count))]
                    activity.logCompletion(exerciseID: ex.id, on: day)
                }
            }
        }
        if let first = workout.exerciseIDs.first {
            for _ in 0..<5 { activity.logCompletion(exerciseID: first) }
        }
        store.seed(workout: workout, activity: activity)
    }

    private static func capture<V: View>(
        _ view: V, size: NSSize, appearance: NSAppearance.Name, to url: URL
    ) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = FitBarTheme.isMonochrome ? .white : .windowBackgroundColor

        let hosting = NSHostingView(
            rootView: view
                .frame(width: size.width)
                .background(FitBarTheme.appBackground)
        )
        hosting.appearance = NSAppearance(named: appearance)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layout()
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        // Let SwiftUI settle (lazy grids, async layout).
        for _ in 0..<6 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("FAILED to create rep for \(url.lastPathComponent)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("FAILED to encode \(url.lastPathComponent)")
            return
        }
        try? png.write(to: url)
        print("rendered \(url.lastPathComponent)")
        window.contentView = nil
    }
}
