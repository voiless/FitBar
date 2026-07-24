import SwiftUI

/// Full exercise details shown in a sheet.
struct ExerciseDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    var onClose: (() -> Void)? = nil
    @State private var showingBlockPicker = false

    var body: some View {
        let _ = store.appTheme
        VStack(alignment: .leading, spacing: 0) {
            header
            FitBarDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    muscles
                    steps
                }
                .padding(20)
            }
            FitBarDivider()
            footer
        }
        .frame(width: 620, height: FitBarTheme.isMonochrome ? 560 : 640)
        .background(FitBarTheme.appBackground)
        .id(store.appTheme)
    }

    private var header: some View {
        HStack(spacing: 14) {
            IconBubble(
                category: exercise.category,
                symbol: ExerciseVisualStyle.icon(exercise),
                showsCategoryBadge: false,
                size: 56
            )
            VStack(alignment: .leading, spacing: 6) {
                Text(store.displayName(exercise))
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                if store.appLanguage == "ru" {
                    Text(exercise.name.capitalized)
                        .font(.system(size: 12))
                        .foregroundStyle(FitBarTheme.textFaint)
                }
                HStack(spacing: 6) {
                    Chip(text: store.categoryLabel(exercise.category),
                         icon: BodyPartStyle.icon(exercise.category),
                         tint: .bodyPart(exercise.category))
                    Chip(text: store.targetLabel(exercise.target), icon: "target",
                         tint: .orange)
                    Chip(text: store.equipmentLabel(exercise.equipment),
                         icon: "dumbbell.fill", tint: .blue)
                }
            }
            Spacer()
            Button {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(FitBarTheme.textFaint)
            }
            .buttonStyle(FitBarPlainButtonStyle())
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    private var muscles: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(store.tr("Мышцы", "Muscles"))
                .font(.headline)
            FlowLayout(spacing: 7) {
                Chip(text: store.targetLabel(exercise.target))
                ForEach(Array(Set(exercise.secondaryMuscles)).sorted(),
                        id: \.self) { muscle in
                    Chip(text: store.muscleLabel(muscle))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.tr("Как выполнять", "How to perform"))
                    .font(.headline)
                Spacer()
            }
            ForEach(Array(exercise.steps(lang: store.appLanguage).enumerated()),
                    id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(width: 24, height: 24)
                        .background(FitBarTheme.isMonochrome ? Color.white : Color.bodyPart(exercise.category).opacity(0.18),
                                    in: Circle())
                        .overlay(Circle().strokeBorder(FitBarTheme.isMonochrome ? Color.black : Color.clear,
                                                       lineWidth: FitBarTheme.isMonochrome ? 1 : 0))
                        .foregroundStyle(FitBarTheme.semantic(.bodyPart(exercise.category)))
                    Text(step)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(FitBarTheme.faintFill(0.035),
                            in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("ID \(exercise.id)")
                .font(.caption)
                .foregroundStyle(FitBarTheme.textFaint)
            Spacer()
            Button {
                showingBlockPicker = true
            } label: {
                Label(
                    store.isInWorkout(exercise)
                        ? store.tr("В моём списке", "In my list")
                        : store.tr("Добавить в список", "Add to list"),
                    systemImage: store.isInWorkout(exercise)
                        ? "checkmark.circle.fill" : "plus.circle.fill"
                )
                .frame(minWidth: 160)
            }
            .controlSize(.large)
            .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
        }
        .padding(16)
        .sheet(isPresented: $showingBlockPicker) {
            ExerciseBlockSelectionSheet(exercise: exercise)
                .environmentObject(store)
        }
    }
}

struct DismissibleDetailOverlay: View {
    @EnvironmentObject var store: AppStore
    @Binding var exercise: Exercise?

    var body: some View {
        let _ = store.appTheme
        if let exercise {
            ZStack {
                FitBarTheme.blackOpacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy) { self.exercise = nil }
                    }
                ExerciseDetailView(exercise: exercise) {
                    withAnimation(.snappy) { self.exercise = nil }
                }
                .environmentObject(store)
                .background(FitBarTheme.appBackground,
                            in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(FitBarTheme.faintFill(0.14), lineWidth: 1)
                )
                .shadow(color: FitBarTheme.isMonochrome ? FitBarTheme.blackOpacity(0.05) : FitBarTheme.blackOpacity(0.35),
                        radius: FitBarTheme.isMonochrome ? 3 : 24,
                        y: FitBarTheme.isMonochrome ? 1 : 12)
                .onTapGesture {}
            }
            .transition(.opacity)
            .zIndex(50)
        }
    }
}
