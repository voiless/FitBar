import SwiftUI
import AppKit

public struct FitBarApp: App {
    @StateObject private var store = AppStore()
    private let windowFact = HealthFacts.randomFact()

    public init() {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    public var body: some Scene {
        Window(windowFact.text(lang: store.appLanguage), id: "main") {
            MainWindowView()
                .environmentObject(store)
                .environment(\.fitBarIconArtwork, personArtwork)
                .preferredColorScheme(preferredScheme)
                .tint(FitBarTheme.accent)
                .background(WindowTitleUpdater(title: windowFact.text(lang: store.appLanguage)))
                .background(ThemeAppearanceUpdater(theme: store.appTheme))
                .background(WindowSizeLimiter(minSize: mainWindowMinSize))
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        // Text fields register undo actions whose targets can outlive their
        // views; ⌘Z then crashes in NSUndoManager (see crash log
        // FitBar-2026-07-02-214744). Undo is not meaningful in this app, so
        // drop the Undo/Redo menu commands entirely.
        .commands { CommandGroup(replacing: .undoRedo) {} }

        Window(store.tr("FitBar — Статистика", "FitBar — Stats"), id: "stats") {
            AllExerciseStatsWindow()
                .environmentObject(store)
                .environment(\.fitBarIconArtwork, personArtwork)
                .preferredColorScheme(preferredScheme)
                .tint(FitBarTheme.accent)
                .background(WindowTitleUpdater(title: store.tr("FitBar — Статистика", "FitBar — Stats")))
                .background(ThemeAppearanceUpdater(theme: store.appTheme))
                .background(WindowSizeLimiter(minSize: CGSize(width: 760, height: 560)))
        }
        .defaultSize(width: 780, height: 620)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environment(\.fitBarIconArtwork, personArtwork)
                .preferredColorScheme(preferredScheme)
                .tint(FitBarTheme.accent)
                .background(ThemeAppearanceUpdater(theme: store.appTheme))
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var personArtwork: FitBarIconArtwork {
        store.profile.gender == .female ? .female : .male
    }

    private var preferredScheme: ColorScheme {
        store.appTheme == .monochrome ? .light : .dark
    }

    private var mainWindowMinSize: CGSize {
        let hasActiveFilters = store.selectedEquipment != nil
            || store.selectedTarget != nil
        return CGSize(width: hasActiveFilters ? 1500 : 1240, height: 700)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FitBarTheme.accent)
            if store.todayCount > 0 {
                Text("\(store.todayCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
    }
}

private struct ThemeAppearanceUpdater: NSViewRepresentable {
    let theme: AppColorTheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        apply()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        apply()
    }

    private func apply() {
        // The SwiftUI tree may be rebuilt immediately after appTheme changes.
        // Keep the shared palette synchronous; only the AppKit appearance needs
        // to hop to the next main-loop turn.
        FitBarTheme.currentMode = theme
        DispatchQueue.main.async {
            NSApp.appearance = NSAppearance(named: theme == .monochrome
                                            ? .aqua
                                            : .darkAqua)
        }
    }
}

private struct WindowSizeLimiter: NSViewRepresentable {
    let minSize: CGSize

    func makeNSView(context: Context) -> NSView {
        WindowSizeLimitView(minSize: minSize)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? WindowSizeLimitView else { return }
        view.minSize = minSize
    }
}

private final class WindowSizeLimitView: NSView {
    var minSize: CGSize {
        didSet { apply(previousMinSize: oldValue) }
    }

    init(minSize: CGSize) {
        self.minSize = minSize
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.minSize = CGSize(width: 1120, height: 700)
        super.init(coder: coder)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    func apply(previousMinSize: CGSize? = nil) {
        DispatchQueue.main.async {
            guard let window = self.window else { return }
            window.minSize = self.minSize
            window.contentMinSize = self.minSize

            var frame = window.frame
            let targetWidth: CGFloat
            if let previousMinSize,
               self.minSize.width < previousMinSize.width,
               frame.width <= previousMinSize.width + 8 {
                targetWidth = self.minSize.width
            } else {
                targetWidth = max(frame.width, self.minSize.width)
            }
            let targetHeight = max(frame.height, self.minSize.height)
            guard targetWidth != frame.width || targetHeight != frame.height else { return }

            frame.size = CGSize(width: targetWidth, height: targetHeight)
            window.setFrame(frame, display: true, animate: false)
        }
    }
}

private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        updateTitle(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateTitle(for: nsView)
    }

    private func updateTitle(for view: NSView) {
        DispatchQueue.main.async {
            view.window?.title = title
        }
    }
}
