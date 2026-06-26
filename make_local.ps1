$ErrorActionPreference = "Stop"

$src = Join-Path $PSScriptRoot "mods"
$workshop = Join-Path $env:USERPROFILE "Zomboid\Workshop\Deadline_Modpacked_Mods_local"
$contents = Join-Path $workshop "Contents"
$dst = Join-Path $contents "mods"

if (-not (Test-Path -LiteralPath $src)) { throw "Missing source folder: $src" }

Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force

Get-ChildItem -LiteralPath $dst -Recurse -Filter "mod.info" | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw
    $text = $text -replace "Deadline", "Deadline_local" -replace "_DL", "_DL_local"
    Set-Content -LiteralPath $_.FullName -Value $text -NoNewline -Encoding UTF8
}

Write-Host "Deployed local workshop mods to $dst"
