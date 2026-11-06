#!/bin/sh
set -eu

DEFAULT_APP_NAME="Doppio"
SRC_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP_DIR="${DOPPIO_APP_DIR:-$HOME/Applications}"

APP_NAME=$DEFAULT_APP_NAME
WITH_CLI=1
WITH_LOGIN=1
WITH_OPEN=1

usage() {
	cli=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
	cat <<EOF
usage: ./install.sh [options]

Builds $APP_NAME.app from source and installs it to ~/Applications.
By default it also installs the $cli CLI to ~/.local/bin/$cli and registers
$APP_NAME to open at login.

options:
  --name NAME      NAME.app plus a lowercase CLI (default: $DEFAULT_APP_NAME);
                   letters, digits, dashes only, must start with a letter
  --no-cli         do not symlink the CLI to ~/.local/bin/$cli
  --no-login-item  do not register $APP_NAME to open at login
  --no-open        do not launch the app after a successful install
  -h, --help       show this help

environment:
  DOPPIO_APP_DIR   install location (default: ~/Applications)
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--name)
		[ $# -ge 2 ] || {
			echo "install.sh: --name requires a value" >&2
			exit 2
		}
		APP_NAME=$2
		shift 2
		;;
	--name=*)
		APP_NAME=${1#--name=}
		shift
		;;
	--no-cli)
		WITH_CLI=0
		shift
		;;
	--no-login-item)
		WITH_LOGIN=0
		shift
		;;
	--no-open)
		WITH_OPEN=0
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "install.sh: unknown option '$1'" >&2
		usage >&2
		exit 2
		;;
	esac
done

case $APP_NAME in
*[!A-Za-z0-9-]* | "" | [0-9-]*)
	echo "install.sh: invalid name '$APP_NAME' (letters, digits, dashes; must start with a letter)" >&2
	exit 2
	;;
esac

CLI_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
APP_PATH="$APP_DIR/$APP_NAME.app"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

"$SRC_DIR/build.sh" --name "$APP_NAME" --out "$TMP"

mkdir -p "$APP_DIR"

# quit a running instance before replacing the bundle
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true

rm -rf "$APP_PATH"
ditto "$TMP/$APP_NAME.app" "$APP_PATH"
touch "$APP_PATH"
echo "==> installed $APP_PATH"

if [ "$WITH_CLI" -eq 1 ]; then
	mkdir -p "$HOME/.local/bin"
	ln -sf "$APP_PATH/Contents/Resources/$CLI_NAME" "$HOME/.local/bin/$CLI_NAME"
	echo "==> cli: ~/.local/bin/$CLI_NAME (make sure it is on your PATH)"
fi

if [ "$WITH_LOGIN" -eq 1 ]; then
	# delete an existing item if present and then add new
	osascript -e "tell application \"System Events\" to if (exists login item \"$APP_NAME\") then delete login item \"$APP_NAME\"" >/dev/null 2>&1 || true
	osascript -e "tell application \"System Events\" to make new login item at end of login items with properties {path:\"$APP_PATH\", name:\"$APP_NAME\", hidden:false}" >/dev/null
	echo "==> login item: $APP_NAME opens at login"
fi

echo
if [ "$WITH_OPEN" -eq 1 ]; then
	open "$APP_PATH"
	echo "done - $APP_NAME is now running in the menu bar."
else
	echo "done. start it with:  open \"$APP_PATH\""
fi
