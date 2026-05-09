# Auto push local HTML changes to GitHub
# Usage: powershell -ExecutionPolicy Bypass -File .\auto-push.ps1

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$watchPath = Join-Path $repoRoot 'pbs-affiliate-landing-master'
if (-not (Test-Path $watchPath)) {
    Write-Error "Watch path not found: $watchPath"
    exit 1
}

$filter = '*.html'
$debounceSeconds = 2
$global:lastEvent = Get-Date '2000-01-01'

$watcher = New-Object System.IO.FileSystemWatcher $watchPath, $filter
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, FileName, Size'

$action = {
    Start-Sleep -Milliseconds 400
    $eventTime = Get-Date
    if (($eventTime - $global:lastEvent).TotalSeconds -lt $debounceSeconds) { return }
    $global:lastEvent = $eventTime

    Write-Host "Detected change in: $($Event.SourceEventArgs.FullPath)"
    Write-Host 'Checking git status...'

    $status = git status --porcelain
    if (-not [string]::IsNullOrEmpty($status)) {
        git add -A
        git commit -m "Auto update HTML files: $($eventTime.ToString('yyyy-MM-dd HH:mm:ss'))" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'Pushing to origin/main...'
            git push origin main
            if ($LASTEXITCODE -eq 0) {
                Write-Host 'Push successful.'
            } else {
                Write-Warning 'Push failed. Please check your git authentication.'
            }
        } else {
            Write-Warning 'Commit failed or no changes to commit.'
        }
    } else {
        Write-Host 'No changes detected by git.'
    }
}

Register-ObjectEvent $watcher Changed -Action $action | Out-Null
Register-ObjectEvent $watcher Created -Action $action | Out-Null
$watcher.EnableRaisingEvents = $true

Write-Host "Watching HTML files in: $watchPath"
Write-Host 'Press Ctrl+C to stop.'
while ($true) { Start-Sleep -Seconds 1 }
