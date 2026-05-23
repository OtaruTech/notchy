import Testing
import AppKit
@testable import Notchy

/// Regression tests for the click-through behaviour of the notification panel.
///
/// **The bug we're protecting against:** when the notification panel exists
/// but has no pill on screen (`feature.current == nil`), it must NOT consume
/// mouse events. Otherwise the 420 × ~148 pt rectangle directly under the notch
/// silently swallows every click in that region — apps behind become
/// un-interactive. We hit this once in v0.7 development and lost half an
/// afternoon to it. Setting `panel.ignoresMouseEvents = false` permanently
/// (as I originally wrote it) is the trap; the SwiftUI-level
/// `.allowsHitTesting(false)` does NOT save you, because AppKit's window-level
/// hit testing claims the event for the panel's NSWindow before SwiftUI gets
/// to decide.
///
/// The contract being tested:
///   - **No notification → panel is click-through** (the bug, if regressed)
///   - **Notification visible → panel captures clicks** (so the user can
///     click the pill to dismiss / focus terminal)
///   - **Dismiss returns to click-through** (no lingering blocking region)
///
/// These tests reach down to `NSPanel.ignoresMouseEvents` (via the
/// `isClickThrough` accessor) because that IS the behaviour: macOS uses that
/// flag at the window level to decide whether to claim or pass through events.
/// Asserting it is the most faithful test we can write short of actually
/// posting NSEvent mouse-down events to the windowing system.
@MainActor
struct NotificationWindowControllerClickThroughTests {

    // MARK: helpers

    private func makeNote(id: String = "test", sticky: Bool = false) -> ExternalNotification {
        ExternalNotification(
            id: id, source: "claude-code", kind: .info,
            title: "Test", body: "body",
            cwd: nil, sessionID: nil,
            ttlSeconds: 30, sticky: sticky,
            receivedAt: Date()
        )
    }

    private func makeController() -> (NotificationFeature, NotificationWindowController) {
        let feature = NotificationFeature()
        let controller = NotificationWindowController(feature: feature)
        controller.show()                 // builds the NSPanel
        // applyMouseGate ran once inside startObserving() — but we call it
        // again to make the test deterministic regardless of observation
        // runtime timing.
        controller.applyMouseGate()
        return (feature, controller)
    }

    // MARK: the regression

    /// **THE** test — protects the bug we kept hitting.
    /// If this fails, the area below the notch will not be clickable.
    @Test func panelIsClickThroughWhenNoNotificationVisible() {
        let (_, controller) = makeController()

        #expect(
            controller.isClickThrough == true,
            """
            Notification panel must be click-through when no pill is on screen.
            Otherwise the 420×148pt area below the notch silently captures clicks
            and apps behind it become un-interactive.

            If this assertion fails: check that
            `NotificationWindowController` sets `panel.ignoresMouseEvents = true`
            during construction AND keeps it bound to `feature.current == nil`
            via `applyMouseGate()`.
            """
        )
    }

    // MARK: the positive side

    @Test func panelCapturesMouseEventsWhilePillVisible() {
        let (feature, controller) = makeController()

        feature.push(makeNote())
        controller.applyMouseGate()      // simulate observation tracking firing

        #expect(
            controller.isClickThrough == false,
            "When a pill is visible the panel must capture clicks so the user can click to dismiss / focus terminal."
        )
    }

    // MARK: dismiss returns to click-through

    @Test func panelReturnsToClickThroughAfterDismiss() {
        let (feature, controller) = makeController()

        feature.push(makeNote())
        controller.applyMouseGate()
        #expect(controller.isClickThrough == false)   // sanity

        feature.dismissCurrent()
        controller.applyMouseGate()

        #expect(
            controller.isClickThrough == true,
            "After dismissing the last notification the panel must release mouse events."
        )
    }

    // MARK: queue draining shouldn't drop the gate

    /// When one sticky pill is showing and another comes in, the queue holds it.
    /// The panel should remain capturing events throughout — there's still a pill.
    @Test func panelStaysCapturingThroughStickyQueue() {
        let (feature, controller) = makeController()

        feature.push(makeNote(id: "a", sticky: true))
        controller.applyMouseGate()
        #expect(controller.isClickThrough == false)

        feature.push(makeNote(id: "b", sticky: true))   // queued behind 'a'
        controller.applyMouseGate()
        #expect(controller.isClickThrough == false, "First sticky pill still visible — must remain capturing")

        feature.dismissCurrent()                         // 'a' goes, 'b' takes over
        controller.applyMouseGate()
        #expect(feature.current?.id == "b", "Queue advances to next pill")
        #expect(controller.isClickThrough == false, "Second pill is now visible — must still capture")

        feature.dismissCurrent()                         // 'b' goes too
        controller.applyMouseGate()
        #expect(controller.isClickThrough == true, "All pills dismissed — must release")
    }

    // MARK: initial state before any show()

    /// Defensive: before `show()` is called there is no panel. The accessor
    /// should report click-through (i.e. nothing claiming events), not
    /// crash. This guards against accidental ordering changes in
    /// AppDelegate setup.
    @Test func isClickThroughBeforeShowIsTrue() {
        let feature = NotificationFeature()
        let controller = NotificationWindowController(feature: feature)
        // intentionally NOT calling show()
        #expect(controller.isClickThrough == true)
    }
}
