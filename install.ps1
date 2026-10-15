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
#   .\install.ps1 -Force -Version v1.2.0 -TargetDir .
#   .\install.ps1 -Source .\claude-engineering-lib    # depuis une copie locale (tests, CI)
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
# Ne pas ecrire ici la commande en une ligne suivie d'un commentaire : Windows Defender (AMSI)
# a bloque tout le script pour cette seule phrase (constate sous Windows 11, octobre 2026).
#
# Ce fichier doit rester en ASCII pur : sous Windows PowerShell 5.1, `iwr | iex` ne
# decode pas le script en UTF-8 et corrompt tout caractere accentue. Les accents et
# symboles affiches sont construits a partir de leur code Unicode ([char]0x...).

param(
    [switch]$Force,
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

    $prevEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())

    try {
        if ($Source) {
            if (-not ((Test-Path (Join-Path $Source 'CLAUDE.md')) -and (Test-Path (Join-Path $Source 'agents')))) {
                throw "$Source n'est pas une copie de la biblioth${eg}que."
            }
            Show-Banner "copie locale"
            $srcDir = Get-Item (Resolve-Path $Source).Path
        } else {
            if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
                throw "La commande tar est introuvable. Sous Windows, elle est fournie a partir de Windows 10 version 1803."
            }
            if (-not $Version) { $Version = Resolve-LatestVersion }

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
            Invoke-Download $archiveUrl $archivePath
            tar -xzf $archivePath -C $tmpDir
            if ($LASTEXITCODE -ne 0) { throw "Extraction de l'archive impossible (tar a ${e}chou${e})." }
            Write-TaskEnd 'DONE'
            Write-Host ""

            $srcDir = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
        }
        # --- Choix des agents, avant toute ecriture : une erreur ne laisse rien derriere elle ---
        $agentTable = @(Get-AgentTable (Join-Path $srcDir.FullName 'agents'))
        $allAgents = @($agentTable | ForEach-Object { $_.Name })
        $profilesFile = Join-Path $srcDir.FullName 'profiles.conf'
        $splitList = { param([string]$Text) @($Text -split '[,\s]+' | Where-Object { $_ }) }
        $wantedGroups = @(& $splitList $Groups)
        $wantedAgents = @(& $splitList $Agents)
        if (-not (Test-Path $profilesFile)) {
            # Version de la bibliotheque sans profiles.conf : tous les agents, comme avant.
            $selected = $allAgents; $label = 'tous'
        } else {
            $conf = Read-Profiles $profilesFile
            $detected = Get-ProjectType $TargetDir
            if (-not $All -and -not $Type -and -not $wantedGroups.Count -and -not $wantedAgents.Count) {
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
                $selected = $allAgents; $label = 'tous'
            } else {
                $groupNames = @($conf.Groups | ForEach-Object { $_.Name })
                $groupsToInstall = @('core')
                $label = ''
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
            }
        }

        $copyItems = @("skills", "standards", "templates", "workflows", "hooks")
        $skipped = @()
        $ClaudeDir = Join-Path $TargetDir ".claude"
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null

        # Agents choisis, un par un : ceux deja installes sont gardes (remplaces avec -Force), et
        # un agent installe auparavant n'est jamais supprime : on peut donc en ajouter plus tard.
        $agentsDir = Join-Path $ClaudeDir 'agents'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        $added = 0
        foreach ($a in $selected) {
            $dst = Join-Path $agentsDir "$a.md"
            if ((Test-Path $dst) -and (-not $Force)) { continue }
            Copy-Item (Join-Path $srcDir.FullName "agents/$a.md") "$dst.new" -Force
            Move-Item "$dst.new" $dst -Force
            $added++
        }
        Write-TaskStart ".claude/agents/" "($($selected.Count)/$($allAgents.Count) $Dot $label)"
        if ($added -eq 0) { $skipped += ".claude/agents/"; Write-TaskEnd 'SKIP' } else { Write-TaskEnd 'DONE' }
        if (Test-Path $profilesFile) { Copy-Item $profilesFile (Join-Path $ClaudeDir 'profiles.conf') -Force }

        foreach ($item in $copyItems) {
            $srcItem = Join-Path $srcDir.FullName $item
            $dstItem = Join-Path $ClaudeDir $item
            if (-not (Test-Path $srcItem)) { continue }

            Write-TaskStart ".claude/$item/" ("(" + @(Get-ChildItem $srcItem).Count + ")")
            if ((Test-Path $dstItem) -and (-not $Force)) {
                $skipped += ".claude/$item/"
                Write-TaskEnd 'SKIP'
            } else {
                # Copie complete a cote avant de remplacer : un echec en cours de copie
                # laisse l'ancienne version intacte.
                $staging = "$dstItem.new"
                if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
                Copy-Item $srcItem $staging -Recurse
                if (Test-Path $dstItem) { Remove-Item $dstItem -Recurse -Force }
                Move-Item $staging $dstItem
                Write-TaskEnd 'DONE'
            }
        }

        $dstClaudeMd = Join-Path $ClaudeDir "CLAUDE.md"
        $srcClaudeMd = Join-Path $srcDir.FullName "CLAUDE.md"
        $claudeMdKept = (Test-Path $dstClaudeMd) -and (-not $Force)
        Write-TaskStart ".claude/CLAUDE.md"
        if ($claudeMdKept) {
            Copy-Item $srcClaudeMd (Join-Path $ClaudeDir "CLAUDE.md.claude-engineering-lib") -Force
            Write-TaskEnd 'MERGE'
        } else {
            Copy-Item $srcClaudeMd $dstClaudeMd -Force
            Write-TaskEnd 'DONE'
        }

        # Hook du regulateur dans .claude/settings.json : ajoute a l'existant, sans rien ecraser.
        # Un fichier illisible n'est jamais reecrit : la configuration a ajouter est mise a cote.
        $hookMerge = $null
        if (Test-Path (Join-Path $srcDir.FullName 'hooks/regulator.ps1')) {
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
                [IO.File]::WriteAllText($settingsPath, (ConvertTo-Json -InputObject $settings -Depth 20), (New-Object System.Text.UTF8Encoding $false))
                Write-TaskEnd 'DONE'
            } elseif ([IO.File]::ReadAllText($settingsPath) -match 'regulator\.(ps1|sh)') {
                Write-TaskEnd 'SKIP'
            } else {
                try {
                    $settings = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
                    if (-not $settings.hooks) { $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
                    $existing = @($settings.hooks.UserPromptSubmit | Where-Object { $_ })
                    $settings.hooks | Add-Member -NotePropertyName UserPromptSubmit -NotePropertyValue (@($existing) + $entry) -Force
                    [IO.File]::WriteAllText($settingsPath, (ConvertTo-Json -InputObject $settings -Depth 20), (New-Object System.Text.UTF8Encoding $false))
                    Write-TaskEnd 'DONE'
                } catch {
                    $hookMerge = Join-Path $ClaudeDir 'settings.regulator.json'
                    $snippet = [pscustomobject]@{ hooks = [pscustomobject]@{ UserPromptSubmit = @($entry) } }
                    [IO.File]::WriteAllText($hookMerge, (ConvertTo-Json -InputObject $snippet -Depth 20), (New-Object System.Text.UTF8Encoding $false))
                    Write-TaskEnd 'MERGE'
                }
            }
        }

        Write-Host ""
        Write-Host ("  " + (Paint " SUCCESS " $BadgeOk) + " Biblioth${eg}que install${e}e dans " + (Paint $TargetDir '1'))
        if ($label -ne 'tous') {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " Agents : $label. Pour en ajouter plus tard : " + (Paint '-Agents <nom>' '1') + " ou " + (Paint '-Groups <groupe>' '1') + ".")
        }
        if ($skipped) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " D${e}j${ag} pr${e}sents, conserv${e}s : " + ($skipped -join ', ') + ". Relance avec " + (Paint '-Force' '1') + " pour les ${e}craser.")
        }
        if ($claudeMdKept) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " .claude/CLAUDE.md existant conserv${e} : la version de la biblioth${eg}que est dans " + (Paint '.claude/CLAUDE.md.claude-engineering-lib' '1') + ", ${ag} fusionner.")
        }
        if ($hookMerge) {
            Write-Host ("  " + (Paint " INFO " $BadgeWarn) + " .claude/settings.json illisible, laiss${e} intact : le hook du r${e}gulateur est dans " + (Paint '.claude/settings.regulator.json' '1') + ", ${ag} fusionner.")
        }
        Write-Host ""
        Write-Host ("  " + (Paint $Arrow $Green) + " Ouvre Claude Code ici et d${e}cris ta t${ac}che : " + (Paint "les agents se lancent tout seuls." "1;$Green"))
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
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        try { [Console]::OutputEncoding = $prevEncoding } catch {}
    }
}

$__claudeLibFailed = $__claudeLibInstall.Failed
Remove-Variable __claudeLibInstall
if ($__claudeLibFailed -and $PSCommandPath) { exit 1 }
Remove-Variable __claudeLibFailed
