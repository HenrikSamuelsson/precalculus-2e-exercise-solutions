# build.ps1 — Recursively compile all .tex files into ./build with tectonic
# Robust: copies style files next to each .tex (and into a local styles/ subfolder)
# so \usepackage{exercise-style-cmbright} and \usepackage{styles/exercise-style-cmbright} both work.

param(
  [switch]$KeepIntermediates
)

$root     = $PSScriptRoot
$buildDir = Join-Path $root "build"
if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }

# Where canonical styles live
$rootStylesDir   = $root
$extraStylesDir  = Join-Path $root "styles"

# Gather style files from root and styles/
$rootStyFiles  = @()
$extraStyFiles = @()

if (Test-Path $rootStylesDir)  { $rootStyFiles  = Get-ChildItem -Path $rootStylesDir  -Filter *.sty -File -ErrorAction SilentlyContinue }
if (Test-Path $extraStylesDir) { $extraStyFiles = Get-ChildItem -Path $extraStylesDir -Filter *.sty -File -ErrorAction SilentlyContinue }

if (($rootStyFiles.Count + $extraStyFiles.Count) -eq 0) {
  Write-Warning "No .sty files found in '$root' or '$extraStylesDir'. If you use a custom style, place it in one of these."
}

# Find all .tex files recursively (skip build/)
$texFiles = Get-ChildItem -Recurse -Filter *.tex | Where-Object { $_.FullName -notlike "$buildDir*" }

if ($texFiles.Count -eq 0) {
  Write-Host "No .tex files found under $root"
  exit 0
}

function Ensure-LocalStyles {
  param(
    [string]$targetDir
  )
  # 1) Copy any root-level .sty directly into the targetDir
  foreach ($sty in $rootStyFiles) {
    $dst = Join-Path $targetDir $sty.Name
    if (-not (Test-Path $dst)) {
      Copy-Item -Path $sty.FullName -Destination $dst -Force
    }
  }
  # 2) Copy styles/*.sty into targetDir\styles\
  if ($extraStyFiles.Count -gt 0) {
    $localStyles = Join-Path $targetDir "styles"
    if (-not (Test-Path $localStyles)) { New-Item -ItemType Directory -Path $localStyles | Out-Null }
    foreach ($sty in $extraStyFiles) {
      $dst = Join-Path $localStyles $sty.Name
      if (-not (Test-Path $dst)) {
        Copy-Item -Path $sty.FullName -Destination $dst -Force
      }
    }
  }
}

foreach ($file in $texFiles) {
  $fileDir = Split-Path $file.FullName -Parent

  # Make sure styles are reachable from this file’s folder
  Ensure-LocalStyles -targetDir $fileDir

  Write-Host "Compiling $($file.FullName)..."
  $args = @("--outdir", $buildDir, $file.FullName)
  if ($KeepIntermediates) { $args += "--keep-intermediates" }

  tectonic @args
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Compilation failed for $($file.FullName)"
    exit 1
  }
}

Write-Host "All done. PDFs are in: $buildDir"
