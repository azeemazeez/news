import Foundation
import PostHog

/// Every analytics event the app sends, gathered in one place.
///
/// The names and property shapes here are mirrored in `public/analytics.js` on
/// the website. `edition_loaded`, `article_opened` and `archive_date_selected`
/// are the cross-platform funnel, so renaming one side without the other
/// quietly splits the numbers in two.
///
/// Nothing here identifies anyone: the app has no accounts, so every event is
/// anonymous. Story text, the reader's saved list and the email address used
/// on the website are never attached to an event.
enum Analytics {
    private static let projectToken = "phc_rq8yTiZJXnUNeVbK7Uxar5Qe9nJKE6VFxXDsSeUANHdC"
    private static let host = "https://us.i.posthog.com"

    /// Shared with the widget extension. Both processes then read and write one
    /// queue in the app group container, so the widget reports as the same
    /// anonymous person as the app instead of a second one, and anything it
    /// captures survives the extension being killed.
    private static let appGroup = "group.com.thenuus.app"

    private static func makeConfiguration() -> PostHogConfig {
        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.appGroupIdentifier = appGroup

        // Every SwiftUI screen is the same UIHostingController underneath, so
        // the automatic capture reports one indistinguishable name for all of
        // them. The views call `Analytics.screen(_:)` themselves instead.
        config.captureScreenViews = false
        return config
    }

    static func start() {
        PostHogSDK.shared.setup(makeConfiguration())

        // Separates app traffic from the website, which registers
        // platform: 'web' in public/posthog.js.
        PostHogSDK.shared.register(["platform": "ios"])
    }

    /// A widget timeline runs in a short-lived extension process that can be
    /// killed before a flush completes, so events are written to the shared
    /// container and sent by whichever process gets there first — in practice
    /// usually the app on its next launch.
    ///
    /// A `static let` runs exactly once per process, which is what this needs:
    /// WidgetKit may ask the same process for several timelines.
    private static let widgetSession: Void = {
        let config = makeConfiguration()
        config.captureApplicationLifecycleEvents = false

        // Try to send immediately rather than wait for a batch of twenty that
        // this process will not live long enough to fill.
        config.flushAt = 1

        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register(["platform": "ios"])
    }()

    static func startForWidget() {
        _ = widgetSession
    }

    private static func capture(_ event: String, _ properties: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    // MARK: - Screens

    enum Screen: String {
        case feed = "Feed"
        case reader = "Reader"
        case archive = "Archive"
        case saved = "Saved"
        case settings = "Settings"
        case voicePicker = "Voice Picker"
        case about = "About"
    }

    static func screen(_ name: Screen) {
        PostHogSDK.shared.screen(name.rawValue)
    }

    // MARK: - Editions

    enum EditionType: String { case latest, archive }

    /// Whether what's on screen came off the network or the offline cache.
    enum EditionSource: String { case network, cache }

    static func editionLoaded(_ edition: Edition, type: EditionType, source: EditionSource) {
        capture("edition_loaded", [
            "edition_date": edition.date,
            "edition_type": type.rawValue,
            "story_count": edition.stories.count,
            "source": source.rawValue,
        ])
    }

    static func editionLoadFailed(date: String?, error: Error) {
        capture("edition_load_failed", [
            "edition_date": date ?? "latest",
            "error": error.localizedDescription,
        ])
    }

    static func archiveDateSelected(_ date: String) {
        capture("archive_date_selected", ["date": date, "from": "archive_screen"])
    }

    // MARK: - Stories

    /// Opening a story's native reading screen. The website has no reader, so
    /// this one has no web counterpart.
    static func storyOpened(_ story: Story, position: Int, editionDate: String?) {
        capture("story_opened", properties(for: story, position: position, editionDate: editionDate))
    }

    /// Leaving for the publisher's own site — the event both platforms share.
    static func articleOpened(_ story: Story, editionDate: String?) {
        capture("article_opened", properties(for: story, editionDate: editionDate))
    }

    static func storySaveToggled(_ story: Story, saved: Bool, editionDate: String?) {
        capture(saved ? "story_saved" : "story_unsaved",
                properties(for: story, editionDate: editionDate))
    }

    /// `completed` separates a real share from opening the sheet and backing
    /// out — something `ShareLink` cannot report, which is why sharing goes
    /// through `ShareSheet` instead.
    static func storyShared(
        _ story: Story,
        editionDate: String?,
        activity: String?,
        completed: Bool
    ) {
        var properties = properties(for: story, editionDate: editionDate)
        properties["completed"] = completed
        if let activity { properties["activity"] = activity }
        capture("story_shared", properties)
    }

    /// Which story it was, never what it said.
    private static func properties(
        for story: Story,
        position: Int? = nil,
        editionDate: String?
    ) -> [String: Any] {
        var properties: [String: Any] = [
            "url": story.url,
            "story_source": story.source,
        ]
        if let position { properties["position"] = position }
        if let editionDate { properties["edition_date"] = editionDate }
        return properties
    }

    // MARK: - Listening

    enum ListenScope: String { case edition, story }

    static func listenStarted(scope: ListenScope, editionDate: String?, voice: String?) {
        var properties: [String: Any] = ["scope": scope.rawValue]
        if let editionDate { properties["edition_date"] = editionDate }
        if let voice { properties["voice"] = voice }
        capture("listen_started", properties)
    }

    static func listenPaused(scope: ListenScope) {
        capture("listen_paused", ["scope": scope.rawValue])
    }

    static func listenResumed(scope: ListenScope) {
        capture("listen_resumed", ["scope": scope.rawValue])
    }

    /// `finished` separates "listened to the end" from "walked away", which is
    /// the only way to tell whether people actually sit through an edition.
    static func listenEnded(scope: ListenScope, finished: Bool, seconds: TimeInterval) {
        capture(finished ? "listen_finished" : "listen_stopped", [
            "scope": scope.rawValue,
            "duration_seconds": Int(seconds.rounded()),
        ])
    }

    // MARK: - Preferences

    static func textSizeChanged(_ size: String) {
        capture("text_size_changed", ["size": size])
    }

    static func voiceChanged(name: String, quality: String) {
        capture("voice_changed", ["voice": name, "quality": quality])
    }

    static func reminderToggled(enabled: Bool, hour: Int) {
        capture("reminder_toggled", ["enabled": enabled, "hour": hour])
    }

    // MARK: - Widget

    /// Sent from the widget extension each time WidgetKit asks for a timeline,
    /// which is roughly every few hours per installed widget — the only signal
    /// the app gets that a widget exists at all.
    static func widgetRendered(family: String, hasEdition: Bool) {
        capture("widget_rendered", ["family": family, "has_edition": hasEdition])
    }

    /// Sent from the app when it is opened by a tap on the widget.
    static func widgetTapped(family: String?) {
        capture("widget_tapped", ["family": family ?? "unknown"])
    }

    // MARK: - Entry points

    enum Shortcut: String { case read, listen }

    static func shortcutInvoked(_ shortcut: Shortcut) {
        capture("shortcut_invoked", ["intent": shortcut.rawValue])
    }
}
