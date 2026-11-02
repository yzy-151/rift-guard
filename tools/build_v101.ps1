param(
    [Parameter(Mandatory=$true)][string]$GodotExe,
    [Parameter(Mandatory=$true)][string]$ExportTemplate,
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'releases/V101' }
$OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
foreach ($inputPath in @($GodotExe, $ExportTemplate)) {
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { throw "Missing build input: $inputPath" }
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
& $GodotExe --headless --path (Join-Path $projectRoot 'game') --export-pack 'Windows Desktop' (Join-Path $OutputDirectory 'RiftGuard-V101.pck')
if ($LASTEXITCODE -ne 0) { throw "Export failed: $LASTEXITCODE" }
Copy-Item -LiteralPath $ExportTemplate -Destination (Join-Path $OutputDirectory 'RiftGuard-V101.exe')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/v101-release-notes.md') -Destination (Join-Path $OutputDirectory 'V101-游玩与改动.md')
$audioOutput = Join-Path $OutputDirectory 'audio-provenance'
New-Item -ItemType Directory -Force -Path $audioOutput | Out-Null
foreach ($document in @('README.md','manifest.json','licenses')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "game/assets/audio_v91/$document") -Destination $audioOutput -Recurse
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'game/assets/world/v92/README.md') -Destination (Join-Path $OutputDirectory '场景素材来源.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'game/assets/world/v92-devices/README.md') -Destination (Join-Path $OutputDirectory '机关素材来源.md')
& python (Join-Path $PSScriptRoot 'v101_evidence.py') --build-directory $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw 'Could not bind build to source and binary hashes' }
Write-Output "Built: $OutputDirectory"
