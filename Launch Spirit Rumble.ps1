$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$logDir = Join-Path $root 'launcher_logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $logDir "launch-$ts.log"

function Write-Log {
  param([string]$Message)
  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
  $line = "[$timestamp] $Message"
  Write-Host $line
  Add-Content -Path $logPath -Value $line
}

function Get-FreeLocalPort {
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), 0)
  try {
    $listener.Start()
    return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
  } finally {
    $listener.Stop()
  }
}

try {
  Write-Log 'Spirit Rumble launcher started.'

  $flutter = Get-Command flutter -ErrorAction SilentlyContinue
  if (-not $flutter) {
    throw 'Flutter is not installed or not on PATH.'
  }

  Write-Log 'Running: flutter --version'
  & flutter --version 2>&1 | Tee-Object -FilePath $logPath -Append | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "flutter --version failed with exit code $LASTEXITCODE"
  }

  Write-Log 'Running: flutter pub get'
  & flutter pub get 2>&1 | Tee-Object -FilePath $logPath -Append | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed with exit code $LASTEXITCODE"
  }

  $edgeCmd = Get-Command msedge -ErrorAction SilentlyContinue
  $edgeLaunchTarget = $null
  if ($edgeCmd) {
    $edgeLaunchTarget = $edgeCmd.Source
  } elseif (Test-Path "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe") {
    $edgeLaunchTarget = "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
  } elseif (Test-Path "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") {
    $edgeLaunchTarget = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
  }

  $port = Get-FreeLocalPort
  $url = "http://127.0.0.1:$port"

  Write-Log "Selected web port: $port"
  if ($edgeLaunchTarget) {
    Write-Log "Edge launch target: $edgeLaunchTarget"
  } else {
    Write-Log 'Edge executable not found. Falling back to microsoft-edge protocol.'
  }
  Write-Log "Starting web server on $url"
  Write-Log 'Keep this launcher window open while playing.'

  $openEdgeJob = Start-Job -ScriptBlock {
    param([string]$edgeTarget, [string]$pageUrl, [int]$launchPort)
    $deadline = (Get-Date).AddSeconds(60)
    $opened = $false
    while ((Get-Date) -lt $deadline) {
      try {
        $client = New-Object Net.Sockets.TcpClient('127.0.0.1', $launchPort)
        $client.Dispose()
        if ($edgeTarget) {
          Start-Process -FilePath $edgeTarget -ArgumentList $pageUrl | Out-Null
        } else {
          Start-Process -FilePath ("microsoft-edge:" + $pageUrl) | Out-Null
        }
        $opened = $true
        break
      } catch {
        Start-Sleep -Milliseconds 400
      }
    }
    if (-not $opened) {
      Start-Process -FilePath ("microsoft-edge:" + $pageUrl) | Out-Null
    }
  } -ArgumentList $edgeLaunchTarget, $url, $port

  & flutter run -d web-server --release --web-hostname 127.0.0.1 --web-port $port 2>&1 | Tee-Object -FilePath $logPath -Append | Out-Host
  $runExit = $LASTEXITCODE

  if ($openEdgeJob) {
    Receive-Job -Job $openEdgeJob -Wait -AutoRemoveJob | Out-Null
  }

  if ($runExit -ne 0) {
    throw "flutter run failed with exit code $runExit"
  }
} catch {
  Write-Log "Launcher error: $($_.Exception.Message)"
  Write-Host ''
  Write-Host "Launcher error: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "See log: $logPath" -ForegroundColor Yellow
  exit 1
}

Write-Log 'Launcher exited cleanly.'
exit 0
