import SwiftUI
import AppKit

private enum GoalWizardStep: String, Identifiable {
    case outputs
    case goal
    case experience
    case trainingSetup
    case limitations
    case workoutBlocks
    case photos

    var id: String { rawValue }

    func title(lang: String) -> String {
        switch (self, lang) {
        case (.outputs, "ru"): return "Что получить"
        case (.goal, "ru"): return "Цель"
        case (.experience, "ru"): return "Опыт"
        case (.trainingSetup, "ru"): return "Тренировки"
        case (.limitations, "ru"): return "Ограничения"
        case (.workoutBlocks, "ru"): return "Сборки"
        case (.photos, "ru"): return "Фото"
        case (.outputs, _): return "Output"
        case (.goal, _): return "Goal"
        case (.experience, _): return "Experience"
        case (.trainingSetup, _): return "Training"
        case (.limitations, _): return "Limits"
        case (.workoutBlocks, _): return "Blocks"
        case (.photos, _): return "Photos"
        }
    }
}

struct GoalsView: View {
    @EnvironmentObject var store: AppStore
    @State private var photos: [GoalPhotoAttachment] = []
    @State private var detailExercise: Exercise?
    @State private var replacementTarget: RecommendedExercisePlan?
    @State private var currentStepIndex = 0
    @State private var maxUnlockedStepIndex = 0
    @State private var wizardCompleted = false
    @State private var wizardFinishedOnce = false
    @State private var showGroqKeyRequiredAfterWizard = false
    @State private var successToast: String?
    @State private var successToastToken = UUID()

    var body: some View {
        let _ = store.appTheme
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text(store.tr("Цели", "Goals"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                FitBarDivider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        inputCard
                        planCard
                    }
                    .padding(16)
                }
            }
            .background(FitBarTheme.appBackground)
            DismissibleDetailOverlay(exercise: $detailExercise)
                .environmentObject(store)
            if let successToast {
                VStack {
                    HStack {
                        Spacer()
                        Label(successToast, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(FitBarTheme.isMonochrome ? FitBarTheme.selectedFill : FitBarTheme.semanticFill(.green, opacity: 0.22), in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(FitBarTheme.semanticFill(.green, opacity: 0.50), lineWidth: 1)
                            )
                            .foregroundStyle(FitBarTheme.isMonochrome ? FitBarTheme.selectedText : FitBarTheme.semantic(.green))
                            .shadow(color: FitBarTheme.isMonochrome ? FitBarTheme.blackOpacity(0.04) : FitBarTheme.blackOpacity(0.22),
                                    radius: FitBarTheme.isMonochrome ? 2 : 12,
                                    x: 0,
                                    y: FitBarTheme.isMonochrome ? 1 : 8)
                    }
                    Spacer()
                }
                .padding(18)
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(5)
            }
        }
        .id(store.appTheme)
        .sheet(item: $replacementTarget) { rec in
            ExerciseReplacementPicker(target: rec)
                .environmentObject(store)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            profileCompactLine
            FitBarDivider().opacity(0.35)
            questionnaireWizard
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 16, raised: true)
    }

    private var profileCompactLine: some View {
        HStack(spacing: 10) {
            Text(store.tr("Профиль цели", "Goal profile"))
                .font(.headline)
            Spacer(minLength: 10)
            profilePill(icon: "ruler", text: "\(Int(store.profile.heightCM)) \(store.tr("см", "cm"))",
                        tint: .blue)
            profilePill(icon: "scalemass.fill",
                        text: String(format: "%.1f %@", store.profile.weightKG,
                                     store.tr("кг", "kg")),
                        tint: .green)
            profilePill(icon: "person.fill",
                        text: effectiveGender.title(lang: store.appLanguage),
                        tint: .secondary)
            HStack(spacing: 5) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(FitBarTheme.semantic(.orange))
                HStack(spacing: 2) {
                    TextField("", value: Binding(
                        get: { store.effectiveTargetWeightKG },
                        set: { store.updateProfileTargetWeightKG($0) }
                    ), format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.plain)
                    .frame(width: targetWeightFieldWidth, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    Text(store.tr("кг", "kg"))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(FitBarTheme.semanticFill(.orange, opacity: 0.13), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(FitBarTheme.isMonochrome
                                  ? Color.black
                                  : FitBarTheme.semanticFill(.orange, opacity: 0.45),
                                  lineWidth: FitBarTheme.isMonochrome ? 1.2 : 1)
            )
            directionBadge
        }
    }

    private var targetWeightFieldWidth: CGFloat {
        let value = store.effectiveTargetWeightKG
        let rounded = value.rounded()
        let text = abs(value - rounded) < 0.05
            ? "\(Int(rounded))"
            : String(format: "%.1f", value)
        return max(20, CGFloat(text.count) * 8 + 5)
    }

    private func profilePill(icon: String, text: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(FitBarTheme.isMonochrome ? Color.black : (tint == .secondary ? Color.primary.opacity(0.78) : tint))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(FitBarTheme.isMonochrome ? Color.white : tint.opacity(tint == .secondary ? 0.10 : 0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(FitBarTheme.isMonochrome ? Color.black : Color.clear, lineWidth: FitBarTheme.isMonochrome ? 1 : 0))
    }

    private var questionnaireWizard: some View {
        let steps = wizardSteps
        let safeIndex = min(currentStepIndex, max(steps.count - 1, 0))
        let step = steps[safeIndex]
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                    let isUnlocked = index <= maxUnlockedStepIndex
                    Button {
                        guard isUnlocked else { return }
                        currentStepIndex = index
                    } label: {
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .frame(width: 24, height: 24)
                                .foregroundStyle(index == safeIndex ? FitBarTheme.selectedText : FitBarTheme.text)
                                .background(index == safeIndex ? FitBarTheme.selectedFill : FitBarTheme.faintFill(isUnlocked ? 0.09 : 0.045),
                                            in: Circle())
                            Text(item.title(lang: store.appLanguage))
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(2)
                                .foregroundStyle(isUnlocked ? FitBarTheme.text : FitBarTheme.textMuted)
                            Spacer(minLength: 0)
                        }
                        .padding(7)
                        .background(index == safeIndex ? (FitBarTheme.isMonochrome ? Color.white : FitBarTheme.selectedFill.opacity(0.18)) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(index == safeIndex && FitBarTheme.isMonochrome ? Color.black : Color.clear,
                                              lineWidth: index == safeIndex && FitBarTheme.isMonochrome ? 1 : 0)
                        )
                    }
                    .buttonStyle(FitBarPlainButtonStyle())
                    .disabled(!isUnlocked)
                }
            }
            .frame(width: 190)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(step.title(lang: store.appLanguage))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Text(store.tr("Шаг \(safeIndex + 1) из \(steps.count)",
                                  "Step \(safeIndex + 1) of \(steps.count)"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
                wizardProgressBar(value: Double(safeIndex + 1),
                                  total: Double(max(steps.count, 1)))
                wizardStepContent(step)
                    .frame(minHeight: 185, alignment: .topLeading)
                HStack {
                    if safeIndex > 0 {
                        Button {
                            currentStepIndex = max(safeIndex - 1, 0)
                        } label: {
                            Label(store.tr("Назад", "Back"), systemImage: "chevron.left")
                        }
                        .buttonStyle(FitBarActionButtonStyle())
                    }
                    Spacer()
                    Button {
                        advanceWizard(from: safeIndex, steps: steps)
                    } label: {
                        Label(safeIndex == steps.count - 1
                              ? store.tr("Готово", "Done")
                              : store.tr("Дальше", "Next"),
                              systemImage: safeIndex == steps.count - 1
                              ? "checkmark"
                              : "chevron.right")
                    }
                    .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                    .disabled(!isStepAnswered(step))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FitBarTheme.faintFill(0.055), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
            )
        }
        .onChange(of: steps.map(\.id)) { _, _ in
            clampWizardProgress(for: steps)
        }
    }

    private func wizardProgressBar(value: Double, total: Double) -> some View {
        Group {
            if FitBarTheme.isMonochrome {
                GeometryReader { proxy in
                    let progress = total <= 0 ? 0 : min(max(value / total, 0), 1)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.black, lineWidth: 1.2)
                            )
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.black)
                            .frame(width: max(0, proxy.size.width * progress))
                    }
                }
                .frame(height: 8)
            } else {
                ProgressView(value: value, total: total)
                    .tint(FitBarTheme.semantic(.green))
            }
        }
    }

    @ViewBuilder
    private func wizardStepContent(_ step: GoalWizardStep) -> some View {
        switch step {
        case .outputs:
            VStack(alignment: .leading, spacing: 10) {
                Text(store.tr("Какую информацию вы хотите получить от ИИ?",
                              "What do you want AI to return?"))
                    .font(.system(size: 13, weight: .semibold))
                outputSelectionRow
                Text(store.tr(
                    "Следующие вопросы будут показаны только для выбранных разделов.",
                    "The next questions appear only for the selected sections."))
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
        case .goal:
            HStack(alignment: .top, spacing: 12) {
                singleSelectRow(store.tr("Цель тренировок", "Training goal"),
                                selection: $store.goal.trainingGoal,
                                mirror: $store.goal.trainingGoals,
                                onChange: markWizardDirty,
                                options: TrainingGoal.allCases)
                multiSelectRow(store.tr("Как хотите выглядеть", "Desired physique"),
                               selection: $store.goal.physiqueGoals,
                               fallback: .leanAndAthletic,
                               onChange: markWizardDirty,
                               options: PhysiqueGoal.allCases)
            }
        case .experience:
            HStack(alignment: .top, spacing: 12) {
                singleSelectRow(store.tr("Опыт", "Experience"),
                                selection: $store.goal.trainingExperience,
                                mirror: $store.goal.trainingExperiences,
                                onChange: markWizardDirty,
                                options: TrainingExperience.allCases)
                frequencySliderCard
            }
        case .trainingSetup:
            HStack(alignment: .top, spacing: 12) {
                singleSelectRow(store.tr("Где тренируетесь", "Training place"),
                                selection: $store.goal.trainingLocation,
                                onChange: markWizardDirty,
                                options: TrainingLocation.allCases)
                multiSelectRow(store.tr("Инвентарь", "Equipment"),
                               selection: $store.goal.equipmentOptions,
                               fallback: .bodyWeight,
                               onChange: markWizardDirty,
                               options: visibleEquipmentOptions)
            }
        case .limitations:
            multiSelectRow(store.tr("Ограничения", "Limitations"),
                           selection: $store.goal.limitationOptions,
                           fallback: .none,
                           onChange: markWizardDirty,
                           options: TrainingLimitations.allCases)
        case .workoutBlocks:
            optionCard(store.tr("Сколько сборок упражнений вы хотите получить?",
                                "How many workout blocks do you want?")) {
                HStack(spacing: 8) {
                    ForEach([1, 2, 3], id: \.self) { count in
                        Button {
                            store.goal.requestedWorkoutPlanCount = count
                            markWizardDirty()
                        } label: {
                            HStack(spacing: 5) {
                                if store.goal.requestedWorkoutPlanCount == count {
                                    Image(systemName: "checkmark")
                                }
                                Text("\(count)")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                store.goal.requestedWorkoutPlanCount == count
                                    ? FitBarTheme.selectedFill
                                    : FitBarTheme.faintFill(0.07),
                                in: Capsule()
                            )
                            .foregroundStyle(store.goal.requestedWorkoutPlanCount == count
                                             ? .white
                                             : FitBarTheme.textMuted)
                        }
                        .buttonStyle(FitBarPlainButtonStyle())
                    }
                }
            }
        case .photos:
            VStack(alignment: .leading, spacing: 10) {
                assessmentOptionsCard
                photoSection
                if let reason = photoStepDisabledReason {
                    Label(reason, systemImage: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(FitBarTheme.semantic(.orange))
                }
            }
        }
    }

    private var requestedOutputs: [GoalOutputOption] {
        store.goal.requestedOutputs
    }

    private var wantsCalories: Bool {
        requestedOutputs.contains(.caloriesMacros)
    }

    private var wantsWater: Bool {
        requestedOutputs.contains(.water)
    }

    private var wantsExercises: Bool {
        requestedOutputs.contains(.exercises)
    }

    private var wantsPhotoAssessment: Bool {
        requestedOutputs.contains(.bodyAssessment) || requestedOutputs.contains(.faceAssessment)
    }

    private var canBuildPlan: Bool {
        !store.planLoading && wizardReadyForGeneration && !requestedOutputs.isEmpty && buildDisabledReason == nil
    }

    private var buildDisabledReason: String? {
        if !store.hasVerifiedGroqAPIKey,
           wizardKeyRequirementShouldBeVisible {
            return groqKeyRequiredText
        }
        if !wizardReadyForGeneration {
            return store.tr("Ответьте на все нужные вопросы и нажмите «Готово».",
                            "Answer every required question and press Done.")
        }
        return planInputDisabledReason
    }

    private var wizardKeyRequirementShouldBeVisible: Bool {
        wizardReadyForGeneration || showGroqKeyRequiredAfterWizard || allRequiredWizardStepsAnswered
    }

    private var allRequiredWizardStepsAnswered: Bool {
        let steps = wizardSteps
        return !steps.isEmpty && steps.allSatisfy { isStepAnswered($0) }
    }

    private var wizardReadyForGeneration: Bool {
        wizardCompleted || (wizardFinishedOnce && allRequiredWizardStepsAnswered)
    }

    private var planInputDisabledReason: String? {
        if !store.hasVerifiedGroqAPIKey {
            return groqKeyRequiredText
        }
        if requestedOutputs.isEmpty {
            return store.tr("Выберите хотя бы один тип ответа ИИ.",
                            "Choose at least one AI response type.")
        }
        if wantsPhotoAssessment && photos.isEmpty {
            return store.tr("Для оценки фигуры или лица прикрепите фото либо отключите этот пункт.",
                            "Attach photos for body or face assessment, or turn that option off.")
        }
        return nil
    }

    private var groqKeyRequiredText: String {
        store.tr(
            "Подключите и проверьте Groq API-ключ во вкладке «ИИ-помощник», чтобы составить план.",
            "Connect and verify a Groq API key in the AI assistant tab to build a plan."
        )
    }

    private var photoStepDisabledReason: String? {
        if wantsPhotoAssessment && photos.isEmpty {
            return store.tr("Для завершения прикрепите фото либо отключите оценку фигуры/лица.",
                            "Attach photos to finish, or turn body/face assessment off.")
        }
        return nil
    }

    private var assessmentOptionsCard: some View {
        optionCard(store.tr("Хотите ли вы получить оценку фигуры и лица от ИИ?",
                            "Do you want AI body and face assessment?")) {
            BalancedFlowLayout(spacing: 8) {
                ForEach([GoalOutputOption.bodyAssessment, .faceAssessment]) { option in
                    let isSelected = store.goal.requestedOutputs.contains(option)
                    Button {
                        markWizardDirty()
                        toggleOutput(option, allowEmpty: true)
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(option.title(lang: store.appLanguage))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Color.white : FitBarTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(isSelected ? FitBarTheme.selectedFill : FitBarTheme.controlFill(),
                                    in: Capsule())
                        .overlay(Capsule().strokeBorder(FitBarTheme.controlStroke(active: isSelected), lineWidth: 1))
                    }
                    .buttonStyle(FitBarPlainButtonStyle())
                }
            }
        }
    }

    private func toggleOutput(_ option: GoalOutputOption, allowEmpty: Bool) {
        markWizardDirty()
        wizardFinishedOnce = false
        var values = store.goal.requestedOutputs
        if let index = values.firstIndex(of: option) {
            values.remove(at: index)
        } else {
            values.append(option)
        }
        if values.isEmpty && !allowEmpty {
            values = [.caloriesMacros]
        }
        store.goal.requestedOutputs = values
        maxUnlockedStepIndex = min(maxUnlockedStepIndex, 0)
        currentStepIndex = 0
    }

    private var outputSelectionRow: some View {
        optionCard("") {
            BalancedFlowLayout(spacing: 8) {
                ForEach(GoalOutputOption.allCases) { option in
                    let isSelected = store.goal.requestedOutputs.contains(option)
                    Button {
                        toggleOutput(option, allowEmpty: true)
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(option.title(lang: store.appLanguage))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Color.white : FitBarTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(isSelected ? FitBarTheme.selectedFill : FitBarTheme.controlFill(),
                                    in: Capsule())
                        .overlay(Capsule().strokeBorder(FitBarTheme.controlStroke(active: isSelected), lineWidth: 1))
                    }
                    .buttonStyle(FitBarPlainButtonStyle())
                }
            }
        }
    }

    private var wizardSteps: [GoalWizardStep] {
        var steps: [GoalWizardStep] = [.outputs, .goal]
        let wantsNutrition = store.goal.requestedOutputs.contains(.caloriesMacros)
            || store.goal.requestedOutputs.contains(.water)
        let wantsExercises = store.goal.requestedOutputs.contains(.exercises)
        let wantsPhotos = store.goal.requestedOutputs.contains(.bodyAssessment)
            || store.goal.requestedOutputs.contains(.faceAssessment)
        if wantsNutrition || wantsExercises {
            steps.append(.experience)
        }
        if wantsExercises {
            steps.append(contentsOf: [.trainingSetup, .limitations, .workoutBlocks])
        }
        if wantsPhotos {
            steps.append(.photos)
        }
        return steps
    }

    private func advanceWizard(from index: Int, steps: [GoalWizardStep]) {
        guard !steps.isEmpty, isStepAnswered(steps[index]) else { return }
        let isLast = index == steps.count - 1
        if isLast {
            wizardCompleted = true
            wizardFinishedOnce = true
            showGroqKeyRequiredAfterWizard = !store.hasVerifiedGroqAPIKey
            maxUnlockedStepIndex = 0
            currentStepIndex = 0
        } else {
            wizardCompleted = false
            let nextIndex = index + 1
            maxUnlockedStepIndex = max(maxUnlockedStepIndex, nextIndex)
            currentStepIndex = nextIndex
        }
    }

    private func clampWizardProgress(for steps: [GoalWizardStep]) {
        let maxIndex = max(steps.count - 1, 0)
        currentStepIndex = min(currentStepIndex, maxIndex)
        maxUnlockedStepIndex = min(maxUnlockedStepIndex, maxIndex)
    }

    private func markWizardDirty() {
        wizardCompleted = false
    }

    private func isStepAnswered(_ step: GoalWizardStep) -> Bool {
        switch step {
        case .outputs:
            return !store.goal.requestedOutputs.isEmpty
        case .goal:
            return !store.goal.physiqueGoals.isEmpty
        case .experience:
            return store.goal.trainingDaysPerWeek >= 1
        case .trainingSetup:
            return !store.goal.equipmentOptions.isEmpty
        case .limitations:
            return !store.goal.limitationOptions.isEmpty
        case .workoutBlocks:
            return store.goal.requestedWorkoutPlanCount >= 1
                && store.goal.requestedWorkoutPlanCount <= 3
        case .photos:
            return !wantsPhotoAssessment || !photos.isEmpty
        }
    }

    private var frequencySliderCard: some View {
        optionCard(store.tr("Тренировок в неделю", "Training days per week")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(store.goal.trainingDaysPerWeek)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(store.tr("раз(а) в неделю", "sessions per week"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                    Spacer()
                }
                Slider(
                    value: Binding(
                        get: { Double(store.goal.trainingDaysPerWeek) },
                        set: {
                            store.goal.trainingDaysPerWeek = min(max(Int($0.rounded()), 1), 7)
                            markWizardDirty()
                        }
                    ),
                    in: 1...7,
                    step: 1
                )
                HStack {
                    Text("1")
                    Spacer()
                    Text("7")
                }
                .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FitBarTheme.textFaint)
            }
        }
    }

    private var visibleEquipmentOptions: [EquipmentAccess] {
        if store.goal.trainingLocation == .home
            || store.goal.limitationOptions.contains(.homeOnly) {
            return [.bodyWeight, .dumbbell, .band, .kettlebell, .pullUpBar]
        }
        if store.goal.trainingLocation == .outdoor {
            return [.bodyWeight, .band]
        }
        return EquipmentAccess.allCases
    }

    private func multiSelectRow<T>(
        _ title: String, selection: Binding<[T]>, fallback: T,
        onChange: (() -> Void)? = nil, options: [T]
    ) -> some View where T: Identifiable & Hashable, T.ID == String {
        optionCard(title) {
            BalancedFlowLayout(spacing: 8) {
                ForEach(options) { option in
                    let isSelected = selection.wrappedValue.contains(option)
                    optionButton(option, isSelected: isSelected, checkmark: true) {
                        toggle(option, in: selection, fallback: fallback)
                        onChange?()
                    }
                }
            }
        }
    }

    private func singleSelectRow<T>(
        _ title: String, selection: Binding<T>, onChange: (() -> Void)? = nil,
        options: [T]
    ) -> some View where T: Identifiable & Hashable, T.ID == String {
        optionCard(title) {
            BalancedFlowLayout(spacing: 8) {
                ForEach(options) { option in
                    let isSelected = selection.wrappedValue == option
                    optionButton(option, isSelected: isSelected, checkmark: false) {
                        selection.wrappedValue = option
                        if let location = option as? TrainingLocation {
                            cleanEquipment(for: location)
                        }
                        onChange?()
                    }
                }
            }
        }
    }

    private func singleSelectRow<T>(
        _ title: String, selection: Binding<T>, mirror: Binding<[T]>,
        onChange: (() -> Void)? = nil, options: [T]
    ) -> some View where T: Identifiable & Hashable, T.ID == String {
        optionCard(title) {
            BalancedFlowLayout(spacing: 8) {
                ForEach(options) { option in
                    let isSelected = selection.wrappedValue == option
                    optionButton(option, isSelected: isSelected, checkmark: false) {
                        selection.wrappedValue = option
                        mirror.wrappedValue = [option]
                        onChange?()
                    }
                }
            }
        }
    }

    private func optionCard<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FitBarTheme.faintFill(0.055),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
    }

    private func optionButton<T>(
        _ option: T, isSelected: Bool, checkmark: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: checkmark ? "checkmark" : "circle.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(optionTitle(option))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : FitBarTheme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isSelected ? FitBarTheme.selectedFill : FitBarTheme.faintFill(0.07),
                in: Capsule()
            )
        }
        .buttonStyle(FitBarPlainButtonStyle())
    }

    private func toggle<T>(
        _ option: T, in selection: Binding<[T]>, fallback: T
    ) where T: Hashable {
        var values = selection.wrappedValue
        if let index = values.firstIndex(of: option) {
            values.remove(at: index)
        } else {
            if let limitation = option as? TrainingLimitations {
                if limitation == .none {
                    values.removeAll()
                } else {
                    values.removeAll { ($0 as? TrainingLimitations) == TrainingLimitations.none }
                }
                if limitation == .homeOnly {
                    cleanEquipment(for: .home)
                }
            }
            values.append(option)
        }
        selection.wrappedValue = values.isEmpty ? [fallback] : values
    }

    private func cleanEquipment(for location: TrainingLocation) {
        if location == .home || store.goal.limitationOptions.contains(.homeOnly) {
            store.goal.equipmentOptions.removeAll { $0 == .barbell || $0 == .machines }
        } else if location == .outdoor {
            store.goal.equipmentOptions.removeAll { ![.bodyWeight, .band].contains($0) }
        }
        if store.goal.equipmentOptions.isEmpty {
            store.goal.equipmentOptions = [.bodyWeight]
        }
    }

    private func optionTitle<T>(_ option: T) -> String {
        if let option = option as? TrainingGoal { return option.title(lang: store.appLanguage) }
        if let option = option as? PhysiqueGoal { return option.title(lang: store.appLanguage) }
        if let option = option as? TrainingExperience { return option.title(lang: store.appLanguage) }
        if let option = option as? WeeklyAvailability { return option.title(lang: store.appLanguage) }
        if let option = option as? TrainingLimitations { return option.title(lang: store.appLanguage) }
        if let option = option as? TrainingLocation { return option.title(lang: store.appLanguage) }
        if let option = option as? EquipmentAccess { return option.title(lang: store.appLanguage) }
        if let option = option as? GoalOutputOption { return option.title(lang: store.appLanguage) }
        return String(describing: option)
    }

    private var profileSummary: some View {
        HStack(spacing: 8) {
            Chip(text: "\(Int(store.profile.heightCM)) \(store.tr("см", "cm"))",
                 icon: "ruler", tint: .blue)
            Chip(text: String(format: "%.1f %@", store.profile.weightKG,
                              store.tr("кг", "kg")),
                 icon: "scalemass.fill", tint: .green)
            Chip(text: effectiveGender.title(lang: store.appLanguage),
                 icon: "person.fill", tint: .secondary)
        }
    }

    private var effectiveGender: UserGender {
        store.profile.gender == .female ? .female : .male
    }

    private var directionBadge: some View {
        let delta = store.effectiveTargetWeightKG - store.profile.weightKG
        let (text, tint, icon): (String, Color, String) =
            delta < 0
                ? (store.tr(String(format: "Похудение: −%.1f кг", abs(delta)),
                            String(format: "Weight loss: −%.1f kg", abs(delta))),
                   .orange, "arrow.down.right")
                : delta > 0
                    ? (store.tr(String(format: "Набор массы: +%.1f кг", delta),
                                String(format: "Weight gain: +%.1f kg", delta)),
                       .blue, "arrow.up.right")
                    : (store.tr("Вес уже на цели", "Already at goal weight"),
                       .green, "checkmark")
        return Chip(text: text, icon: icon, tint: tint)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.tr("Фото для оценки", "Photos for assessment"))
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
                Text(store.tr("не сохраняются", "not saved"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FitBarTheme.textFaint)
                Spacer()
                Button {
                    pickPhotos()
                    markWizardDirty()
                } label: {
                    Label(store.tr("Прикрепить", "Attach"), systemImage: "photo.on.rectangle")
                }
                .buttonStyle(FitBarActionButtonStyle())
                .disabled(photos.count >= 4)
                if !photos.isEmpty {
                    Button {
                        photos.removeAll()
                        markWizardDirty()
                    } label: {
                        Label(store.tr("Очистить", "Clear"), systemImage: "xmark.circle")
                    }
                    .buttonStyle(FitBarPlainButtonStyle())
                    .foregroundStyle(FitBarTheme.textMuted)
                }
            }
            if photos.isEmpty {
                Text(store.tr(
                    "Можно приложить до 4 фото. Они используются только в текущем запросе к Groq и не записываются в файлы приложения.",
                    "Attach up to 4 photos. They are used only for the current Groq request and are not saved by the app."))
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textFaint)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            ZStack(alignment: .topTrailing) {
                                Image(nsImage: photo.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 86, height: 86)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Button {
                                    photos.removeAll { $0.id == photo.id }
                                    markWizardDirty()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white, FitBarTheme.blackOpacity(0.55))
                                        .frame(width: 26, height: 26)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(FitBarPlainButtonStyle())
                            }
                        }
                    }
                }
            }
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.tr("Калории, БЖУ, вода и упражнения",
                              "Calories, macros, water & exercises"))
                    .font(.headline)
                Spacer()
                Button {
                    store.requestPlan(photos: photos.map { $0.payload })
                } label: {
                    HStack(spacing: 6) {
                        if store.planLoading {
                            ProgressView().controlSize(.small)
                            Text(store.tr("Считаю…", "Computing…"))
                        } else {
                            Image(systemName: "sparkles")
                            Text(store.plan == nil
                                 ? store.tr("Составить план", "Build plan")
                                 : store.tr("Перегенерировать", "Regenerate"))
                        }
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .disabled(!canBuildPlan)
            }

            if let reason = buildDisabledReason {
                Label(reason, systemImage: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.semantic(.orange))
            }

            if let error = store.planError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(FitBarTheme.semantic(.red))
                    .textSelection(.enabled)
            }

            if let saved = store.plan {
                planResult(saved)
            } else if !store.planLoading {
                emptyPlanPrompt
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 16)
    }

    private var emptyPlanPrompt: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(FitBarTheme.semanticFill(.green, opacity: 0.14))
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(FitBarTheme.semantic(.green))
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.tr("План ещё не составлен", "No plan yet"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(store.tr(
                    "Ответьте на вопросы выше. ИИ учтёт профиль, желаемый вес и всю библиотеку упражнений.",
                    "Answer the questions above. AI will use your profile, target weight and the full exercise library."))
                    .font(.system(size: 12))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .background(FitBarTheme.faintFill(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
    }

    private func planResult(_ saved: SavedPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            let outputs = saved.goal.requestedOutputs
            let showAssessment = outputs.contains(.bodyAssessment) || outputs.contains(.faceAssessment)
            let showCalories = outputs.contains(.caloriesMacros)
            let showWater = outputs.contains(.water)
            let showExercises = outputs.contains(.exercises)

            if showAssessment {
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.tr("Оценка ИИ по фото", "AI photo assessment"),
                          systemImage: "person.text.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                    Text(saved.plan.assessment.isEmpty
                         ? store.tr("ИИ не вернул отдельный текст оценки. Попробуйте перегенерировать план с фото.",
                                    "AI did not return a separate assessment text. Try regenerating with photos.")
                         : saved.plan.assessment)
                        .font(.system(size: 12))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FitBarTheme.faintFill(0.055),
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
                )
            }

            if showCalories || showWater {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                    if showCalories {
                        planStat(icon: "calendar", tint: .purple,
                                 value: "\(saved.plan.daysToGoal)",
                                 title: store.tr("дней до цели", "days to goal"),
                                 sub: goalDateString(days: saved.plan.daysToGoal))
                        planStat(icon: "flame.fill", tint: .orange,
                                 value: "\(saved.plan.dailyCalories)",
                                 title: store.tr("ккал в день", "kcal per day"), sub: nil)
                        planStat(icon: "chart.pie.fill", tint: .teal,
                                 value: "\(saved.plan.proteinG)/\(saved.plan.fatG)/\(saved.plan.carbsG)",
                                 title: store.tr("Б/Ж/У, г", "P/F/C, g"), sub: nil)
                    }
                    if showWater {
                        planStat(icon: "drop.fill", tint: .cyan,
                                 value: FitBarFormat.waterLiters(
                                    saved.plan.waterTargetML, lang: store.appLanguage),
                                 title: store.tr("воды в день", "water per day"),
                                 sub: nil)
                    }
                }
            }

            if showCalories && !saved.plan.foods.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.tr("Чем питаться в первую очередь", "Priority foods"))
                        .font(.system(size: 13, weight: .semibold))
                    FlowChips(items: saved.plan.foods)
                }
            }

            if showExercises && !saved.plan.workoutFocus.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.tr("Тренировочный фокус", "Training focus"))
                        .font(.system(size: 13, weight: .semibold))
                    FlowLayout(spacing: 6) {
                        ForEach(saved.plan.workoutFocus, id: \.self) { item in
                            Chip(text: item, icon: "target", tint: .blue)
                        }
                    }
                }
            }

            if showExercises {
                recommendations(saved)
            }

            if showCalories && !saved.plan.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(saved.plan.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(FitBarTheme.semantic(.yellow))
                                .padding(.top, 2)
                            Text(tip)
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Text(store.tr("не медицинская рекомендация", "not medical advice"))
                .font(.system(size: 10))
                .foregroundStyle(FitBarTheme.textFaint)
        }
    }

    private func recommendations(_ saved: SavedPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.tr("Рекомендованные упражнения", "Recommended exercises"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    store.regeneratePlanFromUserEdits(includeExercises: true,
                                                      includeNutrition: false)
                } label: {
                    Label(store.tr("Пересчитать по заменам", "Recompute edits"),
                          systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(FitBarActionButtonStyle())
                .disabled(!saved.recommendationsEdited
                          || store.planLoading)
                Button {
                    store.saveRecommendedExercisesToWorkout()
                    showSuccessToast(store.tr("Упражнения сохранены в мой список",
                                              "Exercises saved to my list"))
                } label: {
                    Label(store.tr("Сохранить в мой список", "Save to my list"),
                          systemImage: "plus.circle.fill")
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .disabled(saved.plan.recommendedExercises.isEmpty)
            }

            if saved.plan.recommendedExercises.isEmpty {
                Text(store.tr("ИИ не вернул список упражнений. Попробуйте перегенерировать план.",
                              "AI did not return exercise recommendations. Try regenerating the plan."))
                    .font(.system(size: 12))
                    .foregroundStyle(FitBarTheme.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(displayWorkoutPlans(saved).enumerated()), id: \.element.id) {
                        index, block in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(block.title.isEmpty
                                     ? store.tr("Сборка \(index + 1)", "Plan \(index + 1)")
                                     : block.title)
                                    .font(.system(size: 12, weight: .semibold))
                                ForEach(block.focus.prefix(3), id: \.self) { focus in
                                    Chip(text: focus, icon: "target", tint: .blue)
                                }
                            }
                            ForEach(block.exercises) { rec in
                                recommendationRow(rec)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let exercise = store.byID[rec.exerciseID] {
                                            detailExercise = exercise
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
    }

    private func showSuccessToast(_ text: String) {
        let token = UUID()
        successToastToken = token
        withAnimation(.snappy) {
            successToast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard successToastToken == token else { return }
            withAnimation(.snappy) {
                successToast = nil
            }
        }
    }

    private func displayWorkoutPlans(_ saved: SavedPlan) -> [WorkoutPlanBlock] {
        if !saved.plan.workoutPlans.isEmpty { return saved.plan.workoutPlans }
        return [WorkoutPlanBlock(title: "", focus: saved.plan.workoutFocus,
                                 exercises: saved.plan.recommendedExercises)]
    }

    private func recommendationRow(_ rec: RecommendedExercisePlan) -> some View {
        let exercise = store.byID[rec.exerciseID]
        return HStack(spacing: 10) {
            if let exercise {
                IconBubble(category: exercise.category,
                           symbol: ExerciseVisualStyle.icon(exercise),
                           showsCategoryBadge: false,
                           size: 34)
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 26))
                    .frame(width: 34)
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.map(store.displayName) ?? rec.exerciseID)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(rec.note)
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .lineLimit(2)
            }
            Spacer()
            RecommendedDoseEditButton(rec: rec)
                .environmentObject(store)
            Button {
                replacementTarget = rec
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            .buttonStyle(FitBarPlainButtonStyle())
            .help(store.tr("Заменить упражнение", "Replace exercise"))
        }
        .padding(10)
        .background(FitBarTheme.faintFill(0.055),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
    }

    private func planStat(icon: String, tint: Color, value: String,
                          title: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FitBarTheme.semantic(tint))
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let sub {
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(FitBarTheme.textFaint)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FitBarTheme.faintFill(0.055),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
    }

    private func numberField(
        _ title: String, value: Binding<Double>, unit: String,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(FitBarTheme.textMuted)
            HStack(spacing: 4) {
                TextField("", value: value,
                          format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 84)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        value.wrappedValue = min(max(value.wrappedValue,
                                                     range.lowerBound),
                                                 range.upperBound)
                    }
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundStyle(FitBarTheme.textMuted)
                Stepper("", value: value, in: range, step: 1)
                    .labelsHidden()
            }
        }
    }

    private func goalDateString(days: Int) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: Date())
        else { return "" }
        let formatted = date.formatted(
            Date.FormatStyle(locale: Locale(
                identifier: store.appLanguage == "ru" ? "ru_RU" : "en_US"))
            .day().month(.wide))
        return store.tr("до ", "by ") + formatted
    }

    private func pickPhotos() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            let newPhotos = panel.urls.compactMap { GoalPhotoAttachment(url: $0) }
            photos = Array((photos + newPhotos).prefix(4))
        }
    }
}

struct GoalPhotoAttachment: Identifiable {
    let id = UUID()
    let image: NSImage
    let payload: GoalPhotoPayload

    init?(url: URL) {
        guard let image = NSImage(contentsOf: url),
              let data = Self.jpegData(from: image)
        else { return nil }
        self.image = image
        self.payload = GoalPhotoPayload(mimeType: "image/jpeg", data: data)
    }

    private static func jpegData(from image: NSImage) -> Data? {
        let maxSide: CGFloat = 1024
        let original = image.size
        let scale = min(1, maxSide / max(original.width, original.height))
        let size = NSSize(width: max(1, original.width * scale),
                          height: max(1, original.height * scale))
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        guard let rep else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72])
    }
}

struct ExerciseReplacementPicker: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let target: RecommendedExercisePlan
    @State private var query = ""

    private var candidates: [Exercise] {
        let goal = store.plan?.goal ?? store.goal
        let pool = ExercisePlanCatalog.candidates(
            profile: store.plan?.profile ?? store.profile,
            goal: goal,
            exercises: store.exercises,
            limit: 180
        )
        let existing = Set(store.plan?.plan.recommendedExercises.map(\.exerciseID) ?? [])
            .subtracting([target.exerciseID])
        let filtered = pool.filter { !existing.contains($0.id) }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Array(filtered.prefix(120)) }
        return filtered.filter { ex in
            [
                store.displayName(ex), ex.name, store.targetLabel(ex.target),
                store.equipmentLabel(ex.equipment), store.categoryLabel(ex.category),
            ].joined(separator: " ").lowercased().contains(q)
        }
        .prefix(120)
        .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.tr("Заменить упражнение", "Replace exercise"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(FitBarTheme.textFaint)
                }
                .buttonStyle(FitBarPlainButtonStyle())
            }
            .padding(16)
            FitBarDivider()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FitBarTheme.textMuted)
                TextField(store.tr("Поиск по названию, мышце, инвентарю…",
                                   "Search by name, muscle, equipment…"),
                          text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(FitBarTheme.faintFill(0.06), in: RoundedRectangle(cornerRadius: 9))
            .padding(14)

            List(candidates) { exercise in
                Button {
                    store.replaceRecommendedExercise(target.exerciseID, with: exercise.id)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        IconBubble(category: exercise.category,
                                   symbol: ExerciseVisualStyle.icon(exercise),
                                   showsCategoryBadge: false,
                                   size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.displayName(exercise))
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(store.targetLabel(exercise.target)) · \(store.equipmentLabel(exercise.equipment))")
                                .font(.system(size: 11))
                                .foregroundStyle(FitBarTheme.textMuted)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(FitBarPlainButtonStyle())
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 560, height: 620)
        .dismissOnOutsideSheetClick {
            dismiss()
        }
    }
}

/// Wrapping chips row.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Chip(text: item, icon: "leaf.fill", tint: .green)
            }
        }
    }
}

/// Wraps wizard choices while using the available row width deliberately.
/// Rows with several close-fitting choices are justified; sparse rows are
/// centered so a short final row never leaves an accidental-looking tail.
struct BalancedFlowLayout: Layout {
    var spacing: CGFloat = 8
    var maxJustifiedSpacing: CGFloat = 44

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let arrangement = arrange(
            width: proposal.width ?? .infinity,
            subviews: subviews,
            justify: false
        )
        return CGSize(
            width: proposal.width ?? arrangement.contentWidth,
            height: arrangement.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arrangement = arrange(
            width: bounds.width,
            subviews: subviews,
            justify: true
        )
        for (subview, position) in zip(subviews, arrangement.positions) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x,
                            y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(
        width: CGFloat,
        subviews: Subviews,
        justify: Bool
    ) -> (positions: [CGPoint], height: CGFloat, contentWidth: CGFloat) {
        let availableWidth = width.isFinite ? max(width, 1) : CGFloat.greatestFiniteMagnitude
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0

        for index in sizes.indices {
            let proposedWidth = currentWidth
                + (current.isEmpty ? 0 : spacing)
                + sizes[index].width
            if !current.isEmpty, proposedWidth > availableWidth {
                rows.append(current)
                current = [index]
                currentWidth = sizes[index].width
            } else {
                current.append(index)
                currentWidth = proposedWidth
            }
        }
        if !current.isEmpty { rows.append(current) }

        var positions = Array(repeating: CGPoint.zero, count: sizes.count)
        var y: CGFloat = 0
        var contentWidth: CGFloat = 0

        for row in rows {
            let itemsWidth = row.reduce(CGFloat.zero) { $0 + sizes[$1].width }
            let minimumRowWidth = itemsWidth + spacing * CGFloat(max(row.count - 1, 0))
            let freeWidth = max(0, availableWidth - itemsWidth)
            let justifiedSpacing = row.count > 1
                ? freeWidth / CGFloat(row.count - 1)
                : 0
            let shouldJustify = justify
                && row.count > 1
                && justifiedSpacing <= maxJustifiedSpacing
            let actualSpacing = shouldJustify ? justifiedSpacing : spacing
            let renderedWidth = itemsWidth
                + actualSpacing * CGFloat(max(row.count - 1, 0))
            let startX = justify && !shouldJustify
                ? max(0, (availableWidth - renderedWidth) / 2)
                : 0
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            var x = startX

            for index in row {
                positions[index] = CGPoint(x: x, y: y)
                x += sizes[index].width + actualSpacing
            }
            contentWidth = max(contentWidth, minimumRowWidth)
            y += rowHeight + spacing
        }

        return (
            positions,
            rows.isEmpty ? 0 : max(0, y - spacing),
            contentWidth
        )
    }
}

/// Minimal left-to-right wrapping layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                      cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let positions = arrange(proposal: proposal, subviews: subviews).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified)
        }
    }

    private func arrange(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
        }
        return (CGSize(width: totalWidth, height: y + rowHeight), positions)
    }
}
