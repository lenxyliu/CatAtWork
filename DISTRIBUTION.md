# 发布清单

1. 安装完整 Xcode，设置正式 Team、Bundle ID 与 `MACOSX_DEPLOYMENT_TARGET=14.0`。
2. 使用 Universal 2 Release 配置构建并启用 Hardened Runtime。
3. 使用 Developer ID Application 签名，执行 `codesign --verify --deep --strict`。
4. 用 `notarytool` 上传、公证并 staple。
5. 制作 DMG，在无开发证书的干净 Mac 上验证安装。
6. 集成 Sparkle 2 后，在 Keychain 中生成 EdDSA 私钥，将公钥和 HTTPS appcast URL 写入发布配置。
7. 更新包同时进行 Developer ID 签名、公证与 Sparkle EdDSA 签名。

## 构建脚本

安装并切换到完整 Xcode 后：

```sh
CATATWORK_BUNDLE_ID=你的正式BundleID \
CATATWORK_SIGN_IDENTITY='Developer ID Application: 你的名称 (TEAMID)' \
CATATWORK_RELEASE_BUILD=1 \
SPARKLE_FEED_URL='https://你的域名/appcast.xml' \
SPARKLE_PUBLIC_ED_KEY='你的Sparkle公钥' \
sh Scripts/build_app_bundle.sh

sh Scripts/build_dmg.sh
```

若项目位于 iCloud Drive 或其他文件提供器目录，建议在非同步临时目录完成签名，
避免 Finder 扩展属性污染应用包：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
BUILD_ROOT=/private/tmp/catatwork-release \
sh Scripts/build_app_bundle.sh

sh Scripts/build_dmg.sh \
  /private/tmp/catatwork-release/猫上班了.app \
  Build/Release/猫上班了.dmg
```

未设置 `CATATWORK_SIGN_IDENTITY` 时，脚本生成仅供本机测试的 ad-hoc 签名包，
并使用专用 entitlement 允许加载同为 ad-hoc 签名的 Sparkle。正式 Developer ID
构建不会启用该测试 entitlement。

随后用 `xcrun notarytool submit ... --wait` 公证 DMG，并执行
`xcrun stapler staple Build/Release/猫上班了.dmg`。脚本不会读取或保存证书密码、
公证凭据和 Sparkle 私钥。

证书、公证凭据和 Sparkle 私钥不得提交到仓库。

面向用户的 DMG 安装、权限说明与卸载路径见 `INSTALLATION.md`；隐私处理见
`PRIVACY.md`，默认角色的分发边界见 `IP-LICENSE.md`。
