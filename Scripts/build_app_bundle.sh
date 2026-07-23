#!/bin/sh
set -eu

ACTIVE_DEVELOPER_DIR=${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}
if [ "$ACTIVE_DEVELOPER_DIR" = "/Library/Developer/CommandLineTools" ] || [ ! -x "$ACTIVE_DEVELOPER_DIR/usr/bin/xcodebuild" ]; then
  echo "完整 Xcode 尚未启用。请设置 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer，或运行 xcode-select 切换。" >&2
  exit 2
fi

APP_NAME=猫上班了
BUILD_ROOT=${BUILD_ROOT:-Build/Release}
BUNDLE_ID=${CATATWORK_BUNDLE_ID:-app.catatwork.mac}
SIGN_IDENTITY=${CATATWORK_SIGN_IDENTITY:--}
ENTITLEMENTS=Config/CatAtWork.entitlements
if [ "$SIGN_IDENTITY" = "-" ]; then
  ENTITLEMENTS=Config/CatAtWork-AdHoc.entitlements
fi
SPARKLE_FEED_URL=${SPARKLE_FEED_URL:-https://downloads.example.invalid/catatwork/appcast.xml}
SPARKLE_PUBLIC_ED_KEY=${SPARKLE_PUBLIC_ED_KEY:-REPLACE_BEFORE_RELEASE}
RELEASE_BUILD=${CATATWORK_RELEASE_BUILD:-0}

case "$BUILD_ROOT" in
  ""|"/"|"."|"$HOME"|"$HOME/")
    echo "拒绝使用过宽的 BUILD_ROOT：$BUILD_ROOT" >&2
    exit 4
    ;;
esac

if [ "$RELEASE_BUILD" = "1" ]; then
  if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "正式发布必须设置 CATATWORK_SIGN_IDENTITY=Developer ID Application: ..." >&2
    exit 5
  fi
  if [ "$BUNDLE_ID" = "app.catatwork.mac" ] || [ -z "$BUNDLE_ID" ]; then
    echo "正式发布必须设置一次性确定的 CATATWORK_BUNDLE_ID。" >&2
    exit 5
  fi
  case "$SPARKLE_FEED_URL" in
    https://*example*|https://*.invalid/*|http://*|"")
      echo "正式发布必须使用非占位的 HTTPS SPARKLE_FEED_URL。" >&2
      exit 5
      ;;
  esac
  case "$SPARKLE_PUBLIC_ED_KEY" in
    ""|REPLACE_*)
      echo "正式发布必须设置 SPARKLE_PUBLIC_ED_KEY。" >&2
      exit 5
      ;;
  esac
fi

swift build -c release --arch arm64 --arch x86_64
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
APP="$BUILD_ROOT/$APP_NAME.app"
CONTENTS="$APP/Contents"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"
cp "$BIN_DIR/CatAtWork" "$CONTENTS/MacOS/CatAtWork"
cp Config/Info.plist "$CONTENTS/Info.plist"
cp Sources/CatAtWork/Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

RESOURCE_BUNDLE=$(find "$BIN_DIR" -maxdepth 1 -type d -name '*CatAtWork*.bundle' -print -quit)
if [ -z "$RESOURCE_BUNDLE" ]; then
  echo "未找到 SwiftPM 资源 bundle" >&2
  exit 3
fi
cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"

if [ -d "$BIN_DIR/Sparkle.framework" ]; then
  cp -R "$BIN_DIR/Sparkle.framework" "$CONTENTS/Frameworks/"
fi

install_name_tool -add_rpath @executable_path/../Frameworks "$CONTENTS/MacOS/CatAtWork"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL $SPARKLE_FEED_URL" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_ED_KEY" "$CONTENTS/Info.plist"
if [ "$RELEASE_BUILD" != "1" ]; then
  /usr/libexec/PlistBuddy -c "Set :SUEnableAutomaticChecks false" "$CONTENTS/Info.plist"
fi

xattr -cr "$APP"
# File Provider can reattach FinderInfo to nested Sparkle nib/app bundles while
# copying. codesign rejects that metadata even for an ad-hoc development build.
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
xattr -dr 'com.apple.fileprovider.fpfs#P' "$APP" 2>/dev/null || true
# `xattr -r` treats some bundle packages as opaque. Walk every nested entry so
# FinderInfo on Sparkle's .nib/.app children cannot survive into signing.
find "$APP" -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true
find "$APP" -exec xattr -d com.apple.ResourceFork {} \; 2>/dev/null || true
find "$APP" -exec xattr -d 'com.apple.fileprovider.fpfs#P' {} \; 2>/dev/null || true
if [ -d "$CONTENTS/Frameworks/Sparkle.framework" ]; then
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" \
    "$CONTENTS/Frameworks/Sparkle.framework"
fi
codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
lipo "$CONTENTS/MacOS/CatAtWork" -verify_arch arm64 x86_64
echo "Built $APP"
