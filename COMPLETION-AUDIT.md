# 「猫上班了」首版完成度审计

更新日期：2026-07-23。只有能指向当前源码、构建产物或实际测试输出的项目才标记为已证明。

| 要求 | 当前证据 | 结论 |
| --- | --- | --- |
| 首版只有一只融合后的默认猫，应用与角色同名“猫上班了” | `Config/Info.plist`、内置 `DefaultPet.catpet` 的 `id=cat-at-work/displayName=猫上班了`；设置和欢迎页使用内置缩略图 | 已证明 |
| 下载应用即带默认 IP，旧两猫不作为切换项 | SwiftPM 资源直接复制 `DefaultPet.catpet`；启动时同 ID 永远选内置包；导入器拒绝保留 ID 覆盖 | 已证明 |
| 每个正式动作至少 24 个有效帧 | 内置包 31 个动作全部 24 帧、每动作 24 个不同文件；严格构建器只读取连续 `000...023`；高帧验证报告 0 错误；构建 8 的真实日志连续出现 `idleEar`、`idleTail` | 已证明 |
| 关键动作使用 imagegen 生成，不以复制/仿射伪造补帧 | `Assets/CatAtWork/generated` 保存三段 8 姿势母图；`jump/thrown/startled/landing` 与四个姿势过渡均有 imagegen 联系表与 24 张正式帧 | 已证明 |
| 16 个注视方向与独立眼神层 | manifest 含固定 0–337.5° 的 16 个方向；`LookDirectionPolicy` 和 Metal 眼睛位移不抢占身体动作 | 结构和测试已证明；桌面观感待实机 |
| 动作统一世界比例，不按格子缩放，宽/高动作不裁切 | `pixelsPerBodyUnit=220`、全部 `bodyScale=1.0`、可变 `sourceSize/trimRect/textureRect/pivot/renderOffset`；安全画布 665×761；脚底锚点测试通过 | 自动 QA 已证明；桌面边缘观感待实机 |
| Swift 6、AppKit + SwiftUI + MetalKit、macOS 14+ | Package 平台 macOS 14；透明 AppKit panel、SwiftUI 设置/欢迎、Metal sRGB 渲染；30 Hz 行为与最高 120 Hz 显示物理分离；Xcode 26.6 编译成功 | 已证明 |
| Apple Silicon 与 Intel Universal 2 | 构建 6 `lipo` 同时验证 `arm64 x86_64` | 二进制已证明；Intel 实机运行未证明 |
| 单猫透明窗口、多 Space、多显示器/分辨率恢复 | `canJoinAllSpaces/fullScreenAuxiliary`、屏幕参数观察和可见范围恢复已实现；构建 8 解锁运行时进程表只有 `/private/tmp/catatwork-release-8/猫上班了.app/.../CatAtWork` 一个实例 | 单实例运行已证明；插拔显示器/切 Space 实机待验证 |
| 悬停注视、单击、无按钮区域抚摸、驱散、偶尔靠近鼠标 | 指针意图识别器区分 pass/hover/pet/shoo；方向锁定；全局与无权限局部路径均存在；构建 8 真实日志出现点击、悬停和 `cat-visits-pointer` 串行动作 | 基础路径已实测；四区域往返抚摸和驱散仍待完整桌面复核 |
| 背、肚、耳、下巴各自动作和左右方向 | `backPet/bellyPet/earPet/chinPet` 均 24 帧；区域事件和水平翻转已接入 | 代码/素材已证明；触发区域观感待实机 |
| 抱起逐渐拉长、抛掷、真实撞地后单次落地 | pickup 的 1–16 帧为拉长引导、17–24 循环；高处轻放不提前落地；物理只发一次撞地；landing 解除抱起所有权 | 单元测试与预览已证明；完整鼠标链待实机 |
| 串行主行为链、少数强制中断、姿势过渡 | `ActionCoordinator`、姿势路由和 `sitToStand/standToSit/lieDown/getUp` 24 帧素材；同级排队且不重置 | 36 项测试覆盖；桌面转场待实机 |
| 无输入仍自主活动、2–5 秒微动作、15–35 秒漫游、逐渐睡觉 | 独立 30 Hz 时钟；确定性测试通过；构建 8 实际运行超过 15 分钟且有连续 66 秒无指针事件，期间出现微动作、起身、左右自由行走、坐下、趴低、睡眠和自动醒来，最长合法睡眠停留 45 秒 | 已证明 |
| 工作、会议、音乐、闲置影响行为但不频繁打断 | 前台分类、键鼠活跃、Music/Spotify 播放状态进入 `AutonomyContext`；确定性测试验证不同行为集合 | 逻辑已证明；系统权限实机待验证 |
| 电量、充电、时间、音量、网络、睡眠/唤醒、锁屏、Space | `SystemAwareness` 的观察器/轮询/NWPathMonitor 已接入；构建 7 锁屏启动日志实际记录充电、电量、时段、音量、工作区、网络及 `lock-changed=true`，并立即 `idle→sleep` | 初始状态与锁屏已实测；其他状态切换待验证 |
| 权限分别请求，拒绝后基础宠物仍运行 | 设置分别提供 Accessibility/Input Monitoring/Automation；无 Input Monitoring 时使用局部鼠标事件；核心时钟不依赖权限 | 代码路径已证明；允许/拒绝/运行中撤销待实机 |
| `.catpet` 导入、安全校验、旧 Codex v2 兼容 | schema、目录/ZIP 导入、路径穿越/符号链接/执行位/大小/alpha/尺寸/重复 ID 校验；8×11 v2 保留原 8 帧 | 单元测试与 ZIP 冒烟测试已证明 |
| Sparkle 2、签名更新与失败回滚配置 | Sparkle 2.9 依赖、检查更新菜单、正式构建强制 HTTPS feed/EdDSA 公钥；开发包禁用自动检查 | 配置已证明；真实 appcast 更新/回滚未验证 |
| 无账号、遥测、云同步，隐私只保存在本机 | `PRIVACY.md`；代码无网络上传，仅 NWPath 状态；JSONL 日志 2 MB 轮换且不含按键/标题/精确坐标 | 已证明 |
| 可共享 DMG 和用户说明 | 构建 6 DMG 已通过系统校验、只读挂载、签名、双架构及三份说明存在性检查 | 测试分发包已证明 |
| Developer ID、Hardened Runtime、公证、Staple | 正式构建与公证脚本会拒绝占位配置；当前测试包为 ad-hoc Hardened Runtime | 需要发布者的正式 Bundle ID、Developer ID、Notary 与 Sparkle 密钥，尚未完成 |
| macOS 14、15、26，Apple Silicon/Intel 与干净 Mac 验收 | 当前仅在 macOS 26.5.2、Apple M4 Pro 上完成编译/自动测试；构建 6 GUI 因机器锁屏无法运行 | 未完成 |

## 当前可交付测试件

- `Build/Release/猫上班了-1.0.3-构建8-抛掷动画回退版.dmg`
- 版本 1.0.3（构建 8），素材版本 `2026.07.23.6`
- Universal 2，ad-hoc Hardened Runtime；不代表已完成 Apple 公证的正式发行版

## 完成首版仍必须取得的证据

1. 继续完成各区域往返抚摸、驱散、抱起、抛掷和单次落地的完整真实鼠标链；60 秒无输入、自主漫游、微动作、睡眠及右键菜单已实测。
2. 分别在允许、拒绝和运行中撤销辅助功能/输入监控时执行基础互动测试；自动化权限单独验证 Music/Spotify。
3. 在 macOS 14、15、26 和至少一台 Intel Mac 上运行；插拔显示器、切 Space、睡眠唤醒和变更分辨率。
4. 发布者确定 Bundle ID、Developer ID 与 Sparkle/公证凭据后生成正式包，验证 appcast 更新/回滚，并在干净 Mac 上安装卸载。
