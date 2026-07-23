#!/bin/sh
set -eu

APP=${1:-Build/Release/猫上班了.app}
DMG=${2:-Build/Release/猫上班了.dmg}
PROFILE=${NOTARY_KEYCHAIN_PROFILE:-}
[ -n "$PROFILE" ] || { echo "请设置 NOTARY_KEYCHAIN_PROFILE。" >&2; exit 2; }
[ -d "$APP" ] || { echo "找不到应用包：$APP" >&2; exit 2; }

SIGNATURE=$(codesign -dv --verbose=4 "$APP" 2>&1 || true)
echo "$SIGNATURE" | grep -q 'Authority=Developer ID Application:' || {
  echo "应用不是 Developer ID Application 签名，拒绝公证。" >&2
  exit 3
}

WORK=$(mktemp -d /private/tmp/catatwork-notary.XXXXXX)
trap 'rm -rf "$WORK"' EXIT INT TERM
ZIP="$WORK/猫上班了-notary.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

sh "$(dirname "$0")/build_dmg.sh" "$APP" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=4 "$APP"
hdiutil verify "$DMG"
sh "$(dirname "$0")/verify_dmg.sh" "$DMG"
echo "Notarized and stapled: $DMG"
