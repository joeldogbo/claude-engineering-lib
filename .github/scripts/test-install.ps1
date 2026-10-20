# Verifie install.ps1 de bout en bout : installation, relance, -Force, branche main,
# lancement via iex (decodage Latin-1 comme `iwr | iex` sous Windows PowerShell 5.1)
# et cas d'erreur. Sort en 1 si un controle echoue.
# Fichier en ASCII pur, comme install.ps1 (lu sans BOM par Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
$root    = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$install = Join-Path $root 'install.ps1'
$exe     = (Get-Process -Id $PID).Path
$work    = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $work | Out-Null
$script:fails = 0
$script:logs = @()

"PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)) - $exe"

function Check([string]$What, [bool]$Ok) {
    if ($Ok) { "ok   - $What" } else {
        "FAIL - $What"
        $script:fails++
        # Annotation GitHub Actions : lisible sans ouvrir le journal, avec la derniere sortie de l'installateur.
        if ($env:GITHUB_ACTIONS) {
            $last = if ($script:logs.Count) { [string]$script:logs[-1] } else { '' }
            $detail = ($last -replace '%', '%25' -replace "`r", '' -replace "`n", '%0A')
            "::error title=FAIL - $What::$($detail.Substring(0, [Math]::Min(3000, $detail.Length)))"
        }
    }
}

# Lance l'installateur dans un processus separe, comme un utilisateur (-File).
function Invoke-Install([string[]]$Arguments) {
    $output = & $exe -NoProfile -NonInteractive -File $install @Arguments 2>&1 | Out-String
    # Sans couleurs : dans la CI, les codes ANSI coupent le texte cherche ("mobile<ESC>[0m (package.json").
    $output = $output -replace '\x1b\[[0-9;]*m', ''
    $script:logs += "----- install.ps1 $($Arguments -join ' ')`n$output"
    return @{ Code = $LASTEXITCODE; Out = $output }
}

Check "install.ps1 est en ASCII pur" (@([IO.File]::ReadAllBytes($install) | Where-Object { $_ -gt 127 }).Count -eq 0)

# 1. Installation dans un projet qui a deja son propre CLAUDE.md
$p = Join-Path $work 'projet'
New-Item -ItemType Directory -Path $p | Out-Null
Set-Content -Path (Join-Path $p 'CLAUDE.md') -Value 'projet perso'
$r = Invoke-Install @('-TargetDir', $p)
Check "installation : code de sortie 0" ($r.Code -eq 0)
Check "installation : agents dans .claude/agents" (@(Get-ChildItem (Join-Path $p '.claude/agents') -Filter *.md -ErrorAction SilentlyContinue).Count -gt 0)
Check "installation : routeur de workflows present" (Test-Path (Join-Path $p '.claude/skills/workflow/SKILL.md'))
Check "installation : .claude/CLAUDE.md present" (Test-Path (Join-Path $p '.claude/CLAUDE.md'))
Check "installation : CLAUDE.md du projet intact" ((Get-Content (Join-Path $p 'CLAUDE.md')) -eq 'projet perso')
Check "installation : rien copie a la racine" (-not (Test-Path (Join-Path $p 'agents')))
Check "installation : manifeste ecrit" ((Get-Content (Join-Path $p '.claude/.claude-lib.manifest') -Raw) -match '(?m)^@version ')

# 1 bis. Projet qui a deja son propre .claude/ (CLAUDE.md et agents) : rien d'ecrase, bibliotheque importee
$ex = Join-Path $work 'existant'
New-Item -ItemType Directory -Path (Join-Path $ex '.claude/agents') | Out-Null
Set-Content -Path (Join-Path $ex '.claude/CLAUDE.md') -Value 'consignes du projet'
Set-Content -Path (Join-Path $ex '.claude/agents/testing.md') -Value @('---', 'name: testing', 'description: tests maison', '---')
$r = Invoke-Install @('-Source', $root, '-TargetDir', $ex, '-All')
$exMd = Get-Content (Join-Path $ex '.claude/CLAUDE.md') -Raw
Check ".claude existant : code de sortie 0" ($r.Code -eq 0)
Check ".claude existant : CLAUDE.md du projet conserve" ($exMd -match 'consignes du projet')
Check ".claude existant : bibliotheque importee" ($exMd -match '(?m)^@claude-lib\.md')
Check ".claude existant : claude-lib.md identique" ((Get-FileHash (Join-Path $root 'CLAUDE.md')).Hash -eq (Get-FileHash (Join-Path $ex '.claude/claude-lib.md')).Hash)
Check ".claude existant : agent du projet conserve" ((Get-Content (Join-Path $ex '.claude/agents/testing.md') -Raw) -match 'tests maison')
Check ".claude existant : homonyme signale" ($r.Out -match 'nom qu')
# Le manifeste est reecrit a chaque passage (date) : hors comparaison.
$before = Get-ChildItem $ex -Recurse -File -Force -Exclude '.claude-lib.manifest' | ForEach-Object { "$($_.FullName) $((Get-FileHash $_.FullName).Hash)" }
$r = Invoke-Install @('-Source', $root, '-TargetDir', $ex)
$after = Get-ChildItem $ex -Recurse -File -Force -Exclude '.claude-lib.manifest' | ForEach-Object { "$($_.FullName) $((Get-FileHash $_.FullName).Hash)" }
Check ".claude existant : relance sans rien reecrire" (-not (Compare-Object @($before) @($after)))

# 1 ter. Integrite : empreintes conformes acceptees, fichier altere refuse sans rien ecrire
$sums = Join-Path $work 'SUMS'
$libFiles = @('CLAUDE.md', 'profiles.conf') + @(foreach ($d in 'agents', 'skills', 'standards', 'templates', 'workflows', 'hooks') {
    Get-ChildItem (Join-Path $root $d) -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/') }
})
$lines = foreach ($rel in $libFiles) { (Get-FileHash (Join-Path $root $rel) -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $rel }
[IO.File]::WriteAllLines($sums, [string[]]$lines)
$env:CLAUDE_LIB_TEST_SUMS = $sums
$r = Invoke-Install @('-Source', $root, '-TargetDir', (Join-Path $work 'integre'), '-All')
Check "integrite : empreintes conformes acceptees" ($r.Code -eq 0)
$lines[1] = ('0' * 64) + $lines[1].Substring(64)
[IO.File]::WriteAllLines("$sums-altere", [string[]]$lines)
$env:CLAUDE_LIB_TEST_SUMS = "$sums-altere"
$r = Invoke-Install @('-Source', $root, '-TargetDir', (Join-Path $work 'altere'), '-All')
Remove-Item Env:CLAUDE_LIB_TEST_SUMS
Check "integrite : fichier altere refuse" ($r.Code -ne 0)
Check "integrite : message explicite" ($r.Out -match 'installation refus')
Check "integrite : rien d'ecrit" (-not (Test-Path (Join-Path $work 'altere/.claude')))

# 2. Relance : mise a jour, rien a changer
$r = Invoke-Install @('-TargetDir', $p)
Check "relance : code de sortie 0" ($r.Code -eq 0)
Check "relance : detectee comme mise a jour" ($r.Out -match 'Installation existante')
Check "relance : rien a faire (SKIP)" ($r.Out -match 'SKIP')
Check "relance : aucune sauvegarde inutile" (-not (Test-Path (Join-Path $p '.claude/backups')))

# 3. -Force remplace les fichiers modifies, apres sauvegarde ; les fichiers de l'utilisateur restent
Set-Content -Path (Join-Path $p '.claude/skills/marqueur') -Value 'x'
Set-Content -Path (Join-Path $p '.claude/agents/perso.md') -Value 'agent perso'
Set-Content -Path (Join-Path $p '.claude/agents/git.md') -Value 'modifie'
$r = Invoke-Install @('-TargetDir', $p, '-Force')
Check "-Force : code de sortie 0" ($r.Code -eq 0)
Check "-Force : fichier de l'utilisateur conserve" (Test-Path (Join-Path $p '.claude/skills/marqueur'))
Check "-Force : agent de la bibliotheque remplace" ((Get-Content (Join-Path $p '.claude/agents/git.md') -Raw) -match '(?m)^name: git')
Check "-Force : ancienne version sauvegardee" (@(Get-ChildItem (Join-Path $p '.claude/backups') -Recurse -Filter git.md -ErrorAction SilentlyContinue | Where-Object { (Get-Content $_.FullName -Raw) -match 'modifie' }).Count -eq 1)
Check "-Force : agent de l'utilisateur conserve" (Test-Path (Join-Path $p '.claude/agents/perso.md'))
Check "-Force : aucun residu de copie" (-not (Test-Path (Join-Path $p '.claude/.claude-lib-staging')) -and -not (Test-Path (Join-Path $p '.claude/.claude-lib.lock')))

# 4. Branche main
$r = Invoke-Install @('-Version', 'main', '-TargetDir', (Join-Path $work 'main'))
Check "-Version main : code de sortie 0" ($r.Code -eq 0)

# 5. Via iex, script decode en Latin-1 comme `iwr -useb ... | iex` sous PowerShell 5.1
$iexDir = Join-Path $work 'iex'
New-Item -ItemType Directory -Path $iexDir | Out-Null
# Nom distinct des parametres de install.ps1 (Force, Version, TargetDir, Source) : iex les lie dans cette portee.
$installerText = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($install))
Push-Location $iexDir
try { Invoke-Expression $installerText *>&1 | Out-Null } finally { Pop-Location }
Check "iex : .claude/CLAUDE.md present" (Test-Path (Join-Path $iexDir '.claude/CLAUDE.md'))
Check "iex : aucune variable laissee dans la session" (-not (Get-Variable '__claudeLib*' -ErrorAction SilentlyContinue))

# 6. Erreur : code non nul, message lisible, rien d'ecrit
$ko = Join-Path $work 'ko'
$r = Invoke-Install @('-Version', 'v0.0.0-inexistante', '-TargetDir', $ko)
Check "version inexistante : code de sortie non nul" ($r.Code -ne 0)
Check "version inexistante : message ERREUR" ($r.Out -match 'ERREUR')
Check "version inexistante : aucun dossier cree" (-not (Test-Path (Join-Path $ko '.claude')))

# 7. Copie locale (-Source) : la version du commit teste, hook du regulateur compris
$src = Join-Path $work 'src'
New-Item -ItemType Directory -Path (Join-Path $src '.claude') -Force | Out-Null
Set-Content -Path (Join-Path $src '.claude/settings.json') -Value '{ "permissions": { "allow": ["Bash(ls)"] } }'
$r = Invoke-Install @('-Source', $root, '-TargetDir', $src)
$settingsText = Get-Content (Join-Path $src '.claude/settings.json') -Raw
Check "-Source : code de sortie 0" ($r.Code -eq 0)
Check "-Source : hook du regulateur copie" (Test-Path (Join-Path $src '.claude/hooks/regulator.ps1'))
Check "-Source : hook enregistre dans settings.json" ($settingsText -match 'regulator\.ps1')
Check "-Source : reglages existants conserves" ($settingsText -match 'Bash\(ls\)')
$null = Invoke-Install @('-Source', $root, '-TargetDir', $src)
Check "-Source : hook enregistre une seule fois" (([regex]::Matches((Get-Content (Join-Path $src '.claude/settings.json') -Raw), 'regulator\.ps1')).Count -eq 1)

# 8. Choix des agents selon le type de projet, les groupes, ou agent par agent
function Get-Installed([string]$Dir) { @(Get-ChildItem (Join-Path $Dir '.claude/agents') -Filter *.md -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }) }
function Test-Has([string]$Dir, [string[]]$Names) { $in = Get-Installed $Dir; @($Names | Where-Object { $in -notcontains $_ }).Count -eq 0 }
function Test-Lacks([string]$Dir, [string[]]$Names) { $in = Get-Installed $Dir; @($Names | Where-Object { $in -contains $_ }).Count -eq 0 }
$total = @(Get-ChildItem (Join-Path $root 'agents') -Filter *.md).Count

$mobile = Join-Path $work 'mobile'
New-Item -ItemType Directory -Path $mobile | Out-Null
Set-Content -Path (Join-Path $mobile 'pubspec.yaml') -Value 'name: app'
$r = Invoke-Install @('-Source', $root, '-TargetDir', $mobile)
Check "type detecte (Flutter) : code de sortie 0" ($r.Code -eq 0)
Check "type detecte (Flutter) : agents mobile" (Test-Has $mobile @('frontend', 'backend', 'security', 'project-context', 'language'))
Check "type detecte (Flutter) : pas de SEO" (Test-Lacks $mobile @('seo', 'geo'))

$api = Join-Path $work 'api'
New-Item -ItemType Directory -Path $api | Out-Null
Set-Content -Path (Join-Path $api 'package.json') -Value '{ "dependencies": { "express": "4" } }'
$null = Invoke-Install @('-Source', $root, '-TargetDir', $api, '-Yes')
Check "type detecte (API) : pas d'agent d'interface" (Test-Lacks $api @('frontend', 'ux-ui', 'seo'))
Check "type detecte (API) : agents serveur" (Test-Has $api @('backend', 'api', 'database'))

$groupsDir = Join-Path $work 'groupes'
$null = Invoke-Install @('-Source', $root, '-TargetDir', $groupsDir, '-Groups', 'security,seo')
Check "-Groups : socle + groupes demandes" (Test-Has $groupsDir @('project-context', 'code-reviewer', 'security', 'security-fixer', 'seo', 'geo'))
Check "-Groups : rien d'autre" (Test-Lacks $groupsDir @('frontend', 'payments'))
Check "-Groups : profiles.conf copie pour l'audit" (Test-Path (Join-Path $groupsDir '.claude/profiles.conf'))
$null = Invoke-Install @('-Source', $root, '-TargetDir', $groupsDir, '-Agents', 'payments,manuals')
Check "-Agents : ajout a une installation existante" (Test-Has $groupsDir @('payments', 'manuals', 'security', 'seo'))

$allDir = Join-Path $work 'tout'
$null = Invoke-Install @('-Source', $root, '-TargetDir', $allDir, '-Type', 'library', '-All')
Check "-All : tous les agents" ((Get-Installed $allDir).Count -eq $total)

$ko2 = Join-Path $work 'ko2'
$r = Invoke-Install @('-Source', $root, '-TargetDir', $ko2, '-Type', 'inconnu')
Check "type inconnu : code de sortie non nul" ($r.Code -ne 0)
Check "type inconnu : aucun dossier cree" (-not (Test-Path (Join-Path $ko2 '.claude')))
$r = Invoke-Install @('-Source', $root, '-TargetDir', $ko2, '-Agents', 'nimporte')
Check "agent inconnu : code de sortie non nul" ($r.Code -ne 0)

# Menu : << sur mesure >>, groupes 1 (docs) et 5 (performance), puis un agent en plus.
$menu = Join-Path $work 'menu'
New-Item -ItemType Directory -Path $menu | Out-Null
Set-Content -Path (Join-Path $menu 'package.json') -Value '{ "dependencies": { "react-native": "0.74" } }'
Set-Content -Path (Join-Path $work 'menu.in') -Value "7`n1 5`nseo"
$env:CLAUDE_LIB_TTY = Join-Path $work 'menu.in'
try { $r = Invoke-Install @('-Source', $root, '-TargetDir', $menu) } finally { $env:CLAUDE_LIB_TTY = $null }
Check "menu : code de sortie 0" ($r.Code -eq 0)
Check "menu : type detecte affiche" ($r.Out -match 'mobile \(package\.json')
Check "menu : selection sur mesure" (Test-Has $menu @('project-context', 'documentation', 'manuals', 'performance', 'load-testing', 'seo'))
Check "menu : rien hors selection" (Test-Lacks $menu @('frontend', 'security', 'geo'))
$menuKo = Join-Path $work 'menu-ko'
Set-Content -Path (Join-Path $work 'menu-ko.in') -Value "x`ny`nz"
$env:CLAUDE_LIB_TTY = Join-Path $work 'menu-ko.in'
try { $r = Invoke-Install @('-Source', $root, '-TargetDir', $menuKo) } finally { $env:CLAUDE_LIB_TTY = $null }
Check "menu : reponses invalides, arret sans boucler" ($r.Code -ne 0)
Check "menu : reponses invalides, rien d'ecrit" (-not (Test-Path (Join-Path $menuKo '.claude')))

# 9. Mise a jour : une << nouvelle version >> de la bibliotheque, preparee dans une copie
function Get-Tree([string]$Dir) {
    # Chemins et empreintes, hors sauvegardes : sert a verifier que rien n'a change.
    $base = (Resolve-Path $Dir).Path
    (@(Get-ChildItem $base -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]backups[\\/]' } | ForEach-Object {
        $_.FullName.Substring($base.Length) + ' ' + (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    }) | Sort-Object) -join "`n"
}
function Test-Contains([string]$File, [string]$Text) { (Test-Path $File) -and ((Get-Content $File -Raw) -match $Text) }
$v1 = Join-Path $work 'v1'; $v2 = Join-Path $work 'v2'; $u = Join-Path $work 'maj'
New-Item -ItemType Directory -Path $v1 | Out-Null
foreach ($item in 'CLAUDE.md', 'agents', 'skills', 'standards', 'templates', 'workflows', 'hooks', 'profiles.conf') { Copy-Item (Join-Path $root $item) $v1 -Recurse }
Copy-Item $v1 $v2 -Recurse
$null = Invoke-Install @('-Source', $v1, '-TargetDir', $u, '-Groups', 'security')
Add-Content (Join-Path $v2 'agents/git.md') 'evolution'                                   # change dans la bibliotheque seulement
Add-Content (Join-Path $v2 'agents/code-reviewer.md') 'evolution'; Add-Content (Join-Path $u '.claude/agents/code-reviewer.md') 'perso' # des deux cotes
Add-Content (Join-Path $u '.claude/agents/refactoring.md') 'perso'                         # chez l'utilisateur seulement
Remove-Item (Join-Path $v2 'agents/security-fixer.md')                                     # retire de la bibliotheque
Set-Content (Join-Path $v2 'agents/nouveau.md') "---`nname: nouveau`ndescription: x`ntriggers: zzz`ngroup: security`n---`nx"
Remove-Item (Join-Path $u '.claude/agents/debugging.md')                                   # supprime par l'utilisateur
$before = Get-Tree $u

$r = Invoke-Install @('-Source', $v2, '-TargetDir', $u, '-DryRun')
Check "-DryRun : code de sortie 0" ($r.Code -eq 0)
Check "-DryRun : plan affiche" ($r.Out -match 'agents/git\.md')
Check "-DryRun : rien d'ecrit" ((Get-Tree $u) -eq $before)

$env:CLAUDE_LIB_TEST_FAIL_AT = '2'
try { $r = Invoke-Install @('-Source', $v2, '-TargetDir', $u) } finally { $env:CLAUDE_LIB_TEST_FAIL_AT = $null }
Check "panne en cours d'ecriture : code de sortie non nul" ($r.Code -ne 0)
Check "panne en cours d'ecriture : etat d'avant restaure" ((Get-Tree $u) -eq $before)

$r = Invoke-Install @('-Source', $v2, '-TargetDir', $u, '-Update')
$cl = Join-Path $u '.claude'
Check "-Update : code de sortie 0" ($r.Code -eq 0)
Check "-Update : fichier non modifie mis a jour" (Test-Contains (Join-Path $cl 'agents/git.md') 'evolution')
Check "-Update : ancienne version sauvegardee" (@(Get-ChildItem (Join-Path $cl 'backups') -Recurse -Filter git.md -ErrorAction SilentlyContinue).Count -gt 0)
Check "-Update : modification de l'utilisateur conservee" (Test-Contains (Join-Path $cl 'agents/code-reviewer.md') 'perso')
Check "-Update : conflit signale (MERGE)" ($r.Out -match 'MERGE')
Check "-Update : nouvelle version mise a cote" (Test-Contains (Join-Path $cl 'updates/agents/code-reviewer.md.new') 'evolution')
Check "-Update : modification sans conflit conservee" (Test-Contains (Join-Path $cl 'agents/refactoring.md') 'perso')
Check "-Update : pas de copie a fusionner sans conflit" (-not (Test-Path (Join-Path $cl 'updates/agents/refactoring.md.new')))
Check "-Update : agent retire de la bibliotheque supprime" (-not (Test-Path (Join-Path $cl 'agents/security-fixer.md')))
Check "-Update : nouvel agent d'un groupe installe ajoute" (Test-Path (Join-Path $cl 'agents/nouveau.md'))
Check "-Update : agent supprime par l'utilisateur non reinstalle" (-not (Test-Path (Join-Path $cl 'agents/debugging.md')))
Check "-Update : sauvegardes hors de git" (Test-Path (Join-Path $cl 'backups/.gitignore'))
Check "-Update : manifeste en fins de ligne LF (lu par install.sh)" (-not ([IO.File]::ReadAllText((Join-Path $cl '.claude-lib.manifest')).Contains("`r")))

$null = Invoke-Install @('-Source', $v2, '-TargetDir', $u, '-Agents', 'debugging')
Check "-Agents : agent supprime reinstalle a la demande" (Test-Path (Join-Path $cl 'agents/debugging.md'))
$null = Invoke-Install @('-Source', $v2, '-TargetDir', $u, '-Force')
Check "-Force : conflit remplace" (Test-Contains (Join-Path $cl 'agents/code-reviewer.md') 'evolution')

$none = Join-Path $work 'rien'
$r = Invoke-Install @('-Source', $v2, '-TargetDir', $none, '-Update')
Check "-Update sans installation : code de sortie non nul" ($r.Code -ne 0)
Check "-Update sans installation : aucun dossier cree" (-not (Test-Path (Join-Path $none '.claude')))
$manifest = Join-Path $cl '.claude-lib.manifest'
[IO.File]::WriteAllText($manifest, ([IO.File]::ReadAllText($manifest) -replace '(?m)^@version .*$', '@version v99.0.0'))
$r = Invoke-Install @('-Version', 'v1.0.0', '-TargetDir', $u)
Check "version plus ancienne : refusee sans -Force" ($r.Code -ne 0)
Check "version plus ancienne : message explicite" ($r.Out -match 'plus r.cente')
New-Item -ItemType Directory -Path (Join-Path $cl '.claude-lib.lock') | Out-Null
$r = Invoke-Install @('-Source', $v2, '-TargetDir', $u)
Check "installation simultanee : refusee" ($r.Code -ne 0)
Remove-Item -Force (Join-Path $cl '.claude-lib.lock')

# Installation anterieure au manifeste : les anciennes versions sont remplacees apres sauvegarde
Remove-Item -Force $manifest
Add-Content (Join-Path $cl 'agents/testing.md') 'ancienne'
$r = Invoke-Install @('-Source', $v2, '-TargetDir', $u)
Check "sans manifeste : code de sortie 0" ($r.Code -eq 0)
Check "sans manifeste : ancienne version remplacee" (-not (Test-Contains (Join-Path $cl 'agents/testing.md') 'ancienne'))
Check "sans manifeste : manifeste cree" (Test-Path $manifest)

if ($script:fails -gt 0) {
    ""
    "$($script:fails) controle(s) en echec. Journaux :"
    $script:logs
    exit 1
}
""
"Tous les controles sont passes."
# Explicite : GitHub Actions termine l'etape par `exit $LASTEXITCODE`, qui vaut ici 1
# (dernier installateur lance = cas d'erreur attendu).
exit 0
