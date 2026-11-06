#!/bin/sh
# Compile the app into build/<NAME>.app
# End users want ./install.sh.
set -eu

DEFAULT_APP_NAME="Doppio"
SRC_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

APP_NAME=$DEFAULT_APP_NAME
OUT_DIR="$SRC_DIR/build"

usage() {
	cat <<EOF
usage: ./build.sh [options]

Compiles the applet into an app bundle (osacompile), embeds the CLI,
sets bundle metadata + icon, and ad-hoc signs the result.

options:
  --name NAME   app/CLI name (default: $DEFAULT_APP_NAME);
                letters, digits, dashes only, must start with a letter
  --out DIR     output directory (default: ./build)
  -h, --help    show this help
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--name)
		[ $# -ge 2 ] || {
			echo "build.sh: --name requires a value" >&2
			exit 2
		}
		APP_NAME=$2
		shift 2
		;;
	--name=*)
		APP_NAME=${1#--name=}
		shift
		;;
	--out)
		[ $# -ge 2 ] || {
			echo "build.sh: --out requires a value" >&2
			exit 2
		}
		OUT_DIR=$2
		shift 2
		;;
	--out=*)
		OUT_DIR=${1#--out=}
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "build.sh: unknown option '$1'" >&2
		usage >&2
		exit 2
		;;
	esac
done

# the name becomes a bundle dir, CLI file, bundle id, and login item name
case $APP_NAME in
*[!A-Za-z0-9-]* | "" | [0-9-]*)
	echo "build.sh: invalid name '$APP_NAME' (letters, digits, dashes; must start with a letter)" >&2
	exit 2
	;;
esac

CLI_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
BUNDLE_ID="com.$CLI_NAME.app"
OUT_APP="$OUT_DIR/$APP_NAME.app"

plist_set() { # plist_set <plist> <key> <type> <value>
	if /usr/libexec/PlistBuddy -c "Print :$2" "$1" >/dev/null 2>&1; then
		/usr/libexec/PlistBuddy -c "Set :$2 $4" "$1" >/dev/null
	else
		/usr/libexec/PlistBuddy -c "Add :$2 $3 $4" "$1" >/dev/null
	fi
}

echo "==> building $APP_NAME.app"
mkdir -p "$OUT_DIR"
rm -rf "$OUT_APP"
osacompile -s -o "$OUT_APP" "$SRC_DIR/src/applet.applescript"

cp "$SRC_DIR/src/cli" "$OUT_APP/Contents/Resources/$CLI_NAME"
chmod 755 "$OUT_APP/Contents/Resources/$CLI_NAME"

# icon: CFBundleIconName takes precedence over CFBundleIconFile, so it
# must be deleted; also replace the referenced applet.icns as a fallback
cp "$SRC_DIR/resources/icon.icns" "$OUT_APP/Contents/Resources/icon.icns"
cp "$SRC_DIR/resources/icon.icns" "$OUT_APP/Contents/Resources/applet.icns"

PLIST="$OUT_APP/Contents/Info.plist"
plist_set "$PLIST" "CFBundleIdentifier" string "$BUNDLE_ID"
plist_set "$PLIST" "CFBundleIconFile" string "icon"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" >/dev/null 2>&1 || true
plist_set "$PLIST" "LSUIElement" bool true

# make LaunchServices/Finder drop any cached icon
touch "$OUT_APP"

# osacompile's signature is invalidated by our edits above
if command -v codesign >/dev/null 2>&1; then
	codesign --force --sign - "$OUT_APP" >/dev/null 2>&1 || true
fi

echo "==> built $OUT_APP"
