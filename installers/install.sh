#!/bin/sh
set -eu
REPO_URL=${ITPUSH_NOTIFY_REPO_URL:-https://github.com/Abulfadl-Ahmadi/claude-code-itpush-notify}
REPO_REF=${ITPUSH_NOTIFY_REF:-main}
BASE="$REPO_URL/raw/$REPO_REF"
for tool in curl python3; do command -v "$tool" >/dev/null 2>&1 || { printf 'Missing required tool: %s\n' "$tool" >&2; exit 1; }; done
fetch() { curl -fsSL --max-time 20 "$BASE/$1"; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT HUP INT TERM
fetch hooks/notify.sh > "$TMP/notify.sh"
printf '%s\n' '----- ItPush hook source preview -----'; cat "$TMP/notify.sh"; printf '%s\n' '----- End preview -----'
printf 'Install this hook into your Claude Code user settings? [y/N] '
if [ -r /dev/tty ]; then
  if ( : </dev/tty ) 2>/dev/null; then IFS= read -r answer </dev/tty; else IFS= read -r answer; fi
else
  IFS= read -r answer
fi
case "$answer" in y|Y|yes|YES) ;; *) printf 'Cancelled. No files changed.\n'; exit 0 ;; esac
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}; SETTINGS="$CLAUDE_DIR/settings.json"; HOOK_DIR="$CLAUDE_DIR/hooks/itpush-notify"; HOOK_PATH="$HOOK_DIR/notify.sh"
mkdir -p "$CLAUDE_DIR" "$CLAUDE_DIR/hooks"
python3 - "$SETTINGS" "$HOOK_PATH" "$TMP/notify.sh" <<'PY'
import json, os, sys, tempfile
settings_path, hook_path, source_path = sys.argv[1:]
settings={}
if os.path.exists(settings_path):
    with open(settings_path,encoding='utf-8') as f: settings=json.load(f)
if not isinstance(settings,dict): raise SystemExit('settings.json must contain a JSON object; no changes made')
hooks=settings.setdefault('hooks',{})
if not isinstance(hooks,dict): raise SystemExit('Existing hooks setting is not an object; no changes made')
def add_event(event,matcher,arg):
    entries=hooks.setdefault(event,[])
    if not isinstance(entries,list): raise SystemExit(f'Existing {event} hooks are not a list; no settings changed')
    marker='itpush-notify/notify.sh'; filtered=[]
    for entry in entries:
        if not isinstance(entry,dict): filtered.append(entry); continue
        inner=entry.get('hooks',[])
        if not isinstance(inner,list): filtered.append(entry); continue
        kept=[h for h in inner if not (isinstance(h,dict) and marker in h.get('command',''))]
        if kept: clone=dict(entry); clone['hooks']=kept; filtered.append(clone)
    group={'hooks':[{'type':'command','command':f'"{hook_path}" {arg}'}]}
    if matcher is not None: group['matcher']=matcher
    filtered.append(group); hooks[event]=filtered
add_event('Stop',None,'stop'); add_event('Notification','idle_prompt|permission_prompt','notification')
os.makedirs(os.path.dirname(settings_path),exist_ok=True)
# Stage both outputs before replacing either. Preserve a backup of existing settings.
fd,staged_settings=tempfile.mkstemp(prefix='.settings.',suffix='.tmp',dir=os.path.dirname(settings_path))
try:
    with os.fdopen(fd,'w',encoding='utf-8',newline='\n') as f: json.dump(settings,f,ensure_ascii=False,indent=2); f.write('\n')
    os.chmod(staged_settings,0o600)
    os.makedirs(os.path.dirname(hook_path),exist_ok=True)
    with open(source_path,'rb') as src,open(hook_path+'.tmp','wb') as dst: dst.write(src.read())
    os.chmod(hook_path+'.tmp',0o700)
    if os.path.exists(settings_path):
        import shutil; shutil.copy2(settings_path,settings_path+'.itpush-backup')
    os.replace(hook_path+'.tmp',hook_path)
    os.replace(staged_settings,settings_path)
finally:
    for p in (staged_settings,hook_path+'.tmp'):
        if os.path.exists(p): os.unlink(p)
PY
chmod 700 "$CLAUDE_DIR" "$CLAUDE_DIR/hooks" "$HOOK_DIR" 2>/dev/null || true
printf '\nInstalled. Set ITPUSH_API_KEY in the environment, then restart Claude Code.\nSee README.md for account setup, key storage, test, and uninstall.\n'
