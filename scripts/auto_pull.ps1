<#
Periodically fetches origin and fast-forwards ~/dotfiles if it's behind, then
propagates the pulled .claude/CLAUDE.md content out to the real config file
at ~/.claude/CLAUDE.md. Runs forever, sleeping between cycles.

Deliberately fast-forward-only: never rebases or merges local work. If the
local branch has unpushed commits, this is a no-op and the push watcher
(auto_push_watch.ps1) is responsible for reconciling that side.

Windows notes:
  - Unlike the Linux machines (which symlink ~/.claude/CLAUDE.md straight
    into the repo), this copies content instead -- see auto_push_watch.ps1
    for why (no symlink privilege on this account, and Git for Windows
    unlinks+recreates files on checkout, which would sever a hard link).
  - This account cannot register Scheduled Tasks on this machine (Task
    Scheduler access is denied by policy, confirmed via `whoami /groups`
    showing Administrators as deny-only). Windows Task Scheduler also has a
    1-minute floor on repetition intervals regardless, versus the 30s used
    by the Linux systemd timer. So instead of an external timer triggering
    a one-shot script, this script loops itself and is launched once at
    logon from the per-user Startup folder (no special privilege needed).
#>

$RepoDir = Join-Path $HOME "dotfiles"
$RepoFile = Join-Path $RepoDir ".claude\CLAUDE.md"
$RealFile = Join-Path $HOME ".claude\CLAUDE.md"
$LogDir = Join-Path $HOME ".local\state\dotfiles-sync"
$LogFile = Join-Path $LogDir "watcher.log"
$Branch = "master"
$IntervalSeconds = 30

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$ts $Message"
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $out = & git -C $RepoDir @GitArgs 2>&1
    [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Output   = ($out -join "`n")
    }
}

function Invoke-PullCycle {
    $before = (Invoke-Git @("rev-parse", "HEAD")).Output.Trim()

    $fetch = Invoke-Git @("fetch", "--quiet", "origin", $Branch)
    if ($fetch.ExitCode -ne 0) {
        Write-Log "ERROR: auto-pull fetch failed. $($fetch.Output.Trim())"
        return
    }

    $merge = Invoke-Git @("merge", "--ff-only", "--quiet", "origin/$Branch")
    if ($merge.ExitCode -ne 0) {
        # Local is ahead or diverged (unpushed local commits) -- leave it to
        # the push watcher, this is expected and not an error condition.
        return
    }

    $after = (Invoke-Git @("rev-parse", "HEAD")).Output.Trim()
    if ($before -ne $after) {
        Copy-Item -Path $RepoFile -Destination $RealFile -Force
        Write-Log "OK: auto-pull fast-forwarded $($before.Substring(0,7)) -> $($after.Substring(0,7)), propagated to $RealFile"
    }
}

Write-Log "pull loop started, polling origin/$Branch every ${IntervalSeconds}s"

while ($true) {
    try {
        Invoke-PullCycle
    } catch {
        Write-Log "ERROR: unhandled exception in Invoke-PullCycle: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $IntervalSeconds
}
