# build.ps1 - Compile all .tex files in current folder into ./build using tectonic

# Ensure build folder exists
$buildDir = Join-Path (Get-Location) "build"
if (-Not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

# Find all .tex files in the current folder
$texFiles = Get-ChildItem -Filter *.tex

if ($texFiles.Count -eq 0) {
    Write-Host "No .tex files found in current folder."
    exit 1
}

# Compile each .tex file into build/
foreach ($file in $texFiles) {
    Write-Host "Compiling $($file.Name)..."
    tectonic --outdir $buildDir $file.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compilation failed for $($file.Name)"
        exit 1
    }
}
