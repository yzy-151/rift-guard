param(
    [string]$GodotExe = "$env:USERPROFILE\Desktop\codex\tools\godot-4.6\Godot_v4.6-stable_win64_console.exe",
    [string]$ExportTemplate = "$env:USERPROFILE\Desktop\codex\rift-guard\astra-2026-10-03\windows_release_x86_64.exe",
    [string]$OutputDirectory = ""
)
# Compatibility entry: Starfall now ships inside the V86-enhanced game.
& (Join-Path $PSScriptRoot 'build_v86_enhanced.ps1') @PSBoundParameters
