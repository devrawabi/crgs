# Start (or restart) the CRGS Flask API on port 5318.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $root 'venv\Scripts\python.exe'

if (-not (Test-Path $python)) {
  Write-Error "Missing venv python: $python"
}

Write-Host 'Stopping existing CRGS API (run.py) processes...'
Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine -match 'run\.py' } |
  ForEach-Object {
    Write-Host "  Killing PID $($_.ProcessId)"
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  }
Get-NetTCPConnection -LocalPort 5318 -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

Write-Host "Starting CRGS API with $python"
$env:PYTHONUNBUFFERED = '1'
Start-Process -FilePath $python -ArgumentList 'run.py' -WorkingDirectory $root -WindowStyle Minimized

Start-Sleep -Seconds 3
try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:5318/api/health' -TimeoutSec 10 -UseBasicParsing
  Write-Host "OK $($r.StatusCode) $($r.Content)"
} catch {
  Write-Warning "API did not respond yet: $_"
  Write-Host 'Check the python window for Oracle / startup errors.'
}
