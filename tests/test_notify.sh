#!/bin/sh
set -eu
SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")/../hooks" && pwd)/notify.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fake curl captures request arguments but not the API key's value.
cat > "$TMP/curl" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >> "$CURL_LOG"
cat >/dev/null
MOCK
chmod +x "$TMP/curl"
export PATH="$TMP:$PATH"
export CURL_LOG="$TMP/curl.log"
export ITPUSH_API_KEY='test-key-not-real'

"$SCRIPT" stop
"$SCRIPT" notification <<'JSON'
{"notification_type":"idle_prompt","message":"should not leak"}
JSON
"$SCRIPT" notification <<'JSON'
{"notification_type":"permission_prompt"}
JSON
"$SCRIPT" notification <<'JSON'
{"notification_type":"other"}
JSON

[ "$(wc -l < "$CURL_LOG" | tr -d ' ')" = 3 ]
! grep -q 'should not leak' "$CURL_LOG"
! grep -q 'test-key-not-real' "$CURL_LOG"
printf 'PASS: event filtering and no dynamic payload leak\n'
