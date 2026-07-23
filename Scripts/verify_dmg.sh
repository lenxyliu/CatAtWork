#!/bin/sh
set -eu

DMG=${1:-Build/Release/猫上班了.dmg}
[ -f "$DMG" ] || { echo "找不到 DMG：$DMG" >&2; exit 2; }
hdiutil verify "$DMG"

MOUNT=$(mktemp -d /private/tmp/catatwork-dmg-mount.XXXXXX)
cleanup() {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rmdir "$MOUNT" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$DMG" >/dev/null

APP="$MOUNT/猫上班了.app"
[ -d "$APP" ] || { echo "DMG 中缺少猫上班了.app" >&2; exit 3; }
[ -L "$MOUNT/Applications" ] || { echo "DMG 中缺少 Applications 快捷方式" >&2; exit 3; }
for DOC in INSTALLATION.md PRIVACY.md IP-LICENSE.md; do
  [ -f "$MOUNT/$DOC" ] || { echo "DMG 中缺少分发说明：$DOC" >&2; exit 3; }
done
codesign --verify --deep --strict --verbose=2 "$APP"
lipo "$APP/Contents/MacOS/CatAtWork" -verify_arch arm64 x86_64
echo "DMG mount verification passed: $DMG"
