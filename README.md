# 猫上班了 / CatAtWork

原生 macOS 桌面宠物。首版内置同名长毛猫 IP，支持高帧动画、透明多空间窗口、拖拽抛掷、鼠标互动、系统状态回应和可扩展 `.catpet` 宠物包。

## 当前要求

- macOS 14+
- Xcode（包含 macOS SDK；仅 Command Line Tools 不足以构建 AppKit/Metal 应用）
- Swift 6

## 开发构建

```sh
swift test
swift run CatAtWork
```

在只有 Command Line Tools、SwiftPM 本身不可用的机器上，仍可运行语法、Swift 6 类型检查和核心冒烟测试：

```sh
sh Scripts/typecheck_without_xcode.sh
```

生成可导入的压缩 `.catpet`：

```sh
sh Scripts/package_catpet.sh
```

本机若出现 `llbuild` 动态库符号不匹配，需要在安装完整 Xcode 后执行：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

没有管理员权限切换全局开发者目录时，可为单条命令显式指定：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

应用会把不含按键、窗口标题和精确鼠标轨迹的本机诊断写到
`~/Library/Logs/猫上班了/interaction.jsonl`。复现问题后可运行：

```sh
python3 Scripts/summarize_interaction_log.py
```

汇总会列出动作触发来源与协调器决定，并自动检查重复落地、无自主/
微动作、动作停滞、非移动姿势滑行和鼠标触发风暴。

## 隐私

应用不包含账号、遥测或云同步。窗口标题仅在当前进程内存中归类为工作、浏览、会议、影音或游戏，并立即丢弃原始字符串。

## 素材尺寸规则

动画帧使用可变画布和统一 `pixelsPerBodyUnit`，打包为按动作划分的可变矩形纹理图集。运行时通过 `textureRect`、`sourceSize`、`trimRect` 与 `pivot` 恢复真实尺寸，并按 `220 / pixelsPerBodyUnit` 归一化不同素材密度；禁止逐动作执行 fit-to-cell，因此奔跑不会因为身体更宽而被缩小。

## 目录

- `Sources/CatAtWorkCore`：包格式、校验、行为状态机、物理和隐私分类。
- `Sources/CatAtWork`：AppKit/SwiftUI/Metal 应用。
- `Assets/CatAtWork`：默认 IP 的生成来源、动作帧和 QA。
- `Schemas/catpet-manifest.schema.json`：宠物包公开格式。
- `Scripts`：资产校验与打包工具。

导入器同时接受目录式或 ZIP 式 `.catpet`，并能把 Codex v2 的 8×11 图集按原始 8 帧作为“兼容宠物”导入；不会伪造高帧素材。

签名、公证、Sparkle feed 和正式 Bundle ID 必须在发布者拥有 Apple Developer 账号后配置。

安装、权限降级与完整卸载步骤见 [INSTALLATION.md](INSTALLATION.md)。
