#!/bin/sh
set -eu
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_DIR="$CLAUDE_DIR/hooks/itpush-notify"
if [ -f "$SETTINGS" ]; then
  python3 - "$SETTINGS" <<'PY'
import json, os, sys, tempfile
path = sys.argv[1]
with open(path, encoding='utf-8') as f: data = json.load(f)
hooks = data.get('hooks', {})
if not isinstance(hooks, dict): raise SystemExit('Invalid hooks structure; no changes made')
marker = 'itpush-notify/notify.'
for event in ('Stop', 'Notification'):
    entries = hooks.get(event, [])
    if not isinstance(entries, list): continue
    kept=[]
    for entry in entries:
        if not isinstance(entry, dict): kept.append(entry); continue
        inner=entry.get('hooks', [])
        remaining=[h for h in inner if not (isinstance(h, dict) and marker in h.get('command',''))]
        if remaining:
            clone=dict(entry); clone['hooks']=remaining; kept.append(clone)
    hooks[event]=kept
fd,tmp=tempfile.mkstemp(prefix='.settings.',suffix='.tmp',dir=os.path.dirname(path))
try:
    with os.fdopen(fd,'w',encoding='utf-8') as f: json.dump(data,f,ensure_ascii=False,indent=2); f.write('\n')
    os.chmod(tmp,0o600); os.replace(tmp,path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
PY
fi
rm -rf "$HOOK_DIR"
printf 'ItPush Claude Code hooks removed. Existing settings and API key storage were left untouched.\n'
