param(
    [string]$GodotExe = "$env:USERPROFILE\Desktop\codex\tools\godot-4.6\Godot_v4.6-stable_win64_console.exe",
    [string]$ExportTemplate = "$env:USERPROFILE\Desktop\codex\rift-guard\astra-2026-10-03\windows_release_x86_64.exe",
    [string]$OutputDirectory = ""
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'releases\V86-Enhanced' }
if (-not (Test-Path -LiteralPath $GodotExe)) { throw "Godot executable not found: $GodotExe" }
if (-not (Test-Path -LiteralPath $ExportTemplate)) { throw "Official Windows release template not found: $ExportTemplate" }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$pack = Join-Path $OutputDirectory 'RiftGuard-V86-Enhanced.pck'
& $GodotExe --headless --path (Join-Path $projectRoot 'game') --export-pack 'Windows Desktop' $pack
if ($LASTEXITCODE -ne 0) { throw "Godot pack export failed with exit code $LASTEXITCODE" }
Copy-Item -LiteralPath $ExportTemplate -Destination (Join-Path $OutputDirectory 'RiftGuard-V86-Enhanced.exe') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'V86-动效增强说明.md') -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'STARFALL-游玩说明.md') -Destination $OutputDirectory -Force
foreach ($reportName in @('v86-enhanced-validation', 'starfall-validation')) {
    $validationPath = Join-Path $projectRoot "docs\$reportName"
    if (Test-Path -LiteralPath $validationPath) {
        $docsOutput = Join-Path $OutputDirectory 'docs'
        New-Item -ItemType Directory -Force -Path $docsOutput | Out-Null
        Copy-Item -LiteralPath $validationPath -Destination $docsOutput -Recurse -Force
    }
}
Write-Host "Built: $OutputDirectory"
Write-Host 'Keep the EXE and PCK in the same directory.'
