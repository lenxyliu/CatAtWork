import Foundation

public struct WorkspaceClassifier: Sendable {
    public init() {}

    public func classify(bundleIdentifier: String?, windowTitle: String?) -> WorkspaceCategory {
        let bundle = (bundleIdentifier ?? "").lowercased()
        let title = (windowTitle ?? "").lowercased()
        let combined = bundle + " " + title

        if containsAny(combined, ["zoom", "meet", "teams", "webex", "会议", "meeting"]) { return .meeting }
        if containsAny(combined, ["xcode", "code", "terminal", "iterm", "figma", "notion", "slack", "文稿", "工作"]) { return .work }
        if containsAny(combined, ["safari", "chrome", "firefox", "arc", "浏览器"]) { return .browsing }
        if containsAny(combined, ["music", "spotify", "youtube", "bilibili", "视频", "音乐"]) { return .media }
        if containsAny(combined, ["steam", "game", "游戏"]) { return .game }
        return .privateOrUnknown
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }
}
