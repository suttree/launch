import AppKit

final class ClockView: NSView {
    let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .black
        label.alignment = .right
        label.frame = bounds
        label.autoresizingMask = [.width, .height]
        label.isSelectable = false
        addSubview(label)

        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Menu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
        self.menu = menu
        label.menu = menu
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var clock: ClockView!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Launching a second copy should not create an overlapping clock.
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 64, height: 24),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        clock = ClockView(frame: NSRect(x: 0, y: 0, width: 64, height: 24))
        panel.contentView = clock
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
            name: NSNotification.Name.NSSystemClockDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh),
            name: NSWorkspace.didWakeNotification, object: nil)
        refresh()
    }

    @objc private func refresh() {
        guard let screen = NSScreen.screens.first else { return }
        // Use the full frame so hiding the macOS menu bar never moves the clock.
        panel.setFrameTopLeftPoint(NSPoint(x: screen.frame.maxX - 76, y: screen.frame.maxY - 9))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        let now = Date()
        clock.label.stringValue = formatter.string(from: now)
        clock.setAccessibilityLabel("Time " + clock.label.stringValue)
        panel.orderFrontRegardless()
        timer?.invalidate()
        let interval = 60 - now.timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
        let next = Timer(timeInterval: interval, target: self, selector: #selector(refresh), userInfo: nil, repeats: false)
        next.tolerance = 0.2
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
