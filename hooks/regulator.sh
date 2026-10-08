#!/usr/bin/env bash
# Régulateur des agents — hook UserPromptSubmit de Claude Code (macOS, Linux, Git Bash).
#
# À chaque prompt, relit .claude/agents/*.md, compare le message au champ `triggers:` de
# chaque agent et écrit dans le contexte la seule liste d'agents autorisés pour ce message,
# ou « aucun agent ». Un agent ajouté est pris en compte dès le prompt suivant.
#
# Déclencheurs : liste séparée par des virgules, comparée sans majuscules ni accents.
#   paiement  → début de mot : trouve « paiement », « paiements »
#   ram=      → mot entier : trouve « ram », pas « random »
# Champ facultatif `excludes:` : mêmes règles ; si l'un de ses termes est dans le message,
# l'agent est écarté (ex. performance exclut « mon pc » au profit de system-monitor).
#
# Usage : hook (JSON sur l'entrée standard) ; `--audit` pour vérifier les déclencheurs.
# Variables : REGULATOR_AGENTS_DIR (dossier des agents), REGULATOR_MAX (défaut : 4).

set -u
export LC_ALL=C

DIR="${REGULATOR_AGENTS_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/agents}"
MAX="${REGULATOR_MAX:-4}"
[[ -d "$DIR" ]] || exit 0

# Minuscules, accents retirés, tout ce qui n'est ni lettre ni chiffre devient une espace.
NORMALIZE='
function norm(s) {
  s = tolower(s)
  gsub(/à|â|ä|À|Â|Ä/, "a", s); gsub(/é|è|ê|ë|É|È|Ê|Ë/, "e", s); gsub(/î|ï|Î|Ï/, "i", s)
  gsub(/ô|ö|Ô|Ö/, "o", s); gsub(/ù|û|ü|Ù|Û|Ü/, "u", s); gsub(/ç|Ç/, "c", s); gsub(/œ|Œ/, "oe", s)
  gsub(/[^a-z0-9=]+/, " ", s); gsub(/^ +| +$/, "", s)
  return s
}'

# nom<TAB>déclencheurs normalisés séparés par « | »<TAB>nombre déclaré<TAB>exclusions
# Un seul processus awk pour tous les agents : lancer un processus par fichier coûte
# plusieurs secondes sous Git Bash, et ce hook s'exécute à chaque prompt.
registry() {
  set -- "$DIR"/*.md
  [[ -f "$1" ]] || return 0
  awk "$NORMALIZE"'
    function flush(   out, n, i, p, ex, m, q, parts, xp) {
      if (name != "") {
        out = norm(name)
        n = split(t, parts, ",")
        for (i = 1; i <= n; i++) { p = norm(parts[i]); if (p != "") out = out "|" p }
        ex = ""; m = split(x, xp, ",")
        for (i = 1; i <= m; i++) { q = norm(xp[i]); if (q != "") ex = ex (ex == "" ? "" : "|") q }
        printf "%s\t%s\t%d\t%s\n", name, out, n, ex
      }
      name = ""; t = ""; x = ""
    }
    FNR == 1     { flush(); front = ($0 == "---"); next }
    !front       { next }
    $0 == "---"  { front = 0; next }
    /^name:/     { name = $0; sub(/^name:[ \t]*/, "", name) }
    /^triggers:/ { t = $0; sub(/^triggers:[ \t]*/, "", t) }
    /^excludes:/ { x = $0; sub(/^excludes:[ \t]*/, "", x) }
    END          { flush() }' "$@"
}

if [[ "${1:-}" == "--audit" ]]; then
  echo "# Audit du régulateur — $DIR"
  registry | awk -F'\t' '
    { agents++; if ($3 == 0) missing = missing " " $1
      n = split($2, t, "|"); for (i = 2; i <= n; i++) { owners[t[i]] = owners[t[i]] " " $1; count[t[i]]++ } }
    END {
      printf "%d agents lus.\n", agents
      if (missing != "") printf "Sans déclencheurs (jamais lancés, sauf par leur nom) :%s\n", missing
      for (k in count) if (count[k] > 1) { shared = 1; printf "Déclencheur partagé « %s » :%s\n", k, owners[k] }
      if (missing == "" && !shared) print "Aucun problème."
    }'
  exit 0
fi

INPUT="$(cat)"
# Texte du prompt : champ prompt_text (ou prompt selon la version de Claude Code).
PROMPT="$(printf '%s' "$INPUT" | awk '
  { s = s $0 " " }
  END {
    if (!match(s, /"prompt(_text)?"[ \t]*:[ \t]*"/)) exit
    s = substr(s, RSTART + RLENGTH)
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (c == "\\") { i++; c = substr(s, i, 1); out = out ((c == "n" || c == "t") ? " " : c); continue }
      if (c == "\"") break
      out = out c
    }
    print out
  }')"

# Une commande slash décide elle-même de ce qu'elle lance.
case "$PROMPT" in /*|"") exit 0 ;; esac

SELECTED="$(registry | REGULATOR_PROMPT="$PROMPT" awk -F'\t' "$NORMALIZE"'
  BEGIN { p = " " norm(ENVIRON["REGULATOR_PROMPT"]) " " }
  function has(trig) {
    if (trig ~ /=$/) { sub(/=$/, "", trig); return index(p, " " trig " ") }
    return index(p, " " trig)
  }
  {
    m = split($4, x, "|"); excluded = 0
    for (i = 1; i <= m; i++) if (x[i] != "" && has(x[i])) excluded = 1
    if (excluded) next
    n = split($2, t, "|"); score = 0; hits = ""
    for (i = 1; i <= n; i++) {
      trig = t[i]; found = has(trig); sub(/=$/, "", trig)
      if (found) { score++; if (i > 1 && length(hits) < 60) hits = hits (hits == "" ? "" : ", ") trig }
    }
    if (score) printf "%d\t%s\t%s\n", score, $1, hits
  }' | sort -t "$(printf '\t')" -k1,1nr -k2,2 | head -n "$MAX")"

if [[ -z "$SELECTED" ]]; then
  echo "[Régulateur] Aucun agent pour ce message : réponds directement, sans sous-agent."
  exit 0
fi

LIST="$(printf '%s\n' "$SELECTED" | awk -F'\t' '{ printf "%s%s%s", (NR > 1 ? " ; " : ""), $2, ($3 != "" ? " (" $3 ")" : " (nommé)") }')"
echo "[Régulateur] Agents retenus pour ce message : $LIST."
echo "Lance uniquement ceux de cette liste qui sont réellement utiles après lecture du message, en parallèle s'ils sont indépendants. N'en ajoute un autre que s'il est indispensable, en le signalant « hors régulateur » avec la raison."
