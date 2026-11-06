#!/bin/sh
# Remove the app, its CLI symlink, login item, and all state.
# Best effort only, every step is allowed to fail.
set -u

DEFAULT_APP_NAME="Doppio"
APP_DIR="${DOPPIO_APP_DIR:-$HOME/Applications}"

APP_NAME=$DEFAULT_APP_NAME

usage() {
	cat <<EOF
usage: ./uninstall.sh [options]

options:
  --name NAME   name used at install time (default: $DEFAULT_APP_NAME)
  -h, --help    show this help

environment:
  DOPPIO_APP_DIR   install location (default: ~/Applications)
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--name)
		[ $# -ge 2 ] || {
			echo "uninstall.sh: --name requires a value" >&2
			exit 2
		}
		APP_NAME=$2
		shift 2
		;;
	--name=*)
		APP_NAME=${1#--name=}
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "uninstall.sh: unknown option '$1'" >&2
		usage >&2
		exit 2
		;;
	esac
done

case $APP_NAME in
*[!A-Za-z0-9-]* | "" | [0-9-]*)
	echo "uninstall.sh: invalid name '$APP_NAME'" >&2
	exit 2
	;;
esac

CLI_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
APP_PATH="$APP_DIR/$APP_NAME.app"

osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
[ -x "$APP_PATH/Contents/Resources/$CLI_NAME" ] &&
	"$APP_PATH/Contents/Resources/$CLI_NAME" off >/dev/null 2>&1
rm -rf "$APP_PATH"

osascript -e "tell application \"System Events\" to delete login item \"$APP_NAME\"" >/dev/null 2>&1 || true

rm -rf "$HOME/Library/Application Support/$CLI_NAME"
[ -L "$HOME/.local/bin/$CLI_NAME" ] && rm -f "$HOME/.local/bin/$CLI_NAME"

echo "$CLI_NAME uninstalled"
