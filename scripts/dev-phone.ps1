# Prepares a connected phone for a debug run, then waits for the backend.
#
# Two jobs, in this order:
#   1. `adb reverse tcp:8000 tcp:8000`, so the phone's own localhost:8000 comes
#      out on this machine. It works over USB and over wireless debugging, it
#      survives no matter what IP the router hands out, and it is the fastest
#      path the app has. The app still falls back to this machine's Wi-Fi
#      address when no tunnel exists.
#   2. Waits for /health, so the app is not launched into a backend that is
#      still loading its model (the phoneme model takes about ten seconds).
#
# It never fails the launch: a missing phone or a backend that is not running
# is reported and the run continues, with the app showing its offline state.

param(
  [int]$Port = 8000,
  [int]$WaitSeconds = 25
)

$ErrorActionPreference = 'Continue'

function Find-Adb {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    (Join-Path $env:USERPROFILE 'AppData\Local\Android\Sdk\platform-tools\adb.exe'),
    'adb.exe'
  )
  foreach ($c in $candidates) {
    if ($c -eq 'adb.exe') {
      $found = Get-Command adb.exe -ErrorAction SilentlyContinue
      if ($found) { return $found.Source }
    } elseif (Test-Path $c) {
      return $c
    }
  }
  return $null
}

$adb = Find-Adb
if ($null -eq $adb) {
  Write-Host "adb not found; skipping the tunnel. The app will look for this machine on the Wi-Fi instead."
} else {
  $devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "`tdevice$" }
  if (-not $devices) {
    Write-Host "No phone is attached to adb; skipping the tunnel."
  } else {
    & $adb reverse "tcp:$Port" "tcp:$Port" | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Tunnel ready: the phone reaches this machine's port $Port on its own localhost."
    } else {
      Write-Host "Could not set up the tunnel; the app will look for this machine on the Wi-Fi instead."
    }
  }
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$up = $false
while ((Get-Date) -lt $deadline) {
  try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -UseBasicParsing
    if ($response.StatusCode -eq 200) { $up = $true; break }
  } catch {
    Start-Sleep -Milliseconds 700
  }
}

if ($up) {
  Write-Host "Backend answered on port $Port. Starting the app."
} else {
  Write-Host "Backend did not answer on port $Port within $WaitSeconds seconds. Starting the app anyway; it will show its offline state and reconnect when the backend is up."
}

exit 0
