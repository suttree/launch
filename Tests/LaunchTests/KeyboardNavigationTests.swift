import XCTest
import Carbon.HIToolbox
@testable import Launch

@MainActor
final class KeyboardNavigationTests: XCTestCase {
    func testTypeaheadRecognizesBackspaceAndForwardDelete() {
        XCTAssertTrue(TypeaheadInput.isDeletionKey(UInt16(kVK_Delete)))
        XCTAssertTrue(TypeaheadInput.isDeletionKey(UInt16(kVK_ForwardDelete)))
    }

    func testTypeaheadCanCorrectMistypedQueryWithBackspace() {
        var query = "friefox"
        for _ in 0..<6 {
            query = TypeaheadInput.deletingLastCharacter(from: query)
        }
        query += "irefox"

        XCTAssertEqual(query, "firefox")
        XCTAssertEqual(
            KeyboardNavigation.matchingApplicationIndex(query: query, titles: ["Firefox", "Slack"]),
            0
        )
    }

    func testBarWidthCountsEveryPinnedAndOpenApplication() {
        let width = LauncherLayout.barContentWidth(
            applicationCount: 7,
            hasRecentApplications: true,
            sectionWidths: [76, 76]
        )

        XCTAssertEqual(width, 520)
    }

    func testRecentApplicationsIncludeEveryOpenAppInSavedOrder() {
        let firefox = Bookmark(title: "Firefox", url: "/Applications/Firefox.app", isApplication: true)
        let slack = Bookmark(title: "Slack", url: "/Applications/Slack.app", isApplication: true)
        let notes = Bookmark(title: "Notes", url: "/System/Applications/Notes.app", isApplication: true)

        let applications = RecentApplicationOrder.reconcile(
            openApplications: [firefox, slack, notes],
            previousOrder: [slack, firefox],
            frontmostPath: notes.url
        )

        XCTAssertEqual(applications.map(\.title), ["Notes", "Slack", "Firefox"])
    }

    func testActivatingApplicationMovesItToFrontWithoutDuplication() {
        let firefox = Bookmark(title: "Firefox", url: "/Applications/Firefox.app", isApplication: true)
        let slack = Bookmark(title: "Slack", url: "/Applications/Slack.app", isApplication: true)

        let applications = RecentApplicationOrder.activating(slack, in: [firefox, slack])

        XCTAssertEqual(applications.map(\.title), ["Slack", "Firefox"])
    }

    func testTerminatedApplicationIsRemoved() {
        let firefox = Bookmark(title: "Firefox", url: "/Applications/Firefox.app", isApplication: true)
        let slack = Bookmark(title: "Slack", url: "/Applications/Slack.app", isApplication: true)

        let applications = RecentApplicationOrder.removing(path: firefox.url, from: [firefox, slack])

        XCTAssertEqual(applications.map(\.title), ["Slack"])
    }

    func testGlobalShortcutsIncludeOptionSpaceAndControlP() {
        XCTAssertEqual(
            LauncherHotKeys.definitions,
            [
                GlobalShortcut(id: 1, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)),
                GlobalShortcut(id: 2, keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey))
            ]
        )
    }

    func testTypeaheadFindsPinnedApplication() {
        let match = KeyboardNavigation.matchingApplicationIndex(
            query: "fire",
            titles: ["Firefox", "ChatGPT", "Slack"]
        )

        XCTAssertEqual(match, 0)
    }

    func testTypeaheadFindsRecentApplicationAfterPinnedApplications() {
        let match = KeyboardNavigation.matchingApplicationIndex(
            query: "sla",
            titles: ["Firefox", "ChatGPT", "Slack"]
        )

        XCTAssertEqual(match, 2)
    }

    func testTypeaheadPrefersPrefixMatchAcrossAllApplications() {
        let match = KeyboardNavigation.matchingApplicationIndex(
            query: "sa",
            titles: ["My Safari Profile", "Safari"]
        )

        XCTAssertEqual(match, 1)
    }

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
