# doppio

caffeinate-based amphetamine replacement

## Motivation

Some corporate IT policies block the popular amphetamine application. This project serves as a `caffeinate`-based replacement, striving to be generally available for most macOS IT environments.

`doppio` is built locally using only tools that ship with macOS (`caffeinate`, `osascript`, `osacompile`), making the result a generic AppleScript applet that any user could write themselves on a base macOS installation.

## Features

- Menu bar app with one-click sessions: indefinitely, or 15m / 30m / 1h / 2h / 4h
- Control-click the menu bar icon to instantly toggle a session (indefinite by default; override with `doppio quickstart 30m`)
- Live countdown: `H:MM` next to the icon (`∞` for indefinite sessions), ticking every second in the open menu as `Hh Mm Ss remaining`
- Launches at login (registered by default; also toggleable from the menu)
- `doppio` CLI (`on` / `off` / `toggle` / `status`) for scripting, Shortcuts, and hotkeys

## Install

```sh
curl https://raw.githubusercontent.com/andelink/doppio/main/install.sh | bash
```

This downloads the source, builds `Doppio.app`, installs it to `~/Applications`, symlinks the `doppio` CLI to `~/.local/bin`, registers Doppio to open at login, and launches it. Cloning the repo and running `./install.sh` directly works too.

Pass options through with `bash -s --`:

```sh
curl https://raw.githubusercontent.com/andelink/doppio/main/install.sh | bash -s -- --name Caffeine
```

`install.sh` options:

| flag | effect |
|---|---|
| *(none)* | build `Doppio.app`, install to `~/Applications`, symlink the CLI to `~/.local/bin/doppio`, register Doppio to open at login, and launch it |
| `--name NAME` | install as `NAME.app` with a lowercase `name` CLI instead (e.g. `--name Espresso` → `Espresso.app` + `espresso`); letters, digits, dashes only |
| `--no-cli` | skip the CLI symlink |
| `--no-login-item` | skip the login item registration |
| `--no-open` | do not launch the app after install |


## Usage

Click the cup in the menu bar → **Start Session** → pick a duration. **Stop Session** ends it early. Control-click the cup to instantly start/stop an indefinite session. Quitting the app also stops the session, so no `caffeinate` process is ever orphaned. While a timed session runs, the remaining time shows next to the cup as `H:MM`, and the open menu shows the exact `Hh Mm Ss remaining`, updated every second.

CLI (symlinked to `~/.local/bin/doppio` by default; also embedded in the app at `~/Applications/Doppio.app/Contents/Resources/doppio`):

```sh
doppio on        # indefinite
doppio on 45m    # timed
doppio status    # "on 1234" (seconds left) | "on indefinite" | "off"
doppio toggle
doppio off
doppio open      # open the menu bar app
doppio close     # gracefully quit the app (stops the session)
doppio quickstart       # show the control-click duration
doppio quickstart 30m   # control-click starts a 30m session
doppio quickstart indefinite  # reset to an indefinite session
```

Default assertions are `caffeinate -d -i` (display + system stay awake). Override with `DOPPIO_FLAGS`, e.g. `DOPPIO_FLAGS="-i" doppio on`.

### Global hotkey (native, no extra software)

1. Open **Shortcuts** → new shortcut → **Run Shell Script** action → `~/Applications/Doppio.app/Contents/Resources/doppio toggle`
2. In the shortcut's details, click **Add Keyboard Shortcut**.

(An Automator **Quick Action** bound in System Settings → Keyboard → Keyboard Shortcuts → Services works too.)

## Uninstall

```sh
./uninstall.sh                      # or: ./uninstall.sh --name Caffeine
```

## Development

```sh
./build.sh            # compile only, into ./build (iterating on the source)
./install.sh          # temp-build + install (what end users run)
./test/doppio_test.sh # run the core tests
# or: make build / make install / make test / make clean
```

To rename the built/installed application, pass the `--name NAME` flag e.g. `./install.sh --name Latte`.
Uninstall with the matching `./uninstall.sh --name Latte`.

## License

MIT - see [LICENSE](LICENSE).
