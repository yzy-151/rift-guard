param(
    [string]$GodotExe = "$env:USERPROFILE\Desktop\codex\tools\godot-4.6\Godot_v4.6-stable_win64_console.exe",
    [string]$ExportTemplate = "$env:USERPROFILE\Desktop\codex\rift-guard\astra-2026-10-03\windows_release_x86_64.exe",
    [string]$OutputDirectory = ""
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'releases\V94' }
# Godot resolves relative export paths against game/, while PowerShell uses
# the caller's directory. Resolve once so EXE, PCK and docs always stay together.
$OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $GodotExe)) { throw "Godot executable not found: $GodotExe" }
if (-not (Test-Path -LiteralPath $ExportTemplate)) { throw "Official Windows release template not found: $ExportTemplate" }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$pack = Join-Path $OutputDirectory 'RiftGuard-V94.pck'
& $GodotExe --headless --path (Join-Path $projectRoot 'game') --export-pack 'Windows Desktop' $pack
if ($LASTEXITCODE -ne 0) { throw "Godot pack export failed with exit code $LASTEXITCODE" }
Copy-Item -LiteralPath $ExportTemplate -Destination (Join-Path $OutputDirectory 'RiftGuard-V94.exe') -Force
foreach ($document in @('V94-游玩与改动.md', 'V91-游玩与改动.md', 'STARFALL-游玩说明.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $document) -Destination $OutputDirectory -Force
}
$docsOutput = Join-Path $OutputDirectory 'docs'
New-Item -ItemType Directory -Force -Path $docsOutput | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\v94-validation') -Destination $docsOutput -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\v91-validation') -Destination $docsOutput -Recurse -Force
$audioOutput = Join-Path $OutputDirectory 'audio-provenance'
New-Item -ItemType Directory -Force -Path $audioOutput | Out-Null
foreach ($document in @('README.md', 'manifest.json', 'licenses')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "game\assets\audio_v91\$document") -Destination $audioOutput -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'game\assets\world\v92\README.md') -Destination (Join-Path $OutputDirectory '场景素材来源.md') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'game\assets\world\v92-devices\README.md') -Destination (Join-Path $OutputDirectory '机关素材来源.md') -Force
Write-Host "Built: $OutputDirectory"
Write-Host 'Keep RiftGuard-V94.exe and RiftGuard-V94.pck in the same directory.'
