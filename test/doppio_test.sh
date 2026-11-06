#!/bin/sh
# doppio_test.sh - dependency-free tests for the doppio core.
# Stubs `caffeinate` via PATH so no real power assertions are created.
set -u

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DOPPIO="$HERE/../src/cli"

TMP=$(mktemp -d)
trap '"$DOPPIO" off >/dev/null 2>&1; rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/state"
cat >"$TMP/bin/caffeinate" <<'EOF'
#!/bin/sh
# stub caffeinate: honor `-t <secs>`, otherwise "run" for a day
T=86400
while [ $# -gt 0 ]; do
	case "$1" in
		-t) T=$2; shift 2 ;;
		*)  shift ;;
	esac
done
exec sleep "$T"
EOF
chmod +x "$TMP/bin/caffeinate"

export PATH="$TMP/bin:$PATH"
export DOPPIO_STATE_DIR="$TMP/state"

PASS=0
FAIL=0
ok() {
	PASS=$((PASS + 1))
	printf 'ok   - %s\n' "$1"
}
not_ok() {
	FAIL=$((FAIL + 1))
	printf 'FAIL - %s (expected [%s], got [%s])\n' "$1" "$2" "$3"
}
check() { # check <name> <expected> <actual>
	if [ "$2" = "$3" ]; then ok "$1"; else not_ok "$1" "$2" "$3"; fi
}

# --- initial state -----------------------------------------------------------
out=$("$DOPPIO" status 2>/dev/null)
rc=$?
check "status when off" "off" "$out"
check "status when off (rc=1)" "1" "$rc"

# --- indefinite session ------------------------------------------------------
out=$("$DOPPIO" on)
check "on (indefinite)" "on indefinite" "$out"

out=$("$DOPPIO" status)
rc=$?
check "status when on" "on indefinite" "$out"
check "status when on (rc=0)" "0" "$rc"

pid=$(cat "$DOPPIO_STATE_DIR/pid")
if kill -0 "$pid" 2>/dev/null; then ok "caffeinate running"; else not_ok "caffeinate running" "alive" "dead"; fi

out=$("$DOPPIO" off)
check "off" "off" "$out"
if kill -0 "$pid" 2>/dev/null; then not_ok "caffeinate stopped" "dead" "alive"; else ok "caffeinate stopped"; fi

# --- toggle ------------------------------------------------------------------
out=$("$DOPPIO" toggle)
check "toggle on" "on indefinite" "$out"
out=$("$DOPPIO" toggle)
check "toggle off" "off" "$out"

# --- timed session -----------------------------------------------------------
out=$("$DOPPIO" on 1s)
case $out in
"on 1" | "on 0") ok "on 1s starts" ;;
*) not_ok "on 1s starts" "on 1" "$out" ;;
esac
sleep 2
out=$("$DOPPIO" status 2>/dev/null)
rc=$?
check "timed session expires" "off" "$out"
check "expired status (rc=1)" "1" "$rc"

# --- replace running session -------------------------------------------------
"$DOPPIO" on 2m >/dev/null
out=$("$DOPPIO" on)
check "on replaces session" "on indefinite" "$out"
"$DOPPIO" off >/dev/null

# --- duration parsing --------------------------------------------------------
"$DOPPIO" on 90 >/dev/null 2>&1
dur=$(cat "$DOPPIO_STATE_DIR/duration")
check "bare number = minutes" "5400" "$dur"
"$DOPPIO" off >/dev/null

"$DOPPIO" on 2h >/dev/null 2>&1
dur=$(cat "$DOPPIO_STATE_DIR/duration")
check "hours suffix" "7200" "$dur"
"$DOPPIO" off >/dev/null

"$DOPPIO" on bogus >/dev/null 2>&1
rc=$?
check "invalid duration (rc=2)" "2" "$rc"
out=$("$DOPPIO" status 2>/dev/null)
check "invalid duration = no session" "off" "$out"

# --- unknown command ---------------------------------------------------------
"$DOPPIO" frobnicate >/dev/null 2>&1
rc=$?
check "unknown command (rc=2)" "2" "$rc"

# --- open/close outside a bundle ------------------------------------------------
"$DOPPIO" open >/dev/null 2>&1
rc=$?
check "open unbundled (rc=1)" "1" "$rc"
"$DOPPIO" close >/dev/null 2>&1
rc=$?
check "close unbundled (rc=1)" "1" "$rc"

# --- quickstart (defaults domain com.cli.app, isolated HOME) --------------------
export HOME="$TMP/home"
mkdir -p "$HOME"

out=$("$DOPPIO" quickstart)
check "quickstart default" "indefinite" "$out"

out=$("$DOPPIO" quickstart 30m)
check "quickstart set" "quickStart: 30m" "$out"
out=$("$DOPPIO" quickstart)
check "quickstart read back" "30m" "$out"
out=$(defaults read com.cli.app quickStart)
check "quickstart plist" "30m" "$out"

"$DOPPIO" quickstart bogus >/dev/null 2>&1
rc=$?
check "quickstart bogus (rc=2)" "2" "$rc"
"$DOPPIO" quickstart 0 >/dev/null 2>&1
rc=$?
check "quickstart zero (rc=2)" "2" "$rc"

out=$("$DOPPIO" quickstart indefinite)
check "quickstart reset" "quickStart: indefinite" "$out"
out=$("$DOPPIO" quickstart)
check "quickstart after reset" "indefinite" "$out"

# --- summary -----------------------------------------------------------------
echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
