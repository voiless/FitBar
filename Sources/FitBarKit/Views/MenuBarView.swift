import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @State private var beeped = false
    @State private var customWaterML = 250
    @State private var waterPulse = false
    @State private var showingWaterTargetEditor = false

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = Self.syncTheme(store.appTheme)
        ZStack {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    if let ex = store.currentExercise {
                        session(ex)
                    } else {
                        emptyState
                    }
                    FitBarDivider()
                    activitySection
                    FitBarDivider()
                    footer
                }
                .frame(width: 340)
                FitBarDivider(vertical: true)
                dailyPanel
            }

            if showingWaterTargetEditor {
                Color.black.opacity(FitBarTheme.isMonochrome ? 0.18 : 0.48)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { showingWaterTargetEditor = false }

                WaterTargetEditorPanel {
                    showingWaterTargetEditor = false
                }
                .environmentObject(store)
                .padding(18)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(width: 590)
        .background(FitBarTheme.appBackground)
        .id(store.appTheme)
        .onAppear {
            Self.syncTheme(store.appTheme)
            ensureConcreteWorkoutBlockSelection()
            waterPulse = true
        }
        .onChange(of: store.appTheme) { _, theme in
            Self.syncTheme(theme)
        }
        .onChange(of: store.workout.blocks) { _, _ in
            ensureConcreteWorkoutBlockSelection()
        }
        .onReceive(tick) { _ in
            store.updateSetClock()
            let expired = store.timerEndDate != nil
                && store.timerPausedRemaining == nil
                && store.timerRemaining <= 0
            if expired && !beeped {
                NSSound(named: "Glass")?.play()
                beeped = true
            } else if !expired {
                beeped = false
            }
        }
    }

    private static func syncTheme(_ theme: AppColorTheme) {
        FitBarTheme.currentMode = theme
    }

    // MARK: Current exercise session

    private func session(_ ex: Exercise) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(store.tr("ТРЕНИРОВКА", "WORKOUT"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FitBarTheme.textFaint)
                Spacer()
                Text(store.tr(
                    "\(store.workout.currentIndex + 1) из \(store.activeWorkoutIDs.count)",
                    "\(store.workout.currentIndex + 1) of \(store.activeWorkoutIDs.count)"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(FitBarTheme.textMuted)
            }

            blockPicker
            progressDots

            HStack(spacing: 12) {
                IconBubble(
                    category: ex.category,
                    symbol: ExerciseVisualStyle.icon(ex),
                    showsCategoryBadge: false,
                    size: 48
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.displayName(ex))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Chip(text: store.targetLabel(ex.target),
                             tint: .bodyPart(ex.category))
                        Chip(text: store.equipmentLabel(ex.equipment))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                setClock
                Spacer()
            }
            .frame(maxWidth: .infinity)

            setSummary(ex)

            sessionControls
        }
        .padding(14)
    }

    private var progressDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(store.activeWorkoutIDs.count, 40), id: \.self) { i in
                let isCurrent = i == store.workout.currentIndex
                Capsule()
                    .fill(
                        isCurrent
                            ? (FitBarTheme.isMonochrome ? Color.black : FitBarTheme.semantic(.green))
                            : (FitBarTheme.isMonochrome ? Color.white : FitBarTheme.faintFill(0.12))
                    )
                    .overlay {
                        if FitBarTheme.isMonochrome {
                            Capsule()
                                .strokeBorder(Color.black, lineWidth: 1.2)
                        }
                    }
                    .frame(height: 4)
            }
        }
    }

    private var blockPicker: some View {
        let blocks = nonEmptyWorkoutBlocks
        return HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FitBarTheme.textMuted)
            Picker("", selection: Binding<UUID?>(
                get: { store.workout.selectedBlockID ?? blocks.first?.id },
                set: { store.selectWorkoutBlock($0) }
            )) {
                ForEach(blocks) { block in
                    Text(block.title).tag(Optional(block.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(FitBarTheme.faintFill(0.045), in: RoundedRectangle(cornerRadius: 8))
    }

    private var nonEmptyWorkoutBlocks: [WorkoutBlock] {
        store.workout.blocks.filter { !$0.exerciseIDs.isEmpty }
    }

    private func ensureConcreteWorkoutBlockSelection() {
        let blocks = nonEmptyWorkoutBlocks
        guard !blocks.isEmpty else { return }
        if let selected = store.workout.selectedBlockID,
           blocks.contains(where: { $0.id == selected }) {
            return
        }
        store.selectWorkoutBlock(blocks[0].id)
    }

    private var setClock: some View {
        TimelineView(.animation(minimumInterval: 0.1,
                                paused: store.runPhase == .idle
                                || store.runPhase == .awaitingReps)) { _ in
            ZStack {
                Circle()
                    .stroke(
                        FitBarTheme.isMonochrome
                            ? Color.black
                            : FitBarTheme.faintFill(0.14),
                        lineWidth: 8
                    )
                Circle()
                    .trim(from: 0, to: clockProgress)
                    .stroke(
                        clockTint,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(clockValue)
                        .font(.system(size: clockValue.count > 4 ? 20 : 24,
                                      weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if !clockCaption.isEmpty {
                        Text(clockCaption)
                            .font(.system(size: 9))
                            .foregroundStyle(FitBarTheme.textFaint)
                    }
                }
            }
            .frame(width: 110, height: 110)
        }
        .frame(height: 118)
    }

    private var clockProgress: Double {
        switch store.runPhase {
        case .idle:
            return 0
        case .countdown:
            return max(0, min(1, (5 - store.countdownRemaining) / 5))
        case .running:
            return 1
        case .awaitingReps:
            return 1
        }
    }

    private var clockTint: Color {
        switch store.runPhase {
        case .idle: return FitBarTheme.isMonochrome ? .black : .secondary.opacity(0.45)
        case .countdown: return FitBarTheme.semantic(.orange)
        case .running: return FitBarTheme.semantic(.green)
        case .awaitingReps: return FitBarTheme.semantic(.blue)
        }
    }

    private var clockValue: String {
        switch store.runPhase {
        case .idle:
            return "0:00"
        case .countdown:
            return "\(max(1, Int(ceil(store.countdownRemaining))))"
        case .running:
            return Self.format(store.setElapsed)
        case .awaitingReps:
            return Self.format(TimeInterval(store.pendingSetDurationSeconds))
        }
    }

    private var clockCaption: String {
        switch store.runPhase {
        case .idle:
            return store.tr("ожидание старта", "ready")
        case .countdown:
            return store.tr("приготовьтесь", "get ready")
        case .running:
            return store.tr("секундомер", "stopwatch")
        case .awaitingReps:
            return ""
        }
    }

    private func setSummary(_ ex: Exercise) -> some View {
        let stats = store.todayStats(for: ex.id)
        return HStack(spacing: 8) {
            Chip(text: store.tr("Подходов: \(stats?.setCount ?? 0)",
                                "Sets: \(stats?.setCount ?? 0)"),
                 icon: "number", tint: .green)
            Chip(text: store.tr("Повторов: \(stats?.totalReps ?? 0)",
                                "Reps: \(stats?.totalReps ?? 0)"),
                 icon: "repeat", tint: .blue)
            Chip(text: Self.format(TimeInterval(stats?.totalDurationSeconds ?? 0)),
                 icon: "clock.fill", tint: .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sessionControls: some View {
        switch store.runPhase {
        case .idle:
            HStack(spacing: 8) {
                Button {
                    store.advance(-1)
                } label: {
                    Image(systemName: "backward.fill")
                        .frame(width: 26, height: 18)
                }
                Button {
                    store.startSetCountdown()
                } label: {
                    Label(store.tr("Начать подход", "Start set"),
                          systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .keyboardShortcut(.defaultAction)
                Button {
                    store.finishCurrentExercise()
                } label: {
                    Image(systemName: "forward.fill")
                        .frame(width: 26, height: 18)
                }
            }
            .controlSize(.large)
        case .countdown:
            Button {
                store.cancelCurrentSet()
            } label: {
                Label(store.tr("Отменить отсчёт", "Cancel countdown"),
                      systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
            }
            .controlSize(.large)
        case .running:
            Button {
                store.stopRunningSet()
            } label: {
                Label(store.tr("Стоп подход", "Stop set"),
                      systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
            }
            .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
            .controlSize(.large)
        case .awaitingReps:
            VStack(spacing: 8) {
                HStack {
                    Text(store.tr("Повторы в подходе", "Set reps"))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Stepper("\(store.pendingReps)", value: $store.pendingReps, in: 0...999)
                        .labelsHidden()
                    Text("\(store.pendingReps)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        store.savePendingSet(reps: store.pendingReps)
                    } label: {
                        Label(store.tr("Сохранить", "Save"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                    }
                    .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                    .frame(maxWidth: 250)
                    Spacer(minLength: 0)
                }
                .controlSize(.large)
            }
        }
    }

    private static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            FitBarCharacterMark(foreground: .secondary, accent: FitBarTheme.semanticFill(.green, opacity: 0.8))
                .frame(width: 42, height: 42)
            Text(store.tr("Список тренировки пуст", "The workout list is empty"))
                .font(.system(size: 13, weight: .semibold))
            Text(store.tr("Откройте библиотеку и добавьте\nупражнения кнопкой «+»",
                          "Open the library and add\nexercises with the “+” button"))
                .font(.system(size: 11))
                .foregroundStyle(FitBarTheme.textMuted)
                .multilineTextAlignment(.center)
            Button {
                openMainWindow()
            } label: {
                Label(store.tr("Открыть библиотеку", "Open library"),
                      systemImage: "square.grid.2x2")
            }
            .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    // MARK: Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(store.tr("Подходов сегодня: \(store.todayCount)",
                               "Sets today: \(store.todayCount)"),
                      systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(store.todayCount > 0 ? FitBarTheme.semantic(.orange) : FitBarTheme.textMuted)
                Spacer()
                if store.trainingStreak > 1 {
                    Text(store.tr("серия \(store.trainingStreak)",
                                  "streak \(store.trainingStreak)"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
            }
            HeatmapView(activity: store.activity, weeks: 16, cell: 12.5,
                        spacing: 3, showLegend: false,
                        lang: store.appLanguage)
                .frame(maxWidth: .infinity, alignment: .center)
            if let rec = store.recordExercise {
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(FitBarTheme.semantic(.yellow))
                    Text(store.tr("Рекорд: ", "Record: ")
                         + "\(store.displayName(rec.exercise)) — \(rec.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            Button {
                openMainWindow()
            } label: {
                Label(store.tr("Библиотека", "Library"), systemImage: "square.grid.2x2")
                    .font(.system(size: 12))
            }
            .buttonStyle(FitBarPlainButtonStyle())
            .foregroundStyle(FitBarTheme.textMuted)
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Label(store.tr("Выход", "Quit"), systemImage: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(FitBarPlainButtonStyle())
            .foregroundStyle(FitBarTheme.textMuted)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Daily side panel

    private var dailyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(todayTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(store.tr("серия плана: \(store.trainingStreak)",
                                  "plan streak: \(store.trainingStreak)"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
                Spacer(minLength: 4)
                Button {
                    showingWaterTargetEditor = true
                } label: {
                    Label(FitBarFormat.waterLiters(store.waterTargetML, lang: store.appLanguage),
                          systemImage: "slider.horizontal.3")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .buttonStyle(FitBarActionButtonStyle())
                .controlSize(.small)
                .help(store.tr("Выбрать норму воды", "Choose water target"))
            }

            waterPanel
            exerciseInstructionsPanel
        }
        .padding(12)
        .frame(width: 248, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var waterPanel: some View {
        let current = store.todayWaterML
        let target = max(1, store.waterTargetML)
        let progress = min(1, Double(current) / Double(target))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(store.tr("Вода", "Water"), systemImage: "drop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitBarTheme.semantic(.blue))
                Spacer()
                Text("\(FitBarFormat.waterLiters(current, lang: store.appLanguage)) / "
                     + FitBarFormat.waterLiters(target, lang: store.appLanguage))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            waterProgressBar(progress: progress)

            Text(store.tr("Количество выпитой воды:", "Water amount:"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FitBarTheme.textMuted)
            HStack(spacing: 5) {
                waterButton(store.tr("малое", "small"), ml: 100)
                waterButton(store.tr("среднее", "medium"), ml: 250)
                waterButton(store.tr("большое", "large"), ml: 350)
            }
            HStack(spacing: 6) {
                TextField("", value: $customWaterML, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 68)
                Text(store.tr("мл", "ml"))
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
                Button {
                    store.addWater(customWaterML)
                } label: {
                    Text(store.tr("Добавить", "Add"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(FitBarTheme.faintFill(0.04),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private func waterProgressBar(progress: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = progress <= 0 ? 0 : max(8, width * progress)
                let phase = timeline.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FitBarTheme.semanticFill(.blue, opacity: 0.12))
                    if fillWidth > 0 {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(waterAnimatedFill(phase: phase))
                            .frame(width: fillWidth)
                            .overlay(alignment: .topLeading) {
                                if !FitBarTheme.isMonochrome {
                                    WaveShape(phase: phase)
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: fillWidth, height: 10)
                                        .offset(y: 1)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.semanticFill(.blue, opacity: 0.62), lineWidth: 1.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.faintFill(0.15), lineWidth: 0.8)
                        .padding(2)
                )
                .shadow(color: FitBarTheme.semanticFill(.blue, opacity: FitBarTheme.isMonochrome ? 0 : 0.22),
                        radius: 8, x: 0, y: 0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(FitBarTheme.faintFill(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.semanticFill(.blue, opacity: 0.35), lineWidth: 1)
                        )
                )
            }
        }
        .frame(height: 28)
    }

    private func waterAnimatedFill(phase: TimeInterval) -> AnyShapeStyle {
        if FitBarTheme.isMonochrome {
            return AnyShapeStyle(Color.black)
        }
        let shift = 0.5 + 0.5 * sin(phase * 2.0)
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.70),
                    Color.blue.opacity(0.95),
                    Color.cyan.opacity(0.80),
                ],
                startPoint: UnitPoint(x: -0.35 + shift * 0.45, y: 0.5),
                endPoint: UnitPoint(x: 0.75 + shift * 0.45, y: 0.5)
            )
        )
    }

    private func waterButton(_ title: String, ml: Int) -> some View {
        Button {
            store.addWater(ml)
        } label: {
            Text("\(title)\n(\(ml) \(store.tr("мл", "ml")))")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .frame(height: 25)
        }
        .buttonStyle(FitBarActionButtonStyle())
        .controlSize(.small)
    }

    private var exerciseInstructionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(store.tr("Выполнение", "How to do it"),
                      systemImage: "list.number")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            if let exercise = store.currentExercise {
                let steps = exercise.steps(lang: store.appLanguage)
                if steps.isEmpty {
                    Text(store.tr("Для этого упражнения пока нет пошагового описания.",
                                  "This exercise has no step-by-step description yet."))
                        .font(.system(size: 11))
                        .foregroundStyle(FitBarTheme.textMuted)
                } else {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 7) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(FitBarTheme.semantic(.blue))
                                        .frame(width: 18, height: 18)
                                        .background(
                                            FitBarTheme.semanticFill(.blue, opacity: 0.15),
                                            in: Circle()
                                        )
                                    Text(step)
                                        .font(.system(size: 10))
                                        .foregroundStyle(FitBarTheme.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: .infinity)
                    .scrollIndicators(.automatic)
                }
            } else {
                Text(store.tr("Выберите упражнение, чтобы увидеть шаги.",
                              "Select an exercise to see the steps."))
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FitBarTheme.faintFill(0.04),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private var todayTitle: String {
        let locale = Locale(identifier: store.appLanguage == "ru" ? "ru_RU" : "en_US")
        return Date().formatted(
            Date.FormatStyle(locale: locale)
                .weekday(.wide)
                .day()
                .month(.wide)
        )
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct WaterTargetEditorPanel: View {
    @EnvironmentObject var store: AppStore
    let onClose: () -> Void
    @State private var customLiters = 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(store.tr("Норма воды", "Water target"), systemImage: "drop.fill")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 21))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(FitBarPlainButtonStyle())
                .foregroundStyle(FitBarTheme.textMuted)
            }

            targetButton(
                mode: .standard,
                detail: FitBarFormat.waterLiters(3000, lang: store.appLanguage)
            ) {
                store.setWaterTargetMode(.standard)
                onClose()
            }

            targetButton(
                mode: .ai,
                detail: store.aiWaterTargetML.map {
                    FitBarFormat.waterLiters($0, lang: store.appLanguage)
                } ?? store.tr("Сначала составьте план", "Generate a plan first"),
                disabled: store.aiWaterTargetML == nil
            ) {
                store.setWaterTargetMode(.ai)
                onClose()
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label(WaterTargetMode.custom.title(lang: store.appLanguage),
                          systemImage: store.selectedWaterTargetMode == .custom
                            ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Spacer()
                    TextField("", value: $customLiters,
                              format: .number.precision(.fractionLength(1...2)))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 82)
                    Text(store.tr("л", "L"))
                        .font(.system(size: 13, weight: .semibold))
                }
                Button(store.tr("Применить свою норму", "Apply custom target")) {
                    let ml = Int((min(max(customLiters, 0.5), 7.0) * 1000).rounded())
                    store.setCustomWaterTargetML(ml)
                    onClose()
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .background(FitBarTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FitBarTheme.controlStroke(
                    active: store.selectedWaterTargetMode == .custom), lineWidth: 1))
        }
        .padding(20)
        .frame(width: 420)
        .background(FitBarTheme.appBackground,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(FitBarTheme.strokeStrong, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(FitBarTheme.isMonochrome ? 0.16 : 0.36),
                radius: 24, x: 0, y: 10)
        .onAppear {
            customLiters = Double(store.profile.waterTargetML ?? store.waterTargetML) / 1000.0
        }
    }

    private func targetButton(
        mode: WaterTargetMode,
        detail: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: store.selectedWaterTargetMode == mode
                      ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .bold))
                Text(mode.title(lang: store.appLanguage))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            .padding(12)
            .background(FitBarTheme.controlFill(active: store.selectedWaterTargetMode == mode),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FitBarTheme.controlStroke(
                    active: store.selectedWaterTargetMode == mode), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .foregroundStyle(FitBarTheme.controlText(
            active: store.selectedWaterTargetMode == mode, disabled: disabled))
        .disabled(disabled)
    }
}

private struct WaveShape: Shape {
    var phase: TimeInterval

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude = rect.height * 0.22
        let midY = rect.midY
        let waveLength = max(1, rect.width * 0.65)
        path.move(to: CGPoint(x: rect.minX, y: midY))
        let step: CGFloat = 4
        var x = rect.minX
        while x <= rect.maxX {
            let angle = ((x / waveLength) * .pi * 2) + phase * 2.2
            let y = midY + CGFloat(sin(angle)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
