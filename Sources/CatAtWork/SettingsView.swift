import SwiftUI
import AppKit
import ApplicationServices
import ServiceManagement

struct SettingsView: View {
    @AppStorage("chasePointer") private var chasePointer = true
    @AppStorage("throwEnabled") private var throwEnabled = true
    @AppStorage("systemAwareness") private var systemAwareness = true
    @AppStorage("mediaAwareness") private var mediaAwareness = false
    @AppStorage("petScale") private var petScale = 0.45
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var inputMonitoringGranted = CGPreflightListenEventAccess()

    var body: some View {
        Form {
            Section("猫上班了") {
                if let image = bundledThumbnail() {
                    HStack {
                        Spacer()
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 92)
                            .accessibilityLabel("猫上班了默认小猫")
                        Spacer()
                    }
                }
                HStack {
                    Slider(value: $petScale, in: 0.3...1.0) { Text("宠物大小") }
                    Text("\(Int((petScale * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                Toggle("偶尔靠近鼠标玩耍", isOn: $chasePointer)
                Toggle("允许抱起和抛掷", isOn: $throwEnabled)
            }
            Section("本地系统感知") {
                Toggle("根据应用和窗口类型回应", isOn: $systemAwareness)
                    .onChange(of: systemAwareness) { _, _ in
                        NotificationCenter.default.post(name: .catAtWorkAwarenessSettingsChanged, object: nil)
                    }
                Toggle("读取音乐播放/暂停状态", isOn: $mediaAwareness)
                    .onChange(of: mediaAwareness) { _, _ in
                        NotificationCenter.default.post(name: .catAtWorkAwarenessSettingsChanged, object: nil)
                    }
                Text("窗口标题仅在内存中分类，不写入磁盘，也不会上传。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("音乐感知开启后，macOS 只会在需要时分别询问 Music/Spotify 自动化权限；拒绝后基础宠物仍可运行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("权限与启动") {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        if enabled { try? SMAppService.mainApp.register() }
                        else { try? SMAppService.mainApp.unregister() }
                    }
                Button(accessibilityGranted ? "辅助功能：已允许" : "请求辅助功能权限") {
                    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                    accessibilityGranted = AXIsProcessTrustedWithOptions(options)
                    openPrivacyPane("Privacy_Accessibility")
                }
                Button(inputMonitoringGranted ? "输入监控：已允许" : "请求输入监控权限") {
                    inputMonitoringGranted = CGRequestListenEventAccess()
                    openPrivacyPane("Privacy_ListenEvent")
                }
                Button("打开自动化权限设置") {
                    openPrivacyPane("Privacy_Automation")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 510)
        .padding()
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            inputMonitoringGranted = CGPreflightListenEventAccess()
        }
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func bundledThumbnail() -> NSImage? {
        Bundle.module.resourceURL
            .map { $0.appendingPathComponent("DefaultPet.catpet/thumbnail.png") }
            .flatMap(NSImage.init(contentsOf:))
    }
}

extension Notification.Name {
    static let catAtWorkAwarenessSettingsChanged = Notification.Name("CatAtWorkAwarenessSettingsChanged")
}
