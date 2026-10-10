#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
PORT=18000
cleanup() { kill "$server" 2>/dev/null || true; rm -rf "$TMP"; }
mkdir -p "$TMP/repo/installers" "$TMP/repo/hooks" "$TMP/repo/raw/main/hooks" "$TMP/home/.claude/hooks"
cp "$ROOT/installers/install.sh" "$TMP/repo/installers/"
cp "$ROOT/installers/install.sh" "$TMP/repo/install.sh"
cp "$ROOT/hooks/notify.sh" "$TMP/repo/raw/main/hooks/notify.sh"
printf '%s\n' '{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep"}]}]}}' > "$TMP/home/.claude/settings.json"
python3 -m http.server "$PORT" --directory "$TMP/repo" >"$TMP/http.log" 2>&1 &
server=$!
trap cleanup EXIT HUP INT TERM
sleep 1
for run in cancel install reinstall; do
  case "$run" in cancel) answer=n ;; *) answer=y ;; esac
  printf '%s\n' "$answer" | HOME="$TMP/home" ITPUSH_NOTIFY_REPO_URL="http://127.0.0.1:$PORT" ITPUSH_NOTIFY_REF= sh "$TMP/repo/install.sh" >"$TMP/run-$run.out" 2>&1 || { cat "$TMP/run-$run.out"; exit 1; }
  if [ "$run" = cancel ]; then [ ! -d "$TMP/home/.claude/hooks/itpush-notify" ]; fi
done
python3 - "$TMP/home/.claude/settings.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); assert s['theme']=='dark'
assert any('echo keep' in h['command'] for g in s['hooks']['Stop'] for h in g['hooks'])
for event in ('Stop','Notification'):
    assert sum(1 for g in s['hooks'][event] for h in g['hooks'] if 'itpush-notify/notify.sh' in h['command'])==1
PY
printf 'PASS: cancellation, preserve existing settings, idempotent install\n'
