<#
.SYNOPSIS
  One-shot helper that copies the dashboard into place, initialises git, and
  pushes the whole project to a new GitHub repo using the GitHub CLI.

.PARAMETER RepoName
  Name of the GitHub repo to create (default: fifa-2022-dashboard).

.PARAMETER Visibility
  public | private | internal  (default: public).

.EXAMPLE
  .\push-to-github.ps1 -RepoName "fifa-2022-dashboard" -Visibility "public"

.NOTES
  Requires git and GitHub CLI (gh) on PATH.
    winget install --id Git.Git
    winget install --id GitHub.cli
  Then: gh auth login
#>

param(
  [string]$RepoName       = "fifa-2022-dashboard",
  [ValidateSet("public","private","internal")]
  [string]$Visibility     = "public",
  [string]$CommitMessage  = "Initial commit: Qatar 2022 dashboard + skill + data model"
)

$ErrorActionPreference = "Stop"

foreach ($cmd in "git","gh") {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Error "$cmd is not on PATH. Install it first (see README)."
  }
}

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot
Write-Host "Project root: $ProjectRoot" -ForegroundColor Cyan

$dashDir = Join-Path $ProjectRoot "dashboards"
$dashTarget = Join-Path $dashDir "qatar-2022-dashboard.html"
if (-not (Test-Path $dashTarget)) {
  $candidate = Join-Path (Split-Path -Parent $ProjectRoot) "qatar-2022-dashboard.html"
  if (Test-Path $candidate) {
    if (-not (Test-Path $dashDir)) { New-Item -ItemType Directory -Path $dashDir | Out-Null }
    Copy-Item $candidate $dashTarget
    Write-Host "Copied dashboard from: $candidate" -ForegroundColor Green
  } else {
    Write-Warning "Could not find qatar-2022-dashboard.html. Put it in dashboards/ before continuing."
  }
}

& gh auth status 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Not logged into GitHub CLI yet. Launching gh auth login..." -ForegroundColor Yellow
  & gh auth login
}

if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) {
  & git init -b main | Out-Null
  Write-Host "git initialized" -ForegroundColor Green
}

& git add .
$status = & git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
  Write-Host "Working tree clean." -ForegroundColor Yellow
} else {
  & git commit -m $CommitMessage | Out-Null
  Write-Host "Committed: $CommitMessage" -ForegroundColor Green
}

$existing = & gh repo view $RepoName 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host "Repo '$RepoName' exists — pushing." -ForegroundColor Yellow
  $remote = & git remote 2>$null
  if (-not ($remote -contains "origin")) {
    $owner = (& gh api user --jq .login).Trim()
    & git remote add origin "https://github.com/$owner/$RepoName.git"
  }
  & git push -u origin main
} else {
  & gh repo create $RepoName --$Visibility --source=. --remote=origin --push --description "Interactive Qatar 2022 World Cup dashboard built from a Postgres database."
}

$owner = (& gh api user --jq .login).Trim()
$repoUrl  = "https://github.com/$owner/$RepoName"
$pagesUrl = "https://$owner.github.io/$RepoName/dashboards/qatar-2022-dashboard.html"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Done." -ForegroundColor Green
Write-Host " Repo:  $repoUrl"
Write-Host ""
Write-Host " Turn it into a live URL:"
Write-Host "   1. $repoUrl/settings/pages"
Write-Host "   2. Source: Deploy from a branch  ->  main / (root)"
Write-Host "   3. Wait ~30 seconds, then open:"
Write-Host "      $pagesUrl"
Write-Host "=========================================" -ForegroundColor Cyan
