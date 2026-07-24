import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum SidebarItem: Hashable {
    case all
    case workout
    case activity
    case diary
    case goals
    case aiAssistant
    case account
    case category(String)
}

private enum SidebarSettingsMode {
    case language
    case theme
}

private struct SidebarCategoryContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SidebarCategoryViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SidebarCategoryOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MainWindowView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection: SidebarItem = .all
    @State private var detailExercise: Exercise?
    @State private var accountHasUnsavedChanges = false
    @State private var pendingSelection: SidebarItem?
    @State private var showingDiscardAccountAlert = false
    @State private var categoryScrollContentHeight: CGFloat = 0
    @State private var categoryScrollViewportHeight: CGFloat = 0
    @State private var categoryScrollOffset: CGFloat = 0
    @State private var categoryScrollbarVisible = false
    @State private var categoryScrollbarHideTask: DispatchWorkItem?
    @State private var sidebarSettingsMode: SidebarSettingsMode = .language

    var body: some View {
        // FitBarTheme is a shared palette, so make this view explicitly
        // observe the published theme and redraw the full navigation shell.
        let _ = store.appTheme
        ZStack {
            HStack(spacing: 0) {
                sidebar
                FitBarDivider(vertical: true)
                content
            }
            DismissibleDetailOverlay(exercise: $detailExercise)
                .environmentObject(store)
        }
        .frame(minWidth: mainContentMinWidth, minHeight: 640)
        .sheet(isPresented: Binding(
            get: { store.needsGenderSelection },
            set: { _ in }
        )) {
            GenderOnboardingSheet()
                .environmentObject(store)
        }
        .alert(store.tr("Несохранённые изменения", "Unsaved changes"),
               isPresented: $showingDiscardAccountAlert) {
            Button(store.tr("Остаться", "Stay"), role: .cancel) {
                pendingSelection = nil
            }
            Button(store.tr("Перейти без сохранения", "Leave without saving"),
                   role: .destructive) {
                if let pendingSelection {
                    accountHasUnsavedChanges = false
                    applySelection(pendingSelection)
                    self.pendingSelection = nil
                }
            }
        } message: {
            Text(store.tr(
                "Изменения в профиле не будут сохранены.",
                "Profile changes will not be saved."))
        }
    }

    private var mainContentMinWidth: CGFloat {
        let hasActiveFilters = store.selectedEquipment != nil
            || store.selectedTarget != nil
        return hasActiveFilters ? 1500 : 1240
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            sidebarHeader

            sidebarRow(.all, icon: "square.grid.2x2.fill",
                       title: store.tr("Библиотека", "Library"),
                       count: store.exercises.count)
            sidebarRow(.activity, icon: "chart.bar.fill",
                       title: store.tr("Активность", "Activity"), count: nil)
            sidebarRow(.diary, icon: "book.closed.fill",
                       title: store.tr("Дневник", "Diary"), count: nil)
            sidebarRow(.workout, icon: "list.bullet.rectangle",
                       title: store.tr("Мой список", "My list"),
                       count: nil)
            sidebarRow(.goals, icon: "target",
                       title: store.tr("Цели", "Goals"), count: nil)
            sidebarRow(.aiAssistant,
                       icon: "sparkles",
                       title: store.tr("ИИ-помощник", "AI assistant"),
                       count: nil)
                .opacity(store.hasVerifiedGroqAPIKey ? 1 : 0.62)
            sidebarRow(.account, icon: "person.crop.circle.fill",
                       title: store.tr("Аккаунт", "Account"), count: nil)

            if isLibrarySelection {
                Text(store.tr("ЧАСТИ ТЕЛА", "BODY PARTS"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(FitBarTheme.textFaint)
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(store.allCategories, id: \.name) { cat in
                            sidebarRow(.category(cat.name),
                                       icon: BodyPartStyle.icon(cat.name),
                                       title: store.categoryLabel(cat.name),
                                       count: cat.count,
                                       iconTint: .bodyPart(cat.name))
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: SidebarCategoryContentHeightKey.self,
                                            value: proxy.size.height)
                                .preference(key: SidebarCategoryOffsetKey.self,
                                            value: proxy.frame(in: .named("sidebarCategoryScroll")).minY)
                        }
                    )
                }
                .fitBarHiddenScrollbars()
                .coordinateSpace(name: "sidebarCategoryScroll")
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: SidebarCategoryViewportHeightKey.self,
                                               value: proxy.size.height)
                    }
                )
                .overlay(alignment: .trailing) {
                    if categoryScrollMetrics.isScrollable {
                        Capsule()
                            .fill(FitBarTheme.textMuted.opacity(0.58))
                            .frame(width: 5, height: categoryScrollMetrics.thumbHeight)
                            .offset(y: categoryScrollMetrics.thumbOffset)
                            .opacity(categoryScrollbarVisible ? 1 : 0)
                            .padding(.trailing, 2)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .animation(.easeOut(duration: 0.16), value: categoryScrollbarVisible)
                    }
                }
                .onPreferenceChange(SidebarCategoryContentHeightKey.self) { height in
                    categoryScrollContentHeight = height
                }
                .onPreferenceChange(SidebarCategoryViewportHeightKey.self) { height in
                    categoryScrollViewportHeight = height
                }
                .onPreferenceChange(SidebarCategoryOffsetKey.self) { offset in
                    if abs(categoryScrollOffset - offset) > 0.5 {
                        categoryScrollOffset = offset
                        revealCategoryScrollbar()
                    }
                }
            }
            Spacer(minLength: 0)
            sidebarSettingsSwitcher
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(width: 220)
        .background(
            FitBarTheme.appBackground
                .overlay(FitBarTheme.faintFill(0.025))
        )
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            FitBarCharacterMark(
                foreground: .white,
                accent: Color(red: 0.10, green: 0.92, blue: 0.60)
            )
            .frame(width: 40, height: 40)
            Text("FitBar")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var sidebarSettingsSwitcher: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(store.tr("Настройки", "Settings"), systemImage: "slider.horizontal.3")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(FitBarTheme.textFaint)

            HStack(spacing: 3) {
                sidebarModeButton(
                    mode: .language,
                    title: store.tr("Язык", "Language"),
                    icon: "globe"
                )
                sidebarModeButton(
                    mode: .theme,
                    title: store.tr("Тема", "Theme"),
                    icon: "circle.lefthalf.filled"
                )
            }
            .padding(3)
            .background(FitBarTheme.faintFill(0.055), in: RoundedRectangle(cornerRadius: 9))

            HStack(spacing: 3) {
                switch sidebarSettingsMode {
                case .language:
                    sidebarChoiceButton(title: "RU", isSelected: store.appLanguage == "ru") {
                        store.appLanguage = "ru"
                    }
                    sidebarChoiceButton(title: "EN", isSelected: store.appLanguage == "en") {
                        store.appLanguage = "en"
                    }
                case .theme:
                    ForEach(AppColorTheme.allCases) { theme in
                        sidebarChoiceButton(
                            title: theme.title(lang: store.appLanguage),
                            isSelected: store.appTheme == theme
                        ) {
                            store.setAppTheme(theme)
                        }
                    }
                }
            }
            .padding(3)
            .background(FitBarTheme.faintFill(0.055), in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(.horizontal, 4)
    }

    private func sidebarModeButton(mode: SidebarSettingsMode, title: String, icon: String) -> some View {
        let selected = sidebarSettingsMode == mode
        return Button {
            sidebarSettingsMode = mode
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 26)
                .foregroundStyle(selected ? FitBarTheme.selectedText : FitBarTheme.textMuted)
                .background(
                    selected
                        ? FitBarTheme.selectedFill
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(FitBarTheme.isMonochrome ? Color.black : Color.clear,
                                      lineWidth: FitBarTheme.isMonochrome ? 1.2 : 0)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(maxWidth: .infinity, minHeight: 26)
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .buttonStyle(FitBarPlainButtonStyle())
    }

    private func sidebarChoiceButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 26)
                .foregroundStyle(isSelected ? FitBarTheme.selectedText : FitBarTheme.textMuted)
                .background(
                    isSelected ? FitBarTheme.selectedFill : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(FitBarTheme.isMonochrome ? Color.black : Color.clear,
                                      lineWidth: FitBarTheme.isMonochrome ? 1.2 : 0)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(maxWidth: .infinity, minHeight: 26)
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .buttonStyle(FitBarPlainButtonStyle())
    }

    private var isLibrarySelection: Bool {
        if selection == .all { return true }
        if case .category = selection { return true }
        return false
    }

    private var categoryScrollMetrics: (isScrollable: Bool, thumbHeight: CGFloat, thumbOffset: CGFloat) {
        let viewport = max(categoryScrollViewportHeight, 1)
        let content = max(categoryScrollContentHeight, viewport)
        guard content > viewport + 2 else { return (false, 0, 0) }

        let thumbHeight = max(34, viewport * viewport / content)
        let scrollable = max(content - viewport, 1)
        let rawOffset = min(max(-categoryScrollOffset, 0), scrollable)
        let travel = max(viewport - thumbHeight, 0)
        return (true, thumbHeight, travel * rawOffset / scrollable)
    }

    private func revealCategoryScrollbar() {
        guard categoryScrollMetrics.isScrollable else { return }
        categoryScrollbarHideTask?.cancel()

        withAnimation(.easeOut(duration: 0.12)) {
            categoryScrollbarVisible = true
        }

        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.26)) {
                categoryScrollbarVisible = false
            }
        }
        categoryScrollbarHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: task)
    }

    private func sidebarRow(
        _ item: SidebarItem, icon: String, title: String, count: Int?,
        countTint: Color = .secondary, iconTint: Color? = nil
    ) -> some View {
        let isSelected = selection == item
        return Button {
            requestSelection(item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(iconTint ?? (isSelected ? FitBarTheme.semantic(.green) : FitBarTheme.textMuted))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? FitBarTheme.text : FitBarTheme.textMuted)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(FitBarTheme.semantic(countTint))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(FitBarTheme.faintFill(0.085), in: Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                isSelected ? FitBarTheme.faintFill(0.105) : Color.clear,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(isSelected ? FitBarTheme.strokeStrong : Color.clear,
                                  lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(FitBarPlainButtonStyle())
    }

    private func requestSelection(_ item: SidebarItem) {
        guard selection == .account, item != .account, accountHasUnsavedChanges else {
            applySelection(item)
            return
        }
        pendingSelection = item
        showingDiscardAccountAlert = true
    }

    private func applySelection(_ item: SidebarItem) {
        selection = item
        if case .category(let c) = item {
            store.selectedCategory = c
        } else if item == .all {
            store.selectedCategory = nil
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .all, .category:
            BrowserView(detailExercise: $detailExercise)
        case .activity:
            ActivityView()
        case .diary:
            DiaryView()
        case .workout:
            WorkoutListView(detailExercise: $detailExercise)
        case .goals:
            GoalsView()
        case .aiAssistant:
            AIAssistantView()
        case .account:
            AccountView(hasUnsavedChanges: $accountHasUnsavedChanges)
        }
    }
}

// MARK: - Browser (grid + search + filters)

struct BrowserView: View {
    @EnvironmentObject var store: AppStore
    @Binding var detailExercise: Exercise?

    private let columns = [GridItem(.adaptive(minimum: 285), spacing: 12)]

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            header
            FitBarDivider()
            if store.filtered.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: store.tr("Ничего не найдено", "Nothing found"),
                    subtitle: store.tr(
                        "Попробуйте изменить запрос или сбросить фильтры.",
                        "Try a different query or reset the filters."),
                    actionTitle: store.tr("Сбросить фильтры", "Reset filters"),
                    actionIcon: "xmark.circle.fill"
                ) {
                    withAnimation(.snappy) {
                        store.searchText = ""
                        store.selectedEquipment = nil
                        store.selectedTarget = nil
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.filtered) { ex in
                            ExerciseCard(exercise: ex)
                                .onTapGesture { detailExercise = ex }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(FitBarTheme.appBackground)
        .id(store.appTheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(store.selectedCategory.map { store.categoryLabel($0) }
                     ?? store.tr("Все упражнения", "All exercises"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("\(store.filtered.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(FitBarTheme.semanticFill(.white, opacity: 0.07), in: Capsule())
                Spacer(minLength: 12)
            }
            toolbarPanel
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(FitBarTheme.appBackground.overlay(FitBarTheme.faintFill(0.018)))
    }

    private var toolbarPanel: some View {
        HStack(spacing: 10) {
            searchField
                .frame(minWidth: 300, idealWidth: 430, maxWidth: .infinity)
                .layoutPriority(3)
            libraryControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(FitBarTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
    }

    private var libraryControls: some View {
        HStack(spacing: 10) {
            equipmentFilterControl
                .frame(width: 180)
            muscleFilterControl
                .frame(width: 170)
            sortControl
                .frame(width: 205)
            if hasActiveLibraryControls {
                resetButton
                    .frame(width: 205)
                    .layoutPriority(2)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var equipmentFilterControl: some View {
        filterMenu(
            title: store.tr("Инвентарь", "Equipment"), icon: "dumbbell",
            selection: $store.selectedEquipment,
            options: store.allEquipment, label: store.equipmentLabel
        )
    }

    private var muscleFilterControl: some View {
        filterMenu(
            title: store.tr("Мышца", "Muscle"), icon: "target",
            selection: $store.selectedTarget,
            options: store.allTargets, label: store.targetLabel
        )
    }

    private var filterControls: some View {
        HStack(spacing: 8) {
            equipmentFilterControl
            muscleFilterControl
        }
    }

    private var hasActiveLibraryControls: Bool {
        store.selectedEquipment != nil || store.selectedTarget != nil
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FitBarTheme.textMuted)
                .font(.system(size: 13, weight: .semibold))
            TextField(store.tr("Поиск по названию, мышце, инвентарю…",
                               "Search by name, muscle, equipment…"),
                      text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FitBarTheme.textFaint)
                        .font(.system(size: 12))
                }
                .buttonStyle(FitBarPlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(FitBarTheme.panelStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(store.searchText.isEmpty ? FitBarTheme.stroke : (FitBarTheme.isMonochrome ? Color.black : FitBarTheme.selectedFill.opacity(0.45)),
                              lineWidth: 1)
        )
    }

    private func filterMenu(
        title: String, icon: String, selection: Binding<String?>,
        options: [String], label: @escaping (String) -> String
    ) -> some View {
        let isActive = selection.wrappedValue != nil
        let currentTitle = selection.wrappedValue.map(label) ?? title

        return Menu {
            Button(store.tr("Все", "All")) { selection.wrappedValue = nil }
            FitBarDivider()
            ForEach(options, id: \.self) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    if selection.wrappedValue == option {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(currentTitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            .foregroundStyle(FitBarTheme.controlText(active: isActive))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                FitBarTheme.controlFill(active: isActive),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(FitBarTheme.controlStroke(active: isActive),
                                  lineWidth: isActive ? 1.5 : 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .help(currentTitle)
    }

    private var sortControl: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    store.sortOrder = order
                } label: {
                    if store.sortOrder == order {
                        Label(order.title(lang: store.appLanguage), systemImage: "checkmark")
                    } else {
                        Text(order.title(lang: store.appLanguage))
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .bold))
                Text(store.sortOrder.title(lang: store.appLanguage))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            .foregroundStyle(FitBarTheme.textMuted)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(FitBarTheme.semanticFill(.white, opacity: 0.055), in: Capsule())
            .overlay(Capsule().strokeBorder(FitBarTheme.stroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .help(store.tr("Сортировка", "Sort"))
    }

    private var resetButton: some View {
        Button {
            withAnimation(.snappy) {
                store.selectedEquipment = nil
                store.selectedTarget = nil
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(store.tr("Сбросить фильтрацию", "Reset filtering"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(FitBarTheme.controlFill(), in: Capsule())
            .overlay(Capsule().strokeBorder(FitBarTheme.controlStroke(), lineWidth: 1.2))
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .foregroundStyle(FitBarTheme.text)
    }
}

// MARK: - My workout list

struct WorkoutListView: View {
    @EnvironmentObject var store: AppStore
    @Binding var detailExercise: Exercise?
    @State private var addingToBlock: WorkoutBlock?
    @State private var showingCreateBlock = false

    private var destructiveIconColor: Color {
        FitBarTheme.isMonochrome ? .black : FitBarTheme.semantic(.red)
    }

    private var destructiveIconFill: Color {
        FitBarTheme.isMonochrome ? .white : FitBarTheme.semanticFill(.red, opacity: 0.10)
    }

    private var destructiveIconStroke: Color {
        FitBarTheme.isMonochrome ? .black : FitBarTheme.semanticFill(.red, opacity: 0.36)
    }

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(store.tr("Мой список", "My list"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    showingCreateBlock = true
                } label: {
                    Label(store.tr("Создать сборку", "Create plan"),
                          systemImage: "square.stack.3d.up.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(FitBarActionButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            FitBarDivider()

            if store.workout.exerciseIDs.isEmpty && store.workout.blocks.isEmpty {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: store.tr("Список пуст", "The list is empty"),
                    subtitle: store.tr(
                        "Создайте сборку или добавьте упражнения из библиотеки кнопкой «+».",
                        "Create a plan block or add exercises from the library with the “+” button.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(store.workout.blocks.enumerated()), id: \.element.id) {
                            index, block in
                            blockCard(index: index, block: block)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(FitBarTheme.appBackground)
        .id(store.appTheme)
        .onAppear { store.ensureWorkoutBlocksForDisplay() }
        .sheet(item: $addingToBlock) { block in
            WorkoutBlockExercisePicker(block: block)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingCreateBlock) {
            CreateWorkoutBlockSheet(defaultTitle: store.nextWorkoutBlockTitle()) { title in
                store.addWorkoutBlock(title: title)
            }
            .environmentObject(store)
        }
    }

    private func blockCard(index: Int, block: WorkoutBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                HStack(spacing: 8) {
                    TextField(
                        store.tr("Название сборки", "Plan name"),
                        text: Binding(
                            get: { block.title },
                            set: { store.renameWorkoutBlock(block.id, title: $0) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: 260)
                    Spacer()
                    Button {
                        addingToBlock = block
                    } label: {
                        Label(store.tr("Добавить упражнение", "Add exercise"),
                              systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(FitBarActionButtonStyle())
                    Button(role: .destructive) {
                        store.removeWorkoutBlock(block.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(destructiveIconColor)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FitBarPlainButtonStyle())
                    .help(store.tr("Удалить сборку", "Delete plan block"))
                }
                HStack {
                    Spacer()
                    Chip(
                        text: store.tr("Всего упражнений: \(block.exerciseIDs.count)",
                                       "Total exercises: \(block.exerciseIDs.count)"),
                        icon: "list.bullet",
                        tint: .blue
                    )
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            let exercises = store.workoutExercises(in: block)
            if exercises.isEmpty {
                Text(store.tr("В этой сборке пока нет упражнений.",
                              "This plan block has no exercises yet."))
                    .font(.system(size: 12))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FitBarTheme.faintFill(0.055),
                                in: RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(exercises) { exercise in
                    workoutRow(block: block, exercise: exercise)
                        .contentShape(Rectangle())
                        .onTapGesture { detailExercise = exercise }
                }
            }
        }
        .padding(12)
        .fitBarCard(radius: 14)
    }

    private func workoutRow(block: WorkoutBlock, exercise: Exercise) -> some View {
        let globalIndex = store.workout.exerciseIDs.firstIndex(of: exercise.id)
        let isCurrent = globalIndex == store.workout.currentIndex
        return HStack(spacing: 10) {
            IconBubble(
                category: exercise.category,
                symbol: ExerciseVisualStyle.icon(exercise),
                showsCategoryBadge: false,
                size: 34
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(store.displayName(exercise))
                    .font(.system(size: 13, weight: isCurrent ? .bold : .semibold))
                    .lineLimit(1)
                Text("\(store.targetLabel(exercise.target)) · \(store.equipmentLabel(exercise.equipment))")
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                store.removeExercise(exercise.id, from: block.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(destructiveIconColor)
                    .frame(width: 28, height: 28)
                    .background(destructiveIconFill, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(destructiveIconStroke, lineWidth: 1)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(FitBarPlainButtonStyle())
            .help(store.tr("Удалить из сборки", "Remove from plan block"))
            Button {
                detailExercise = exercise
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            .buttonStyle(FitBarPlainButtonStyle())
        }
        .padding(10)
        .background(FitBarTheme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
        .contextMenu {
            if let globalIndex {
                Button {
                    store.jump(to: globalIndex)
                } label: {
                    Label(store.tr("Сделать текущим в menu bar",
                                   "Make current in the menu bar"),
                          systemImage: "arrow.right.circle")
                }
            }
            Button(role: .destructive) {
                store.removeExercise(exercise.id, from: block.id)
            } label: {
                Label(store.tr("Удалить из сборки", "Remove from plan block"),
                      systemImage: "trash")
            }
        }
    }
}

struct WorkoutBlockExercisePicker: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let block: WorkoutBlock
    @State private var query = ""

    private var currentBlock: WorkoutBlock? {
        store.workout.blocks.first { $0.id == block.id }
    }

    private var candidates: [Exercise] {
        let used = Set(currentBlock?.exerciseIDs ?? [])
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.exercises
            .filter { !used.contains($0.id) }
            .filter { ex in
                guard !q.isEmpty else { return true }
                return [
                    store.displayName(ex), ex.name,
                    store.targetLabel(ex.target),
                    store.equipmentLabel(ex.equipment),
                    store.categoryLabel(ex.category),
                ].joined(separator: " ").lowercased().contains(q)
            }
    }

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            HStack {
                Text(store.tr("Добавить в сборку", "Add to plan block"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(currentBlock?.title ?? block.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitBarTheme.textMuted)
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
                    store.addExercise(exercise, to: block.id)
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
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(FitBarTheme.semantic(.green))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(FitBarPlainButtonStyle())
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .padding(.vertical, 6)
        }
        .frame(width: 620, height: 680)
        .dismissOnOutsideSheetClick {
            dismiss()
        }
    }
}

// MARK: - First launch profile setup

struct GenderOnboardingSheet: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.stroke,
                                          lineWidth: 1)
                    )
                FitBarArtworkImage(artwork: .app, padding: 3)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(width: 86, height: 86)

            VStack(spacing: 6) {
                Text(store.tr("Выберите пол", "Choose your gender"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(store.tr(
                    "Это нужно для схемы тела, целей и базовых расчётов профиля.",
                    "This helps body maps, goals and profile estimates work correctly."))
                    .font(.system(size: 13))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                genderButton(.male, icon: "figure.stand")
                genderButton(.female, icon: "figure.stand.dress")
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(FitBarTheme.appBackground)
    }

    private func genderButton(_ gender: UserGender, icon: String) -> some View {
        Button {
            store.setProfileGender(gender)
        } label: {
            Label(gender.title(lang: store.appLanguage), systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
    }
}

// MARK: - AI Assistant

struct AIAssistantView: View {
    @EnvironmentObject var store: AppStore
    @State private var draftGroqKey = ""
    @State private var showsGroqKey = false
    @State private var isChangingGroqKey = false
    @State private var modelDropdownExpanded = false
    private let keyActionButtonWidth: CGFloat = 178
    private let keyActionButtonHeight: CGFloat = 30

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            HStack {
                Text(store.tr("ИИ-помощник", "AI assistant"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            FitBarDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.hasVerifiedGroqAPIKey {
                        assistantDashboard
                    } else {
                        activationPanel
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(FitBarTheme.appBackground)
        .onAppear {
            draftGroqKey = store.groqAPIKey
            store.refreshGroqModelsIfNeeded()
        }
        .onChange(of: store.groqAPIKey) { _, key in
            draftGroqKey = key
        }
        .onChange(of: store.groqKeyValidationState) { _, state in
            if state == .valid,
               normalizedDraftGroqKey == store.groqAPIKey,
               isChangingGroqKey {
                isChangingGroqKey = false
                showsGroqKey = false
            }
        }
    }

    private var activationPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.semantic(.orange))
                    .frame(width: 44, height: 44)
                    .background(FitBarTheme.semanticFill(.orange, opacity: 0.14),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FitBarTheme.stroke, lineWidth: 1))
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.tr("Подключите Groq API-ключ", "Connect a Groq API key"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(store.tr(
                        "ИИ-помощник использует Groq для генерации планов во вкладке «Цели». Ключ хранится только локально на этом Mac в Application Support.",
                        "The AI assistant uses Groq to generate plans in Goals. The key is stored only locally on this Mac in Application Support."
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(store.tr("Как получить ключ", "How to get a key"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(store.tr(
                    "Откройте Groq Console, войдите в аккаунт, создайте API key в разделе Keys и скопируйте значение, которое начинается с gsk_.",
                    "Open Groq Console, sign in, create an API key in Keys, then copy the value that starts with gsk_."
                ))
                .font(.system(size: 12))
                .foregroundStyle(FitBarTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                Link(destination: URL(string: "https://console.groq.com/keys")!) {
                    Label(store.tr("Открыть Groq Console", "Open Groq Console"),
                          systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(FitBarActionButtonStyle())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FitBarTheme.faintFill(0.055), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FitBarTheme.stroke, lineWidth: 1))

            keyEntry
            assistantStatusLine
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 16, raised: true)
    }

    private var keyEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.tr("Groq API-ключ", "Groq API key"))
                .font(.system(size: 11))
                .foregroundStyle(FitBarTheme.textMuted)
            HStack(spacing: 8) {
                Group {
                    if showsGroqKey {
                        TextField(store.tr("Вставьте ключ вида gsk_…", "Paste a gsk_… key"),
                                  text: $draftGroqKey)
                    } else {
                        SecureField(store.tr("Вставьте ключ вида gsk_…", "Paste a gsk_… key"),
                                    text: $draftGroqKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

                Button {
                    showsGroqKey.toggle()
                } label: {
                    Image(systemName: showsGroqKey ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .frame(width: 34, height: keyActionButtonHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FitBarPlainButtonStyle())
                .help(store.tr(showsGroqKey ? "Скрыть ключ" : "Показать ключ",
                               showsGroqKey ? "Hide key" : "Show key"))

                Button {
                    store.connectGroqAPIKey(normalizedDraftGroqKey)
                } label: {
                    if store.groqKeyValidationState == .checking {
                        Label(store.tr("Проверяем…", "Verifying…"),
                              systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label(keySubmitTitle,
                              systemImage: "checkmark.shield.fill")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .frame(width: keyActionButtonWidth, height: keyActionButtonHeight)
                .disabled(normalizedDraftGroqKey.isEmpty || store.groqKeyValidationState == .checking)
            }
        }
    }

    private var assistantDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            connectedCard
            if isChangingGroqKey {
                keyChangeCard
            }
            modelPickerCard
        }
    }

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.semantic(.green))
                    .frame(width: 42, height: 42)
                    .background(FitBarTheme.semanticFill(.green, opacity: 0.14),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FitBarTheme.stroke, lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.tr("ИИ-помощник подключён", "AI assistant connected"))
                        .font(.headline)
                    Text(store.tr(
                        "Активная модель используется при генерации и регенерации планов во вкладке «Цели».",
                        "The active model is used for generating and regenerating plans in Goals."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(FitBarTheme.textMuted)
                }
                Spacer()
                groqStatusBadge
            }

            HStack(spacing: 10) {
                Label(store.maskedGroqAPIKey, systemImage: "key.fill")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FitBarTheme.textMuted)
                Spacer()
                Button {
                    draftGroqKey = store.groqAPIKey
                    isChangingGroqKey.toggle()
                    showsGroqKey = false
                } label: {
                    Label(isChangingGroqKey
                          ? store.tr("Скрыть замену", "Hide key change")
                          : store.tr("Изменить ключ", "Change key"),
                          systemImage: isChangingGroqKey ? "xmark.circle" : "key")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .buttonStyle(FitBarActionButtonStyle())

                Button {
                    store.refreshGroqModels(force: true)
                } label: {
                    if store.groqModelsLoading {
                        Label(store.tr("Обновляем…", "Refreshing…"),
                              systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label(store.tr("Обновить модели", "Refresh models"),
                              systemImage: "arrow.clockwise")
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .buttonStyle(FitBarActionButtonStyle())
                .disabled(store.groqModelsLoading)
            }

            Text(modelCatalogStatusText)
                .font(.system(size: 11))
                .foregroundStyle(FitBarTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 15, raised: true)
    }

    private var keyChangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.tr("Замена Groq API-ключа", "Change Groq API key"))
                .font(.headline)
            Text(store.tr(
                "Новый ключ будет сохранён только после успешной проверки через Groq.",
                "The new key is saved only after a successful Groq verification."
            ))
            .font(.system(size: 12))
            .foregroundStyle(FitBarTheme.textMuted)
            keyEntry
            assistantStatusLine
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 15)
    }

    private var modelPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.tr("Модель Groq", "Groq model"))
                    .font(.headline)
                Spacer()
                Text(store.tr("по убыванию мощности", "strongest first"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FitBarTheme.textFaint)
            }

            modelMenu
            if modelDropdownExpanded {
                modelDropdownList
            }
            selectedModelDetails
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 15)
    }

    private var modelMenu: some View {
        Button {
            withAnimation(.snappy) {
                modelDropdownExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FitBarTheme.semantic(.green))
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedGroqModel.id)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(FitBarTheme.text)
                        .lineLimit(1)
                    Text(modelMetaText(store.selectedGroqModel))
                        .font(.system(size: 11))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .lineLimit(1)
                }
                Spacer()
                Text(store.tr("Выбрать модель", "Choose model"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(FitBarTheme.textMuted)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .rotationEffect(.degrees(modelDropdownExpanded ? 180 : 0))
            }
            .padding(11)
            .background(FitBarTheme.faintFill(0.055), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FitBarTheme.stroke, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(FitBarPlainButtonStyle())
    }

    private var modelDropdownList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 6) {
                ForEach(store.availableGroqModels) { model in
                    Button {
                        store.selectGroqModel(model.id)
                        withAnimation(.snappy) {
                            modelDropdownExpanded = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: model.id == store.selectedGroqModelID
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(model.id == store.selectedGroqModelID
                                                 ? FitBarTheme.semantic(.green)
                                                 : FitBarTheme.textMuted)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.id)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(FitBarTheme.text)
                                    .lineLimit(1)
                                Text(modelMetaText(model))
                                    .font(.system(size: 10))
                                    .foregroundStyle(FitBarTheme.textMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            model.id == store.selectedGroqModelID
                                ? FitBarTheme.faintFill(0.09)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(FitBarPlainButtonStyle())
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 260)
        .background(FitBarTheme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FitBarTheme.strokeStrong, lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var selectedModelDetails: some View {
        let model = store.selectedGroqModel
        let isSelected = model.id == store.selectedGroqModelID
        let usage = store.groqModelUsage[model.id]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? FitBarTheme.semantic(.green) : FitBarTheme.textMuted)
                    .frame(width: 20, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.id)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(FitBarTheme.text)
                            .lineLimit(1)
                        if model.isFallback {
                            Text(store.tr("fallback", "fallback"))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(FitBarTheme.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FitBarTheme.faintFill(0.08), in: Capsule())
                        }
                    }
                    Text(modelMetaText(model))
                        .font(.system(size: 11))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .lineLimit(1)
                    Text(modelUsageText(usage))
                        .font(.system(size: 11))
                        .foregroundStyle(FitBarTheme.textFaint)
                        .lineLimit(2)
                    if let message = usage?.lastRateLimitMessage, !message.isEmpty {
                        Text(store.tr("Последний лимит: \(message)",
                                      "Latest limit: \(message)"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FitBarTheme.semantic(.orange))
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
        }
        .padding(10)
        .background(FitBarTheme.faintFill(0.045), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FitBarTheme.stroke, lineWidth: 1))
    }

    private var assistantStatusLine: some View {
        Label(statusText, systemImage: statusIcon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(statusColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var groqStatusBadge: some View {
        Label(statusText, systemImage: statusIcon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(FitBarTheme.isMonochrome ? Color.black : statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                FitBarTheme.isMonochrome ? Color.white : statusColor.opacity(0.13),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    FitBarTheme.isMonochrome ? Color.black : statusColor.opacity(0.42),
                    lineWidth: 1
                )
            )
    }

    private var normalizedDraftGroqKey: String {
        draftGroqKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var keySubmitTitle: String {
        if store.hasVerifiedGroqAPIKey {
            return store.tr("Проверить и заменить", "Verify and replace")
        }
        return store.tr("Проверить и включить", "Verify and enable")
    }

    private var statusText: String {
        switch store.groqKeyValidationState {
        case .missing:
            return store.tr("Ключ не добавлен", "No key added")
        case .unchecked:
            return store.tr("Ключ нужно проверить", "Key needs verification")
        case .checking:
            return store.tr("Проверяем ключ через Groq…", "Verifying the key with Groq…")
        case .valid:
            return store.tr("Ключ работает", "Key works")
        case .invalid:
            return store.tr("Groq отклонил ключ", "Groq rejected the key")
        case .unavailable(let message):
            return store.tr("Проверка не удалась: \(message)",
                            "Verification failed: \(message)")
        }
    }

    private var statusIcon: String {
        switch store.groqKeyValidationState {
        case .missing: return "key.slash"
        case .unchecked: return "questionmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.octagon.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch store.groqKeyValidationState {
        case .valid:
            return FitBarTheme.semantic(.green)
        case .checking:
            return FitBarTheme.semantic(.blue)
        case .invalid, .unavailable:
            return FitBarTheme.semantic(.red)
        case .missing, .unchecked:
            return FitBarTheme.semantic(.orange)
        }
    }

    private var modelCatalogStatusText: String {
        if let error = store.groqModelsError {
            return store.tr(
                "Не удалось обновить список моделей: \(error). Используется последний кэш или fallback.",
                "Could not refresh models: \(error). Using the last cache or fallback."
            )
        }
        if let date = store.groqModelsUpdatedAt {
            return store.tr("Список моделей обновлён: \(formatDate(date)).",
                            "Model list updated: \(formatDate(date)).")
        }
        return store.tr(
            "Список моделей обновится автоматически после подключения ключа и затем не чаще раза в сутки.",
            "The model list refreshes automatically after key connection and then at most once per day."
        )
    }

    private func modelMetaText(_ model: GroqModelInfo) -> String {
        let power = model.parameterSummary == model.id
            ? store.tr("мощность определена эвристически", "power estimated heuristically")
            : store.tr("размер \(model.parameterSummary)", "size \(model.parameterSummary)")
        return "\(power) · \(model.ownedBy)"
    }

    private func modelUsageText(_ usage: GroqModelUsage?) -> String {
        guard let usage, usage.requestCount > 0 else {
            return store.tr("Расход FitBar: пока нет запросов.",
                            "FitBar usage: no requests yet.")
        }
        let last = usage.lastUsedAt.map(formatDate) ?? store.tr("нет даты", "no date")
        return store.tr(
            "Расход FitBar: \(usage.requestCount) запрос(ов), \(usage.totalTokens) токенов, последний раз \(last).",
            "FitBar usage: \(usage.requestCount) request(s), \(usage.totalTokens) tokens, last used \(last)."
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.appLanguage == "ru" ? "ru_RU" : "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Account

struct AccountView: View {
    @EnvironmentObject var store: AppStore
    @Binding private var hasUnsavedChanges: Bool
    @State private var draftProfile = UserProfile()
    @State private var savedProfile = UserProfile()
    @State private var didLoadDraft = false
    @State private var showSavedToast = false
    @State private var showingAvatarImporter = false
    @State private var avatarError: String?
    @State private var avatarRefreshID = UUID()

    init(hasUnsavedChanges: Binding<Bool> = .constant(false)) {
        _hasUnsavedChanges = hasUnsavedChanges
    }

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            HStack {
                Text(store.tr("Аккаунт", "Account"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            FitBarDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    profileHeader
                    parametersCard
                    saveBar
                }
                .id(store.appTheme)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(FitBarTheme.appBackground)
        .fileImporter(
            isPresented: $showingAvatarImporter,
            allowedContentTypes: [.image],
            onCompletion: importAvatar
        )
        .onAppear {
            syncDraftFromStore(force: true)
        }
        .onDisappear {
            if !hasUnsavedChanges {
                syncDraftFromStore(force: true)
            }
        }
        .onChange(of: draftProfile) { _, _ in updateDirtyFlag() }
        .onChange(of: store.profile) { _, _ in
            if !hasUnsavedChanges { syncDraftFromStore(force: true) }
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                avatarPicker
                VStack(alignment: .leading, spacing: 6) {
                    Text(draftProfile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? store.tr("Без имени", "No nickname")
                         : draftProfile.nickname)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text(summaryLine)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .lineLimit(1)
                }
                Spacer()
            }
            if let avatarError {
                Text(avatarError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitBarTheme.semantic(.red))
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(minHeight: 138)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 15, raised: true)
    }

    private var avatarPicker: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button {
            avatarError = nil
            showingAvatarImporter = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = customAvatarImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .id(avatarRefreshID)
                    } else {
                        FitBarArtworkImage(artwork: accountArtwork)
                            .scaledToFill()
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(shape)
                .overlay(shape.strokeBorder(FitBarTheme.stroke, lineWidth: 1))

                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FitBarTheme.isMonochrome ? FitBarTheme.text : .white)
                    .frame(width: 30, height: 30)
                    .background(
                        FitBarTheme.isMonochrome
                            ? FitBarTheme.panel
                            : FitBarTheme.accent,
                        in: Circle()
                    )
                    .overlay(Circle().strokeBorder(FitBarTheme.stroke, lineWidth: 1))
                    .offset(x: 5, y: 5)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(store.tr("Изменить аватар", "Change avatar"))
        .contextMenu {
            Button(store.tr("Выбрать фото", "Choose photo")) {
                avatarError = nil
                showingAvatarImporter = true
            }
            if draftProfile.avatarImagePath != nil {
                Button(store.tr("Удалить аватар", "Remove avatar")) {
                    removeAvatar()
                }
            }
        }
    }

    private var parametersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.tr("Личные данные", "Personal data"))
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 24) {
                    nicknameField
                        .frame(maxWidth: .infinity, alignment: .leading)
                    numberField(store.tr("Рост", "Height"),
                                value: Binding(
                                    get: { draftProfile.heightCM },
                                    set: { draftProfile.heightCM = $0 }
                                ),
                                unit: store.tr("см", "cm"),
                                range: 120...230)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    numberField(store.tr("Вес", "Weight"),
                                value: Binding(
                                    get: { draftProfile.weightKG },
                                    set: { draftProfile.weightKG = $0 }
                                ),
                                unit: store.tr("кг", "kg"),
                                range: 35...300)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: 24) {
                    segmentedField(store.tr("Пол", "Gender")) {
                        HStack(spacing: 8) {
                            ForEach(selectableGenders) { gender in
                                segmentedChoice(
                                    title: gender.title(lang: store.appLanguage),
                                    isSelected: effectiveGender == gender
                                ) {
                                    draftProfile.gender = gender
                                }
                            }
                        }
                        .frame(maxWidth: 420, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitBarCard(radius: 15)
    }

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(store.tr("Ник", "Nickname"))
                .font(.system(size: 11))
                .foregroundStyle(FitBarTheme.textMuted)
            TextField(store.tr("Введите ник", "Enter nickname"),
                      text: $draftProfile.nickname)
                .textFieldStyle(.roundedBorder)
                .frame(width: 190)
        }
    }

    private var saveBar: some View {
        HStack(spacing: 10) {
            if hasUnsavedChanges {
                Button {
                    saveChanges()
                } label: {
                    Label(store.tr("Сохранить изменения", "Save changes"),
                          systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(minWidth: 170)
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if showSavedToast {
                Label(store.tr("Изменения сохранены", "Changes saved"),
                      systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitBarTheme.semantic(.green))
                    .transition(.opacity)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: hasUnsavedChanges)
    }

    private func segmentedField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(FitBarTheme.textMuted)
            content()
        }
    }

    private func segmentedChoice(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 26)
        }
        .controlSize(.small)
        .buttonStyle(FitBarActionButtonStyle(variant: isSelected ? .prominent : .bordered))
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
                    .frame(width: 68)
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

    private var customAvatarImage: NSImage? {
        guard let path = draftProfile.avatarImagePath,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return NSImage(contentsOf: URL(fileURLWithPath: path))
    }

    private func importAvatar(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try store.setProfileAvatar(from: url)
                let saved = store.profile
                draftProfile.avatarImagePath = saved.avatarImagePath
                savedProfile = saved
                avatarRefreshID = UUID()
                avatarError = nil
                updateDirtyFlag()
            } catch {
                avatarError = error.localizedDescription
            }
        case .failure(let error):
            avatarError = error.localizedDescription
        }
    }

    private func removeAvatar() {
        store.clearProfileAvatar()
        let saved = store.profile
        draftProfile.avatarImagePath = nil
        savedProfile = saved
        avatarRefreshID = UUID()
        avatarError = nil
        updateDirtyFlag()
    }

    private func syncDraftFromStore(force: Bool = false) {
        guard force || !didLoadDraft else { return }
        draftProfile = store.profile
        savedProfile = store.profile
        hasUnsavedChanges = false
        didLoadDraft = true
    }

    private func updateDirtyFlag() {
        hasUnsavedChanges = draftProfile != savedProfile
        if hasUnsavedChanges {
            withAnimation(.snappy) { showSavedToast = false }
        }
    }

    private func saveChanges() {
        store.applyProfile(draftProfile)
        savedProfile = store.profile
        draftProfile = store.profile
        hasUnsavedChanges = false
        withAnimation(.snappy) { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.snappy) { showSavedToast = false }
        }
    }

    private var selectableGenders: [UserGender] {
        [.male, .female]
    }

    private var effectiveGender: UserGender {
        draftProfile.gender == .female ? .female : .male
    }

    private var accountArtwork: FitBarIconArtwork {
        effectiveGender == .female ? .female : .male
    }

    private var summaryLine: String {
        let height = String(format: "%.0f", draftProfile.heightCM)
        let weight = String(format: "%.1f", draftProfile.weightKG)
        return "\(height) \(store.tr("см", "cm")) · \(weight) \(store.tr("кг", "kg")) · "
            + effectiveGender.title(lang: store.appLanguage)
    }
}

// MARK: - Activity page

struct ActivityView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    private let gridSpacing: CGFloat = 12
    @State private var exportDocument = FitBarActivityDocument(data: Data())
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingClearAlert = false
    @State private var fileMessage: String?

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            HStack {
                Text(store.tr("Активность", "Activity"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    openWindow(id: "stats")
                } label: {
                    Label(store.tr("Все показатели", "All stats"),
                          systemImage: "tablecells")
                }
                .buttonStyle(FitBarActionButtonStyle())
                Button {
                    do {
                        exportDocument = FitBarActivityDocument(
                            data: try store.exportBackupData())
                        showingExporter = true
                    } catch {
                        fileMessage = error.localizedDescription
                    }
                } label: {
                    Label(store.tr("Сохранить", "Export"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(FitBarActionButtonStyle())
                Button {
                    showingImporter = true
                } label: {
                    Label(store.tr("Восстановить", "Restore"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(FitBarActionButtonStyle())
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Label(store.tr("Стереть", "Clear"), systemImage: "trash")
                }
                .buttonStyle(FitBarActionButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            FitBarDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    activitySummaryColumns

                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.tr("Активность по дням", "Daily activity"))
                            .font(.headline)
                        HeatmapView(activity: store.activity, weeks: 52, cell: 10.5,
                                    spacing: 2.5, fillWidth: true,
                                    lang: store.appLanguage)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fitBarCard(radius: 16)

                    if let fileMessage {
                        Label(fileMessage, systemImage: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(FitBarTheme.textMuted)
                            .textSelection(.enabled)
                    }
                }
                .padding(16)
            }
        }
        .background(FitBarTheme.appBackground)
        .id(store.appTheme)
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "FitBar-activity-backup"
        ) { result in
            switch result {
            case .success:
                fileMessage = store.tr("Данные сохранены в документ.",
                                       "Data exported to a document.")
            case .failure(let error):
                fileMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                try store.restoreBackup(from: Data(contentsOf: url))
                fileMessage = store.tr("Данные восстановлены из документа.",
                                       "Data restored from the document.")
            } catch {
                fileMessage = error.localizedDescription
            }
        }
        .alert(store.tr("Стереть все данные?", "Clear all data?"),
               isPresented: $showingClearAlert) {
            Button(store.tr("Отмена", "Cancel"), role: .cancel) {}
            Button(store.tr("Стереть", "Clear"), role: .destructive) {
                store.clearAllUserData()
                fileMessage = store.tr("Данные приложения очищены.",
                                       "Application data cleared.")
            }
        } message: {
            Text(store.tr(
                "Будут удалены список упражнений, активность, подходы, повторы, время, сохранённый план и Groq API-ключ.",
                "This removes the exercise list, activity, sets, reps, time, saved plan and Groq API key."
            ))
        }
    }

    private var activitySummaryColumns: some View {
        VStack(spacing: gridSpacing) {
            HStack(alignment: .center, spacing: gridSpacing) {
                dashboardNumberCard(
                    icon: "flame.fill",
                    tint: .orange,
                    title: store.tr("Подходов сегодня", "Sets today"),
                    value: "\(store.todayCount)",
                    size: .hero
                )
                .frame(maxWidth: .infinity)

                VStack(spacing: gridSpacing) {
                    dashboardNumberCard(
                        icon: "sum",
                        tint: .blue,
                        title: store.tr("Всего подходов", "Total sets"),
                        value: "\(store.activity.totalCompletions)",
                        size: .compact
                    )
                    dashboardNumberCard(
                        icon: "clock.fill",
                        tint: .green,
                        title: store.tr("Общее время", "Total time"),
                        value: Self.duration(store.totalWorkoutTimeSeconds),
                        size: .compact
                    )
                }
                .frame(width: 280)
            }

            dashboardDetailCard(
                icon: "star.fill",
                tint: .green,
                title: store.tr("Самое частое упражнение", "Most frequent"),
                primary: store.recordExercise.map {
                    store.displayName($0.exercise)
                } ?? store.tr("Пока нет данных", "No data yet"),
                secondary: store.recordExercise.map {
                    store.tr("\($0.count) подходов", "\($0.count) sets")
                } ?? "—",
                prominent: true
            )

            HStack(alignment: .center, spacing: gridSpacing) {
                dashboardDetailCard(
                    icon: "arrow.up.circle.fill",
                    tint: .orange,
                    title: store.tr("Максимум за подход", "Best set"),
                    primary: store.maxRepsSet.map {
                        store.displayName($0.exercise)
                    } ?? store.tr("Пока нет данных", "No data yet"),
                    secondary: store.maxRepsSet.map {
                        store.tr("\($0.set.reps) повторов", "\($0.set.reps) reps")
                    } ?? "—"
                )
                .frame(maxWidth: .infinity)

                dashboardDetailCard(
                    icon: "repeat",
                    tint: .blue,
                    title: store.tr("Всего повторов", "Total reps"),
                    primary: "\(store.totalReps)",
                    secondary: store.tr("за всё время", "all time"),
                    compactText: true
                )
                .frame(width: 280)

                dashboardNumberCard(
                    icon: "bolt.fill",
                    tint: .yellow,
                    title: store.tr("Серия плана", "Plan streak"),
                    value: "\(store.trainingStreak)",
                    size: .compact
                )
                .frame(width: 210)
            }
        }
    }

    @ViewBuilder
    private func dashboardPairRow<Left: View, Right: View>(
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) -> some View {
        HStack(spacing: gridSpacing) {
            left()
                .frame(maxWidth: .infinity)
            right()
                .frame(maxWidth: .infinity)
        }
    }

    private enum DashboardNumberSize: Equatable {
        case hero
        case compact
        case medium
        case final

        var valueSize: CGFloat {
            switch self {
            case .hero: return 56
            case .compact: return 28
            case .medium: return 34
            case .final: return 36
            }
        }

        var minHeight: CGFloat {
            switch self {
            case .hero: return 132
            case .compact: return 60
            case .medium: return 92
            case .final: return 92
            }
        }

        var verticalSpacing: CGFloat {
            switch self {
            case .hero: return 8
            case .compact: return 3
            case .medium, .final: return 8
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .hero: return 22
            case .compact: return 14
            case .medium, .final: return 18
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .hero: return 18
            case .compact: return 10
            case .medium, .final: return 16
            }
        }
    }

    private func dashboardNumberCard(
        icon: String,
        tint: Color,
        title: String,
        value: String,
        size: DashboardNumberSize
    ) -> some View {
        VStack(alignment: .leading, spacing: size.verticalSpacing) {
            metricTitle(icon: icon, tint: tint, title: title)
            Text(value)
                .font(.system(size: size.valueSize, weight: .bold, design: .rounded))
                .foregroundStyle(FitBarTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .monospacedDigit()
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(maxWidth: .infinity, minHeight: size.minHeight, alignment: .leading)
        .activityDashboardCard()
    }

    private func dashboardDetailCard(
        icon: String,
        tint: Color,
        title: String,
        primary: String,
        secondary: String,
        prominent: Bool = false,
        compactText: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: prominent ? 14 : 12) {
            Image(systemName: icon)
                .font(.system(size: prominent ? 22 : 18, weight: .semibold))
                .foregroundStyle(FitBarTheme.semantic(tint).opacity(0.82))
                .frame(width: prominent ? 28 : 24)
            VStack(alignment: .leading, spacing: prominent ? 4 : 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(primary)
                    .font(.system(size: prominent ? 18 : (compactText ? 17 : 15),
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundStyle(FitBarTheme.text)
                    .lineLimit(prominent ? 2 : 1)
                    .minimumScaleFactor(0.62)
                Text(secondary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FitBarTheme.textFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, prominent ? 20 : 16)
        .padding(.vertical, prominent ? 14 : 12)
        .frame(maxWidth: .infinity,
               minHeight: prominent ? 84 : 72,
               alignment: .leading)
        .activityDashboardCard()
    }

    private func metricTitle(icon: String, tint: Color, title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FitBarTheme.semantic(tint).opacity(0.78))
                .frame(width: 13)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FitBarTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

private extension View {
    func activityDashboardCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(FitBarTheme.panel)
                .shadow(
                    color: FitBarTheme.shadow.opacity(FitBarTheme.isMonochrome ? 0.75 : 0.24),
                    radius: FitBarTheme.isMonochrome ? 2 : 8,
                    y: FitBarTheme.isMonochrome ? 1 : 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
    }
}

struct FitBarActivityDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum AllStatsSort: String, CaseIterable, Identifiable {
    case reps
    case sets
    case best
    case time
    case name

    var id: String { rawValue }

    @MainActor
    func title(_ store: AppStore) -> String {
        switch self {
        case .reps: return store.tr("Повторы", "Reps")
        case .sets: return store.tr("Подходы", "Sets")
        case .best: return store.tr("Макс.", "Best")
        case .time: return store.tr("Время", "Time")
        case .name: return store.tr("Название", "Name")
        }
    }

    var icon: String {
        switch self {
        case .reps: return "repeat"
        case .sets: return "number"
        case .best: return "arrow.up.circle.fill"
        case .time: return "clock.fill"
        case .name: return "textformat"
        }
    }
}

struct AllExerciseStatsWindow: View {
    @EnvironmentObject var store: AppStore
    @State private var sort: AllStatsSort = .reps
    @State private var descending = true

    var body: some View {
        let _ = store.appTheme
        VStack(spacing: 0) {
            HStack {
                Text(store.tr("Показатели всех упражнений", "All Exercise Stats"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                sortControls
            }
            .padding(16)
            FitBarDivider()

            if sortedStats.isEmpty {
                EmptyStateView(
                    icon: "tablecells",
                    title: store.tr("Пока нет подходов", "No sets yet"),
                    subtitle: store.tr(
                        "Начните подход из menu bar, остановите секундомер и сохраните повторы.",
                        "Start a set from the menu bar, stop the stopwatch and save reps."
                    )
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedStats, id: \.stats.exerciseID) { item in
                            statRow(item)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(FitBarTheme.appBackground)
        .id(store.appTheme)
    }

    private var sortControls: some View {
        HStack(spacing: 8) {
            Text(store.tr("Сортировка", "Sort"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FitBarTheme.textMuted)
            Menu {
                ForEach(AllStatsSort.allCases) { option in
                    Button {
                        sort = option
                    } label: {
                        if sort == option {
                            Label(option.title(store), systemImage: "checkmark")
                        } else {
                            Label(option.title(store), systemImage: option.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: sort.icon)
                    Text(sort.title(store))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(FitBarTheme.faintFill(0.055), in: Capsule())
                .overlay(Capsule().strokeBorder(FitBarTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(FitBarPlainButtonStyle())

            Button {
                descending.toggle()
            } label: {
                Image(systemName: descending ? "arrow.down" : "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(FitBarTheme.faintFill(0.055), in: Circle())
                    .overlay(Circle().strokeBorder(FitBarTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(FitBarPlainButtonStyle())
            .help(descending
                  ? store.tr("По убыванию", "Descending")
                  : store.tr("По возрастанию", "Ascending"))
        }
    }

    private var sortedStats: [(exercise: Exercise, stats: ExerciseActivityStats)] {
        store.allWorkoutStats.sorted { lhs, rhs in
            let result: ComparisonResult
            switch sort {
            case .reps:
                result = compare(lhs.stats.totalReps, rhs.stats.totalReps)
            case .sets:
                result = compare(lhs.stats.setCount, rhs.stats.setCount)
            case .best:
                result = compare(lhs.stats.maxReps, rhs.stats.maxReps)
            case .time:
                result = compare(lhs.stats.totalDurationSeconds,
                                 rhs.stats.totalDurationSeconds)
            case .name:
                result = store.displayName(lhs.exercise)
                    .localizedStandardCompare(store.displayName(rhs.exercise))
            }
            if result == .orderedSame {
                return store.displayName(lhs.exercise)
                    .localizedStandardCompare(store.displayName(rhs.exercise)) == .orderedAscending
            }
            return descending ? result == .orderedDescending : result == .orderedAscending
        }
    }

    private func compare(_ lhs: Int, _ rhs: Int) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func statRow(
        _ item: (exercise: Exercise, stats: ExerciseActivityStats)
    ) -> some View {
        HStack(spacing: 12) {
            IconBubble(
                category: item.exercise.category,
                symbol: ExerciseVisualStyle.icon(item.exercise),
                showsCategoryBadge: false,
                size: 38
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(store.displayName(item.exercise))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(store.displayName(item.exercise))
                Text("\(store.targetLabel(item.exercise.target)) · \(store.equipmentLabel(item.exercise.equipment))")
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            tableMetric(store.tr("Повторы", "Reps"),
                        "\(item.stats.totalReps)", .blue)
            tableMetric(store.tr("Подходы", "Sets"),
                        "\(item.stats.setCount)", .green)
            tableMetric(store.tr("Макс.", "Best"),
                        "\(item.stats.maxReps)", .orange)
            tableMetric(store.tr("Время", "Time"),
                        ActivityView.duration(item.stats.totalDurationSeconds),
                        .purple,
                        width: 86)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FitBarTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FitBarTheme.stroke, lineWidth: 1)
        )
    }

    private func tableMetric(
        _ title: String, _ value: String, _ tint: Color, width: CGFloat = 74
    ) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(FitBarTheme.textFaint)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FitBarTheme.semantic(tint))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: width, alignment: .center)
    }
}
