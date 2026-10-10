$ErrorActionPreference = 'Stop'
$claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$settingsPath = Join-Path $claudeDir 'settings.json'
$hookDir = Join-Path $claudeDir 'hooks/itpush-notify'
if (Test-Path -LiteralPath $settingsPath) {
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    if ($settings['hooks'] -isnot [System.Collections.IDictionary]) { throw 'Invalid hooks structure; no changes made.' }
    foreach ($event in @('Stop', 'Notification')) {
        if (-not $settings['hooks'].Contains($event)) { continue }
        $kept = @()
        foreach ($entry in @($settings['hooks'][$event])) {
            if ($entry -isnot [System.Collections.IDictionary]) { $kept += $entry; continue }
            $remaining = @(@($entry['hooks']) | Where-Object { $_ -isnot [System.Collections.IDictionary] -or $_['command'] -notlike '*itpush-notify/notify.ps1*' })
            if ($remaining.Count -gt 0) { $clone = $entry.Clone(); $clone['hooks'] = $remaining; $kept += $clone }
        }
        $settings['hooks'][$event] = @($kept)
    }
    $json = ConvertTo-Json -InputObject $settings -Depth 100
    $temp = "$settingsPath.$([guid]::NewGuid().ToString()).tmp"
    try {
        [IO.File]::WriteAllText($temp, $json + "`n", [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temp -Destination $settingsPath -Force
    } finally { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
}
Remove-Item -LiteralPath $hookDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'ItPush Claude Code hooks removed. Existing settings and API key storage were left untouched.'
