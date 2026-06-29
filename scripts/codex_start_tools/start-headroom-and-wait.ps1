param(
    [int]$Port = 8787,
    [int]$TimeoutSeconds = 30,
    [string]$HeadroomExe = "headroom",
    [string]$TargetApiUrl = ""
)

function Test-Port {
    param(
        [string]$HostName = "127.0.0.1",
        [int]$Port,
        [int]$TimeoutMs = 200
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $success = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if ($success) {
            $client.EndConnect($async)
            $client.Close()
            return $true
        }

        $client.Close()
        return $false
    }
    catch {
        return $false
    }
}

if (Test-Port -Port $Port) {
    'True'
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($TargetApiUrl)) {
    $env:OPENAI_TARGET_API_URL = $TargetApiUrl
}

try {
    Start-Process $HeadroomExe -ArgumentList "proxy --port $Port" -WindowStyle Normal | Out-Null
}
catch {
    'False'
    exit 1
}

for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Port -Port $Port) {
        'True'
        exit 0
    }
    Start-Sleep -Seconds 1
}

'False'
exit 1