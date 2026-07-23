import AppKit
import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            if let image = bundledCatImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .accessibilityLabel("猫上班了默认小猫")
            }
            Text("猫上班了")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("它会陪你工作、回应鼠标互动，也会在空闲时舔毛和睡觉。\n所有状态只在本机处理。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 18) {
                Label("24 帧动作", systemImage: "film.stack")
                Label("无账号与遥测", systemImage: "hand.raised")
                Label("可扩展宠物包", systemImage: "shippingbox")
            }
            .font(.callout)
            Button("开始一起上班") { onStart() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 580, height: 440)
    }

    private func bundledCatImage() -> NSImage? {
        let root = Bundle.module.resourceURL?.appendingPathComponent("DefaultPet.catpet", isDirectory: true)
        return root.flatMap { NSImage(contentsOf: $0.appendingPathComponent("thumbnail.png")) }
    }
}
