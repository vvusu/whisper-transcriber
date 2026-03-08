# Whisper Transcriber - Windows installer
# Installs ffmpeg and whisper-cli (whisper.cpp) via winget/choco/scoop when possible.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Model base

param(
  [ValidateSet('none','tiny','base','small','medium','large')]
  [string]$Model = 'base'
)

$ErrorActionPreference = 'Stop'

function Has($cmd) {
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Ok($m){ Write-Host "[OK]   $m" -ForegroundColor Green }
function Err($m){ Write-Host "[ERR]  $m" -ForegroundColor Red }

$SkillDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ModelDir = Join-Path $SkillDir 'assets\models'
New-Item -ItemType Directory -Force -Path $ModelDir | Out-Null

function Install-WithWinget {
  param([string[]]$Ids)
  foreach($id in $Ids){
    Info "winget install $id"
    winget install --id $id -e --accept-source-agreements --accept-package-agreements
  }
}

function Install-WithChoco {
  param([string[]]$Pkgs)
  foreach($p in $Pkgs){
    Info "choco install $p"
    choco install -y $p
  }
}

function Install-WithScoop {
  param([string[]]$Pkgs)
  foreach($p in $Pkgs){
    Info "scoop install $p"
    scoop install $p
  }
}

# Dependencies
$needFfmpeg = -not (Has 'ffmpeg')
$needWhisper = -not (Has 'whisper-cli')

if(-not $needFfmpeg -and -not $needWhisper){
  Ok "Dependencies already installed (ffmpeg, whisper-cli)"
} else {
  if(Has 'winget'){
    # Note: package ids may vary by system; best-effort.
    $ids = @()
    if($needFfmpeg){ $ids += 'Gyan.FFmpeg' }
    if($needWhisper){
      Warn "No universal winget id for whisper.cpp CLI. Install whisper.cpp manually if this fails."
    }
    if($ids.Count -gt 0){ Install-WithWinget -Ids $ids }
  } elseif(Has 'choco'){
    $pkgs = @()
    if($needFfmpeg){ $pkgs += 'ffmpeg' }
    if($needWhisper){ Warn "Chocolatey package for whisper.cpp may not exist; install whisper.cpp manually if missing." }
    if($pkgs.Count -gt 0){ Install-WithChoco -Pkgs $pkgs }
  } elseif(Has 'scoop'){
    $pkgs = @()
    if($needFfmpeg){ $pkgs += 'ffmpeg' }
    if($needWhisper){ Warn "Scoop bucket for whisper.cpp may not exist; install whisper.cpp manually if missing." }
    if($pkgs.Count -gt 0){ Install-WithScoop -Pkgs $pkgs }
  } else {
    Err "No package manager found (winget/choco/scoop). Please install ffmpeg and whisper.cpp manually."
  }
}

function ModelFile([string]$m){
  switch($m){
    'tiny' { 'ggml-tiny.bin' }
    'base' { 'ggml-base.bin' }
    'small' { 'ggml-small.bin' }
    'medium' { 'ggml-medium.bin' }
    'large' { 'ggml-large-v3.bin' }
    default { '' }
  }
}

if($Model -ne 'none'){
  $mf = ModelFile $Model
  if($mf -eq ''){ throw "Unknown model: $Model" }
  $target = Join-Path $ModelDir $mf
  if(Test-Path $target){
    Ok "Model already exists: $target"
  } else {
    $url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$mf"
    Info "Downloading model $Model from $url"
    Invoke-WebRequest -Uri $url -OutFile $target
    Ok "Model downloaded: $target"
  }
} else {
  Warn "Skipping model download"
}

Ok "Done. Use WSL bash script or run whisper-cli directly on Windows. Skill dir: $SkillDir"
