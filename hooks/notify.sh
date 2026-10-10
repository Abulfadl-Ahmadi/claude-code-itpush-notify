#!/bin/sh
# Minimal, non-blocking ItPush sender for Claude Code hooks.
set -u

EVENT=${1:-}
case "$EVENT" in
  stop)
    TITLE='Claude Code: response ready'
    MESSAGE='Claude finished a response.'
    ;;
  notification)
    INPUT=$(cat)
    NOTIFICATION_TYPE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("notification_type", ""))' 2>/dev/null || true)
    case "$NOTIFICATION_TYPE" in
      idle_prompt)
        TITLE='Claude Code: your turn'
        MESSAGE='Claude is waiting for your next message.'
        ;;
      permission_prompt)
        TITLE='Claude Code: approval needed'
        MESSAGE='Claude needs your approval to continue.'
        ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

[ -n "${ITPUSH_API_KEY:-}" ] || exit 0
PAYLOAD=$(TITLE="$TITLE" MESSAGE="$MESSAGE" python3 -c 'import json,os; print(json.dumps({"title":os.environ["TITLE"],"message":os.environ["MESSAGE"],"emergency":0}, ensure_ascii=False))' 2>/dev/null) || exit 0

# Keep the bearer token out of curl's process argument list.
printf 'header = "Authorization: Bearer %s"\n' "$ITPUSH_API_KEY" | \
  curl --config - --silent --show-error --max-time 8 --fail \
    -X POST 'https://itpush.dev/api/send' \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data-binary "$PAYLOAD" >/dev/null 2>&1 || true
