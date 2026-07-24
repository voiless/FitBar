import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedEntry: DiaryEntry?
    @State private var showingDeleteReason = false
    @State private var showingFinalDelete = false

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            header
            FitBarDivider()
            if store.diary.isActive {
                activeDiary
            } else {
                DiaryStartView()
            }
        }
        .background(FitBarTheme.appBackground)
        .id(store.appTheme)
        .onAppear { store.refreshDiaryForToday() }
        .sheet(item: $selectedEntry) { entry in
            DiaryEntryEditor(entry: entry,
                             readOnly: store.diary.isReadOnly(entry))
                .environmentObject(store)
        }
        .confirmationDialog(store.tr("Удалить цель", "Delete goal"),
                            isPresented: $showingDeleteReason) {
            Button(store.tr("Ввёл неверные данные", "I entered incorrect data"),
                   role: .destructive) {
                store.resetDiary()
            }
            Button(store.tr("Другая причина", "Another reason")) {
                showingFinalDelete = true
            }
            Button(store.tr("Отмена", "Cancel"), role: .cancel) {}
        } message: {
            Text(store.tr("Почему хотите удалить цель?",
                          "Why do you want to delete the goal?"))
        }
        .sheet(isPresented: $showingFinalDelete) {
            DiaryDeleteMotivationSheet {
                store.resetDiary()
                showingFinalDelete = false
            }
            .environmentObject(store)
        }
    }

    private var header: some View {
        HStack {
            Text(store.tr("Дневник", "Diary"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(FitBarTheme.text)
            Spacer()
            if store.diary.isActive {
                Button(role: .destructive) {
                    showingDeleteReason = true
                } label: {
                    Label(store.tr("Удалить цель", "Delete goal"),
                          systemImage: "trash")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(FitBarActionButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var activeDiary: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Text(store.tr(
                        "Осталось \(store.diary.daysLeft()) дней до цели",
                        "\(store.diary.daysLeft()) days left to goal"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FitBarTheme.text)
                        .multilineTextAlignment(.center)
                    Text(store.diary.goalText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 14)

                LazyVStack(spacing: 10) {
                    ForEach(store.diary.sortedEntries()) { entry in
                        DiaryEntryRow(entry: entry) {
                            if !entry.isMissed {
                                selectedEntry = entry
                            }
                        }
                        .disabled(entry.isMissed)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 1050)
            .frame(maxWidth: .infinity)
        }
        .fitBarOverlayScrollbars()
    }
}

private enum DiaryDurationMode {
    case days
    case date
}

private struct DiaryStartIntroCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(FitBarTheme.semanticFill(.green, opacity: 0.14))
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FitBarTheme.semantic(.green))
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                Text(store.tr("Начните путь к цели", "Start your goal journey"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(FitBarTheme.text)
                Text(store.tr(
                    "Выберите срок, частоту тренировок и сформулируйте цель. После старта здесь будут появляться ежедневные записи.",
                    "Choose a timeline, weekly training frequency and your goal. Daily entries will appear here after you start."))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(22)
        .fitBarCard(radius: 18, raised: true)
    }
}

private struct DiaryStartView: View {
    @EnvironmentObject var store: AppStore
    @State private var durationMode: DiaryDurationMode = .days
    @State private var days = 30
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var trainingDays = 3
    @State private var goalText = ""
    @State private var seeded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DiaryStartIntroCard()

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        durationButton(.days,
                                       title: store.tr("По дням", "By days"),
                                       icon: "number")
                        durationButton(.date,
                                       title: store.tr("По календарю", "By date"),
                                       icon: "calendar")
                    }

                    if durationMode == .days {
                        DiaryNumberField(title: store.tr("Количество дней", "Number of days"),
                                         value: $days,
                                         suffix: store.tr("дн.", "days"),
                                         range: 1...3650)
                    } else {
                        DatePicker(store.tr("Дата цели", "Goal date"),
                                   selection: $targetDate,
                                   in: Date()...,
                                   displayedComponents: .date)
                            .datePickerStyle(.field)
                            .foregroundStyle(FitBarTheme.text)
                    }

                    DiaryNumberField(title: store.tr("Тренировок в неделю", "Workouts per week"),
                                     value: $trainingDays,
                                     suffix: store.tr("раз", "times"),
                                     range: 1...7)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(store.tr("Цель", "Goal"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(FitBarTheme.textMuted)
                        TextField(store.tr("Например: стать выносливее и похудеть",
                                           "Example: improve endurance and lose weight"),
                                  text: $goalText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(FitBarTheme.controlFill(), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FitBarTheme.controlStroke(), lineWidth: 1))
                    }

                    Button {
                        store.startDiary(days: durationDays,
                                         trainingDaysPerWeek: trainingDays,
                                         goalText: goalText)
                    } label: {
                        Label(store.tr("Начать путь", "Start journey"),
                              systemImage: "flag.checkered")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                    .disabled(goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(22)
                .fitBarCard(radius: 18, raised: true)
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .fitBarOverlayScrollbars()
        .onAppear {
            guard !seeded else { return }
            seeded = true
            days = store.suggestedDiaryDays()
            trainingDays = store.goal.trainingDaysPerWeek
            targetDate = Calendar.current.date(byAdding: .day, value: max(days - 1, 0), to: Date()) ?? Date()
        }
    }

    private var durationDays: Int {
        if durationMode == .days {
            return min(max(days, 1), 3650)
        }
        let current = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        return min(max((Calendar.current.dateComponents([.day], from: current, to: target).day ?? 0) + 1, 1), 3650)
    }

    private func durationButton(_ mode: DiaryDurationMode, title: String, icon: String) -> some View {
        let active = durationMode == mode
        return Button {
            durationMode = mode
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FitBarTheme.controlFill(active: active), in: Capsule())
                .overlay(Capsule().strokeBorder(FitBarTheme.controlStroke(active: active), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .foregroundStyle(FitBarTheme.controlText(active: active))
    }
}

private struct DiaryEntryRow: View {
    @EnvironmentObject var store: AppStore
    let entry: DiaryEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(entry.isMissed ? FitBarTheme.faintFill(0.05) : FitBarTheme.controlFill(active: entry.hasMeaningfulData))
                    Text("\(entry.dayNumber)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.hasMeaningfulData ? FitBarTheme.selectedText : FitBarTheme.textMuted)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(rowTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.isMissed ? FitBarTheme.textFaint : FitBarTheme.text)
                        .lineLimit(2)
                    Text(rowSubtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.isMissed ? FitBarTheme.textFaint : FitBarTheme.textMuted)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: entry.isMissed ? "lock.fill" : "chevron.right")
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            .padding(16)
            .fitBarCard(radius: 16)
        }
        .buttonStyle(FitBarPlainButtonStyle())
    }

    private var rowTitle: String {
        "\(dateString(entry.date)), \(yearString(entry.date)) — \(entry.dayNumber) \(store.tr("день на пути к цели", "day on the path to goal"))"
    }

    private var rowSubtitle: String {
        if entry.isMissed {
            return store.tr("День пропущен", "Day missed")
        }
        if entry.isRestDay {
            return store.tr("Сегодня отдых", "Rest day")
        }
        var parts: [String] = []
        if entry.exerciseSets > 0 {
            parts.append(store.tr("\(entry.exerciseSets) подходов", "\(entry.exerciseSets) sets"))
        }
        if entry.waterML > 0 {
            parts.append(FitBarFormat.waterLiters(entry.waterML, lang: store.appLanguage)
                         + " " + store.tr("воды", "water"))
        }
        if entry.calories > 0 {
            parts.append("\(entry.calories) \(store.tr("ккал", "kcal"))")
        }
        return parts.isEmpty
            ? store.tr("Запись ожидает заполнения", "Entry is waiting to be filled")
            : parts.joined(separator: " · ")
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.appLanguage == "ru" ? "ru_RU" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate(store.appLanguage == "ru" ? "d MMMM" : "MMMM d")
        return formatter.string(from: date)
    }

    private func yearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}

private struct DiaryEntryEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DiaryEntry
    let readOnly: Bool

    init(entry: DiaryEntry, readOnly: Bool) {
        _draft = State(initialValue: entry)
        self.readOnly = readOnly
    }

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: readOnly ? "lock.fill" : "square.and.pencil")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FitBarTheme.semantic(.blue))
                    .frame(width: 50, height: 50)
                    .background(FitBarTheme.semanticFill(.blue, opacity: 0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(readOnly
                         ? store.tr("Прошлый день можно только посмотреть.", "Past days are read-only.")
                         : store.tr(
                            "Тренировка и вода считываются из menu bar. Остальные поля можно оставить пустыми.",
                            "Workout and water data come from the menu bar. Other fields may be left empty."))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                }
                .buttonStyle(FitBarPlainButtonStyle())
                .foregroundStyle(FitBarTheme.textMuted)
            }
            .padding(20)

            FitBarDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $draft.isRestDay) {
                        Label(store.tr("Сегодня отдых", "Rest day"),
                              systemImage: "moon.zzz.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .disabled(readOnly)
                    .toggleStyle(FitBarCheckboxToggleStyle())

                    VStack(alignment: .leading, spacing: 10) {
                        Label(store.tr("Данные из menu bar", "Data from menu bar"),
                              systemImage: "menubar.rectangle")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(FitBarTheme.textMuted)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            DiaryReadOnlyMetric(title: store.tr("Подходы", "Sets"),
                                                value: "\(draft.exerciseSets)")
                            DiaryReadOnlyMetric(title: store.tr("Повторы", "Reps"),
                                                value: "\(draft.exerciseReps)")
                            DiaryReadOnlyMetric(title: store.tr("Время упражнений", "Exercise time"),
                                                value: "\(draft.exerciseMinutes) \(store.tr("мин", "min"))")
                            DiaryReadOnlyMetric(title: store.tr("Вода", "Water"),
                                                value: FitBarFormat.waterLiters(
                                                    draft.waterML, lang: store.appLanguage))
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text(store.tr("Упражнения", "Exercises"))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(FitBarTheme.textMuted)
                            ScrollView(.vertical, showsIndicators: false) {
                                Text(draft.exerciseNotes.isEmpty
                                     ? store.tr("Сегодня в menu bar пока нет сохранённых подходов.",
                                                "No sets have been saved in the menu bar today yet.")
                                     : draft.exerciseNotes)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(draft.exerciseNotes.isEmpty
                                                     ? FitBarTheme.textFaint
                                                     : FitBarTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .fitBarHiddenScrollbars()
                            .frame(minHeight: 82, maxHeight: 112)
                            .background(FitBarTheme.controlFill(), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(FitBarTheme.controlStroke(), lineWidth: 1))
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DiaryNumberField(title: store.tr("Калории", "Calories"),
                                         value: $draft.calories,
                                         suffix: store.tr("ккал", "kcal"), range: 0...50000)
                        DiaryNumberField(title: store.tr("Белки", "Protein"),
                                         value: $draft.proteinG,
                                         suffix: store.tr("г", "g"), range: 0...5000)
                        DiaryNumberField(title: store.tr("Жиры", "Fat"),
                                         value: $draft.fatG,
                                         suffix: store.tr("г", "g"), range: 0...5000)
                        DiaryNumberField(title: store.tr("Углеводы", "Carbs"),
                                         value: $draft.carbsG,
                                         suffix: store.tr("г", "g"), range: 0...5000)
                    }
                    .disabled(readOnly)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(store.tr("Мысли дня", "Daily thoughts"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(FitBarTheme.textMuted)
                        FitBarHiddenTextEditor(text: $draft.thoughts, isEditable: !readOnly)
                            .padding(8)
                            .frame(minHeight: 120)
                            .background(FitBarTheme.controlFill(), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FitBarTheme.controlStroke(), lineWidth: 1))
                            .disabled(readOnly)
                    }
                }
                .padding(20)
            }
            .fitBarOverlayScrollbars()

            FitBarDivider()
            HStack {
                Spacer()
                if readOnly {
                    Button(store.tr("Закрыть", "Close")) {
                        dismiss()
                    }
                    .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                } else {
                    Button {
                        store.saveDiaryEntry(draft)
                        dismiss()
                    } label: {
                        Label(store.tr("Сохранить день", "Save day"), systemImage: "checkmark")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(minWidth: 155, minHeight: 28)
                    }
                    .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                }
            }
            .padding(16)
        }
        .frame(width: 720, height: 720)
        .background(FitBarTheme.appBackground)
        .onAppear { syncAuthoritativeActivityData() }
        .onChange(of: store.diary) { _, _ in syncAuthoritativeActivityData() }
        .dismissOnOutsideSheetClick {
            dismiss()
        }
    }

    private var title: String {
        store.tr("Запись дня \(draft.dayNumber)", "Day \(draft.dayNumber) entry")
    }

    private func syncAuthoritativeActivityData() {
        guard let latest = store.diary.entries[draft.dateKey] else { return }
        draft.exerciseSets = latest.exerciseSets
        draft.exerciseReps = latest.exerciseReps
        draft.exerciseMinutes = latest.exerciseMinutes
        draft.waterML = latest.waterML
        draft.exerciseNotes = latest.exerciseNotes
    }
}

private struct DiaryDeleteMotivationSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.red)
                Text(store.tr("Подумайте ещё раз", "Think once more"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(FitBarTheme.text)
            }
            Text(store.tr(
                "Пауза — это нормально. Сомнения тоже нормальны. Но цель появилась не случайно: в начале пути вы хотели что-то изменить и уже сделали выбор в свою пользу. Вы точно уверены, что хотите бросить то, к чему стремились и хотели добиться в самом начале вашего пути?",
                "A pause is normal. Doubts are normal too. But this goal did not appear by accident: at the beginning you wanted to change something and already chose yourself. Are you sure you want to abandon what you were aiming for at the start of your journey?"
            ))
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(FitBarTheme.textMuted)
            .lineSpacing(3)

            HStack(spacing: 12) {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text(store.tr("Нет", "No"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(width: 118, height: 38)
                        .foregroundStyle(Color.white)
                        .background(FitBarTheme.selectedFill, in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(FitBarPlainButtonStyle())

                Button(role: .destructive) {
                    onConfirm()
                    dismiss()
                } label: {
                    Text(store.tr("Да", "Yes"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(width: 118, height: 38)
                        .foregroundStyle(Color.red)
                        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(Color.red.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(FitBarPlainButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(FitBarTheme.appBackground)
        .dismissOnOutsideSheetClick {
            dismiss()
        }
    }
}

private struct DiaryReadOnlyMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(FitBarTheme.textMuted)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(FitBarTheme.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FitBarTheme.controlFill(), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(FitBarTheme.controlStroke(), lineWidth: 1)
        }
    }
}

private struct DiaryNumberField: View {
    let title: String
    @Binding var value: Int
    let suffix: String
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(FitBarTheme.textMuted)
            HStack(spacing: 7) {
                TextField("", value: $value, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .onChange(of: value) { _, newValue in
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .frame(minWidth: 76)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(FitBarTheme.controlFill(), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FitBarTheme.controlStroke(), lineWidth: 1))
        }
    }
}
