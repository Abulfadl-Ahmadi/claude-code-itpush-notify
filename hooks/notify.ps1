$ErrorActionPreference = 'Stop'
try {
    $eventType = if ($args.Count -gt 0) { $args[0] } else { '' }
    if ($eventType -eq 'notification') {
        $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
        $eventType = $hookInput.notification_type
    }

    switch ($eventType) {
        'stop' {
            $title = 'Claude Code: response ready'
            $message = 'Claude finished a response.'
        }
        'idle_prompt' {
            $title = 'Claude Code: your turn'
            $message = 'Claude is waiting for your next message.'
        }
        'permission_prompt' {
            $title = 'Claude Code: approval needed'
            $message = 'Claude needs your approval to continue.'
        }
        default { exit 0 }
    }

    $apiKey = [Environment]::GetEnvironmentVariable('ITPUSH_API_KEY', 'User')
    if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:ITPUSH_API_KEY }
    if ([string]::IsNullOrWhiteSpace($apiKey)) { exit 0 }

    $payload = @{ title = $title; message = $message; emergency = 0 } | ConvertTo-Json -Compress
    $payloadBytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $headerPath = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.cfg')
    $bodyPath = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.json')
    try {
        [IO.File]::WriteAllBytes($bodyPath, $payloadBytes)
        [IO.File]::WriteAllText($headerPath, "header = `"Authorization: Bearer $apiKey`"`n", [Text.Encoding]::ASCII)
        $null = & curl.exe --config $headerPath --silent --show-error --max-time 8 --fail -X POST 'https://itpush.dev/api/send' -H 'Content-Type: application/json; charset=utf-8' --data-binary "@$bodyPath" 2>$null
    } finally {
        Remove-Item -LiteralPath $headerPath, $bodyPath -Force -ErrorAction SilentlyContinue
    }
}
catch {
    # Notification failures must not interrupt Claude Code.
    exit 0
}
finally {
    $apiKey = $null
}
