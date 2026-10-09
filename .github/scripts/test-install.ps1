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
    if ($Ok) { "ok   - $What" } else { "FAIL - $What"; $script:fails++ }
}

# Lance l'installateur dans un processus separe, comme un utilisateur (-File).
function Invoke-Install([string[]]$Arguments) {
    $output = & $exe -NoProfile -NonInteractive -File $install @Arguments 2>&1 | Out-String
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

# 2. Relance sans -Force : rien n'est ecrase
$r = Invoke-Install @('-TargetDir', $p)
Check "relance : code de sortie 0" ($r.Code -eq 0)
Check "relance : dossiers existants ignores (SKIP)" ($r.Out -match 'SKIP')
Check "relance : CLAUDE.md de la bibliotheque mis a cote" (Test-Path (Join-Path $p '.claude/CLAUDE.md.claude-engineering-lib'))

# 3. -Force remplace proprement (les agents ajoutes par l'utilisateur sont gardes)
Set-Content -Path (Join-Path $p '.claude/skills/marqueur') -Value 'x'
Set-Content -Path (Join-Path $p '.claude/agents/perso.md') -Value 'agent perso'
Set-Content -Path (Join-Path $p '.claude/agents/git.md') -Value 'modifie'
$r = Invoke-Install @('-TargetDir', $p, '-Force')
Check "-Force : code de sortie 0" ($r.Code -eq 0)
Check "-Force : ancien contenu remplace" (-not (Test-Path (Join-Path $p '.claude/skills/marqueur')))
Check "-Force : agent de la bibliotheque remplace" ((Get-Content (Join-Path $p '.claude/agents/git.md') -Raw) -match '(?m)^name: git')
Check "-Force : agent de l'utilisateur conserve" (Test-Path (Join-Path $p '.claude/agents/perso.md'))
Check "-Force : aucun dossier .new residuel" (@(Get-ChildItem (Join-Path $p '.claude') -Filter '*.new' -Directory).Count -eq 0)

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
