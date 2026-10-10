# Claude Code ItPush Notifications

Get push notifications on your phone when Claude Code finishes a response or is waiting for you. Works with Claude Code in a terminal and Claude Desktop's **Code** sessions on Windows, macOS, and Linux.

> Community integration; not an official Anthropic or ItPush product.

## What it does

Installs user-level Claude Code hooks and a small local sender script:

| Hook event | Notification |
|---|---|
| `Stop` | Claude finished a response. |
| `Notification` → `idle_prompt` | Claude is waiting for your next message. |
| `Notification` → `permission_prompt` | Claude needs your approval. |

Only fixed event messages are sent with `emergency: 0`. Prompts, responses, tool output, filenames, project names, transcript paths, and session IDs are not sent. The chat-title limitation is described below. Requests use HTTPS to `https://itpush.dev/api/send`, with an 8-second timeout. API/network errors are ignored so they cannot block Claude Code.

The sender requires `curl` and `python3` on macOS/Linux; Windows uses PowerShell and `curl.exe`.

## 1. Create your ItPush API key

1. Sign up at [itpush.dev](https://itpush.dev/).
2. Create a project, install the ItPush mobile app, and link your device using the dashboard QR code.
3. Get the **API Key** from Dashboard → API Keys. The **Auth Key** is for linking the phone app and is not used by this integration.
4. Keep the API key secret. If exposed in chat, screenshots, shell history, or a public repository, reset it in the dashboard and use the replacement.

The ItPush docs currently list 100 notifications/day on the free plan. Each matching event uses one API request; check their current plan limits.

## 2. Install

The one-line commands fetch and display the local hook source, then ask for confirmation before installing. The installer merges only its own entries into the user settings and leaves unrelated settings/hooks intact. It creates a backup of existing settings before updating them. Review both installer and hook source if you want to audit all behavior.

### macOS / Linux

Requires `curl`, `python3`, Claude Code:

```sh
curl -fsSL https://raw.githubusercontent.com/Abulfadl-Ahmadi/claude-code-itpush-notify/main/installers/install.sh | sh
```

Inspect the installer separately first, if preferred:

```sh
curl -fsSLo install.sh https://raw.githubusercontent.com/Abulfadl-Ahmadi/claude-code-itpush-notify/main/installers/install.sh
less install.sh
sh install.sh
```

### Windows PowerShell

Requires Windows PowerShell 5.1 or PowerShell 7 and Claude Code. This one-line command downloads and displays the installer, then runs it only after you type `y`:

```powershell
$installer = Join-Path $env:TEMP 'itpush-install.ps1'; try { Invoke-WebRequest 'https://raw.githubusercontent.com/Abulfadl-Ahmadi/claude-code-itpush-notify/main/installers/install.ps1' -OutFile $installer; Get-Content $installer; $ok = Read-Host 'Review the installer above. Type y to run it'; if ($ok -eq 'y') { & $installer } } finally { Remove-Item $installer -Force -ErrorAction SilentlyContinue }
```

For reproducibility, download from a versioned release tag rather than `main`, and verify the release before execution.

## 3. Provide the key to Claude Code

The installer does not receive or store the key. The hook reads `ITPUSH_API_KEY` from the environment inherited by Claude Code. Never put the key in command-line arguments, project files, `settings.json`, logs, screenshots, or Git.

### Temporary: launch Claude Code from a terminal

This asks for the key without echoing it and keeps it in the current terminal process only. Do not append the entered key to the command itself.

macOS/Linux:

```sh
read -rsp 'ItPush API key: ' ITPUSH_API_KEY; printf '\n'; export ITPUSH_API_KEY; claude
```

Windows PowerShell 7:

```powershell
$secure = Read-Host 'ItPush API key' -AsSecureString; $env:ITPUSH_API_KEY = [System.Net.NetworkCredential]::new('', $secure).Password; claude
```

Close that terminal to discard the temporary variable. Claude Desktop must inherit the environment for this to work; an app launched from the Start menu may not inherit terminal variables.

### Persistent user environment

Persistent environment variables are convenient but **are not encrypted secret storage**; processes running as your user may read them. A platform keychain/secret manager is preferable if available. If setting a user variable, use your OS environment-variable settings, then completely exit and reopen Claude Desktop/Claude Code.

- **Windows:** open Start → search “Edit environment variables for your account” → add `ITPUSH_API_KEY`. Treat it as a plaintext user environment value.
- **macOS/Linux:** configure the variable in the login environment used to launch Claude Code, or use a supported OS secret manager and a reviewed launcher. GUI apps often do not inherit interactive shell startup files, so verify the environment is available to the Claude Code process.

Do not run `export ITPUSH_API_KEY=...` or `$env:ITPUSH_API_KEY=...` with the literal key in a shell command: it may be stored in history.

## Chat/session title limitation

Claude Code's `Stop` and `Notification` hook input does not document a human-readable chat-title field. It may provide a session ID, but that is not the title. This integration intentionally does not inspect transcript files to guess a title, to avoid transmitting or exposing conversation content. Notifications identify the event, not which chat produced it.

## Files and settings

- macOS/Linux helper: `~/.claude/hooks/itpush-notify/notify.sh`
- Windows helper: `%USERPROFILE%\.claude\hooks\itpush-notify\notify.ps1`
- User settings: `~/.claude/settings.json` or `%USERPROFILE%\.claude\settings.json`
- Backup (if a settings file existed): `settings.json.itpush-backup`

The installation is intended to be repeatable. If settings JSON is malformed or the hooks structure is incompatible, the installer stops rather than discarding the file. Review the settings diff and backup after installation. Restart Claude Code after installing or changing environment variables. Use `/hooks` to inspect hook registration.

## Uninstall

macOS/Linux:

```sh
sh installers/uninstall.sh
```

Windows PowerShell:

```powershell
.
installers\uninstall.ps1
```

These remove only the ItPush hook entries and helper directory; they leave unrelated settings and the API key environment variable untouched. Remove the variable yourself if no longer needed, and delete the backup only after confirming you do not need it.

## Troubleshooting and privacy

- If no push arrives, confirm the phone is linked and the API Key is valid; do not print or paste it into logs.
- Check the ItPush quota dashboard. On invalid keys, network outage, or exhausted quota, this hook fails silently by design.
- Make sure Claude Code inherited `ITPUSH_API_KEY`; fully restart the app after changing the variable.
- Check `/hooks` for hook configuration errors.
- The helper processes hook input only to identify `notification_type`; it does not include dynamic input in the ItPush body.
- Local scripts run with your user permissions. Review them before running. The API key can send notifications on your ItPush account; rotate it if exposed.

## License

MIT. See [LICENSE](LICENSE).
