import AppKit
import CatAtWorkCore
import Sparkle
import SwiftUI
import UniformTypeIdentifiers

@main
struct CatAtWorkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { SettingsView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var petWindow: PetWindowController?
    private var awareness: SystemAwareness?
    private var statusItem: NSStatusItem?
    private var mediaAwareness: MediaAwareness?
    private var welcomeWindow: NSWindow?
    private var settingsObserver: NSObjectProtocol?
    private var updaterController: SPUStandardUpdaterController?
    private var didCompleteLaunch = false
    private var currentActionItem: NSMenuItem?
    private var packageVersionItem: NSMenuItem?
    private var previewMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            completeLaunch()
            return
        }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard !others.isEmpty else {
            completeLaunch()
            return
        }

        let currentURL = Bundle.main.bundleURL.standardizedFileURL
        if let sameBuild = others.first(where: { $0.bundleURL?.standardizedFileURL == currentURL }) {
            sameBuild.activate(options: [])
            NSApp.terminate(nil)
            return
        }

        // Development builds are frequently launched from a new path. Keeping
        // the old process alive made the new build quit immediately, leaving an
        // old cat, old assets, or several stale cats on screen. Hand over to the
        // newly launched bundle instead.
        others.forEach { _ = $0.terminate() }
        Task { @MainActor [weak self] in
            for _ in 0..<20 {
                guard others.contains(where: { !$0.isTerminated }) else {
                    self?.completeLaunch()
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            others.filter { !$0.isTerminated }.forEach { _ = $0.forceTerminate() }
            for _ in 0..<10 {
                guard others.contains(where: { !$0.isTerminated }) else { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            self?.completeLaunch()
        }
    }

    private func completeLaunch() {
        guard !didCompleteLaunch else { return }
        didCompleteLaunch = true
        UserDefaults.standard.register(defaults: [
            "chasePointer": true,
            "throwEnabled": true,
            "systemAwareness": true,
            "mediaAwareness": false,
            "petScale": 0.45,
            "currentPetSupportsThrow": true,
            "currentPetSupportsLocomotion": true,
        ])
        if !UserDefaults.standard.bool(forKey: "appliedCompactDefaultScaleV2") {
            UserDefaults.standard.set(0.45, forKey: "petScale")
            UserDefaults.standard.set(true, forKey: "appliedCompactDefaultScaleV2")
        }
        NSApp.setActivationPolicy(.accessory)
        let controller = PetWindowController()
        petWindow = controller
        loadSelectedOrDefaultPet(into: controller)
        controller.showPet()

        updateAwarenessServices()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .catAtWorkAwarenessSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateAwarenessServices() }
        }
        installStatusItem()
        if updatesAreConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
        if !UserDefaults.standard.bool(forKey: "completedWelcome") {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let settingsObserver { NotificationCenter.default.removeObserver(settingsObserver) }
        awareness?.stop()
        mediaAwareness?.stop()
    }

    private func updateAwarenessServices() {
        awareness?.stop()
        awareness = nil
        mediaAwareness?.stop()
        mediaAwareness = nil
        if UserDefaults.standard.bool(forKey: "systemAwareness") {
            let service = SystemAwareness()
            service.onEvent = { [weak controller = petWindow] event in controller?.handleSystemEvent(event) }
            service.start()
            awareness = service
        }
        if UserDefaults.standard.bool(forKey: "mediaAwareness") {
            let service = MediaAwareness()
            service.onEvent = { [weak controller = petWindow] event in controller?.handleSystemEvent(event) }
            service.start()
            mediaAwareness = service
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let statusImage = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "猫上班了")
        statusImage?.isTemplate = true
        item.button?.image = statusImage
        item.button?.title = statusImage == nil ? "🐾" : ""
        item.button?.toolTip = "猫上班了"
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "显示小猫", action: #selector(showPet), keyEquivalent: "")
        let sizeItem = NSMenuItem(title: "宠物大小", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu(title: "宠物大小")
        for (title, value) in [("小（45%）", 0.45), ("中（65%）", 0.65), ("大（85%）", 0.85)] {
            let item = NSMenuItem(title: title, action: #selector(setPetScale(_:)), keyEquivalent: "")
            item.representedObject = value
            item.target = self
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
        menu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "导入 .catpet…", action: #selector(importPet), keyEquivalent: "i")
        let previewItem = NSMenuItem(title: "动作检查", action: nil, keyEquivalent: "")
        let animationsMenu = NSMenu(title: "动作检查")
        previewMenu = animationsMenu
        previewItem.submenu = animationsMenu
        rebuildPreviewMenu()
        menu.addItem(previewItem)
        if updatesAreConfigured {
            menu.addItem(withTitle: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "u")
        } else {
            let unavailable = NSMenuItem(title: "更新：开发测试版未配置", action: nil, keyEquivalent: "")
            unavailable.isEnabled = false
            menu.addItem(unavailable)
        }
        let packageItem = NSMenuItem(title: "素材版本：读取中", action: nil, keyEquivalent: "")
        packageItem.isEnabled = false
        menu.addItem(packageItem)
        packageVersionItem = packageItem
        let actionItem = NSMenuItem(title: "当前动作：读取中", action: nil, keyEquivalent: "")
        actionItem.isEnabled = false
        menu.addItem(actionItem)
        currentActionItem = actionItem
        menu.addItem(withTitle: "打开诊断日志…", action: #selector(openDiagnosticsLog), keyEquivalent: "")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        let versionItem = NSMenuItem(title: "版本 \(version) (\(build)) · 内置猫", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "猫下班了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        menu.items.forEach { $0.target = self }
        versionItem.target = nil
        quitItem.target = NSApp
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildPreviewMenu()
        currentActionItem?.title = "当前动作：\(petWindow?.currentActionStatus ?? "未加载")"
        packageVersionItem?.title = "素材版本：\(petWindow?.currentPackageVersion ?? "未加载")"
    }

    private func rebuildPreviewMenu() {
        guard let previewMenu else { return }
        previewMenu.removeAllItems()
        for id in petWindow?.availableAnimationIDs ?? [] {
            let action = NSMenuItem(title: id, action: #selector(previewAction(_:)), keyEquivalent: "")
            action.representedObject = id
            action.target = self
            previewMenu.addItem(action)
        }
    }

    @objc private func openDiagnosticsLog() {
        guard let url = petWindow?.diagnosticsLogURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func showPet() { petWindow?.showPet() }

    @objc private func setPetScale(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(scale, forKey: "petScale")
    }

    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showWelcome() {
        let view = WelcomeView { [weak self] in
            UserDefaults.standard.set(true, forKey: "completedWelcome")
            self?.welcomeWindow?.close()
            self?.welcomeWindow = nil
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "欢迎使用猫上班了"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func checkForUpdates() { updaterController?.checkForUpdates(nil) }

    private var updatesAreConfigured: Bool {
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https",
              let host = url.host, !host.hasSuffix(".invalid"), !host.contains("example."),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !key.isEmpty, !key.hasPrefix("REPLACE_") else { return false }
        return true
    }

    @objc private func previewAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        petWindow?.previewAnimation(id)
    }

    @objc private func importPet() {
        let panel = NSOpenPanel()
        panel.title = "导入宠物包"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, .zip, .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let installed = try PetStore().install(from: url)
            try petWindow?.loadPet(at: installed.rootURL)
            UserDefaults.standard.set(installed.manifest.id, forKey: "selectedPetID")
            if !installed.isHighFrame {
                let alert = NSAlert()
                alert.messageText = "已安装兼容宠物"
                alert.informativeText = "这个宠物包含少于 24 帧的动作，将按原始帧率播放，因此可能不如默认的“猫上班了”流畅。"
                alert.alertStyle = .informational
                alert.runModal()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "无法导入这个宠物包"
            alert.runModal()
        }
    }

    private func loadSelectedOrDefaultPet(into controller: PetWindowController) {
        let embeddedRoot = Bundle.module.resourceURL?.appendingPathComponent("DefaultPet.catpet", isDirectory: true)
        let embeddedManifest = embeddedRoot.flatMap { try? PetPackageImporter().inspectDirectory(at: $0).manifest }
        let selectedID = UserDefaults.standard.string(forKey: "selectedPetID")

        // The built-in IP ships with the app and must follow app updates. An old
        // Application Support copy with the same ID previously shadowed every
        // newly bundled frame set forever.
        if selectedID == nil || selectedID == embeddedManifest?.id {
            if let embeddedRoot, (try? controller.loadPet(at: embeddedRoot)) != nil {
                if let id = embeddedManifest?.id { UserDefaults.standard.set(id, forKey: "selectedPetID") }
                return
            }
        }

        if let selectedID,
           selectedID.wholeMatch(of: /^[a-z0-9][a-z0-9-]{1,63}$/) != nil,
           let support = try? FileManager.default.url(
               for: .applicationSupportDirectory,
               in: .userDomainMask,
               appropriateFor: nil,
               create: false
           ) {
            let installed = support
                .appendingPathComponent("猫上班了/Pets", isDirectory: true)
                .appendingPathComponent("\(selectedID).catpet", isDirectory: true)
            if (try? controller.loadPet(at: installed)) != nil { return }
            UserDefaults.standard.removeObject(forKey: "selectedPetID")
        }
        if let embeddedRoot {
            try? controller.loadPet(at: embeddedRoot)
        }
    }
}
