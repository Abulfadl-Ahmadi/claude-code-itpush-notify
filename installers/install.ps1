$ErrorActionPreference = 'Stop'
$repoUrl = if ($env:ITPUSH_NOTIFY_REPO_URL) { $env:ITPUSH_NOTIFY_REPO_URL } else { 'https://github.com/Abulfadl-Ahmadi/claude-code-itpush-notify' }
$repoRef = if ($env:ITPUSH_NOTIFY_REF) { $env:ITPUSH_NOTIFY_REF } else { 'main' }
$hookUrl = "$repoUrl/raw/$repoRef/hooks/notify.ps1"
$tempHook = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.ps1')
try {
    Invoke-WebRequest -Uri $hookUrl -OutFile $tempHook -TimeoutSec 20
    Write-Host '----- ItPush hook source preview -----'
    Get-Content -LiteralPath $tempHook
    Write-Host '----- End preview -----'
    $answer = Read-Host 'Install this hook into your Claude Code user settings? Type y'
    if ($answer -notin @('y', 'Y', 'yes', 'YES')) { Write-Host 'Cancelled. No files changed.'; exit 0 }

    $claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    $hookDir = Join-Path $claudeDir 'hooks/itpush-notify'
    $hookPath = Join-Path $hookDir 'notify.ps1'
    $settingsPath = Join-Path $claudeDir 'settings.json'
    $settings = @{}
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
        if ($settings -isnot [System.Collections.IDictionary]) { throw 'settings.json must contain a JSON object. No files were changed.' }
    }
    if (-not $settings.Contains('hooks')) { $settings['hooks'] = @{} }
    if ($settings['hooks'] -isnot [System.Collections.IDictionary]) { throw 'Existing hooks setting is not an object. No files were changed.' }
    $hooks = $settings['hooks']

    function Add-ItPushEvent($EventName, $Matcher, $Argument) {
        if (-not $hooks.Contains($EventName)) { $hooks[$EventName] = @() }
        $entries = @($hooks[$EventName])
        $marker = 'itpush-notify/notify.ps1'
        $kept = @()
        foreach ($entry in $entries) {
            if ($entry -isnot [System.Collections.IDictionary]) { $kept += $entry; continue }
            $inner = @($entry['hooks'])
            if ($entry['hooks'] -isnot [System.Collections.IList] -and $null -ne $entry['hooks']) { $kept += $entry; continue }
            $remaining = @($inner | Where-Object { $_ -isnot [System.Collections.IDictionary] -or $_['command'] -notlike "*$marker*" })
            if ($remaining.Count -gt 0) { $copy = $entry.Clone(); $copy['hooks'] = $remaining; $kept += $copy }
        }
        $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$hookPath`" $Argument"
        $group = @{ hooks = @(@{ type = 'command'; command = $command }) }
        if ($null -ne $Matcher) { $group['matcher'] = $Matcher }
        $hooks[$EventName] = @($kept) + @($group)
    }

    Add-ItPushEvent 'Stop' $null 'stop'
    Add-ItPushEvent 'Notification' 'idle_prompt|permission_prompt' 'notification'

    # Stage settings before touching either installed file.
    $json = ConvertTo-Json -InputObject $settings -Depth 100
    $tempSettings = "$settingsPath.$([guid]::NewGuid().ToString()).tmp"
    $backupPath = "$settingsPath.itpush-backup"
    $hadSettings = Test-Path -LiteralPath $settingsPath
    try {
        [IO.File]::WriteAllText($tempSettings, $json + "`n", [Text.UTF8Encoding]::new($false))
        if ($hadSettings -and -not (Test-Path -LiteralPath $backupPath)) { Copy-Item -LiteralPath $settingsPath -Destination $backupPath }
        New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
        Copy-Item -LiteralPath $tempHook -Destination $hookPath -Force
        Move-Item -LiteralPath $tempSettings -Destination $settingsPath -Force
    } catch {
        if (-not $hadSettings) { Remove-Item -LiteralPath $settingsPath -Force -ErrorAction SilentlyContinue }
        Remove-Item -LiteralPath $hookPath -Force -ErrorAction SilentlyContinue
        throw
    } finally { Remove-Item -LiteralPath $tempSettings -Force -ErrorAction SilentlyContinue }
    Write-Host 'Installed. Set ITPUSH_API_KEY in your user environment, then restart Claude Code.'
    Write-Host 'See README.md for account setup, key storage, test, and uninstall.'
} finally { Remove-Item -LiteralPath $tempHook -Force -ErrorAction SilentlyContinue }
