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

# 3. -Force remplace proprement
Set-Content -Path (Join-Path $p '.claude/agents/marqueur') -Value 'x'
$r = Invoke-Install @('-TargetDir', $p, '-Force')
Check "-Force : code de sortie 0" ($r.Code -eq 0)
Check "-Force : ancien contenu remplace" (-not (Test-Path (Join-Path $p '.claude/agents/marqueur')))
Check "-Force : aucun dossier .new residuel" (@(Get-ChildItem (Join-Path $p '.claude') -Filter '*.new' -Directory).Count -eq 0)

# 4. Branche main
$r = Invoke-Install @('-Version', 'main', '-TargetDir', (Join-Path $work 'main'))
Check "-Version main : code de sortie 0" ($r.Code -eq 0)

# 5. Via iex, script decode en Latin-1 comme `iwr -useb ... | iex` sous PowerShell 5.1
$iexDir = Join-Path $work 'iex'
New-Item -ItemType Directory -Path $iexDir | Out-Null
$source = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($install))
Push-Location $iexDir
try { Invoke-Expression $source *>&1 | Out-Null } finally { Pop-Location }
Check "iex : .claude/CLAUDE.md present" (Test-Path (Join-Path $iexDir '.claude/CLAUDE.md'))
Check "iex : aucune variable laissee dans la session" (-not (Get-Variable '__claudeLib*' -ErrorAction SilentlyContinue))

# 6. Erreur : code non nul, message lisible, rien d'ecrit
$ko = Join-Path $work 'ko'
$r = Invoke-Install @('-Version', 'v0.0.0-inexistante', '-TargetDir', $ko)
Check "version inexistante : code de sortie non nul" ($r.Code -ne 0)
Check "version inexistante : message ERREUR" ($r.Out -match 'ERREUR')
Check "version inexistante : aucun dossier cree" (-not (Test-Path (Join-Path $ko '.claude')))

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
