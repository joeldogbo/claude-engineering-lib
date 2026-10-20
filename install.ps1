#!/usr/bin/env pwsh
# Installe la bibliotheque claude-engineering-lib dans le dossier .claude/ du depot courant.
# Fonctionne avec Windows PowerShell 5.1 et PowerShell 7+ (Windows, macOS, Linux).
#
# Usage:
#   iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1 | iex
#   $env:CLAUDE_LIB_FORCE=1; iwr -useb .../install.ps1 | iex
#   & ([scriptblock]::Create((iwr -useb .../install.ps1))) -Force -Version v1.2.0
#
# Ou en local:
#   .\install.ps1 -Update                     # met a jour une installation existante
#   .\install.ps1 -DryRun                     # montre ce qui changerait, sans rien ecrire
#   .\install.ps1 -Force -Version v1.2.0 -TargetDir .
#   .\install.ps1 -Source .\claude-engineering-lib    # depuis une copie locale (tests, CI)
# En une commande : $env:CLAUDE_LIB_UPDATE=1 ou $env:CLAUDE_LIB_DRY_RUN=1 avant iwr ... | iex.
#
# Choix des agents (groupes et profils decrits dans profiles.conf) :
#   -Type web|mobile|api|desktop|library   agents adaptes au type de projet
#   -Groups security,performance           groupes d'agents (core est toujours installe)
#   -Agents seo,geo                        agents precis, a ajouter a une installation existante
#   -All                                   tous les agents
#   -Yes                                   sans menu : type detecte (tout si rien n'est reconnu)
# Sans option, un menu propose le type detecte dans le projet. Pour l'installation en une
# commande, les memes choix passent par les variables d'environnement CLAUDE_LIB_TYPE,
# CLAUDE_LIB_GROUPS, CLAUDE_LIB_AGENTS, CLAUDE_LIB_ALL=1 et CLAUDE_LIB_YES=1.
#
# Mise a jour : relancer l'installateur dans un projet deja equipe le met a jour (-Update
# l'exige). Le manifeste .claude/.claude-lib.manifest (meme format qu'install.sh) garde la
# version et l'empreinte de chaque fichier installe, ce qui permet, pour chaque fichier :
#   - inchange chez toi, nouvelle version dans la bibliotheque -> remplace (ancien sauvegarde) ;
#   - modifie chez toi -> conserve, nouvelle version dans .claude/updates/<fichier>.new
#     (-Force le remplace, apres sauvegarde) ;
#   - retire de la bibliotheque -> supprime s'il n'a pas ete modifie, conserve sinon ;
#   - agent supprime par toi -> pas reinstalle (sauf -Agents <nom>) ;
#   - nouvel agent d'un groupe installe -> ajoute ; tes propres fichiers -> jamais touches.
# Revenir a une version plus ancienne que celle installee exige -Force.
# Toute erreur ou interruption en cours d'ecriture restaure l'etat d'avant ; les fichiers
# remplaces restent dans .claude/backups/<date>/ (les 5 dernieres sauvegardes sont gardees).
# Ne pas ecrire ici la commande en une ligne suivie d'un commentaire : Windows Defender (AMSI)
# a bloque tout le script pour cette seule phrase (constate sous Windows 11, octobre 2026).
#
# Ce fichier doit rester en ASCII pur : sous Windows PowerShell 5.1, `iwr | iex` ne
# decode pas le script en UTF-8 et corrompt tout caractere accentue. Les accents et
# symboles affiches sont construits a partir de leur code Unicode ([char]0x...).

param(
    [switch]$Force,
    [switch]$Update,
    [switch]$DryRun,
    [string]$Version = "",
    [string]$TargetDir = (Get-Location).Path,
    # Copie locale de la bibliotheque a installer a la place du telechargement (tests, CI, depot clone).
    [string]$Source = "",
    [string]$Type = "",
    [string]$Groups = "",
    [string]$Agents = "",
    [switch]$All,
    [switch]$Yes
)

# Resultat lu apres le bloc : un echec ne ferme jamais la fenetre de l'utilisateur
# (lancement via iex), mais renvoie le code 1 quand le script est lance comme fichier.
$__claudeLibInstall = @{ Failed = $false }

# Bloc isole : lance via `iex`, le script s'execute dans la session de l'utilisateur.
# Ce bloc evite d'y laisser variables, fonctions et preferences modifiees.
& {
    $ErrorActionPreference = "Stop"
    $ProgressPreference = "SilentlyContinue"
    $Repo = "joeldogbo/claude-engineering-lib"
    if ($env:CLAUDE_LIB_FORCE) { $Force = $true }
    if ($env:CLAUDE_LIB_UPDATE -eq '1') { $Update = $true }
    if ($env:CLAUDE_LIB_DRY_RUN -eq '1') { $DryRun = $true }
    if ($env:CLAUDE_LIB_ALL -eq '1') { $All = $true }
    if ($env:CLAUDE_LIB_YES -eq '1') { $Yes = $true }
    if (-not $Type -and $env:CLAUDE_LIB_TYPE) { $Type = $env:CLAUDE_LIB_TYPE }
    if (-not $Groups -and $env:CLAUDE_LIB_GROUPS) { $Groups = $env:CLAUDE_LIB_GROUPS }
    if (-not $Agents -and $env:CLAUDE_LIB_AGENTS) { $Agents = $env:CLAUDE_LIB_AGENTS }

    # --- Caracteres non ASCII ---
    $e     = [char]0x00E9   # e accent aigu
    $eg    = [char]0x00E8   # e accent grave
    $ag    = [char]0x00E0   # a accent grave
    $ac    = [char]0x00E2   # a accent circonflexe
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
    $o     = [char]0x00F4   # o accent circonflexe
    $Dot   = [char]0x00B7
    $Width     = 46
    $State     = @{ TaskPending = $false; Tries = 0; Answers = $null; AnswerIndex = 0 }
    $Utf8      = New-Object System.Text.UTF8Encoding $false

    function Paint([string]$Text, [string]$Style) {
        if ($UseColor) { return "$Esc[${Style}m$Text$Esc[0m" }
        return $Text
    }

    # Banniere DOGBO Engineering Library : logo "D" au </> en degrade bleu, puis DOGBO en blanc.
    # Un pixel = deux caracteres ; "C" marque les trois pixels du </>. Largeur : 78 colonnes.
    function Show-Banner([string]$Label) {
        $logo = @('XXXXX  ', 'XX  XX ', 'XX   XX', 'XXCXX', 'XX   XX', 'XX  XX ', 'XXXXX  ')
        $word = @(
            '                             ',
            'XXXX   XXX   XXXX XXXX   XXX ',
            'X   X X   X X     X   X X   X',
            'X   X X   X X  XX XXXX  X   X',
            'X   X X   X X   X X   X X   X',
            'XXXX   XXX   XXXX XXXX   XXX ',
            '                             '
        )
        $shades = @('38;5;51', '38;5;45', '38;5;39', '38;5;33', '38;5;33', '38;5;27', '38;5;27')
        $toPixels = { param([string]$Row) $Row.Replace(' ', '  ').Replace('X', $Pixel) }
        Write-Host ""
        for ($i = 0; $i -lt $logo.Count; $i++) {
            $parts = $logo[$i].Split('C')
            $mark = Paint (& $toPixels $parts[0]) $shades[$i]
            if ($parts.Count -gt 1) { $mark += (Paint ' </>  ' '1;97') + (Paint (& $toPixels $parts[1]) $shades[$i]) }
            Write-Host ("  " + $mark + "    " + (Paint (& $toPixels $word[$i]) '1;97'))
        }
        Write-Host ""
        Write-Host ("  " + (Paint "E N G I N E E R I N G   L I B R A R Y" '1;38;5;39') + "  " + (Paint $Label $Gray))
        Write-Host ("  " + (Paint "La biblioth${eg}que d'agents IA, de comp${e}tences et de workflows" '38;5;45'))
        Write-Host ("  " + (Paint "pour le d${e}veloppement logiciel." '38;5;45'))
        Write-Host ("  " + (Paint "Code $Dot Automatise $Dot Construis l'avenir $([char]0x2014) by" $Gray) + " " + (Paint "joeldogbo" '1;38;5;39'))
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

    # Derniere release via la redirection de github.com/<repo>/releases/latest :
    # contrairement a l'API GitHub, elle n'est pas limitee a 60 appels par heure.
    # Renvoie "" si le depot n'a encore aucune release.
    function Resolve-LatestVersion {
        try {
            $request = [Net.WebRequest]::Create("https://github.com/$Repo/releases/latest")
            $request.Method = 'HEAD'
            $request.UserAgent = 'claude-engineering-lib-installer'
            $response = $request.GetResponse()
            try { $finalUrl = $response.ResponseUri.AbsoluteUri } finally { $response.Close() }
        } catch {
            throw "Impossible de joindre GitHub pour trouver la derni${eg}re version ($($_.Exception.Message))."
        }
        if ($finalUrl -match '/releases/tag/([^/?#]+)$') { return [Uri]::UnescapeDataString($Matches[1]) }
        return ""
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

    # --- Choix des agents : groupes et profils de profiles.conf, groupe de chaque agent ---
    function Read-Profiles([string]$Path) {
        $conf = @{ Groups = @(); Profiles = @() }
        foreach ($line in [IO.File]::ReadAllLines($Path, $Utf8)) {
            $f = $line.TrimEnd("`r").Split('|')
            if ($f[0] -eq 'group' -and $f.Count -ge 3) {
                $conf.Groups += [pscustomobject]@{ Name = $f[1]; Desc = $f[2] }
            } elseif ($f[0] -eq 'profile' -and $f.Count -ge 4) {
                $conf.Profiles += [pscustomobject]@{ Name = $f[1]; Desc = $f[2]; Groups = @($f[3].Split(' ') | Where-Object { $_ }) }
            }
        }
        return $conf
    }

    function Get-AgentTable([string]$AgentsDir) {
        foreach ($file in Get-ChildItem -Path $AgentsDir -Filter *.md | Sort-Object Name) {
            $lines = [IO.File]::ReadAllLines($file.FullName, $Utf8)
            $group = ''
            if ($lines.Count -and $lines[0].TrimEnd() -eq '---') {
                for ($i = 1; $i -lt $lines.Count -and $lines[$i].TrimEnd() -ne '---'; $i++) {
                    if ($lines[$i] -match '^group:\s*(\S+)') { $group = $Matches[1] }
                }
            }
            [pscustomobject]@{ Name = $file.BaseName; Group = $group }
        }
    }

    function Get-AgentsOfGroups($Table, [string[]]$Names) {
        return @($Table | Where-Object { $_.Group -and ($Names -contains $_.Group) } | ForEach-Object { $_.Name })
    }

    # Type de projet d'apres les fichiers presents : @(type, raison), ou $null.
    function Get-ProjectType([string]$Dir) {
        $pkgPath = Join-Path $Dir 'package.json'
        $pkg = if (Test-Path $pkgPath) { [IO.File]::ReadAllText($pkgPath) } else { '' }
        $hasDep = { param([string[]]$Names) @($Names | Where-Object { $pkg.Contains('"' + $_) }).Count -gt 0 }
        $csproj = @(Get-ChildItem -Path $Dir -Filter *.csproj -ErrorAction SilentlyContinue)
        $inDir = { param([string[]]$Names) @($Names | Where-Object { Test-Path (Join-Path $Dir $_) }).Count -gt 0 }
        if (& $inDir @('pubspec.yaml')) { return @('mobile', 'pubspec.yaml (Flutter)') }
        if (& $hasDep @('react-native', 'expo"', '@capacitor/', '@ionic/')) { return @('mobile', 'package.json (mobile)') }
        if ((& $inDir @('app/src/main/AndroidManifest.xml')) -or ((& $inDir @('ios')) -and (& $inDir @('android'))) -or
            @(Get-ChildItem -Path $Dir -Filter *.xcodeproj -Directory -ErrorAction SilentlyContinue).Count) {
            return @('mobile', 'projet Android ou iOS')
        }
        if ((& $hasDep @('electron"', '@tauri-apps/')) -or (& $inDir @('src-tauri'))) { return @('desktop', 'Electron ou Tauri') }
        if (@($csproj | Where-Object { [IO.File]::ReadAllText($_.FullName) -match '<Use(WPF|WindowsForms)>true' }).Count) { return @('desktop', 'WPF ou WinForms') }
        if (& $hasDep @('react"', 'vue"', '@angular/core', 'svelte', 'next"', 'nuxt', 'astro', 'vite"')) { return @('web', 'package.json (front web)') }
        if (& $inDir @('composer.json', 'manage.py', 'Gemfile', 'index.html')) { return @('web', "framework web c${o}t${e} serveur") }
        if ((& $inDir @('go.mod', 'pom.xml', 'build.gradle', 'build.gradle.kts', 'requirements.txt', 'package.json')) -or $csproj.Count) {
            return @('api', "backend sans interface d${e}tect${e}e")
        }
        if (& $inDir @('Cargo.toml', 'pyproject.toml', 'setup.py', 'CMakeLists.txt')) { return @('library', "biblioth${eg}que ou CLI") }
        return $null
    }

    # Reponse lue sur la console ; CLAUDE_LIB_TTY (un fichier, une reponse par ligne) la remplace (tests).
    function Read-Answer([string]$Question, [string]$Default) {
        Write-Host -NoNewline ("  " + (Paint $Question '1') + " " + (Paint "[$Default]" $Gray) + " ")
        if ($null -ne $State.Answers) {
            $reply = if ($State.AnswerIndex -lt $State.Answers.Count) { $State.Answers[$State.AnswerIndex] } else { $null }
            $State.AnswerIndex++
            Write-Host $reply
        } else {
            $reply = [Console]::ReadLine()
        }
        if (-not $reply -or -not $reply.Trim()) { return $Default }
        return $reply.Trim()
    }

    # Au-dela de 3 reponses invalides, l'installation s'arrete au lieu de boucler.
    function Write-Retry([string]$Message) {
        $State.Tries++
        if ($State.Tries -ge 3) { throw "Choix invalide. Relance avec -Type, -Groups, -Agents ou -All." }
        Write-Host ("  " + (Paint $Message $Yellow))
    }

    # Menu : renvoie @{ Type; All; Groups; Agents }.
    function Show-Menu($Conf, $Table, $Detected) {
        $choice = @{ Type = ''; All = $false; Groups = @(); Agents = @() }
        Write-Host ""
        if ($Detected) {
            Write-Host ("  Type de projet d${e}tect${e} : " + (Paint $Detected[0] "1;$Green") + " " + (Paint "($($Detected[1]))" $Gray))
        } else {
            Write-Host "  Aucun type de projet reconnu dans ce dossier."
        }
        Write-Host ""
        $profiles = @($Conf.Profiles)
        $default = $profiles.Count + 1
        for ($i = 0; $i -lt $profiles.Count; $i++) {
            $p = $profiles[$i]
            if ($Detected -and $p.Name -eq $Detected[0]) { $default = $i + 1 }
            $n = @(Get-AgentsOfGroups $Table (@('core') + $p.Groups)).Count
            Write-Host ("    " + (Paint ($i + 1) "1;$Green") + "  " + $p.Name.PadRight(10) + " " + (Paint ("{0,2} agents" -f $n) $Gray) + "  " + $p.Desc)
        }
        Write-Host ("    " + (Paint ($profiles.Count + 1) "1;$Green") + "  " + 'tout'.PadRight(10) + " " + (Paint ("{0,2} agents" -f @($Table).Count) $Gray) + "  Tous les agents")
        Write-Host ("    " + (Paint ($profiles.Count + 2) "1;$Green") + "  " + 'sur mesure'.PadRight(10) + " " + (' ' * 9) + "  Choisir les groupes et les agents")
        Write-Host ""
        while ($true) {
            $answer = Read-Answer "Ton choix" "$default"
            $num = 0
            if ([int]::TryParse($answer, [ref]$num) -and $num -ge 1 -and $num -le $profiles.Count + 2) { break }
            Write-Retry "Entre un num${e}ro entre 1 et $($profiles.Count + 2)."
        }
        Write-Host ""
        if ($num -le $profiles.Count) { $choice.Type = $profiles[$num - 1].Name; return $choice }
        if ($num -eq $profiles.Count + 1) { $choice.All = $true; return $choice }

        Write-Host "  Groupes (core est toujours install${e}) :"
        $optional = @($Conf.Groups | Where-Object { $_.Name -ne 'core' })
        for ($i = 0; $i -lt $optional.Count; $i++) {
            $g = $optional[$i]
            $n = @(Get-AgentsOfGroups $Table @($g.Name)).Count
            Write-Host ("    " + (Paint ("{0,2}" -f ($i + 1)) "1;$Green") + "  " + $g.Name.PadRight(12) + " " + (Paint "($n)" $Gray) + "  " + $g.Desc)
        }
        Write-Host ""
        while ($true) {
            $answer = Read-Answer "Num${e}ros des groupes, s${e}par${e}s par des espaces" "aucun"
            if ($answer -eq 'aucun') { break }
            $picked = @(); $valid = $true
            foreach ($token in ($answer -split '\s+' | Where-Object { $_ })) {
                $num = 0
                if ([int]::TryParse($token, [ref]$num) -and $num -ge 1 -and $num -le $optional.Count) { $picked += $optional[$num - 1].Name }
                else { $valid = $false; break }
            }
            if ($valid) { $choice.Groups = $picked; break }
            Write-Retry "Num${e}ros entre 1 et $($optional.Count), s${e}par${e}s par des espaces."
        }
        $extra = Read-Answer "Agents en plus, s${e}par${e}s par des virgules (ex. seo,payments)" "aucun"
        if ($extra -ne 'aucun') { $choice.Agents = @($extra -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        Write-Host ""
        return $choice
    }

    # --- Mise a jour : empreintes, manifeste et journal des ecritures (defait en cas d'echec) ---
    $Sha = [Security.Cryptography.SHA256]::Create()
    function Get-Sha([string]$Path) {
        $stream = [IO.File]::OpenRead($Path)
        try { return ([BitConverter]::ToString($Sha.ComputeHash($stream)) -replace '-', '').ToLowerInvariant() } finally { $stream.Dispose() }
    }

    # Empreinte de chaque chemin (relatif a $Dir) present dans $Dir.
    function Get-Hashes([string]$Dir, $Paths) {
        $hashes = @{}
        foreach ($rel in $Paths) {
            $file = Join-Path $Dir $rel
            if (-not $hashes.ContainsKey($rel) -and (Test-Path -LiteralPath $file -PathType Leaf)) { $hashes[$rel] = Get-Sha $file }
        }
        return $hashes
    }

    # Vrai si la version $A est strictement anterieure a $B (formes vX.Y.Z ; sinon : faux).
    function Test-OlderVersion([string]$A, [string]$B) {
        $x = $A.TrimStart('v'); $y = $B.TrimStart('v')
        if ($x -notmatch '^\d+\.\d+\.\d+$' -or $y -notmatch '^\d+\.\d+\.\d+$') { return $false }
        return ([version]$x) -lt ([version]$y)
    }

    function Add-Journal([string]$Action, [string]$Rel) { [void]$Txn.Journal.Add(@($Action, $Rel)) }

    # Copie le fichier dans la sauvegarde avant qu'il soit remplace ou supprime.
    function Backup-File([string]$Rel) {
        $dst = Join-Path $Txn.BackupDir $Rel
        New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $ClaudeDir $Rel) $dst -Force
        Add-Journal 'saved' $Rel
    }

    function Remove-EmptyDirs {
        foreach ($item in @('agents') + $copyItems) {
            $dir = Join-Path $ClaudeDir $item
            if (-not (Test-Path $dir)) { continue }
            Get-ChildItem $dir -Recurse -Directory -Force | Sort-Object { $_.FullName.Length } -Descending |
                Where-Object { -not (Get-ChildItem $_.FullName -Force) } | Remove-Item -Force
        }
    }

    # Defait les ecritures du journal dans l'ordre inverse : fichiers crees retires, fichiers
    # remplaces ou supprimes recopies depuis la sauvegarde. Au mieux : une erreur n'arrete pas la suite.
    function Undo-Writes {
        for ($i = $Txn.Journal.Count - 1; $i -ge 0; $i--) {
            $act, $rel = $Txn.Journal[$i]
            $file = Join-Path $ClaudeDir $rel
            try {
                if ($act -eq 'created') { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
                else {
                    New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
                    Copy-Item -LiteralPath (Join-Path $Txn.BackupDir $rel) $file -Force
                }
            } catch {}
        }
        Remove-Item $updatesDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $oldUpdates) { try { Move-Item $oldUpdates $updatesDir } catch {} }
        try { Remove-EmptyDirs } catch {}
    }

    $prevEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    $sumsFile = $null; $integrityNote = $null
    # Chemin absolu : les appels .NET ([IO.File]) ne suivent pas le dossier courant de PowerShell.
    $TargetDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetDir)
    $ClaudeDir = Join-Path $TargetDir '.claude'
    $manifestPath = Join-Path $ClaudeDir '.claude-lib.manifest'
    $lockDir = Join-Path $ClaudeDir '.claude-lib.lock'
    $stageDir = Join-Path $ClaudeDir '.claude-lib-staging'
    $updatesDir = Join-Path $ClaudeDir 'updates'
    $oldUpdates = Join-Path $ClaudeDir '.claude-lib-old-updates'
    $copyItems = @("skills", "standards", "templates", "workflows", "hooks")
    # Consignes de la bibliotheque quand le projet a deja son propre .claude/CLAUDE.md.
    $libMd = 'claude-lib.md'
    # Etat de l'ecriture, pour defaire ce qui a ete fait si l'installation echoue ou est interrompue.
    $Txn = @{ Applying = $false; Locked = $false; CreatedDir = $false; Done = $false; BackupDir = ''; Journal = New-Object System.Collections.ArrayList }

    try {
        # --- Verifications avant tout telechargement ---
        if ((Test-Path -LiteralPath $TargetDir) -and -not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
            throw "$TargetDir existe mais n'est pas un dossier."
        }

        # --- Installation existante : manifeste (version, groupes, empreintes) ou, avant lui, fichiers presents ---
        $existing = $false; $legacy = $false
        $old = @{ version = ''; groups = ''; agents = ''; excluded = '' }
        $manifestHashes = @{}
        if (Test-Path $manifestPath) {
            $existing = $true
            foreach ($line in [IO.File]::ReadAllLines($manifestPath, $Utf8)) {
                $line = $line.TrimEnd("`r")
                if ($line -match '^@(\w+)\s*(.*)$') { $old[$Matches[1]] = $Matches[2].Trim() }
                elseif ($line -notmatch '^#' -and $line -match '^(\S+)\s+(.+)$') { $manifestHashes[$Matches[2]] = $Matches[1] }
            }
        } elseif (@('hooks/regulator.sh', 'hooks/regulator.ps1', 'skills/workflow/SKILL.md' | Where-Object { Test-Path (Join-Path $ClaudeDir $_) }).Count) {
            $existing = $true; $legacy = $true
        }
        if ($Update -and -not $existing) {
            throw "Aucune installation de la biblioth${eg}que dans $TargetDir : relance sans -Update pour l'installer."
        }

        if ($Source) {
            if (-not ((Test-Path (Join-Path $Source 'CLAUDE.md')) -and (Test-Path (Join-Path $Source 'agents')))) {
                throw "$Source n'est pas une copie de la biblioth${eg}que."
            }
            Show-Banner "copie locale"
            $srcDir = Get-Item (Resolve-Path $Source).Path
            $newVersion = 'local'
        } else {
            if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
                throw "La commande tar est introuvable. Sous Windows, elle est fournie a partir de Windows 10 version 1803."
            }
            if (-not $Version) { $Version = Resolve-LatestVersion }
            $newVersion = if ($Version) { $Version } else { 'main' }
            if ($existing -and -not $Force -and (Test-OlderVersion $newVersion $old.version)) {
                throw "La version install${e}e ($($old.version)) est plus r${e}cente que $newVersion : relance avec -Force pour revenir en arri${eg}re."
            }

            if ($Version -eq 'main') {
                Show-Banner "main"
                $archiveUrl = "https://github.com/$Repo/archive/refs/heads/main.tar.gz"
                Write-TaskStart "T${e}l${e}chargement" "main"
            } elseif ($Version) {
                Show-Banner $Version
                $archiveUrl = "https://github.com/$Repo/archive/refs/tags/$Version.tar.gz"
                Write-TaskStart "T${e}l${e}chargement" $Version
            } else {
                Show-Banner "main"
                $archiveUrl = "https://github.com/$Repo/archive/refs/heads/main.tar.gz"
                Write-TaskStart "T${e}l${e}chargement" "main (aucune release)"
            }

            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
            $archivePath = Join-Path $tmpDir "lib.tar.gz"
            try { Invoke-Download $archiveUrl $archivePath } catch {
                throw "T${e}l${e}chargement impossible : $archiveUrl (version inexistante, connexion ou proxy ?)"
            }
            tar -xzf $archivePath -C $tmpDir
            if ($LASTEXITCODE -ne 0) { throw "Extraction de l'archive impossible (archive corrompue ou disque plein ?)." }
            $srcDir = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
            if (-not $srcDir -or -not (Test-Path (Join-Path $srcDir.FullName 'CLAUDE.md')) -or -not (Test-Path (Join-Path $srcDir.FullName 'agents'))) {
                throw "Archive incompl${eg}te : CLAUDE.md ou agents/ manquant."
            }
            Write-TaskEnd 'DONE'
            # Empreintes publiees avec la release : un fichier altere (miroir, proxy, tag deplace) est refuse.
            if ($Version -and $Version -ne 'main') {
                Write-TaskStart "Int${e}grit${e}" "(SHA256SUMS)"
                $sumsPath = Join-Path $tmpDir 'SHA256SUMS'
                try { Invoke-Download "https://github.com/$Repo/releases/download/$Version/SHA256SUMS" $sumsPath; $sumsFile = $sumsPath; Write-TaskEnd 'DONE' }
                catch { Write-TaskEnd 'SKIP'; $integrityNote = "Release sans empreintes publi${e}es (SHA256SUMS) : int${e}grit${e} non v${e}rifi${e}e." }
            } else {
                $integrityNote = "Branche main : pas d'empreintes publi${e}es, int${e}grit${e} non v${e}rifi${e}e. Pr${e}f${eg}re une release (-Version vX.Y.Z)."
            }
            Write-Host ""
        }
        # Reserve aux tests : fichier d'empreintes local, a la place de celui de la release.
        if ($env:CLAUDE_LIB_TEST_SUMS) { $sumsFile = $env:CLAUDE_LIB_TEST_SUMS; $integrityNote = $null }
        if ($existing) {
            $from = if ($legacy) { "Installation existante sans manifeste (version ant${e}rieure)" } else { "Installation existante : $(if ($old.version) { $old.version } else { '?' })" }
            Write-Host ("  " + (Paint " UPDATE " $BadgeWarn) + " $from $Arrow $newVersion")
        }

        # --- Choix des agents, avant toute ecriture : une erreur ne laisse rien derriere elle ---
        $agentTable = @(Get-AgentTable (Join-Path $srcDir.FullName 'agents'))
        $allAgents = @($agentTable | ForEach-Object { $_.Name })
        $profilesFile = Join-Path $srcDir.FullName 'profiles.conf'
        $splitList = { param([string]$Text) @($Text -split '[,\s]+' | Where-Object { $_ }) }
        $wantedGroups = @(& $splitList $Groups)
        $wantedAgents = @(& $splitList $Agents)
        $explicit = $All -or $Type -or $wantedGroups.Count -or $wantedAgents.Count
        $selected = @(); $label = ''
        $recordGroups = @(); $recordExtra = @(); $recordExcluded = @()
        $conf = $null
        if (-not (Test-Path $profilesFile)) {
            # Version de la bibliotheque sans profiles.conf : tous les agents, comme avant.
            $selected = $allAgents; $label = 'tous'; $recordGroups = @('all')
        } else {
            $conf = Read-Profiles $profilesFile
            $detected = Get-ProjectType $TargetDir
            # Mise a jour sans option : pas de menu, la selection vient de l'installation existante.
            if (-not $explicit -and -not $existing) {
                # Entree ou sortie redirigee (CI, journal, tests) : pas de menu.
                $nonInteractive = [Console]::IsInputRedirected -or [Console]::IsOutputRedirected
                if ($env:CLAUDE_LIB_TTY) { $State.Answers = @([IO.File]::ReadAllLines($env:CLAUDE_LIB_TTY, $Utf8)) }
                if (-not $Yes -and ($env:CLAUDE_LIB_TTY -or -not $nonInteractive)) {
                    $menu = Show-Menu $conf $agentTable $detected
                    $Type = $menu.Type; $All = $menu.All; $wantedGroups = @($menu.Groups); $wantedAgents = @($menu.Agents)
                } elseif ($detected) {
                    $Type = $detected[0]
                } else {
                    $All = $true
                }
            }
            if ($All -or $Type -eq 'all' -or $Type -eq 'tout') {
                $selected = $allAgents; $label = 'tous'; $recordGroups = @('all')
            } elseif ($explicit -or -not $existing) {
                $groupNames = @($conf.Groups | ForEach-Object { $_.Name })
                $groupsToInstall = @('core')
                if ($Type) {
                    $profileEntry = $conf.Profiles | Where-Object { $_.Name -eq $Type } | Select-Object -First 1
                    if (-not $profileEntry) { throw "Type de projet inconnu : $Type (types : $((@($conf.Profiles | ForEach-Object { $_.Name }) + 'all') -join ' '))." }
                    $groupsToInstall += $profileEntry.Groups; $label = $Type
                }
                foreach ($g in $wantedGroups) {
                    if ($groupNames -notcontains $g) { throw "Groupe inconnu : $g (groupes : $($groupNames -join ' '))." }
                    $groupsToInstall += $g
                }
                if ($wantedGroups.Count) { $label = $(if ($label) { $label } else { 'core' }) + ' + ' + ($wantedGroups -join ', ') }
                $selected = @(Get-AgentsOfGroups $agentTable $groupsToInstall)
                foreach ($a in $wantedAgents) {
                    if ($allAgents -notcontains $a) { throw "Agent inconnu : $a (voir la liste dans CLAUDE.md)." }
                    if ($selected -notcontains $a) { $selected += $a }
                }
                if ($wantedAgents.Count) { $label = $(if ($label) { $label } else { 'core' }) + ' + ' + ($wantedAgents -join ', ') }
                if (-not $label) { $label = 'core' }
                $recordGroups = @($groupsToInstall | Select-Object -Unique); $recordExtra = @($wantedAgents)
            }
        }

        # Mise a jour : agents deja installes, plus les nouveaux agents des groupes installes,
        # sauf ceux que l'utilisateur a supprimes (sauf s'il les redemande avec -Agents ou -Groups).
        if ($existing) {
            $installed = @($allAgents | Where-Object { Test-Path (Join-Path $ClaudeDir "agents/$_.md") })
            if (-not $legacy) {
                $excluded = @(& $splitList $old.excluded)
                foreach ($rel in @($manifestHashes.Keys)) {
                    if ($rel -match '^agents/(.+)\.md$' -and -not (Test-Path (Join-Path $ClaudeDir $rel))) { $excluded += $Matches[1] }
                }
                $recordExcluded = @($excluded | Select-Object -Unique | Where-Object { $selected -notcontains $_ })
                $oldGroups = @(& $splitList $old.groups); $oldExtra = @(& $splitList $old.agents)
                $fromGroups = if ($oldGroups -contains 'all') { $allAgents } else { @(Get-AgentsOfGroups $agentTable $oldGroups) + $oldExtra }
                foreach ($a in $fromGroups) {
                    if ($allAgents -contains $a -and $recordExcluded -notcontains $a -and $installed -notcontains $a) { $installed += $a }
                }
                if ($oldGroups -contains 'all' -or $recordGroups -contains 'all') { $recordGroups = @('all') }
                else { $recordGroups = @(@($oldGroups) + @($recordGroups) | Select-Object -Unique) }
                $recordExtra = @(@($oldExtra) + @($recordExtra) | Select-Object -Unique)
            } elseif ($conf -and $recordGroups -notcontains 'all') {
                # Sans manifeste, les groupes installes sont ceux dont tous les agents sont presents.
                foreach ($g in $conf.Groups) {
                    $members = @(Get-AgentsOfGroups $agentTable @($g.Name))
                    if ($members.Count -and -not @($members | Where-Object { $installed -notcontains $_ }).Count -and $recordGroups -notcontains $g.Name) { $recordGroups += $g.Name }
                }
            }
            foreach ($a in $installed) { if ($selected -notcontains $a) { $selected += $a } }
            $label = if ($explicit) { "mise ${ag} jour + " + ($label -replace '^core \+ ', '') } else { "mise ${ag} jour" }
        }

        # --- Plan : chaque fichier de la bibliotheque compare a la copie installee et au manifeste ---
        $srcRoot = $srcDir.FullName
        $files = New-Object System.Collections.Generic.List[string]
        foreach ($a in $selected) { $files.Add("agents/$a.md") }
        if (Test-Path $profilesFile) { $files.Add('profiles.conf') }
        foreach ($item in $copyItems) {
            $dir = Join-Path $srcRoot $item
            if (-not (Test-Path $dir)) { continue }
            $rels = [string[]]@(Get-ChildItem -LiteralPath $dir -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($srcRoot.Length).TrimStart('\', '/').Replace('\', '/') })
            [Array]::Sort($rels, [StringComparer]::Ordinal)
            foreach ($rel in $rels) { $files.Add($rel) }
        }
        $files.Add('CLAUDE.md')
        $srcHash = Get-Hashes $srcRoot $files
        if ($srcHash.Count -ne $files.Count) { throw "Fichiers de la biblioth${eg}que illisibles dans la source (archive incompl${eg}te ?)." }
        # Integrite : chaque fichier a installer doit avoir l'empreinte publiee avec la release.
        if ($sumsFile) {
            $published = @{}
            foreach ($line in [IO.File]::ReadAllLines($sumsFile, $Utf8)) {
                if ($line -match '^([0-9a-fA-F]{64}) +\*?(?:\./)?(.+?)\s*$') { $published[$Matches[2]] = $Matches[1].ToLowerInvariant() }
            }
            $altered = @($files | Where-Object { $published[$_] -ne $srcHash[$_] })
            if ($altered.Count) { throw "Int${e}grit${e} : fichier(s) diff${e}rent(s) de la release publi${e}e, installation refus${e}e : $($altered -join ', ')." }
        }
        $dstHash = Get-Hashes $ClaudeDir (@($files) + @($manifestHashes.Keys))

        #   add      absent chez toi                       -> copie
        #   same     identique a la bibliotheque           -> rien
        #   update   non modifie depuis l'installation     -> remplace (ancien sauvegarde)
        #   force    modifie chez toi, -Force              -> remplace (ancien sauvegarde)
        #   kept     modifie chez toi, inchange dans la bibliotheque -> conserve
        #   conflict modifie chez toi et dans la bibliotheque -> conserve, nouvelle version dans updates/
        #   remove   retire de la bibliotheque, non modifie -> supprime (sauvegarde)
        #   orphan   retire de la bibliotheque, modifie     -> conserve
        #   import   .claude/CLAUDE.md propre au projet    -> conserve ; la bibliotheque va dans
        #            claude-lib.md, importe par une ligne @claude-lib.md ajoutee a la fin du sien
        # Sans manifeste (installation anterieure), un fichier different est une ancienne version :
        # remplace apres sauvegarde, sauf CLAUDE.md, souvent personnalise.
        $plan = New-Object System.Collections.ArrayList
        foreach ($rel in $files) {
            $s = $srcHash[$rel]; $m = $manifestHashes[$rel]; $inManifest = $manifestHashes.ContainsKey($rel)
            $act = if (-not $dstHash.ContainsKey($rel)) { 'add' }
                elseif ($dstHash[$rel] -eq $s) { 'same' }
                elseif ($inManifest -and $dstHash[$rel] -eq $m) { 'update' }
                elseif ($rel -eq 'CLAUDE.md' -and -not $inManifest -and -not $legacy) { 'import' }
                elseif ($Force) { 'force' }
                elseif ($inManifest -and $s -eq $m) { 'kept' }
                elseif ($legacy -and $rel -ne 'CLAUDE.md') { 'update' }
                else { 'conflict' }
            [void]$plan.Add([pscustomobject]@{ Act = $act; Path = $rel; Src = $s; Old = $m })
        }
        foreach ($rel in @($manifestHashes.Keys)) {
            if (-not $srcHash.ContainsKey($rel) -and $dstHash.ContainsKey($rel)) {
                $act = if ($dstHash[$rel] -eq $manifestHashes[$rel]) { 'remove' } else { 'orphan' }
                [void]$plan.Add([pscustomobject]@{ Act = $act; Path = $rel; Src = ''; Old = $manifestHashes[$rel] })
            }
        }
        $countOf = { param([string[]]$Acts) @($plan | Where-Object { $Acts -contains $_.Act }).Count }
        $pathsOf = { param([string]$Act) (@($plan | Where-Object { $_.Act -eq $Act } | ForEach-Object { $_.Path }) -join ', ') }
        # Import deja en place (claude-lib.md a jour, ligne presente) : rien a ecrire.
        $libFile = Join-Path $ClaudeDir $libMd
        $importLine = { @([IO.File]::ReadAllLines((Join-Path $ClaudeDir 'CLAUDE.md'), $Utf8) | Where-Object { $_.StartsWith("@$libMd") }).Count }
        foreach ($x in @($plan | Where-Object { $_.Act -eq 'import' })) {
            if ((Test-Path $libFile) -and (Get-Sha $libFile) -eq $x.Src -and (& $importLine)) { $x.Act = 'linked' }
        }

        if ($DryRun) {
            Write-Host ""
            Write-Host ("  " + (Paint " DRY-RUN " $BadgeWarn) + " Simulation : rien n'est ${e}crit. Agents : $label.")
            Write-Host ""
            $marks = @{
                add      = @('+', "ajout${e}")
                update   = @('~', "mis ${ag} jour, ancien sauvegard${e}")
                force    = @('~', "modifi${e} chez toi, remplac${e} : -Force")
                kept     = @('=', "modifi${e} chez toi, inchang${e} dans la biblioth${eg}que : conserv${e}")
                conflict = @('!', "modifi${e} chez toi : conserv${e}, nouvelle version dans .claude/updates/")
                import   = @('+', "ton CLAUDE.md est conserv${e} et importe $libMd")
                remove   = @('-', "retir${e} de la biblioth${eg}que")
                orphan   = @('?', "retir${e} de la biblioth${eg}que, modifi${e} chez toi : conserv${e}")
            }
            foreach ($x in $plan) {
                $shown = if ($x.Act -eq 'import') { $libMd } else { $x.Path }
            if ($marks.ContainsKey($x.Act)) { Write-Host ("    " + $marks[$x.Act][0] + " " + $shown + "   (" + $marks[$x.Act][1] + ")") }
            }
            Write-Host ""
            Write-Host ("  Ajout${e}s $(& $countOf 'add') $Dot mis ${ag} jour $(& $countOf 'update','force') $Dot conflits $(& $countOf 'conflict') $Dot supprim${e}s $(& $countOf 'remove') $Dot inchang${e}s $(& $countOf 'same')")
            Write-Host ""
            $Txn.Done = $true
            return
        }

        # --- Preparation de l'ecriture : dossier accessible, une seule installation a la fois ---
        if (-not (Test-Path $ClaudeDir)) {
            try { New-Item -ItemType Directory -Path $ClaudeDir | Out-Null } catch { throw "Impossible de cr${e}er $ClaudeDir (droits d'${e}criture sur le dossier ?)." }
            $Txn.CreatedDir = $true
        }
        $probe = Join-Path $ClaudeDir ".claude-lib-write-test.$PID"
        try { [IO.File]::WriteAllText($probe, ''); Remove-Item -LiteralPath $probe -Force } catch { throw "Pas de droit d'${e}criture dans $ClaudeDir." }
        try { New-Item -ItemType Directory -Path $lockDir | Out-Null } catch {
            throw "Une autre installation est en cours dans ce projet. Si ce n'est pas le cas, supprime $lockDir et relance."
        }
        $Txn.Locked = $true

        # --- Ecriture en trois temps : copie a cote, sauvegarde, remplacement -- defaite si une etape echoue ---
        if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
        foreach ($x in $plan) {
            if (@('add', 'update', 'force', 'conflict', 'import') -notcontains $x.Act) { continue }
            $staged = Join-Path $stageDir $x.Path
            try {
                New-Item -ItemType Directory -Path (Split-Path $staged) -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $srcRoot $x.Path) $staged -Force
            } catch { throw "Copie impossible de $($x.Path) dans $ClaudeDir (disque plein ou droits ?)." }
        }

        $Txn.BackupDir = Join-Path $ClaudeDir ('backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $Txn.Applying = $true
        # Copies de conflits d'une installation precedente : mises de cote (regenerees si besoin, remises en cas d'echec).
        if (Test-Path $oldUpdates) { Remove-Item $oldUpdates -Recurse -Force }
        if (Test-Path $updatesDir) { Move-Item $updatesDir $oldUpdates }
        $applied = 0
        foreach ($x in $plan) {
            $file = Join-Path $ClaudeDir $x.Path
            $staged = Join-Path $stageDir $x.Path
            if ($x.Act -eq 'add') {
                New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
                Add-Journal 'created' $x.Path
                Move-Item -LiteralPath $staged $file -Force
            } elseif ($x.Act -eq 'update' -or $x.Act -eq 'force') {
                Backup-File $x.Path
                Move-Item -LiteralPath $staged $file -Force
            } elseif ($x.Act -eq 'remove') {
                Backup-File $x.Path
                Remove-Item -LiteralPath $file -Force
            } elseif ($x.Act -eq 'conflict') {
                $newCopy = Join-Path $updatesDir "$($x.Path).new"
                New-Item -ItemType Directory -Path (Split-Path $newCopy) -Force | Out-Null
                Add-Journal 'created' "updates/$($x.Path).new"
                Move-Item -LiteralPath $staged $newCopy -Force
            } elseif ($x.Act -eq 'import') {
                if (Test-Path $libFile) { Backup-File $libMd } else { Add-Journal 'created' $libMd }
                Move-Item -LiteralPath $staged $libFile -Force
                if (-not (& $importLine)) {
                    Backup-File $x.Path
                    $note = "`n<!-- Biblioth${eg}que d'ing${e}nierie (agents, r${e}gulateur, workflows) : ne pas retirer cette ligne. -->`n@$libMd`n"
                    [IO.File]::AppendAllText($file, $note, $Utf8)
                }
            } else { continue }
            $applied++
            # Reserve aux tests : simule une panne apres N ecritures pour verifier la restauration.
            if ($env:CLAUDE_LIB_TEST_FAIL_AT -and $applied -ge [int]$env:CLAUDE_LIB_TEST_FAIL_AT) { throw "Panne simul${e}e (CLAUDE_LIB_TEST_FAIL_AT)." }
        }
        Remove-EmptyDirs

        # Verification : chaque fichier ecrit est identique a celui de la bibliotheque.
        foreach ($x in $plan) {
            if (@('add', 'update', 'force') -contains $x.Act -and (Get-Sha (Join-Path $ClaudeDir $x.Path)) -ne $x.Src) {
                throw "V${e}rification apr${eg}s copie ${e}chou${e}e : $($x.Path) diff${eg}re de la biblioth${eg}que."
            }
            if ($x.Act -eq 'import' -and (Get-Sha $libFile) -ne $x.Src) {
                throw "V${e}rification apr${eg}s copie ${e}chou${e}e : $libMd diff${eg}re de la biblioth${eg}que."
            }
        }

        # DONE si quelque chose a change, MERGE si conflit, SKIP sinon.
        function Write-Report([string]$Label, [string]$Detail, [string]$Prefix) {
            $mine = @($plan | Where-Object { $_.Path.StartsWith($Prefix) })
            Write-TaskStart $Label $Detail
            if (@($mine | Where-Object { $_.Act -eq 'conflict' }).Count) { Write-TaskEnd 'MERGE' }
            elseif (@($mine | Where-Object { @('add', 'update', 'force', 'remove', 'import') -contains $_.Act }).Count) { Write-TaskEnd 'DONE' }
            else { Write-TaskEnd 'SKIP' }
        }
        Write-Report ".claude/agents/" "($($selected.Count)/$($allAgents.Count) $Dot $label)" 'agents/'
        foreach ($item in $copyItems) {
            $srcItem = Join-Path $srcRoot $item
            if (Test-Path $srcItem) { Write-Report ".claude/$item/" ("(" + @(Get-ChildItem $srcItem).Count + ")") "$item/" }
        }
        $nImport = & $countOf 'import'
        Write-Report ".claude/CLAUDE.md" $(if ($nImport) { "(le tien, qui importe $libMd)" } else { "" }) 'CLAUDE.md'

        # Hook du regulateur dans .claude/settings.json : ajoute a l'existant, sans rien ecraser.
        # Un fichier illisible n'est jamais reecrit : la configuration a ajouter est mise a cote.
        $hookMerge = $null
        if (Test-Path (Join-Path $srcRoot 'hooks/regulator.ps1')) {
            $settingsPath = Join-Path $ClaudeDir 'settings.json'
            $shellExe = if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { 'pwsh' } else { 'powershell' }
            $hook = [pscustomobject]@{
                type    = 'command'
                command = $shellExe
                args    = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '${CLAUDE_PROJECT_DIR}/.claude/hooks/regulator.ps1')
                timeout = 30
            }
            $entry = [pscustomobject]@{ hooks = @($hook) }
            Write-TaskStart ".claude/settings.json" "(r${e}gulateur)"
            if (-not (Test-Path $settingsPath)) {
                $settings = [pscustomobject]@{ hooks = [pscustomobject]@{ UserPromptSubmit = @($entry) } }
                Add-Journal 'created' 'settings.json'
                [IO.File]::WriteAllText($settingsPath, (ConvertTo-Json -InputObject $settings -Depth 20), $Utf8)
                Write-TaskEnd 'DONE'
            } elseif ([IO.File]::ReadAllText($settingsPath) -match 'regulator\.(ps1|sh)') {
                Write-TaskEnd 'SKIP'
            } else {
                try {
                    $settings = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
                    if (-not $settings.hooks) { $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
                    $existingHooks = @($settings.hooks.UserPromptSubmit | Where-Object { $_ })
                    $settings.hooks | Add-Member -NotePropertyName UserPromptSubmit -NotePropertyValue (@($existingHooks) + $entry) -Force
                    $json = ConvertTo-Json -InputObject $settings -Depth 20
                } catch { $json = $null }
                if ($json) {
                    # Ecrit a cote puis remplace : un arret en cours d'ecriture ne laisse pas un fichier tronque.
                    Backup-File 'settings.json'
                    [IO.File]::WriteAllText("$settingsPath.new", $json, $Utf8)
                    Move-Item -LiteralPath "$settingsPath.new" $settingsPath -Force
                    Write-TaskEnd 'DONE'
                } else {
                    $hookMerge = Join-Path $ClaudeDir 'settings.regulator.json'
                    $snippet = [pscustomobject]@{ hooks = [pscustomobject]@{ UserPromptSubmit = @($entry) } }
                    Add-Journal 'created' 'settings.regulator.json'
                    [IO.File]::WriteAllText($hookMerge, (ConvertTo-Json -InputObject $snippet -Depth 20), $Utf8)
                    Write-TaskEnd 'MERGE'
                }
            }
        }

        # --- Manifeste, ecrit en dernier : il ne decrit que ce qui est reellement installe ---
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add("# claude-engineering-lib : version install${e}e et empreinte de chaque fichier de la biblioth${eg}que.")
        $lines.Add("# Sert aux mises ${ag} jour (fichiers modifi${e}s chez toi d${e}tect${e}s et conserv${e}s). Ne pas modifier ${ag} la main.")
        $lines.Add("@version $newVersion")
        $lines.Add("@date " + (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"))
        $lines.Add("@groups " + ($recordGroups -join ' '))
        $lines.Add("@agents " + ($recordExtra -join ' '))
        $lines.Add("@excluded " + ($recordExcluded -join ' '))
        foreach ($x in $plan) {
            if (@('add', 'same', 'update', 'force') -contains $x.Act) { $lines.Add("$($x.Src)  $($x.Path)") }
            elseif (@('kept', 'conflict', 'orphan') -contains $x.Act -and $x.Old) { $lines.Add("$($x.Old)  $($x.Path)") }
        }
        # Fins de ligne LF : le manifeste est aussi lu par install.sh.
        [IO.File]::WriteAllText("$manifestPath.new", (($lines -join "`n") + "`n"), $Utf8)
        if (Test-Path $manifestPath) { Backup-File '.claude-lib.manifest' } else { Add-Journal 'created' '.claude-lib.manifest' }
        Move-Item -LiteralPath "$manifestPath.new" $manifestPath -Force
        $Txn.Applying = $false
        $Txn.Done = $true
        Remove-Item $oldUpdates -Recurse -Force -ErrorAction SilentlyContinue

        # Sauvegarde qui ne contient que l'ancien manifeste (gardee pour la restauration) : inutile une fois fini.
        if (-not @($Txn.Journal | Where-Object { $_[0] -eq 'saved' -and $_[1] -ne '.claude-lib.manifest' }).Count) {
            Remove-Item $Txn.BackupDir -Recurse -Force -ErrorAction SilentlyContinue
            $backupsRoot = Join-Path $ClaudeDir 'backups'
            if ((Test-Path $backupsRoot) -and -not (Get-ChildItem $backupsRoot -Force)) { Remove-Item $backupsRoot -Force }
        }
        # Sauvegardes et copies de conflits hors de git ; seules les 5 dernieres sauvegardes sont gardees.
        foreach ($d in @('backups', 'updates')) {
            $dir = Join-Path $ClaudeDir $d
            if (Test-Path $dir) { [IO.File]::WriteAllText((Join-Path $dir '.gitignore'), "*`n", $Utf8) }
        }
        $backupsRoot = Join-Path $ClaudeDir 'backups'
        if (Test-Path $backupsRoot) {
            $dirs = @(Get-ChildItem $backupsRoot -Directory | Sort-Object Name)
            if ($dirs.Count -gt 5) { $dirs[0..($dirs.Count - 6)] | Remove-Item -Recurse -Force }
        }

        $nConflict = & $countOf 'conflict'; $nOrphan = & $countOf 'orphan'
        Write-Host ""
        if ($existing) {
            Write-Host ("  " + (Paint " SUCCESS " $BadgeOk) + " Biblioth${eg}que mise ${ag} jour dans " + (Paint $TargetDir '1') + " ($(if ($old.version) { $old.version } else { 'sans manifeste' }) $Arrow $newVersion)")
        } else {
            Write-Host ("  " + (Paint " SUCCESS " $BadgeOk) + " Biblioth${eg}que install${e}e dans " + (Paint $TargetDir '1'))
        }
        Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Ajout${e}s $(& $countOf 'add') $Dot mis ${ag} jour $(& $countOf 'update','force') $Dot supprim${e}s $(& $countOf 'remove') $Dot inchang${e}s $(& $countOf 'same') $Dot tes modifications conserv${e}es $(& $countOf 'kept','conflict','orphan')")
        if ($label -ne 'tous' -and -not $existing) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Agents : $label. Pour en ajouter plus tard : " + (Paint '-Agents <nom>' '1') + " ou " + (Paint '-Groups <groupe>' '1') + ".")
        }
        if ($nImport) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Ton .claude/CLAUDE.md est conserv${e} : les consignes de la biblioth${eg}que sont dans " + (Paint ".claude/$libMd" '1') + ", import${e} par la ligne " + (Paint "@$libMd" '1') + " ajout${e}e ${ag} la fin.")
        }
        if ($nConflict -and -not $existing) {
            Write-Host ("  " + (Paint " MERGE " $BadgeWarn) + " $nConflict fichier(s) du projet portant le m${e}me nom qu'un fichier de la biblioth${eg}que, conserv${e}(s) : $(& $pathsOf 'conflict'). La version de la biblioth${eg}que est dans " + (Paint '.claude/updates/<fichier>.new' '1') + " ; " + (Paint '-Force' '1') + " la met ${ag} la place (apr${eg}s sauvegarde).")
        } elseif ($nConflict) {
            Write-Host ("  " + (Paint " MERGE " $BadgeWarn) + " $nConflict fichier(s) modifi${e}(s) chez toi, conserv${e}(s) : $(& $pathsOf 'conflict'). La nouvelle version est dans " + (Paint '.claude/updates/<fichier>.new' '1') + ", ${ag} fusionner ; " + (Paint '-Force' '1') + " les remplace (apr${eg}s sauvegarde).")
        }
        if ($nOrphan) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Retir${e}(s) de la biblioth${eg}que mais modifi${e}(s) chez toi, conserv${e}(s) : $(& $pathsOf 'orphan').")
        }
        if (Test-Path $Txn.BackupDir) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Anciennes versions sauvegard${e}es dans " + (Paint ".claude/backups/$(Split-Path $Txn.BackupDir -Leaf)" '1') + ".")
        }
        if ($integrityNote) { Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " $integrityNote") }
        if ($hookMerge) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " .claude/settings.json illisible, laiss${e} intact : le hook du r${e}gulateur est dans " + (Paint '.claude/settings.regulator.json' '1') + ", ${ag} fusionner.")
        }
        Write-Host ""
        Write-Host ("  " + (Paint $Arrow $Green) + " Ouvre Claude Code ici et d${e}cris ta t${ac}che : " + (Paint "les agents se lancent tout seuls." "1;$Green"))
        Write-Host ("  " + (Paint ([char]0x21BB) $Green) + " Mise ${ag} jour plus tard : relance la m${e}me commande (ou " + (Paint '-DryRun' '1') + " pour voir ce qui changerait).")
        Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Claude Code d${e}j${ag} ouvert dans ce dossier (terminal ou VS Code) : " + (Paint "red${e}marre la session" '1') + ", les agents ne sont charg${e}s qu'au d${e}marrage.")
        Write-Host ("  " + (Paint $Star $Green) + " " + (Paint "github.com/$Repo" $Gray))
        Write-Host ""
    } catch {
        $__claudeLibInstall.Failed = $true
        if ($State.TaskPending) { Write-TaskEnd 'FAIL' }
        Write-Host ""
        Write-Host ("  " + (Paint " ERREUR " $BadgeErr) + " " + $_.Exception.Message)
        Write-Host ""
    } finally {
        # Echec ou Ctrl+C en cours d'ecriture : retour a l'etat d'avant.
        if ($Txn.Applying) {
            Undo-Writes
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Rien n'a chang${e} : les fichiers d${e}j${ag} ${e}crits ont ${e}t${e} retir${e}s ou restaur${e}s.")
            Write-Host ""
        }
        if ($Txn.CreatedDir -and -not $Txn.Done) { Remove-Item $ClaudeDir -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
        if ($Txn.Locked) { Remove-Item $lockDir -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        $Sha.Dispose()
        try { [Console]::OutputEncoding = $prevEncoding } catch {}
    }
}

$__claudeLibFailed = $__claudeLibInstall.Failed
Remove-Variable __claudeLibInstall
if ($__claudeLibFailed -and $PSCommandPath) { exit 1 }
Remove-Variable __claudeLibFailed
