import SwiftUI
import AppKit

enum FitBarTheme {
    static var currentMode: AppColorTheme = .dark
    static var isMonochrome: Bool { currentMode == .monochrome }

    static var appBackground: Color {
        isMonochrome ? .white : Color(red: 0.095, green: 0.095, blue: 0.095)
    }

    static var panel: Color {
        isMonochrome ? .white : Color(red: 0.125, green: 0.125, blue: 0.125)
    }

    static var panelRaised: Color {
        isMonochrome ? .white : Color(red: 0.145, green: 0.145, blue: 0.145)
    }

    static var panelStrong: Color {
        isMonochrome ? .white : Color(red: 0.165, green: 0.165, blue: 0.165)
    }

    static var stroke: Color {
        isMonochrome ? .black : FitBarTheme.semanticFill(.white, opacity: 0.09)
    }

    static var strokeStrong: Color {
        isMonochrome ? .black : FitBarTheme.semanticFill(.white, opacity: 0.16)
    }

    static var text: Color {
        isMonochrome ? .black : .primary
    }

    static var textMuted: Color {
        isMonochrome ? .black : .secondary
    }

    static var textFaint: Color {
        isMonochrome ? .black : FitBarTheme.semanticFill(.white, opacity: 0.40)
    }

    static var shadow: Color {
        isMonochrome ? Color.black.opacity(0.06) : FitBarTheme.blackOpacity(0.34)
    }

    static var accent: Color {
        isMonochrome ? .black : .green
    }

    static var selectedFill: Color {
        isMonochrome ? .black : .accentColor
    }

    static var selectedText: Color {
        .white
    }

    static func semantic(_ color: Color) -> Color {
        isMonochrome ? .black : color
    }

    static func semanticFill(_ color: Color, opacity: Double) -> Color {
        isMonochrome ? .white : color.opacity(opacity)
    }

    static func faintFill(_ opacity: Double) -> Color {
        isMonochrome ? .white : Color.primary.opacity(opacity)
    }

    static func controlFill(active: Bool = false, disabled: Bool = false) -> Color {
        if isMonochrome {
            return active ? .black : .white
        }
        if disabled {
            return Color.primary.opacity(0.06)
        }
        return active ? selectedFill : Color.primary.opacity(0.07)
    }

    static func controlText(active: Bool = false, disabled: Bool = false) -> Color {
        if isMonochrome {
            return active ? .white : .black
        }
        if disabled {
            return textFaint
        }
        return active ? selectedText : textMuted
    }

    static func controlStroke(active: Bool = false, disabled: Bool = false) -> Color {
        if isMonochrome {
            return .black
        }
        return active ? selectedFill.opacity(0.55) : stroke
    }

    static func blackOpacity(_ opacity: Double) -> Color {
        Color.black.opacity(opacity)
    }
}

enum FitBarFormat {
    static func waterLiters(_ milliliters: Int, lang: String) -> String {
        String(format: "%.2f %@", Double(max(0, milliliters)) / 1000.0,
               lang == "ru" ? "л" : "L")
    }
}

struct FitBarCheckboxToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(configuration.isOn
                              ? (FitBarTheme.isMonochrome ? Color.black : Color.accentColor)
                              : FitBarTheme.controlFill())
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.controlStroke(),
                                      lineWidth: 1)
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 19, height: 19)
                configuration.label
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .disabled(!isEnabled)
    }
}

struct FitBarHiddenTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable = true

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
        textView.isEditable = isEditable
        textView.textColor = FitBarTheme.isMonochrome ? .black : .labelColor
        textView.insertionPointColor = FitBarTheme.isMonochrome ? .black : .white
        scrollView.hasVerticalScroller = false
        scrollView.verticalScroller?.isHidden = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

enum FitBarIconArtwork: String {
    case app = "fitbar-icon-app"
    case male = "fitbar-icon-male"
    case female = "fitbar-icon-female"

    var image: NSImage? {
        guard let url = Bundle.module.url(forResource: rawValue, withExtension: "png")
        else { return nil }
        return NSImage(contentsOf: url)
    }
}

private struct FitBarIconArtworkKey: EnvironmentKey {
    static let defaultValue: FitBarIconArtwork = .male
}

extension EnvironmentValues {
    var fitBarIconArtwork: FitBarIconArtwork {
        get { self[FitBarIconArtworkKey.self] }
        set { self[FitBarIconArtworkKey.self] = newValue }
    }
}

struct FitBarArtworkImage: View {
    let artwork: FitBarIconArtwork
    var padding: CGFloat = 0

    var body: some View {
        Group {
            if let image = artwork.image {
                ZStack {
                    Color.white
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .padding(padding)
                }
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .scaledToFit()
                    .padding(padding + 4)
                    .foregroundStyle(FitBarTheme.isMonochrome ? .black : .white)
            }
        }
    }
}

struct FitBarCardModifier: ViewModifier {
    var radius: CGFloat = 14
    var raised = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(raised ? FitBarTheme.panelStrong : FitBarTheme.panel)
                    .shadow(color: FitBarTheme.shadow.opacity(FitBarTheme.isMonochrome ? 1 : (raised ? 0.7 : 0.35)),
                            radius: FitBarTheme.isMonochrome ? (raised ? 3 : 1.5) : (raised ? 10 : 5),
                            y: FitBarTheme.isMonochrome ? 1 : (raised ? 4 : 2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(raised ? FitBarTheme.strokeStrong : FitBarTheme.stroke,
                                  lineWidth: 1)
            )
    }
}

struct FitBarCharacterMark: View {
    var foreground: Color = .white
    var accent: Color = .mint
    var showsGround = false

    var body: some View {
        FitBarArtworkImage(artwork: .app)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .aspectRatio(1, contentMode: .fit)
    }

}

private struct FitBarHairShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x,
                    y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: p(0.03, 0.82))
        path.addLine(to: p(0.18, 0.20))
        path.addLine(to: p(0.30, 0.74))
        path.addLine(to: p(0.47, 0.06))
        path.addLine(to: p(0.56, 0.73))
        path.addLine(to: p(0.75, 0.18))
        path.addLine(to: p(0.73, 0.82))
        path.addLine(to: p(0.96, 0.48))
        path.addLine(to: p(0.83, 0.98))
        path.addLine(to: p(0.18, 0.98))
        path.closeSubpath()
        return path
    }
}

extension View {
    func fitBarCard(radius: CGFloat = 14, raised: Bool = false) -> some View {
        modifier(FitBarCardModifier(radius: radius, raised: raised))
    }

    func fitBarOverlayScrollbars() -> some View {
        background(FitBarScrollViewConfigurator())
    }

    func fitBarHiddenScrollbars() -> some View {
        background(FitBarHiddenScrollViewConfigurator())
    }
}

private struct FitBarScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> FitBarScrollViewConfiguratorView {
        FitBarScrollViewConfiguratorView()
    }

    func updateNSView(_ nsView: FitBarScrollViewConfiguratorView, context: Context) {
        nsView.configureSoon()
    }
}

private final class FitBarScrollViewConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureSoon()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureSoon()
    }

    func configureSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.configureScrollView()
        }
    }

    private func configureScrollView() {
        var parent = superview
        while let view = parent {
            if let scrollView = view as? NSScrollView {
                scrollView.scrollerStyle = .overlay
                scrollView.autohidesScrollers = true
                scrollView.hasHorizontalScroller = false
                scrollView.drawsBackground = false
                scrollView.borderType = .noBorder
                scrollView.verticalScroller?.controlSize = .small
                scrollView.verticalScroller?.scrollerStyle = .overlay
                scrollView.verticalScroller?.isHidden = false
                scrollView.scrollerKnobStyle = FitBarTheme.isMonochrome ? .default : .light
                return
            }
            parent = view.superview
        }
    }
}

private struct FitBarHiddenScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> FitBarHiddenScrollViewConfiguratorView {
        FitBarHiddenScrollViewConfiguratorView()
    }

    func updateNSView(_ nsView: FitBarHiddenScrollViewConfiguratorView, context: Context) {
        nsView.configureSoon()
    }
}

private final class FitBarHiddenScrollViewConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureSoon()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureSoon()
    }

    func configureSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.configureScrollView()
        }
    }

    private func configureScrollView() {
        var parent = superview
        while let view = parent {
            if let scrollView = view as? NSScrollView {
                scrollView.scrollerStyle = .overlay
                scrollView.autohidesScrollers = true
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.drawsBackground = false
                scrollView.borderType = .noBorder
                scrollView.verticalScroller?.isHidden = true
                scrollView.horizontalScroller?.isHidden = true
                return
            }
            parent = view.superview
        }
    }
}

struct FitBarActionButtonStyle: ButtonStyle {
    enum Variant {
        case bordered
        case prominent
    }

    var variant: Variant = .bordered
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let prominent = variant == .prominent
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(FitBarTheme.isMonochrome
                             ? (prominent && isEnabled ? Color.white : Color.black)
                             : (prominent && isEnabled ? Color.white : FitBarTheme.textMuted))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(FitBarTheme.isMonochrome
                          ? (prominent && isEnabled ? Color.black : Color.white)
                          : (prominent && isEnabled ? FitBarTheme.selectedFill : FitBarTheme.faintFill(0.07)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(FitBarTheme.isMonochrome ? Color.black : FitBarTheme.strokeStrong,
                                  lineWidth: FitBarTheme.isMonochrome ? 1.4 : 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : (FitBarTheme.isMonochrome ? 1 : 0.55))
    }
}

/// Keeps the entire rendered label clickable for custom buttons that should
/// otherwise retain SwiftUI's borderless appearance.
struct FitBarPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct FitBarDivider: View {
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(FitBarTheme.stroke)
            .frame(width: vertical ? 1 : nil,
                   height: vertical ? nil : 1)
    }
}

extension Color {
    static func bodyPart(_ category: String) -> Color {
        if FitBarTheme.isMonochrome { return .black }
        return Color(hue: BodyPartStyle.hue(category), saturation: 0.65, brightness: 0.85)
    }

    static func bodyPartSoft(_ category: String) -> Color {
        if FitBarTheme.isMonochrome { return .black }
        return Color(hue: BodyPartStyle.hue(category), saturation: 0.35, brightness: 0.95)
    }
}

/// Rounded-square icon with a per-body-part gradient.
struct IconBubble: View {
    let category: String
    var symbol: String? = nil
    var showsCategoryBadge = false
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(iconFill)
            Image(systemName: symbol ?? BodyPartStyle.icon(category))
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(iconForeground)
            if showsCategoryBadge {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(FitBarTheme.panel)
                            Image(systemName: BodyPartStyle.icon(category))
                                .font(.system(size: size * 0.2, weight: .bold))
                                .foregroundStyle(Color.bodyPart(category))
                        }
                        .overlay(Circle().strokeBorder(FitBarTheme.stroke, lineWidth: 1))
                        .frame(width: size * 0.34, height: size * 0.34)
                        .offset(x: size * 0.08, y: size * 0.08)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(FitBarTheme.isMonochrome ? Color.black : Color.clear,
                              lineWidth: FitBarTheme.isMonochrome ? 1.5 : 0)
        )
    }

    private var iconFill: AnyShapeStyle {
        if FitBarTheme.isMonochrome {
            return AnyShapeStyle(Color.white)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [.bodyPart(category), .bodyPart(category).opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var iconForeground: Color {
        FitBarTheme.isMonochrome ? .black : .white
    }
}

/// Small capsule tag.
struct Chip: View {
    let text: String
    var icon: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(chipBackground, in: Capsule())
        .overlay(Capsule().strokeBorder(chipStroke, lineWidth: 1))
        .foregroundStyle(chipForeground)
        .lineLimit(1)
    }

    private var chipBackground: Color {
        FitBarTheme.isMonochrome ? .white : tint.opacity(0.22)
    }

    private var chipStroke: Color {
        FitBarTheme.isMonochrome ? .black : tint.opacity(0.36)
    }

    private var chipForeground: Color {
        FitBarTheme.isMonochrome ? .black : tint
    }
}

struct SelectAllTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var selectAllOnAppear = false
    var onCommit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 15, weight: .semibold)
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        if selectAllOnAppear {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                field.selectText(nil)
            }
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.text = $text
        context.coordinator.onCommit = onCommit
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onCommit: (() -> Void)?

        init(text: Binding<String>, onCommit: (() -> Void)?) {
            self.text = text
            self.onCommit = onCommit
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text.wrappedValue = textView.string
                onCommit?()
                return true
            }
            return false
        }
    }
}

private struct OutsideSheetClickDismissObserver: NSViewRepresentable {
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.installMonitorIfNeeded()
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.view = view
        context.coordinator.onDismiss = onDismiss
        context.coordinator.installMonitorIfNeeded()
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        weak var view: NSView?
        var onDismiss: () -> Void
        private var monitor: Any?

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        deinit {
            removeMonitor()
        }

        func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self,
                      let sheetWindow = self.view?.window,
                      sheetWindow.isKeyWindow
                else {
                    return event
                }

                guard let eventWindow = event.window,
                      eventWindow !== sheetWindow
                else {
                    return event
                }

                DispatchQueue.main.async {
                    self.onDismiss()
                }
                return nil
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

extension View {
    func dismissOnOutsideSheetClick(_ onDismiss: @escaping () -> Void) -> some View {
        background(OutsideSheetClickDismissObserver(onDismiss: onDismiss)
            .frame(width: 0, height: 0))
    }
}

struct CreateWorkoutBlockSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let defaultTitle: String
    let onCreate: (String) -> Void
    @State private var title: String

    init(defaultTitle: String, onCreate: @escaping (String) -> Void) {
        self.defaultTitle = defaultTitle
        self.onCreate = onCreate
        _title = State(initialValue: defaultTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FitBarTheme.semantic(.blue))
                    .frame(width: 44, height: 44)
                    .background(FitBarTheme.semanticFill(.blue, opacity: 0.16), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.tr("Создание сборки", "Create Plan Block"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(store.tr(
                        "Оставьте стандартное название или введите своё.",
                        "Keep the default name or enter your own."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(FitBarTheme.textMuted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(store.tr("Название", "Name"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitBarTheme.textMuted)
                SelectAllTextField(
                    text: $title,
                    placeholder: defaultTitle,
                    selectAllOnAppear: true,
                    onCommit: create
                )
                .frame(height: 30)
            }
            .padding(14)
            .background(FitBarTheme.faintFill(0.045), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Button(store.tr("Отмена", "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    create()
                } label: {
                    Label(store.tr("Создать", "Create"), systemImage: "checkmark.circle.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 430)
        .background(FitBarTheme.appBackground)
        .dismissOnOutsideSheetClick {
            dismiss()
        }
        .onAppear {
            title = defaultTitle
        }
    }

    private func create() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate(cleanTitle.isEmpty ? defaultTitle : title)
        dismiss()
    }
}

struct RecommendedDoseEditButton: View {
    @EnvironmentObject var store: AppStore
    let rec: RecommendedExercisePlan
    @State private var showingEditor = false

    var body: some View {
        DoseEditButtonLabel(
            sets: current?.sets ?? rec.sets,
            reps: current?.reps ?? rec.reps,
            action: { showingEditor = true }
        )
        .sheet(isPresented: $showingEditor) {
            RecommendedDoseEditSheet(exerciseID: rec.exerciseID)
                .environmentObject(store)
        }
    }

    private var current: RecommendedExercisePlan? {
        store.plan?.plan.recommendedExercises.first { $0.exerciseID == rec.exerciseID }
    }
}

private struct DoseEditButtonLabel: View {
    @EnvironmentObject var store: AppStore
    let sets: Int
    let reps: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label(store.tr("Изменить подходы/повторы", "Edit sets/reps"),
                      systemImage: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(store.tr("\(sets) подх. · \(repsText) повт.",
                              "\(sets) sets · \(repsText) reps"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(FitBarTheme.semanticFill(.blue, opacity: 0.13), in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(FitBarTheme.semanticFill(.blue, opacity: 0.25))
            )
            .foregroundStyle(FitBarTheme.semantic(.blue))
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .help(store.tr("Изменить количество подходов и повторений",
                       "Edit number of sets and reps"))
    }

    private var repsText: String {
        reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0" : reps
    }
}

struct RecommendedDoseEditSheet: View {
    @EnvironmentObject var store: AppStore
    let exerciseID: String

    var body: some View {
        ExerciseDoseEditSheet(
            title: exercise.map(store.displayName) ?? exerciseID,
            subtitle: store.tr("Настройки рекомендации ИИ", "AI recommendation settings"),
            sets: Binding(
                get: { current?.sets ?? 0 },
                set: { store.updateRecommendedExerciseSetting(exerciseID: exerciseID, sets: $0) }
            ),
            reps: Binding(
                get: { current?.reps ?? "0" },
                set: { store.updateRecommendedExerciseSetting(exerciseID: exerciseID, reps: $0) }
            )
        )
    }

    private var exercise: Exercise? { store.byID[exerciseID] }
    private var current: RecommendedExercisePlan? {
        store.plan?.plan.recommendedExercises.first { $0.exerciseID == exerciseID }
    }
}

private struct ExerciseDoseEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    @Binding var sets: Int
    @Binding var reps: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FitBarTheme.semantic(.blue))
                    .frame(width: 42, height: 42)
                    .background(FitBarTheme.semanticFill(.blue, opacity: 0.14), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.tr("Подходы и повторы", "Sets and reps"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.tr("Количество подходов", "Number of sets"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                    Stepper(value: setsBinding, in: 0...12) {
                        Text(store.tr("\(sets) подх.", "\(sets) sets"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }
                .padding(14)
                .background(FitBarTheme.faintFill(0.045), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.tr("Повторений в подходе", "Reps per set"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                    TextField("0", text: repsBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(store.tr("Можно указать число или диапазон, например 12 или 10-12.",
                                  "You can enter a number or a range, for example 12 or 10-12."))
                        .font(.system(size: 10))
                        .foregroundStyle(FitBarTheme.textFaint)
                }
                .padding(14)
                .background(FitBarTheme.faintFill(0.045), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label(store.tr("Готово", "Done"), systemImage: "checkmark.circle.fill")
                        .frame(minWidth: 120)
                }
                .buttonStyle(FitBarActionButtonStyle(variant: .prominent))
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(FitBarTheme.appBackground)
        .dismissOnOutsideSheetClick {
            dismiss()
        }
    }

    private var setsBinding: Binding<Int> {
        Binding(
            get: { sets },
            set: { sets = min(max($0, 0), 12) }
        )
    }

    private var repsBinding: Binding<String> {
        Binding(
            get: { reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0" : reps },
            set: { value in
                let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                reps = cleaned.isEmpty ? "0" : String(cleaned.prefix(16))
            }
        )
    }
}

/// Card for one exercise in the grid.
struct ExerciseCard: View {
    @EnvironmentObject var store: AppStore
    let exercise: Exercise
    @State private var hovering = false
    @State private var showingBlockPicker = false

    var body: some View {
        cardContent
        .padding(12)
        .frame(maxWidth: .infinity,
               minHeight: 142,
               alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hovering ? FitBarTheme.panelRaised : FitBarTheme.panel)
                .shadow(
                    color: FitBarTheme.isMonochrome ? FitBarTheme.blackOpacity(0.05) : FitBarTheme.blackOpacity(hovering ? 0.28 : 0.16),
                    radius: FitBarTheme.isMonochrome ? (hovering ? 3 : 1.5) : (hovering ? 11 : 6),
                    y: FitBarTheme.isMonochrome ? 1 : (hovering ? 5 : 2)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    hovering ? (FitBarTheme.isMonochrome ? Color.black : Color.bodyPart(exercise.category).opacity(0.55))
                             : FitBarTheme.faintFill(0.06),
                    lineWidth: 1
                )
        )
        .animation(.snappy(duration: 0.18), value: hovering)
        .onHover { hovering = $0 }
        .sheet(isPresented: $showingBlockPicker) {
            ExerciseBlockSelectionSheet(exercise: exercise)
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        compactContent
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 11) {
                IconBubble(
                    category: exercise.category,
                    symbol: ExerciseVisualStyle.icon(exercise),
                    showsCategoryBadge: false,
                    size: 46
                )
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.displayName(exercise))
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(2)
                    Text(ExerciseVisualStyle.muscleLine(exercise, lang: store.appLanguage))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FitBarTheme.textMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                addButton
            }
            HStack(spacing: 5) {
                Chip(text: store.targetLabel(exercise.target))
                Chip(text: store.equipmentLabel(exercise.equipment), icon: "dumbbell.fill")
            }
            .frame(height: 28, alignment: .leading)
        }
    }

    private var addButton: some View {
        Button {
            showingBlockPicker = true
        } label: {
            Image(systemName: store.isInWorkout(exercise)
                  ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 21))
                .foregroundStyle(store.isInWorkout(exercise)
                                 ? FitBarTheme.semantic(.green) : FitBarTheme.textMuted)
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .help(store.isInWorkout(exercise)
              ? store.tr("Выбрать сборку", "Choose a plan block")
              : store.tr("Добавить в сборку", "Add to a plan block"))
    }
}

struct ExerciseBlockSelectionSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    @State private var showingCreateBlock = false

    var body: some View {
        VStack(spacing: 0) {
            header
            FitBarDivider()
            if store.workout.blocks.isEmpty {
                emptyBlocks
            } else {
                blockList
            }
            FitBarDivider()
            footer
        }
        .frame(width: 500, height: store.workout.blocks.isEmpty ? 340 : 450)
        .background(FitBarTheme.appBackground)
        .dismissOnOutsideSheetClick {
            dismiss()
        }
        .sheet(isPresented: $showingCreateBlock) {
            CreateWorkoutBlockSheet(defaultTitle: store.nextWorkoutBlockTitle()) { title in
                createBlockAndAdd(title: title)
            }
            .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconBubble(
                category: exercise.category,
                symbol: ExerciseVisualStyle.icon(exercise),
                showsCategoryBadge: false,
                size: 42
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(store.tr("Куда добавить?", "Where to add?"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(store.displayName(exercise))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .lineLimit(1)
            }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }

    private var emptyBlocks: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(FitBarTheme.textMuted)
            Text(store.tr("Сборок пока нет", "No plan blocks yet"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(store.tr(
                "Создайте первую сборку, и упражнение сразу попадёт в неё.",
                "Create the first plan block, and the exercise will be added to it."
            ))
            .font(.system(size: 12))
            .foregroundStyle(FitBarTheme.textMuted)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320)
            Button {
                showingCreateBlock = true
            } label: {
                Label(store.tr("Создать сборку и добавить", "Create block and add"),
                      systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(FitBarTheme.semantic(.blue), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(FitBarPlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var blockList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(store.workout.blocks) { block in
                    blockRow(block)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
        }
    }

    private func blockRow(_ block: WorkoutBlock) -> some View {
        let contains = block.exerciseIDs.contains(exercise.id)
        return Button {
            guard !contains else { return }
            withAnimation(.snappy) {
                store.addExercise(exercise, to: block.id)
            }
        } label: {
            ExerciseBlockSelectionRow(block: block, contains: contains)
                .environmentObject(store)
        }
        .buttonStyle(FitBarPlainButtonStyle())
        .disabled(contains)
    }

    private var footer: some View {
        HStack {
            Text(store.tr("Можно добавить одно упражнение в несколько сборок.",
                          "One exercise can be added to several plan blocks."))
                .font(.system(size: 11))
                .foregroundStyle(FitBarTheme.textFaint)
            Spacer()
            if !store.workout.blocks.isEmpty {
                Button {
                    showingCreateBlock = true
                } label: {
                    Label(store.tr("Новая сборка", "New block"),
                          systemImage: "square.stack.3d.up.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(FitBarTheme.semanticFill(.blue, opacity: 0.16), in: Capsule())
                        .foregroundStyle(FitBarTheme.semantic(.blue))
                }
                .buttonStyle(FitBarPlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    private func createBlockAndAdd(title: String) {
        let blockID = store.addWorkoutBlock(title: title)
        withAnimation(.snappy) {
            store.addExercise(exercise, to: blockID)
        }
    }
}

private struct ExerciseBlockSelectionRow: View {
    @EnvironmentObject var store: AppStore
    let block: WorkoutBlock
    let contains: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: contains ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(contains ? FitBarTheme.semantic(.green) : FitBarTheme.semantic(.blue))
            VStack(alignment: .leading, spacing: 3) {
                Text(block.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(countText)
                    .font(.system(size: 11))
                    .foregroundStyle(FitBarTheme.textMuted)
            }
            Spacer()
            Text(actionText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(contains ? FitBarTheme.textMuted : FitBarTheme.semantic(.blue))
        }
        .padding(10)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(rowStroke)
        )
        .contentShape(Rectangle())
    }

    private var countText: String {
        store.tr("\(block.exerciseIDs.count) упражнений",
                 "\(block.exerciseIDs.count) exercises")
    }

    private var actionText: String {
        contains ? store.tr("Уже здесь", "Already here")
                 : store.tr("Добавить", "Add")
    }

    private var rowBackground: Color {
        contains ? FitBarTheme.semanticFill(.green, opacity: 0.08) : FitBarTheme.faintFill(0.045)
    }

    private var rowStroke: Color {
        contains ? FitBarTheme.semanticFill(.green, opacity: 0.25) : FitBarTheme.faintFill(0.06)
    }
}

/// Centered empty-state placeholder.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(FitBarTheme.faintFill(0.07))
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(FitBarTheme.textMuted)
                }
                .frame(width: 72, height: 72)
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(FitBarTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 440)
                if let actionTitle, let action {
                    Button(action: action) {
                        Label(actionTitle, systemImage: actionIcon ?? "plus.circle.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(FitBarTheme.semanticFill(.green, opacity: 0.20), in: Capsule())
                            .overlay(Capsule().strokeBorder(FitBarTheme.semanticFill(.green, opacity: 0.45), lineWidth: 1))
                            .foregroundStyle(FitBarTheme.semantic(.green))
                    }
                    .buttonStyle(FitBarPlainButtonStyle())
                }
            }
            .padding(28)
            .frame(maxWidth: 560)
            .fitBarCard(radius: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
