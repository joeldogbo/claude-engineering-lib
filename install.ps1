#!/usr/bin/env pwsh
# Installe la bibliotheque claude-engineering-lib dans le depot courant.
# Usage:
#   iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1 | iex
#   $env:CLAUDE_LIB_FORCE=1; iwr -useb .../install.ps1 | iex
#
# Ou en local:
#   .\install.ps1 -Force -Version v1.2.0 -TargetDir .
#
# Ce fichier doit rester en ASCII pur : sous Windows PowerShell 5.1, `iwr | iex` ne
# decode pas le script en UTF-8 et corrompt tout caractere accentue. Les accents et
# symboles affiches sont construits a partir de leur code Unicode ([char]0x...).

param(
    [switch]$Force,
    [string]$Version = "",
    [string]$TargetDir = (Get-Location).Path
)

# Bloc isole : lance via `iex`, le script s'execute dans la session de l'utilisateur.
# Ce bloc evite d'y laisser variables, fonctions et preferences modifiees.
& {
    $ErrorActionPreference = "Stop"
    $ProgressPreference = "SilentlyContinue"
    $Repo = "joeldogbo/claude-engineering-lib"
    if ($env:CLAUDE_LIB_FORCE) { $Force = $true }

    # --- Caracteres non ASCII ---
    $e     = [char]0x00E9   # e accent aigu
    $eg    = [char]0x00E8   # e accent grave
    $ag    = [char]0x00E0   # a accent grave
    $Pixel = [string][char]0x2588 * 2
    $Arrow = [char]0x2192
    $Star  = [char]0x2605

    # --- Couleurs ANSI 256, desactivees si le terminal ne les gere pas ---
    $UseColor = (-not $env:NO_COLOR) -and [bool]$Host.UI.SupportsVirtualTerminal
    $Esc       = [char]27
    $Green     = '38;5;41'
    $Gray      = '38;5;245'
    $Yellow    = '38;5;214'
    $Red       = '38;5;203'
    $BadgeOk   = '1;38;5;16;48;5;41'
    $BadgeWarn = '1;38;5;16;48;5;214'
    $BadgeErr  = '1;97;48;5;160'
    $Width     = 46
    $State     = @{ TaskPending = $false }

    function Paint([string]$Text, [string]$Style) {
        if ($UseColor) { return "$Esc[${Style}m$Text$Esc[0m" }
        return $Text
    }

    function Show-Banner([string]$Label) {
        $rows = @(
            ' XXXX X      XXX  X   X XXXX  XXXXX',
            'X     X     X   X X   X X   X X    ',
            'X     X     XXXXX X   X X   X XXXX ',
            'X     X     X   X X   X X   X X    ',
            ' XXXX XXXXX X   X  XXX  XXXX  XXXXX'
        )
        $shades = @('38;5;120', '38;5;84', '38;5;48', '38;5;41', '38;5;35')
        Write-Host ""
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $line = $rows[$i].Replace(' ', '  ').Replace('X', $Pixel)
            Write-Host ("  " + (Paint $line $shades[$i]))
        }
        Write-Host ""
        Write-Host ("  " + (Paint "E N G I N E E R I N G   L I B" "1;$Green") + "  " + (Paint $Label $Gray))
        Write-Host ("  " + (Paint "Agents, skills & workflows pour Claude Code, quelle que soit la stack." $Gray))
        Write-Host ("  " + (Paint "by" $Gray) + " " + (Paint "joeldogbo" "1;$Green"))
        Write-Host ""
    }

    function Write-TaskStart([string]$Label, [string]$Detail = "") {
        $used = $Label.Length
        if ($Detail) { $used += $Detail.Length + 1 }
        $dots = '.' * [Math]::Max(3, $Width - $used)
        $text = "  " + (Paint $Label '1')
        if ($Detail) { $text += " " + (Paint $Detail $Gray) }
        Write-Host -NoNewline ($text + " " + (Paint $dots $Gray) + " ")
        $State.TaskPending = $true
    }

    function Write-TaskEnd([string]$Status) {
        $style = switch ($Status) { 'DONE' { "1;$Green" } 'FAIL' { "1;$Red" } default { "1;$Yellow" } }
        Write-Host (Paint $Status $style)
        $State.TaskPending = $false
    }

    function Invoke-Download([string]$Url, [string]$OutFile) {
        $client = New-Object System.Net.WebClient
        $client.Headers.Add('User-Agent', 'claude-engineering-lib-installer')
        try {
            $task = $client.DownloadFileTaskAsync($Url, $OutFile)
            $frames = if ($UseColor) {
                0x280B, 0x2819, 0x2839, 0x2838, 0x283C, 0x2834, 0x2826, 0x2827, 0x2807, 0x280F | ForEach-Object { [string][char]$_ }
            } else { '|', '/', '-', '\' }
            $i = 0
            $animate = -not [Console]::IsOutputRedirected
            while (-not $task.IsCompleted) {
                if ($animate) { Write-Host -NoNewline ((Paint $frames[$i % $frames.Count] $Green) + "`b") }
                $i++
                Start-Sleep -Milliseconds 80
            }
            if ($animate) { Write-Host -NoNewline " `b" }
            if ($task.IsFaulted) { throw $task.Exception.InnerException }
        } finally {
            $client.Dispose()
        }
    }

    $prevEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if (-not $Version) {
        try {
            $Version = (Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest").tag_name
        } catch {
            $Version = ""
        }
    }

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        if ($Version) {
            Show-Banner $Version
            $archiveUrl = "https://github.com/$Repo/archive/refs/tags/$Version.tar.gz"
            Write-TaskStart "T${e}l${e}chargement" $Version
        } else {
            Show-Banner "main"
            $archiveUrl = "https://github.com/$Repo/archive/refs/heads/main.tar.gz"
            Write-TaskStart "T${e}l${e}chargement" "main (aucune release)"
        }

        $archivePath = Join-Path $tmpDir "lib.tar.gz"
        Invoke-Download $archiveUrl $archivePath
        tar -xzf $archivePath -C $tmpDir
        if ($LASTEXITCODE -ne 0) { throw "Extraction de l'archive impossible (tar a ${e}chou${e})." }
        Write-TaskEnd 'DONE'
        Write-Host ""

        $srcDir = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
        $copyItems = @("agents", "skills", "standards", "templates", "workflows")
        $skipped = @()
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

        foreach ($item in $copyItems) {
            $srcItem = Join-Path $srcDir.FullName $item
            $dstItem = Join-Path $TargetDir $item
            if (-not (Test-Path $srcItem)) { continue }

            Write-TaskStart "$item/" ("(" + @(Get-ChildItem $srcItem).Count + ")")
            if ((Test-Path $dstItem) -and (-not $Force)) {
                $skipped += "$item/"
                Write-TaskEnd 'SKIP'
            } else {
                if (Test-Path $dstItem) { Remove-Item $dstItem -Recurse -Force }
                Copy-Item $srcItem $dstItem -Recurse
                Write-TaskEnd 'DONE'
            }
        }

        $dstClaudeMd = Join-Path $TargetDir "CLAUDE.md"
        $srcClaudeMd = Join-Path $srcDir.FullName "CLAUDE.md"
        $claudeMdKept = (Test-Path $dstClaudeMd) -and (-not $Force)
        Write-TaskStart "CLAUDE.md"
        if ($claudeMdKept) {
            Copy-Item $srcClaudeMd (Join-Path $TargetDir "CLAUDE.md.claude-engineering-lib") -Force
            Write-TaskEnd 'MERGE'
        } else {
            Copy-Item $srcClaudeMd $dstClaudeMd -Force
            Write-TaskEnd 'DONE'
        }

        Write-Host ""
        Write-Host ("  " + (Paint " SUCCESS " $BadgeOk) + " Biblioth${eg}que install${e}e dans " + (Paint $TargetDir '1'))
        if ($skipped) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " D${e}j${ag} pr${e}sents, conserv${e}s : " + ($skipped -join ', ') + ". Relance avec " + (Paint '-Force' '1') + " pour les ${e}craser.")
        }
        if ($claudeMdKept) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " CLAUDE.md existant conserv${e} : la version de la biblioth${eg}que est dans " + (Paint 'CLAUDE.md.claude-engineering-lib' '1') + ", ${ag} fusionner.")
        }
        Write-Host ""
        Write-Host ("  " + (Paint $Arrow $Green) + " Ouvre Claude Code ici, puis lance " + (Paint "/workflow feature-development" "1;$Green"))
        Write-Host ("  " + (Paint $Star $Green) + " " + (Paint "github.com/$Repo" $Gray))
        Write-Host ""
    } catch {
        if ($State.TaskPending) { Write-TaskEnd 'FAIL' }
        Write-Host ""
        Write-Host ("  " + (Paint " ERREUR " $BadgeErr) + " " + $_.Exception.Message)
        Write-Host ""
    } finally {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        try { [Console]::OutputEncoding = $prevEncoding } catch {}
    }
}
