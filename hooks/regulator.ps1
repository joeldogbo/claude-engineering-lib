# Régulateur des agents — hook UserPromptSubmit de Claude Code (Windows PowerShell 5.1 et PowerShell 7).
# Même logique que regulator.sh, qui en est la version bash : toute règle modifiée ici l'est aussi là-bas.
#
# À chaque prompt, relit .claude/agents/*.md, compare le message au champ `triggers:` de
# chaque agent et écrit dans le contexte la seule liste d'agents autorisés pour ce message,
# ou « aucun agent ». Un agent ajouté est pris en compte dès le prompt suivant.
#
# Déclencheurs : liste séparée par des virgules, comparée sans majuscules ni accents.
#   paiement  -> début de mot : trouve « paiement », « paiements »
#   ram=      -> mot entier : trouve « ram », pas « random »
# Champ facultatif `excludes:` : mêmes règles ; si l'un de ses termes est dans le message,
# l'agent est écarté (ex. performance exclut « mon pc » au profit de system-monitor).
# Champ `after:` : agents N1 (analyse) dont cet agent est le N2 (correction) ; le régulateur
# affiche la chaîne N1 -> N2 pour que le contrôleur les enchaîne au lieu de les paralléliser.
# Travail interrompu : les fichiers .claude/progress/*.md marqués `statut: en cours` sont
# signalés à chaque message, pour reprendre là où le travail s'est arrêté.
#
# Usage : hook (JSON sur l'entrée standard) ; -Audit pour vérifier que chaque agent respecte
# les règles communes (déclencheurs, groupe, protocole, N1 existant) — code 1 sinon.
# Variables : REGULATOR_AGENTS_DIR (dossier des agents), REGULATOR_PROGRESS_DIR (points de
# reprise), REGULATOR_MAX (défaut : 4).

param([switch]$Audit)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $utf8 } catch {}

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { '.' }
$dir = if ($env:REGULATOR_AGENTS_DIR) { $env:REGULATOR_AGENTS_DIR } else { Join-Path $projectDir '.claude/agents' }
$progressDir = if ($env:REGULATOR_PROGRESS_DIR) { $env:REGULATOR_PROGRESS_DIR } else { Join-Path $projectDir '.claude/progress' }
$max = if ($env:REGULATOR_MAX) { [int]$env:REGULATOR_MAX } else { 4 }
if (-not (Test-Path $dir)) { exit 0 }

# Minuscules, accents retirés, tout ce qui n'est ni lettre ni chiffre devient une espace.
function Normalize-Text([string]$Text) {
    $s = $Text.ToLowerInvariant().Replace([string][char]0x0153, 'oe').Normalize([Text.NormalizationForm]::FormD)
    $s = -join ($s.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    return ($s -replace '[^a-z0-9=]+', ' ').Trim()
}

$registry = foreach ($file in Get-ChildItem -Path $dir -Filter *.md | Sort-Object Name) {
    $lines = [IO.File]::ReadAllLines($file.FullName, $utf8)
    if ($lines.Count -eq 0 -or $lines[0] -ne '---') { continue }
    $name = $null; $declared = ''; $declaredExcludes = ''; $after = ''; $group = ''
    for ($i = 1; $i -lt $lines.Count -and $lines[$i] -ne '---'; $i++) {
        if ($lines[$i] -match '^name:\s*(.*)$') { $name = $Matches[1].Trim() }
        elseif ($lines[$i] -match '^triggers:\s*(.*)$') { $declared = $Matches[1] }
        elseif ($lines[$i] -match '^excludes:\s*(.*)$') { $declaredExcludes = $Matches[1] }
        elseif ($lines[$i] -match '^after:\s*(.*)$') { $after = $Matches[1] }
        elseif ($lines[$i] -match '^group:\s*(.*)$') { $group = $Matches[1].Trim() }
    }
    if (-not $name) { continue }
    $triggers = @($declared -split ',' | ForEach-Object { Normalize-Text $_ } | Where-Object { $_ })
    $excludes = @($declaredExcludes -split ',' | ForEach-Object { Normalize-Text $_ } | Where-Object { $_ })
    [pscustomobject]@{
        Name = $name; Triggers = @(Normalize-Text $name) + $triggers; Declared = $triggers.Count; Excludes = $excludes
        After = @($after -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }); Group = $group
        Protocol = ([IO.File]::ReadAllText($file.FullName, $utf8)).Contains('agent-protocol.md')
    }
}

if ($Audit) {
    "# Audit du régulateur - $dir"
    "$(@($registry).Count) agents lus."
    # Groupes connus : profiles.conf de la bibliothèque (racine du dépôt ou .claude/ installé).
    $profilesFile = Join-Path $dir '../profiles.conf'
    $knownGroups = if (Test-Path $profilesFile) {
        @([IO.File]::ReadAllLines((Resolve-Path $profilesFile).Path, $utf8) | Where-Object { $_ -like 'group|*' } | ForEach-Object { $_.Split('|')[1] })
    } else { @() }
    $names = @($registry | ForEach-Object { $_.Name })
    $missing = @($registry | Where-Object { $_.Declared -eq 0 } | ForEach-Object { $_.Name })
    $noGroup = @($registry | Where-Object { -not $_.Group } | ForEach-Object { $_.Name })
    $badGroup = @($registry | Where-Object { $_.Group -and $knownGroups.Count -and $knownGroups -notcontains $_.Group } | ForEach-Object { "$($_.Name) ($($_.Group))" })
    $noProtocol = @($registry | Where-Object { -not $_.Protocol } | ForEach-Object { $_.Name })
    $badAfter = @(foreach ($agent in $registry) { foreach ($n1 in $agent.After) { if ($names -notcontains $n1) { "$($agent.Name) ($n1)" } } })
    if ($missing.Count) { "Sans déclencheurs (jamais lancés, sauf par leur nom) : $($missing -join ' ')" }
    if ($noGroup.Count) { "Sans groupe (group:, requis par l installation par groupe) : $($noGroup -join ' ')" }
    if ($badGroup.Count) { "Groupe absent de profiles.conf : $($badGroup -join ' ')" }
    if ($noProtocol.Count) { "Sans protocole commun (standards/agent-protocol.md) : $($noProtocol -join ' ')" }
    if ($badAfter.Count) { "N1 introuvable dans after: : $($badAfter -join ' ')" }
    $owners = @{}
    foreach ($agent in $registry) {
        foreach ($t in ($agent.Triggers | Select-Object -Skip 1)) { $owners[$t] = @($owners[$t]) + $agent.Name | Where-Object { $_ } }
    }
    $shared = @($owners.Keys | Where-Object { @($owners[$_]).Count -gt 1 } | Sort-Object)
    foreach ($t in $shared) { "Déclencheur partagé « $t » : $(@($owners[$t]) -join ' ')" }
    $bad = $missing.Count + $noGroup.Count + $badGroup.Count + $noProtocol.Count + $badAfter.Count
    if (-not $bad -and -not $shared.Count) { "Aucun problème." }
    exit ([int]($bad -gt 0))
}

# Octets bruts de l'entrée standard, décodés en UTF-8 : [Console]::In dépend de l'encodage de la
# console et peut lire une entrée vide quand Claude Code lance le hook directement.
try {
    $buffer = New-Object System.IO.MemoryStream
    [Console]::OpenStandardInput().CopyTo($buffer)
    # Tolère un BOM ou des octets nuls autour du JSON, que certains programmes ajoutent.
    $hookInput = $utf8.GetString($buffer.ToArray()).Trim([char]0xFEFF, [char]0, ' ', "`r", "`n", "`t") | ConvertFrom-Json
} catch { exit 0 }
# Texte du prompt : champ prompt_text (ou prompt selon la version de Claude Code).
$prompt = if ($hookInput.prompt_text) { [string]$hookInput.prompt_text } elseif ($hookInput.prompt) { [string]$hookInput.prompt } else { '' }
# Une commande slash décide elle-même de ce qu'elle lance.
if (-not $prompt -or $prompt.StartsWith('/')) { exit 0 }

# Points de reprise laissés par un travail interrompu (coupure de connexion, session fermée).
if (Test-Path $progressDir) {
    $pending = @(Get-ChildItem -Path $progressDir -Filter *.md | Sort-Object Name | Where-Object {
        @([IO.File]::ReadAllLines($_.FullName, $utf8) | Where-Object { $_ -match '^statut:\s*en cours' }).Count
    } | ForEach-Object { ".claude/progress/$($_.Name)" })
    if ($pending.Count) {
        "[Régulateur] Travail interrompu à reprendre : $($pending -join ', '). Lis ces fichiers et propose à l'utilisateur de reprendre à la première étape non cochée, sans refaire les étapes déjà faites."
    }
}

$text = ' ' + (Normalize-Text $prompt) + ' '
function Test-Trigger([string]$Trigger) {
    if ($Trigger.EndsWith('=')) { return $text.Contains(' ' + $Trigger.TrimEnd('=') + ' ') }
    return $text.Contains(" $Trigger")
}
$selected = foreach ($agent in $registry) {
    if (@($agent.Excludes | Where-Object { Test-Trigger $_ }).Count) { continue }
    $score = 0; $hits = @()
    for ($i = 0; $i -lt $agent.Triggers.Count; $i++) {
        if (Test-Trigger $agent.Triggers[$i]) {
            $score++
            if ($i -gt 0 -and ($hits -join ', ').Length -lt 60) { $hits += $agent.Triggers[$i].TrimEnd('=') }
        }
    }
    if ($score) { [pscustomobject]@{ Score = $score; Name = $agent.Name; Hits = $hits -join ', '; After = $agent.After } }
}
$selected = @($selected | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } -CaseSensitive | Select-Object -First $max)

if (-not $selected.Count) {
    "[Régulateur] Aucun agent pour ce message : réponds directement, sans sous-agent."
    exit 0
}
# Niveaux : chaque N2 déclare ses N1 (after:) ; on en déduit le N2 de chaque N1.
$list = ($selected | ForEach-Object {
    $agent = $_
    $item = if ($agent.Hits) { "$($agent.Name) ($($agent.Hits))" } else { "$($agent.Name) (nommé)" }
    $n2 = @($registry | Where-Object { $_.After -contains $agent.Name } | ForEach-Object { $_.Name })
    if ($agent.After.Count) { $item += " [N2 de $($agent.After -join ', ')]" }
    elseif ($n2.Count) { $item += " [N1 $([char]0x2192) $($n2 -join ', ')]" }
    $item
}) -join ' ; '
"[Régulateur] Agents retenus pour ce message : $list."
"Lance uniquement ceux de cette liste qui sont réellement utiles après lecture du message, en parallèle s'ils sont indépendants. N'en ajoute un autre que s'il est indispensable, en le signalant « hors régulateur » avec la raison."
if ($list.Contains('[N1 ')) {
    "Niveaux : un N1 analyse sans rien modifier, son N2 corrige à partir du rapport du N1. Jamais en parallèle : N1 d'abord, puis N2 seulement si le N1 a des constats, avec l'accord de l'utilisateur pour la sécurité et le déploiement."
}
