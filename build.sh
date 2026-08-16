#!/bin/sh
# Builds "Influencer Ratio.app" into ./build and optionally installs it.
#   ./build.sh            build only
#   ./build.sh install    build, then replace /Applications/Influencer Ratio.app and launch it
#
# Set SIGN_ID to a Developer ID identity to avoid re-granting Accessibility on
# every rebuild; otherwise the bundle is ad-hoc signed.
set -eu

APP_NAME="Influencer Ratio"
BUNDLE_ID="com.pamp.influencer-ratio"
VERSION="1.0"
ROOT=$(cd "$(dirname "$0")" && pwd)
APP="$ROOT/build/$APP_NAME.app"

swift build -c release --package-path "$ROOT"
BIN=$(swift build -c release --package-path "$ROOT" --show-bin-path)/InfluencerRatio

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>$APP_NAME</string>
	<key>CFBundleDisplayName</key><string>$APP_NAME</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleExecutable</key><string>$APP_NAME</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSUIElement</key><true/>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign "${SIGN_ID:--}" --identifier "$BUNDLE_ID" "$APP"
echo "Built $APP"

if [ "${1:-}" = "install" ]; then
	osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
	pkill -f "/Applications/$APP_NAME.app" 2>/dev/null || true
	rm -rf "/Applications/$APP_NAME.app"
	cp -R "$APP" "/Applications/$APP_NAME.app"

	# An ad-hoc signature gets a new CDHash on every build, so the existing
	# Accessibility grant silently stops matching: the toggle still reads ON while
	# macOS treats this as a different app. Clear it so there is one honest prompt.
	if [ "${SIGN_ID:--}" = "-" ]; then
		tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
		echo "Cleared the old Accessibility grant (ad-hoc signature changed)."
		echo "Grant it once more when the app asks."
	fi

	open "/Applications/$APP_NAME.app"
	echo "Installed and launched /Applications/$APP_NAME.app"
fi
