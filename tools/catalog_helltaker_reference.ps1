param(
    [Parameter(Mandatory = $true)]
    [string]$ExportedPath
)

$resolved = Resolve-Path -LiteralPath $ExportedPath -ErrorAction Stop
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $projectRoot 'research\helltaker-reference'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$extensions = @('.png', '.jpg', '.jpeg', '.wav', '.ogg', '.mp3', '.ttf', '.otf', '.anim', '.controller')
$rows = Get-ChildItem -LiteralPath $resolved -Recurse -File |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($resolved.Path, $_.FullName)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        [pscustomobject]@{
            RelativePath = $relative
            Extension = $_.Extension.ToLowerInvariant()
            Bytes = $_.Length
            SHA256 = $hash
        }
    }

$catalogPath = Join-Path $outputRoot 'catalog.csv'
$rows | Sort-Object Extension, RelativePath | Export-Csv -LiteralPath $catalogPath -NoTypeInformation -Encoding utf8BOM
Write-Host "Cataloged $($rows.Count) reference files to $catalogPath"
