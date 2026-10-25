$container = "self-healing-compose-app"
$url = "http://localhost:8002/health"
$logDir = Join-Path $PSScriptRoot "logs"
$logFile = Join-Path $logDir "recovery.log"

$checkIntervalSeconds = 10
$restartCooldownSeconds = 60
$recoveryAttempts = 6
$retryDelaySeconds = 5
$lastRestartAttempt = [datetime]::MinValue
$script:healthError = ""

function Write-RecoveryLog {
    param([string]$Message)

    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $Message"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Test-AppHealth {
    try {
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 3
        if ($response.status -ne "healthy") {
            throw "Health endpoint returned status '$($response.status)'"
        }
        $script:healthError = ""
        return $true
    }
    catch {
        $script:healthError = $_.Exception.Message
        return $false
    }
}

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Write-Host "Watchdog started. Monitoring $url"
Write-Host "Target container: $container"
Write-Host "Press Ctrl+C to stop."

while ($true) {
    if (Test-AppHealth) {
        Start-Sleep -Seconds $checkIntervalSeconds
        continue
    }

    $now = Get-Date
    if (($now - $lastRestartAttempt).TotalSeconds -lt $restartCooldownSeconds) {
        Start-Sleep -Seconds $checkIntervalSeconds
        continue
    }

    $lastRestartAttempt = $now
    Write-RecoveryLog "Health check failed: $script:healthError. Attempting restart of $container."

    try {
        $restartOutput = & docker restart $container 2>&1
        $restartExitCode = $LASTEXITCODE

        if ($restartOutput) {
            Write-Host ($restartOutput | Out-String).Trim()
        }

        if ($restartExitCode -ne 0) {
            Write-RecoveryLog "Docker restart failed with exit code $restartExitCode."
            Start-Sleep -Seconds $checkIntervalSeconds
            continue
        }
    }
    catch {
        Write-RecoveryLog "Could not run Docker restart: $($_.Exception.Message)"
        Start-Sleep -Seconds $checkIntervalSeconds
        continue
    }

    $recovered = $false
    for ($attempt = 1; $attempt -le $recoveryAttempts; $attempt++) {
        Start-Sleep -Seconds $retryDelaySeconds

        if (Test-AppHealth) {
            Write-RecoveryLog "Recovery succeeded; health endpoint returned healthy (attempt $attempt of $recoveryAttempts)."
            $recovered = $true
            break
        }

        Write-RecoveryLog "Recovery check $attempt of $recoveryAttempts failed: $script:healthError"
    }

    if (-not $recovered) {
        Write-RecoveryLog "Recovery failed after $recoveryAttempts health checks. Another restart will not be attempted for $restartCooldownSeconds seconds."
    }

    Start-Sleep -Seconds $checkIntervalSeconds
}
