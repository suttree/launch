import AppKit
import Carbon.HIToolbox
import Photos
import SwiftUI
import UniformTypeIdentifiers

private let gotoSurface = Color(red: 0.93, green: 0.72, blue: 0.30).opacity(0.95)

struct Section: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var bookmarks: [Bookmark]

    init(id: UUID = UUID(), name: String, bookmarks: [Bookmark] = []) {
        self.id = id
        self.name = name
        self.bookmarks = bookmarks
    }
}

struct Bookmark: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: String
    var isApplication: Bool
    var isFavorite: Bool
    let addedAt: Date

    enum CodingKeys: String, CodingKey { case id, title, url, isApplication, isFavorite, addedAt }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        url = try values.decode(String.self, forKey: .url)
        isApplication = try values.decodeIfPresent(Bool.self, forKey: .isApplication) ?? false
        isFavorite = try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        addedAt = try values.decodeIfPresent(Date.self, forKey: .addedAt) ?? .now
    }

    init(id: UUID = UUID(), title: String, url: String, addedAt: Date = .now, isApplication: Bool = false, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.url = url
        self.addedAt = addedAt
        self.isApplication = isApplication
        self.isFavorite = isFavorite
    }
}

@MainActor
final class Store: ObservableObject {
    @Published var sections: [Section] { didSet { save() } }
    @Published var mainApplications: [Bookmark] { didSet { saveMainApplications() } }
    let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GOTO", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("sections.json")
        if let data = UserDefaults.standard.data(forKey: "GOTO.mainApplications"), let apps = try? JSONDecoder().decode([Bookmark].self, from: data), !apps.isEmpty {
            mainApplications = apps
        } else {
            mainApplications = ["Firefox", "ChatGPT", "Host"].compactMap { name in
                let path = "/Applications/\(name).app"
                return FileManager.default.fileExists(atPath: path) ? Bookmark(title: name, url: path, isApplication: true) : nil
            }
        }
        if let data = try? Data(contentsOf: fileURL) {
            do { sections = try JSONDecoder().decode([Section].self, from: data) }
            catch { print("Launch could not load saved sections: \(error)"); sections = [Section(name: "READ"), Section(name: "WATCH")] }
        } else {
            sections = [Section(name: "READ"), Section(name: "WATCH")]
        }
    }

    func addSection(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !sections.contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) else { return }
        sections.append(Section(name: clean.uppercased()))
    }

    func remove(_ section: Section) { sections.removeAll { $0.id == section.id } }

    func moveSection(id: UUID, before targetID: UUID) {
        guard id != targetID, let source = sections.firstIndex(where: { $0.id == id }), let target = sections.firstIndex(where: { $0.id == targetID }) else { return }
        let section = sections.remove(at: source)
        sections.insert(section, at: source < target ? target - 1 : target)
    }

    func moveBookmark(id: UUID, before targetID: UUID, in section: Section) {
        guard id != targetID, let sectionIndex = sections.firstIndex(where: { $0.id == section.id }), let source = sections[sectionIndex].bookmarks.firstIndex(where: { $0.id == id }), let target = sections[sectionIndex].bookmarks.firstIndex(where: { $0.id == targetID }) else { return }
        let bookmark = sections[sectionIndex].bookmarks.remove(at: source)
        let destination = source < target ? target - 1 : target
        sections[sectionIndex].bookmarks.insert(bookmark, at: destination)
    }

    func rename(_ section: Section, to name: String) {
        guard let index = sections.firstIndex(of: section), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sections[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    func updateBookmark(_ bookmark: Bookmark, in section: Section, title: String, url: String) {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == section.id }), let itemIndex = sections[sectionIndex].bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        sections[sectionIndex].bookmarks[itemIndex].title = title
        sections[sectionIndex].bookmarks[itemIndex].url = url
    }

    func addBookmark(url: String, to section: Section) {
        guard let parsed = URL(string: url), parsed.scheme?.hasPrefix("http") == true else { return }
        let title = parsed.host?.replacingOccurrences(of: "www.", with: "") ?? parsed.absoluteString
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return }
        let bookmark = Bookmark(title: title, url: parsed.absoluteString)
        sections[index].bookmarks.insert(bookmark, at: 0)
        if let host = parsed.host, host.contains("youtube.com") || host == "youtu.be" {
            fetchYouTubeTitle(for: bookmark.id, url: parsed, in: section.id)
        } else {
            fetchTitle(for: bookmark.id, url: parsed, in: section.id)
        }
    }

    private func fetchYouTubeTitle(for bookmarkID: UUID, url: URL, in sectionID: UUID) {
        var components = URLComponents(string: "https://www.youtube.com/oembed")
        components?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString), URLQueryItem(name: "format", value: "json")]
        guard let endpoint = components?.url else { return }
        URLSession.shared.dataTask(with: endpoint) { [weak self] data, _, _ in
            guard let data, let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let title = payload["title"] as? String else { return }
            Task { @MainActor in
                guard let self, let sectionIndex = self.sections.firstIndex(where: { $0.id == sectionID }), let itemIndex = self.sections[sectionIndex].bookmarks.firstIndex(where: { $0.id == bookmarkID }) else { return }
                self.sections[sectionIndex].bookmarks[itemIndex].title = title
            }
        }.resume()
    }

    private func fetchTitle(for bookmarkID: UUID, url: URL, in sectionID: UUID) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let html = String(data: data, encoding: .utf8),
                  let match = html.range(of: #"(?is)<title[^>]*>\s*(.*?)\s*</title>"#, options: .regularExpression) else { return }
            let title = String(html[match]).replacingOccurrences(of: #"(?is)</?title[^>]*>"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            Task { @MainActor in
                guard let self, let sectionIndex = self.sections.firstIndex(where: { $0.id == sectionID }), let itemIndex = self.sections[sectionIndex].bookmarks.firstIndex(where: { $0.id == bookmarkID }) else { return }
                self.sections[sectionIndex].bookmarks[itemIndex].title = title
            }
        }.resume()
    }

    func addApplication(at url: URL, to section: Section) {
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return }
        let title = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        sections[index].bookmarks.insert(Bookmark(title: title, url: url.path, isApplication: true), at: 0)
    }

    func addMainApplication(at url: URL) {
        let title = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        guard !mainApplications.contains(where: { $0.url == url.path }) else { return }
        mainApplications.append(Bookmark(title: title, url: url.path, isApplication: true))
    }

    func removeMainApplication(_ app: Bookmark) {
        mainApplications.removeAll { $0.id == app.id }
    }

    func toggleFavorite(_ bookmark: Bookmark, in section: Section) {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == section.id }), let itemIndex = sections[sectionIndex].bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        sections[sectionIndex].bookmarks[itemIndex].isFavorite.toggle()
    }

    func removeBookmark(_ bookmark: Bookmark, from section: Section) {
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return }
        sections[index].bookmarks.removeAll { $0.id == bookmark.id }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sections) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func saveMainApplications() {
        if let data = try? JSONEncoder().encode(mainApplications) { UserDefaults.standard.set(data, forKey: "GOTO.mainApplications") }
    }
}

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum PhotosDropHandler {
    static func saveImage(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data else { return }
            save(data)
        }
        return true
    }

    private static func save(_ data: Data) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }) { success, _ in
                guard success else { return }
                addNewestAssetToAlbum()
            }
        }
    }

    private static func addNewestAssetToAlbum() {
        let assets = PHAsset.fetchAssets(with: .image, options: {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 1
            return options
        }())
        guard let asset = assets.firstObject else { return }
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var target: PHAssetCollection?
        albums.enumerateObjects { album, _, stop in
            if album.localizedTitle == "State of the Onion" {
                target = album
                stop.pointee = true
            }
        }
        PHPhotoLibrary.shared().performChanges({
            let changeRequest = target.map { PHAssetCollectionChangeRequest(for: $0) }
                ?? PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "State of the Onion")
            changeRequest?.addAssets([asset] as NSArray)
        }, completionHandler: nil)
    }
}

@main
struct LaunchApp: App {
    @StateObject private var store = Store()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: Panel!
    private var hosting: NSHostingView<BarView>!
    private let store = Store()
    private let keyboardNavigation = KeyboardNavigation()
    private var previousApplication: NSRunningApplication?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let iconName = isDark ? "AppIcon-dark" : "AppIcon"
        if let iconURL = Bundle.main.url(forResource: iconName, withExtension: "png"), let icon = NSImage(contentsOf: iconURL) { NSApp.applicationIconImage = icon }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let contentWidth = 98 + store.sections.reduce(CGFloat.zero) { $0 + max(76, CGFloat($1.name.count * 8 + 28)) }
        let width = min(max(contentWidth + 270, 300), visibleFrame.width - 40)
        let frame = NSRect(x: visibleFrame.midX - width / 2, y: visibleFrame.maxY - 361, width: width, height: 361)
        panel = Panel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.level = .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hasShadow = false
        hosting = NSHostingView(rootView: BarView(store: store, keyboardNavigation: keyboardNavigation))
        panel.contentView = hosting
        panel.orderFrontRegardless()
        registerHotKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) == true ? nil : event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in appDelegate.showForKeyboardNavigation() }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        let hotKeyID = EventHotKeyID(signature: OSType(0x474F544F), id: 1)
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKey)
    }

    private func showForKeyboardNavigation() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = frontmost
        }
        keyboardNavigation.begin(itemCount: dockItems.count)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private var dockItems: [KeyboardNavigation.DockItem] {
        store.mainApplications.map { .application($0.id) } + store.sections.map { .section($0.id) }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard NSApp.isActive, keyboardNavigation.selectedDockIndex != nil else { return false }

        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            guard keyboardNavigation.openSectionID == nil else { return false }
            keyboardNavigation.moveDock(by: -1, itemCount: dockItems.count)
        case kVK_RightArrow:
            guard keyboardNavigation.openSectionID == nil else { return false }
            keyboardNavigation.moveDock(by: 1, itemCount: dockItems.count)
        case kVK_UpArrow:
            guard let section = openSection else { return false }
            keyboardNavigation.moveSubmenu(by: -1, itemCount: sortedBookmarks(in: section).count)
        case kVK_DownArrow:
            guard let section = openSection else { return false }
            keyboardNavigation.moveSubmenu(by: 1, itemCount: sortedBookmarks(in: section).count)
        case kVK_Space:
            guard keyboardNavigation.openSectionID == nil,
                  let selectedItem,
                  case let .section(sectionID) = selectedItem,
                  let section = store.sections.first(where: { $0.id == sectionID }) else { return false }
            keyboardNavigation.openSubmenu(sectionID: sectionID, itemCount: sortedBookmarks(in: section).count)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            launchSelection()
        case kVK_Escape:
            dismissToPreviousApplication()
        default:
            return false
        }
        return true
    }

    private var selectedItem: KeyboardNavigation.DockItem? {
        guard let index = keyboardNavigation.selectedDockIndex, dockItems.indices.contains(index) else { return nil }
        return dockItems[index]
    }

    private var openSection: Section? {
        guard let sectionID = keyboardNavigation.openSectionID else { return nil }
        return store.sections.first(where: { $0.id == sectionID })
    }

    private func sortedBookmarks(in section: Section) -> [Bookmark] {
        section.bookmarks.sorted { $0.isFavorite && !$1.isFavorite || ($0.isFavorite == $1.isFavorite && $0.addedAt > $1.addedAt) }
    }

    private func launchSelection() {
        if let section = openSection,
           let index = keyboardNavigation.selectedSubmenuIndex,
           sortedBookmarks(in: section).indices.contains(index) {
            open(sortedBookmarks(in: section)[index])
            return
        }

        guard let selectedItem else { return }
        switch selectedItem {
        case let .application(id):
            if let app = store.mainApplications.first(where: { $0.id == id }) { open(app) }
        case let .section(id):
            if let section = store.sections.first(where: { $0.id == id }) {
                keyboardNavigation.openSubmenu(sectionID: id, itemCount: sortedBookmarks(in: section).count)
            }
        }
    }

    private func open(_ bookmark: Bookmark) {
        if bookmark.isApplication { NSWorkspace.shared.open(URL(fileURLWithPath: bookmark.url)) }
        else if let url = URL(string: bookmark.url) { NSWorkspace.shared.open(url) }
    }

    private func dismissToPreviousApplication() {
        keyboardNavigation.clear()
        panel.orderOut(nil)
        if previousApplication?.activate(options: [.activateIgnoringOtherApps]) != true {
            NSApp.deactivate()
        }
    }
}

struct BarView: View {
    @ObservedObject var store: Store
    @ObservedObject var keyboardNavigation: KeyboardNavigation
    @Environment(\.colorScheme) private var colorScheme
    @State private var addingSection = false
    @State private var newName = ""
    @State private var savedSection: UUID?
    @State private var isPhotoDropTargeted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            HStack(spacing: 0) {
                ForEach(Array(store.mainApplications.enumerated()), id: \.element.id) { index, app in
                    Button { NSWorkspace.shared.open(URL(fileURLWithPath: app.url)) } label: { Image(nsImage: NSWorkspace.shared.icon(forFile: app.url)).resizable().aspectRatio(contentMode: .fit).frame(width: 19, height: 19).padding(.horizontal, 10).frame(height: 40).background(keyboardNavigation.selectedDockIndex == index ? selectionHighlight : .clear) }.buttonStyle(.plain).focusable(false).contextMenu { Button("Remove", role: .destructive) { store.removeMainApplication(app) } }
                }
                ForEach(Array(store.sections.enumerated()), id: \.element.id) { index, section in
                    SectionButton(section: section, store: store, isOpen: keyboardNavigation.openSectionID == section.id, isSelected: keyboardNavigation.selectedDockIndex == store.mainApplications.count + index) {
                        keyboardNavigation.toggleSubmenu(sectionID: section.id, itemCount: sortedBookmarks(in: section).count)
                    } onDrop: { url in store.addBookmark(url: url, to: section); savedSection = section.id; DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { savedSection = nil } }
                    .scaleEffect(savedSection == section.id ? 1.08 : 1).animation(.easeOut(duration: 0.25), value: savedSection)
                    .contextMenu { Button("Remove section", role: .destructive) { store.remove(section); keyboardNavigation.clear() } }
                    .overlay(alignment: .topLeading) {
                        if keyboardNavigation.openSectionID == section.id {
                            SectionPopover(section: section, store: store, selectedIndex: keyboardNavigation.selectedSubmenuIndex) { keyboardNavigation.clear() }
                                .offset(y: 40)
                        }
                    }
                }
                Text("🌍")
                    .font(.system(size: 13))
                    .frame(width: 40, height: 40)
                    .background(isPhotoDropTargeted ? selectionHighlight : .clear)
                    .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: $isPhotoDropTargeted) { providers in
                        PhotosDropHandler.saveImage(from: providers)
                    }
                Menu {
                    Button("Add category") { addSectionPrompt() }
                    Button("Add application") { chooseMainApplication() }
                } label: { Image(systemName: "plus").font(.system(size: 18, weight: .light)).offset(x: -4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) }.menuStyle(.borderlessButton).menuIndicator(.hidden).focusable(false).frame(width: 48, height: 40)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 40)
            .padding(.trailing, 16)
            .background(.regularMaterial)
            .frame(maxWidth: .infinity, alignment: .center)
            if isPhotoDropTargeted {
                Text("Drop image to State of the Onion")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
            }
            if addingSection {
                HStack(spacing: 8) {
                    TextField("Section name", text: $newName) { committed in
                        if committed { store.addSection(newName); newName = ""; addingSection = false }
                    }.textFieldStyle(.roundedBorder).frame(width: 150)
                    Button("Cancel") { addingSection = false; newName = "" }.buttonStyle(.plain)
                }.padding(10).background(.regularMaterial).cornerRadius(7).offset(x: 65, y: 42)
            }
        }
        .frame(height: 360, alignment: .top)
        .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: $isPhotoDropTargeted) { providers in
            PhotosDropHandler.saveImage(from: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            keyboardNavigation.clear()
            savedSection = nil
        }
    }

    private func sortedBookmarks(in section: Section) -> [Bookmark] {
        section.bookmarks.sorted { $0.isFavorite && !$1.isFavorite || ($0.isFavorite == $1.isFavorite && $0.addedAt > $1.addedAt) }
    }

    private var selectionHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.24) : Color.accentColor.opacity(0.22)
    }

    private func panelMakeKey() {
        NSApp.keyWindow?.makeKey()
    }

    private func addSectionPrompt() {
        let alert = NSAlert()
        alert.messageText = "New section"
        alert.informativeText = "Choose a short name for the new section."
        let field = NSTextField(string: "")
        field.placeholderString = "Section name"
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        field.drawsBackground = true
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn { store.addSection(field.stringValue) }
    }

    private func chooseMainApplication() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in if response == .OK, let url = panel.url { store.addMainApplication(at: url) } }
    }
}

struct MenuBarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct SectionButton: View {
    let section: Section
    @ObservedObject var store: Store
    let isOpen: Bool
    let isSelected: Bool
    let action: () -> Void
    let onDrop: (String) -> Void
    @State private var isDropTarget = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) { Text(section.name).font(.system(size: 12, weight: .medium, design: .monospaced)).padding(.horizontal, 14).frame(height: 40).background(isDropTarget ? Color.accentColor.opacity(0.25) : (isSelected ? selectionHighlight : (isOpen ? Color.black.opacity(0.09) : .clear))) }
            .buttonStyle(.plain)
            .focusable(false)
            .onDrop(of: [.text, .url], isTargeted: $isDropTarget) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                    if let value, let string = value as? String {
                        DispatchQueue.main.async {
                            if let id = UUID(uuidString: string) { store.moveSection(id: id, before: section.id) }
                            else { onDrop(string) }
                        }
                    }
                }
                return true
            }
    }

    private var selectionHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.24) : Color.accentColor.opacity(0.22)
    }
}


struct SectionPopover: View {
    let section: Section
    @ObservedObject var store: Store
    let selectedIndex: Int?
    let dismiss: () -> Void
    @State private var hoveredBookmark: UUID?
    @State private var editingBookmark: UUID?
    @State private var editedBookmarkTitle = ""
    @State private var editedBookmarkURL = ""
    @FocusState private var bookmarkTitleFocused: Bool
    @State private var editingTitle = false
    @State private var editedTitle = ""
    @FocusState private var titleFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var activeSection: Section {
        store.sections.first(where: { $0.id == section.id }) ?? section
    }

    private var sortedBookmarks: [Bookmark] {
        activeSection.bookmarks.sorted { $0.isFavorite && !$1.isFavorite || ($0.isFavorite == $1.isFavorite && $0.addedAt > $1.addedAt) }
    }

    private var bookmarkViewportHeight: CGFloat {
        min(max(CGFloat(sortedBookmarks.count) * 40, 0), 180)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if editingTitle {
                    TextField("Section name", text: $editedTitle).textFieldStyle(.plain).font(.system(size: 11, weight: .bold, design: .monospaced)).focused($titleFocused).onSubmit { store.rename(section, to: editedTitle); editingTitle = false }
                } else {
                    Text(section.name).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.remove(section); dismiss() } label: { Image(systemName: "trash").foregroundStyle(.secondary) }.buttonStyle(.plain).padding(.trailing, 14)
                Button { editedTitle = section.name; editingTitle = true; titleFocused = true } label: { Image(systemName: "pencil").foregroundStyle(.secondary) }.buttonStyle(.plain).padding(.trailing, 14)
            }.padding(14)
            Divider()
            if activeSection.bookmarks.isEmpty { Text("Drop a link here").foregroundStyle(.secondary).padding(24) }
            Button { chooseApplication() } label: {
                Label("Add application", systemImage: "plus").padding(.horizontal, 14).padding(.vertical, 9)
            }.buttonStyle(.plain)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sortedBookmarks.enumerated()), id: \.element.id) { index, bookmark in
                if index > 0 && !bookmark.isFavorite && sortedBookmarks[index - 1].isFavorite {
                    Divider()
                }
                    HStack(spacing: 8) {
                    Button { open(bookmark); dismiss() } label: {
                        HStack(spacing: 9) {
                            ItemIcon(bookmark: bookmark)
                            if editingBookmark == bookmark.id {
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Title", text: $editedBookmarkTitle).textFieldStyle(.roundedBorder).frame(width: 140).focused($bookmarkTitleFocused).onSubmit { commitBookmarkEdit(bookmark) }
                                }
                            } else {
                                Text(bookmark.isApplication ? bookmark.title : "\(bookmark.title), \(URL(string: bookmark.url)?.host ?? bookmark.url)").lineLimit(1).truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading).help(bookmark.url)
                            }
                        }.padding(.leading, 14).padding(.vertical, 9).frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                    if hoveredBookmark == bookmark.id {
                        if editingBookmark == bookmark.id {
                            EmptyView()
                        } else {
                            Button { editedBookmarkTitle = bookmark.title; editedBookmarkURL = bookmark.url; editingBookmark = bookmark.id; DispatchQueue.main.async { bookmarkTitleFocused = true } } label: { Image(systemName: "pencil").foregroundStyle(.secondary) }.buttonStyle(.plain)
                        }
                        Button { store.toggleFavorite(bookmark, in: section) } label: { Image(systemName: bookmark.isFavorite ? "star.fill" : "star").foregroundStyle(bookmark.isFavorite ? .yellow : .secondary) }.buttonStyle(.plain)
                        Button { store.removeBookmark(bookmark, from: section) } label: { Image(systemName: "trash").foregroundStyle(.secondary) }.buttonStyle(.plain)
                    }
                    }
                    .padding(.trailing, 28)
                    .background(selectedIndex == index || hoveredBookmark == bookmark.id ? selectionHighlight : .clear)
                    .onHover { hoveredBookmark = $0 ? bookmark.id : nil }
                    .onDrag { NSItemProvider(object: bookmark.id.uuidString as NSString) }
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                            if let value, let string = value as? String, let id = UUID(uuidString: string) { DispatchQueue.main.async { store.moveBookmark(id: id, before: bookmark.id, in: section) } }
                        }
                        return true
                    }
                    .contextMenu { Button("Remove", role: .destructive) { store.removeBookmark(bookmark, from: section) } }
                        }
                    }
                }
                .frame(height: bookmarkViewportHeight)
                .onChange(of: selectedIndex) { newIndex in
                    guard let newIndex, sortedBookmarks.indices.contains(newIndex) else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(sortedBookmarks[newIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 230)
        .background(.regularMaterial)
        .clipShape(Rectangle())
        .shadow(radius: 0)
        .onDrop(of: [.text, .url], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                if let value, let url = value as? String { DispatchQueue.main.async { store.addBookmark(url: url, to: section) } }
            }
            return true
        }
        .onDrag { NSItemProvider(object: section.id.uuidString as NSString) }
    }

    private func chooseApplication() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url { self.store.addApplication(at: url, to: section) }
        }
    }

    private var selectionHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.30) : Color.accentColor.opacity(0.16)
    }

    private func open(_ bookmark: Bookmark) {
        if bookmark.isApplication { NSWorkspace.shared.open(URL(fileURLWithPath: bookmark.url)) }
        else if let url = URL(string: bookmark.url) { NSWorkspace.shared.open(url) }
    }

    private func commitBookmarkEdit(_ bookmark: Bookmark) {
        store.updateBookmark(bookmark, in: section, title: editedBookmarkTitle, url: bookmark.url)
        editingBookmark = nil
    }
}

struct MarqueeText: View {
    let text: String
    @State private var scrolling = false

    var body: some View {
        Text(text).lineLimit(1).offset(x: scrolling ? -18 : 0).animation(.linear(duration: 2).repeatForever(autoreverses: true), value: scrolling).onHover { scrolling = $0 && text.count > 28 }
    }
}

struct ItemIcon: View {
    let bookmark: Bookmark

    var body: some View {
        Group {
            if bookmark.isApplication {
                Image(nsImage: NSWorkspace.shared.icon(forFile: bookmark.url)).resizable().aspectRatio(contentMode: .fit)
            } else if let host = URL(string: bookmark.url)?.host {
                AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=32")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "globe").resizable().padding(2)
                }
            } else {
                Image(systemName: "link").resizable().padding(2)
            }
        }.frame(width: 20, height: 20).clipped()
    }
}
