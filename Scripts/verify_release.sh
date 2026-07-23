#!/bin/sh
set -eu

APP=${1:-Build/Release/猫上班了.app}
DMG=${2:-}
INFO="$APP/Contents/Info.plist"
BIN="$APP/Contents/MacOS/CatAtWork"

[ -f "$INFO" ] && [ -f "$BIN" ] || { echo "无效应用包：$APP" >&2; exit 2; }
codesign --verify --deep --strict --verbose=2 "$APP"
lipo "$BIN" -verify_arch arm64 x86_64

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")
FEED=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$INFO")
KEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$INFO")
[ "$BUNDLE_ID" != "app.catatwork.mac" ] || { echo "仍在使用开发 Bundle ID" >&2; exit 3; }
case "$FEED" in https://*example*|https://*.invalid/*|http://*|"") echo "Sparkle feed 仍是占位值" >&2; exit 3;; esac
case "$KEY" in ""|REPLACE_*) echo "Sparkle 公钥仍是占位值" >&2; exit 3;; esac

if [ -n "$DMG" ]; then
  [ -f "$DMG" ] || { echo "找不到 DMG：$DMG" >&2; exit 2; }
  hdiutil verify "$DMG"
fi
echo "Release verification passed: $BUNDLE_ID"
