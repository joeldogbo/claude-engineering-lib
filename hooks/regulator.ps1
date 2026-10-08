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
#
# Usage : hook (JSON sur l'entrée standard) ; -Audit pour vérifier les déclencheurs.
# Variables : REGULATOR_AGENTS_DIR (dossier des agents), REGULATOR_MAX (défaut : 4).

param([switch]$Audit)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $utf8 } catch {}

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { '.' }
$dir = if ($env:REGULATOR_AGENTS_DIR) { $env:REGULATOR_AGENTS_DIR } else { Join-Path $projectDir '.claude/agents' }
$max = if ($env:REGULATOR_MAX) { [int]$env:REGULATOR_MAX } else { 4 }
if (-not (Test-Path $dir)) { exit 0 }

# Minuscules, accents retirés, tout ce qui n'est ni lettre ni chiffre devient une espace.
function Normalize-Text([string]$Text) {
    $s = $Text.ToLowerInvariant().Replace([string][char]0x0153, 'oe').Normalize([Text.NormalizationForm]::FormD)
    $s = -join ($s.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    return ($s -replace '[^a-z0-9=]+', ' ').Trim()
}

$registry = foreach ($file in Get-ChildItem -Path $dir -Filter *.md) {
    $lines = [IO.File]::ReadAllLines($file.FullName, $utf8)
    if ($lines.Count -eq 0 -or $lines[0] -ne '---') { continue }
    $name = $null; $declared = ''; $declaredExcludes = ''
    for ($i = 1; $i -lt $lines.Count -and $lines[$i] -ne '---'; $i++) {
        if ($lines[$i] -match '^name:\s*(.*)$') { $name = $Matches[1].Trim() }
        elseif ($lines[$i] -match '^triggers:\s*(.*)$') { $declared = $Matches[1] }
        elseif ($lines[$i] -match '^excludes:\s*(.*)$') { $declaredExcludes = $Matches[1] }
    }
    if (-not $name) { continue }
    $triggers = @($declared -split ',' | ForEach-Object { Normalize-Text $_ } | Where-Object { $_ })
    $excludes = @($declaredExcludes -split ',' | ForEach-Object { Normalize-Text $_ } | Where-Object { $_ })
    [pscustomobject]@{ Name = $name; Triggers = @(Normalize-Text $name) + $triggers; Declared = $triggers.Count; Excludes = $excludes }
}

if ($Audit) {
    "# Audit du régulateur - $dir"
    "$(@($registry).Count) agents lus."
    $missing = @($registry | Where-Object { $_.Declared -eq 0 } | ForEach-Object { $_.Name })
    if ($missing.Count) { "Sans déclencheurs (jamais lancés, sauf par leur nom) : $($missing -join ' ')" }
    $owners = @{}
    foreach ($agent in $registry) {
        foreach ($t in ($agent.Triggers | Select-Object -Skip 1)) { $owners[$t] = @($owners[$t]) + $agent.Name | Where-Object { $_ } }
    }
    $shared = @($owners.Keys | Where-Object { @($owners[$_]).Count -gt 1 } | Sort-Object)
    foreach ($t in $shared) { "Déclencheur partagé « $t » : $(@($owners[$t]) -join ' ')" }
    if (-not $missing.Count -and -not $shared.Count) { "Aucun problème." }
    exit 0
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
    if ($score) { [pscustomobject]@{ Score = $score; Name = $agent.Name; Hits = $hits -join ', ' } }
}
$selected = @($selected | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } -CaseSensitive | Select-Object -First $max)

if (-not $selected.Count) {
    "[Régulateur] Aucun agent pour ce message : réponds directement, sans sous-agent."
    exit 0
}
$list = ($selected | ForEach-Object { if ($_.Hits) { "$($_.Name) ($($_.Hits))" } else { "$($_.Name) (nommé)" } }) -join ' ; '
"[Régulateur] Agents retenus pour ce message : $list."
"Lance uniquement ceux de cette liste qui sont réellement utiles après lecture du message, en parallèle s'ils sont indépendants. N'en ajoute un autre que s'il est indispensable, en le signalant « hors régulateur » avec la raison."
