import XCTest
@testable import Launch

@MainActor
final class KeyboardNavigationTests: XCTestCase {
    func testPanelLeavesEnoughRoomForPopoverAtEitherEdge() {
        let width = LauncherLayout.panelWidth(contentWidth: 400, visibleWidth: 1_000)

        XCTAssertEqual(width, 888)
    }

    func testPanelWidthStaysInsideVisibleScreen() {
        let width = LauncherLayout.panelWidth(contentWidth: 900, visibleWidth: 1_000)

        XCTAssertEqual(width, 960)
    }

    func testBeginSelectsFirstDockItem() {
        let navigation = KeyboardNavigation()

        navigation.begin(itemCount: 3)

        XCTAssertEqual(navigation.selectedDockIndex, 0)
    }

    func testDockNavigationWrapsInBothDirections() {
        let navigation = KeyboardNavigation()
        navigation.begin(itemCount: 3)

        navigation.moveDock(by: -1, itemCount: 3)
        XCTAssertEqual(navigation.selectedDockIndex, 2)

        navigation.moveDock(by: 1, itemCount: 3)
        XCTAssertEqual(navigation.selectedDockIndex, 0)
    }

    func testOpeningSubmenuSelectsFirstItem() {
        let navigation = KeyboardNavigation()
        let sectionID = UUID()

        navigation.openSubmenu(sectionID: sectionID, itemCount: 2)

        XCTAssertEqual(navigation.openSectionID, sectionID)
        XCTAssertEqual(navigation.selectedSubmenuIndex, 0)
    }

    func testMovingUpFromFirstSubmenuItemReturnsToDock() {
        let navigation = KeyboardNavigation()
        navigation.openSubmenu(sectionID: UUID(), itemCount: 2)

        navigation.moveSubmenu(by: -1, itemCount: 2)

        XCTAssertNil(navigation.openSectionID)
        XCTAssertNil(navigation.selectedSubmenuIndex)
    }

    func testSubmenuNavigationStopsAtBottom() {
        let navigation = KeyboardNavigation()
        navigation.openSubmenu(sectionID: UUID(), itemCount: 2)

        navigation.moveSubmenu(by: 1, itemCount: 2)
        navigation.moveSubmenu(by: 1, itemCount: 2)

        XCTAssertEqual(navigation.selectedSubmenuIndex, 1)
    }

    func testClearClosesSubmenuAndRemovesSelections() {
        let navigation = KeyboardNavigation()
        navigation.begin(itemCount: 2)
        navigation.openSubmenu(sectionID: UUID(), itemCount: 2)

        navigation.clear()

        XCTAssertNil(navigation.selectedDockIndex)
        XCTAssertNil(navigation.openSectionID)
        XCTAssertNil(navigation.selectedSubmenuIndex)
    }
}
