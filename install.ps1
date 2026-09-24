#!/usr/bin/env pwsh
# Installe la bibliothèque claude-engineering-lib dans le dépôt courant.
# Usage:
#   iwr -useb https://raw.githubusercontent.com/dogbojoel30/claude-engineering-lib/main/install.ps1 | iex
#   $env:CLAUDE_LIB_FORCE=1; iwr -useb .../install.ps1 | iex
#
# Ou en local:
#   .\install.ps1 -Force -Version v1.2.0 -TargetDir .

param(
    [switch]$Force,
    [string]$Version = "",
    [string]$TargetDir = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$Repo = "dogbojoel30/claude-engineering-lib"

if (-not $Version) {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -ErrorAction Stop
        $Version = $release.tag_name
    } catch {
        $Version = ""
    }
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    if ($Version) {
        Write-Host "Téléchargement de $Repo@$Version..."
        $archiveUrl = "https://github.com/$Repo/archive/refs/tags/$Version.tar.gz"
    } else {
        Write-Host "Aucune release trouvée, téléchargement de la branche main..."
        $archiveUrl = "https://github.com/$Repo/archive/refs/heads/main.tar.gz"
    }

    $archivePath = Join-Path $tmpDir "lib.tar.gz"
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing

    tar -xzf $archivePath -C $tmpDir
    $srcDir = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1

    $copyItems = @("agents", "skills", "standards", "templates", "workflows")
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

    foreach ($item in $copyItems) {
        $srcItem = Join-Path $srcDir.FullName $item
        $dstItem = Join-Path $TargetDir $item
        if (Test-Path $srcItem) {
            if ((Test-Path $dstItem) -and (-not $Force)) {
                Write-Host "⚠️  $item/ existe déjà, ignoré (utilise -Force pour écraser)."
            } else {
                if (Test-Path $dstItem) { Remove-Item $dstItem -Recurse -Force }
                Copy-Item $srcItem $dstItem -Recurse
                Write-Host "✅ $item/ installé."
            }
        }
    }

    $dstClaudeMd = Join-Path $TargetDir "CLAUDE.md"
    $srcClaudeMd = Join-Path $srcDir.FullName "CLAUDE.md"
    if ((Test-Path $dstClaudeMd) -and (-not $Force)) {
        Copy-Item $srcClaudeMd (Join-Path $TargetDir "CLAUDE.md.claude-engineering-lib") -Force
        Write-Host "⚠️  CLAUDE.md existe déjà. Le fichier de la bibliothèque a été copié sous CLAUDE.md.claude-engineering-lib — fusionne-le manuellement."
    } else {
        Copy-Item $srcClaudeMd $dstClaudeMd -Force
        Write-Host "✅ CLAUDE.md installé."
    }

    Write-Host ""
    Write-Host "Installation terminée dans: $TargetDir"
} finally {
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
