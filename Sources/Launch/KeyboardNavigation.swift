import Foundation

@MainActor
final class KeyboardNavigation: ObservableObject {
    enum DockItem: Equatable {
        case application(UUID)
        case section(UUID)
    }

    @Published private(set) var selectedDockIndex: Int?
    @Published private(set) var openSectionID: UUID?
    @Published private(set) var selectedSubmenuIndex: Int?
    @Published private(set) var searchQuery = ""

    func begin(itemCount: Int) {
        selectedDockIndex = itemCount > 0 ? 0 : nil
        openSectionID = nil
        selectedSubmenuIndex = nil
        searchQuery = ""
    }

    func moveDock(by offset: Int, itemCount: Int) {
        guard itemCount > 0 else {
            clear()
            return
        }

        let current = selectedDockIndex ?? 0
        selectedDockIndex = (current + offset + itemCount) % itemCount
        openSectionID = nil
        selectedSubmenuIndex = nil
    }

    func selectDock(index: Int, itemCount: Int) {
        guard itemCount > 0, (0..<itemCount).contains(index) else { return }
        selectedDockIndex = index
        openSectionID = nil
        selectedSubmenuIndex = nil
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
    }

    func openSubmenu(sectionID: UUID, itemCount: Int) {
        openSectionID = sectionID
        selectedSubmenuIndex = itemCount > 0 ? 0 : nil
    }

    func toggleSubmenu(sectionID: UUID, itemCount: Int) {
        if openSectionID == sectionID {
            openSectionID = nil
            selectedSubmenuIndex = nil
        } else {
            openSubmenu(sectionID: sectionID, itemCount: itemCount)
        }
    }

    func moveSubmenu(by offset: Int, itemCount: Int) {
        guard itemCount > 0 else {
            selectedSubmenuIndex = nil
            return
        }

        let current = selectedSubmenuIndex ?? 0
        if offset < 0 && current == 0 {
            openSectionID = nil
            selectedSubmenuIndex = nil
            return
        }
        if offset > 0 && current >= itemCount - 1 {
            selectedSubmenuIndex = itemCount - 1
            return
        }
        selectedSubmenuIndex = (current + offset + itemCount) % itemCount
    }

    func clear() {
        selectedDockIndex = nil
        openSectionID = nil
        selectedSubmenuIndex = nil
    }
}
