#!/usr/bin/env bash
#
# Builds Termina for release and packages it into an installer disk image.
#
#   ./Scripts/package.sh
#
# Produces dist/Termina.app and dist/Termina-<version>.dmg — the latter with a
# custom window: backdrop, placed icons, hidden toolbar, and the app's own
# artwork as the volume icon.
#
# The app is ad-hoc signed, which is enough to run on the machine that built
# it. To hand it to someone else, set DEVELOPER_ID to a "Developer ID
# Application: ..." identity from `security find-identity -v -p codesigning`
# and the script will sign with it; the notarisation commands are printed at
# the end, since only a signed build can be notarised.
#
# Styling the window drives Finder through AppleScript, so the first run may
# ask for permission to control Finder. Declining only costs the styling — the
# disk image is still produced.

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR=".build"
DIST_DIR="dist"
SCHEME="Termina"

# Must match the slots drawn in Scripts/make-dmg-background.swift.
WINDOW_WIDTH=640
WINDOW_HEIGHT=400
APP_SLOT_X=170
APP_SLOT_Y=200
APPLICATIONS_SLOT_X=470
APPLICATIONS_SLOT_Y=200
ICON_SIZE=128

command -v xcodegen >/dev/null || { echo "xcodegen is not installed (brew install xcodegen)"; exit 1; }

echo "==> Generating project"
xcodegen generate >/dev/null

echo "==> Building Release"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"
xcodebuild \
    -project Termina.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -skipPackagePluginValidation \
    build \
    | grep -E "error:|^\*\* BUILD" || true

APP="$BUILD_DIR/Build/Products/Release/Termina.app"
[ -d "$APP" ] || { echo "build produced no app at $APP"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
# No version in the volume name: the dots make AppleScript unable to resolve
# paths on the disk, which is what the window styling works through.
VOLUME_NAME="Termina"
DMG="$DIST_DIR/Termina-$VERSION.dmg"

if [ -n "${DEVELOPER_ID:-}" ]; then
    echo "==> Signing with $DEVELOPER_ID"
    # Hardened runtime is required for notarisation; it stays off for local
    # builds because an unsigned app cannot use it.
    codesign --force --deep --options runtime --timestamp \
        --sign "$DEVELOPER_ID" "$APP"
fi

codesign --verify --deep --strict "$APP" && echo "==> Signature OK"
cp -R "$APP" "$DIST_DIR/"

# ---------------------------------------------------------------- staging ---

echo "==> Staging disk image contents"
STAGE=$(mktemp -d)
SCRATCH=$(mktemp -d)
trap 'rm -rf "$STAGE" "$SCRATCH"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Backdrop. Finder does not scale it, so both resolutions go into one TIFF.
if [ ! -f Design/dmg-background.png ] || [ ! -f Design/dmg-background@2x.png ]; then
    swift Scripts/make-dmg-background.swift
fi
mkdir -p "$STAGE/.background"
tiffutil -cathidpicheck \
    Design/dmg-background.png \
    Design/dmg-background@2x.png \
    -out "$STAGE/.background/background.tiff" >/dev/null

# The mounted volume shows the app's own icon rather than a blank disk.
ICONSET="$SCRATCH/Termina.iconset"
mkdir -p "$ICONSET"
cp Sources/Assets.xcassets/AppIcon.appiconset/icon_*.png "$ICONSET/"
iconutil -c icns "$ICONSET" -o "$STAGE/.VolumeIcon.icns"

# ------------------------------------------------------------------- image ---

echo "==> Building $DMG"
STAGE_MB=$(du -sm "$STAGE" | cut -f1)
RW_DMG="$SCRATCH/rw.dmg"
hdiutil create \
    -srcfolder "$STAGE" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size $((STAGE_MB + 40))m \
    -ov "$RW_DMG" >/dev/null

MOUNT_POINT="/Volumes/$VOLUME_NAME"
hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen >/dev/null
trap 'hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true; rm -rf "$STAGE" "$SCRATCH"' EXIT
# The volume is not writable the instant attach returns.
sleep 2

# Marks the volume as having a custom icon; without this .VolumeIcon.icns is
# just a hidden file.
if command -v SetFile >/dev/null; then
    SetFile -a C "$MOUNT_POINT" || true
fi

echo "==> Styling the window"
osascript <<EOF || echo "    (Finder declined; shipping the image unstyled)"
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set sidebar width of container window to 0
        -- Finder's bounds include the title bar, hence the extra height.
        set the bounds of container window to {200, 140, $((200 + WINDOW_WIDTH)), $((140 + WINDOW_HEIGHT + 22))}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $ICON_SIZE
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "Termina.app" of container window to {$APP_SLOT_X, $APP_SLOT_Y}
        set position of item "Applications" of container window to {$APPLICATIONS_SLOT_X, $APPLICATIONS_SLOT_Y}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || hdiutil detach "$MOUNT_POINT" -force >/dev/null
# Converting while the volume is still going away fails with "Resource
# temporarily unavailable", so wait for it to disappear.
for _ in $(seq 1 40); do
    [ -d "$MOUNT_POINT" ] || break
    sleep 0.5
done
trap 'rm -rf "$STAGE" "$SCRATCH"' EXIT

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

echo
echo "Done."
echo "  App: $DIST_DIR/Termina.app   (drag into /Applications)"
echo "  DMG: $DMG"

if [ -n "${DEVELOPER_ID:-}" ]; then
    cat <<EOF

To notarise before sharing:
  xcrun notarytool submit "$DMG" --keychain-profile "AC_PASSWORD" --wait
  xcrun stapler staple "$DMG"

(One-time setup for the profile:
  xcrun notarytool store-credentials "AC_PASSWORD" \\
      --apple-id "<your Apple ID>" --team-id "<team id>" --password "<app-specific password>")
EOF
else
    cat <<'EOF'

This build is ad-hoc signed: it runs on this Mac, but another Mac will refuse
it with "damaged or incomplete". Set DEVELOPER_ID and re-run to sign properly.
EOF
fi
