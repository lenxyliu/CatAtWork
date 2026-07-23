#!/bin/sh
set -eu

APP=${1:-Build/Release/猫上班了.app}
DMG=${2:-Build/Release/猫上班了.dmg}
STAGING=$(mktemp -d /private/tmp/catatwork-dmg-staging.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT INT TERM
if [ ! -d "$APP" ] || [ ! -f "$APP/Contents/MacOS/CatAtWork" ]; then
  echo "找不到有效应用包：$APP" >&2
  exit 2
fi
mkdir -p "$(dirname "$DMG")"
mkdir -p "$STAGING"
codesign --verify --deep --strict --verbose=2 "$APP"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
for DOC in INSTALLATION.md PRIVACY.md IP-LICENSE.md; do
  if [ ! -f "$DOC" ]; then
    echo "缺少分发说明：$DOC" >&2
    exit 3
  fi
  cp "$DOC" "$STAGING/$DOC"
done
hdiutil create -volname 猫上班了 -srcfolder "$STAGING" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
echo "Built $DMG"
