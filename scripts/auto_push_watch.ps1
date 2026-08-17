<#
Watches ~/.claude/CLAUDE.md (the real, in-use config file) and auto-commits
/pushes its content to origin via the ~/dotfiles repo copy.

Windows port of scripts/auto_push_watch.py. Two differences from the Linux
version, both forced by the same constraint (no symlink privilege on this
account, and Git for Windows unlinks+recreates files on checkout/rebase
which would sever a hard link):
  - Uses System.IO.FileSystemWatcher (ReadDirectoryChangesW) instead of
    pyinotify.
  - Watches the REAL file directly and copies its content into the repo
    working tree before each commit, rather than watching a linked file
    inside the repo.

Debounce, commit/rebase/push logic, log format, and error semantics are
otherwise kept identical to the Python version so the shared watcher.log
timeline stays consistent across machines.

Launched from the per-user Startup folder (shell:startup), not a Scheduled
Task -- this account cannot register Scheduled Tasks on this machine (Task
Scheduler access is denied by policy). Long-running -- blocks forever
pumping watcher events.
#>

# Register-ObjectEvent -Action blocks run in the event subsystem's own scope
# and can only see global-scope variables/functions, not this script's
# locals -- so everything the handlers touch is declared global: below.
$global:RepoDir = Join-Path $HOME "dotfiles"
$global:RepoFile = Join-Path $global:RepoDir ".claude\CLAUDE.md"
$RealDir = Join-Path $HOME ".claude"
$WatchFileName = "CLAUDE.md"
$global:RealFile = Join-Path $RealDir $WatchFileName
$LogDir = Join-Path $HOME ".local\state\dotfiles-sync"
$global:LogFile = Join-Path $LogDir "watcher.log"
$DebounceSeconds = 3
$global:Branch = "master"

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function global:Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $global:LogFile -Value "$ts $Message"
}

function global:Invoke-Git {
    param([string[]]$GitArgs)
    $out = & git -C $global:RepoDir @GitArgs 2>&1
    [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Output   = ($out -join "`n")
    }
}

function global:Sync-Repo {
    try {
        Sync-RepoInner
    } catch {
        Write-Log "ERROR: unhandled exception in Sync-Repo: $($_.Exception.Message)"
    }
}

function global:Sync-RepoInner {
    Copy-Item -Path $global:RealFile -Destination $global:RepoFile -Force

    $status = Invoke-Git @("status", "--porcelain", "--", ".claude/CLAUDE.md")
    if ([string]::IsNullOrWhiteSpace($status.Output)) {
        return
    }

    Invoke-Git @("add", ".claude/CLAUDE.md") | Out-Null
    $hostName = $env:COMPUTERNAME
    $commit = Invoke-Git @("commit", "-m", "auto-sync: CLAUDE.md updated on $hostName", "--quiet")
    if ($commit.ExitCode -ne 0) {
        Write-Log "INFO: nothing to commit ($($commit.Output.Trim()))"
        return
    }

    $fetch = Invoke-Git @("fetch", "--quiet", "origin", $global:Branch)
    if ($fetch.ExitCode -ne 0) {
        Write-Log "ERROR: git fetch failed after local commit. Resolve manually in $global:RepoDir (local commit is intact, unpushed). $($fetch.Output.Trim())"
        return
    }

    $rebase = Invoke-Git @("rebase", "--quiet", "origin/$global:Branch")
    if ($rebase.ExitCode -ne 0) {
        Invoke-Git @("rebase", "--abort") | Out-Null
        Write-Log "ERROR: git rebase onto origin/$global:Branch failed (likely conflict) after local commit. Resolve manually in $global:RepoDir (local commit is intact, unpushed). $($rebase.Output.Trim())"
        return
    }

    $push = Invoke-Git @("push", "--quiet", "origin", $global:Branch)
    if ($push.ExitCode -eq 0) {
        Write-Log "OK: pushed CLAUDE.md change from $hostName"
    } else {
        Write-Log "ERROR: git push failed (possible conflict). Resolve manually in $global:RepoDir. $($push.Output.Trim())"
    }
}

Write-Log "watcher started, watching $global:RealFile"

$fsw = New-Object System.IO.FileSystemWatcher
$fsw.Path = $RealDir
$fsw.Filter = $WatchFileName
$fsw.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$fsw.IncludeSubdirectories = $false

$global:debounceTimer = New-Object System.Timers.Timer
$global:debounceTimer.Interval = $DebounceSeconds * 1000
$global:debounceTimer.AutoReset = $false
Register-ObjectEvent -InputObject $global:debounceTimer -EventName Elapsed -Action { Sync-Repo } | Out-Null

$onTrigger = {
    $global:debounceTimer.Stop()
    $global:debounceTimer.Start()
}
Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $onTrigger | Out-Null
Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $onTrigger | Out-Null

$fsw.EnableRaisingEvents = $true

while ($true) {
    Wait-Event -Timeout 3600 | Out-Null
}
