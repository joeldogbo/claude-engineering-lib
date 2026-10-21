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
# Champ `after:` : agents N1 (analyse) dont cet agent est le N2 (correction) ; le régulateur
# affiche la chaîne N1 → N2 pour que le contrôleur les enchaîne au lieu de les paralléliser.
# Travail interrompu : les fichiers .claude/progress/*.md marqués `statut: en cours` sont
# signalés à chaque message, pour reprendre là où le travail s'est arrêté.
# Demande répétée : un message très proche d'un précédent est signalé, pour vérifier ce qui
# existe déjà au lieu de tout refaire (journal local .claude/hooks/prompts.log).
# Agents propres au projet, sans `triggers:` (installés avant la bibliothèque) : impossibles à
# filtrer, ils sont signalés à chaque message pour que Claude les choisisse d'après leur description.
#
# Usage : hook (JSON sur l'entrée standard) ; `--audit` pour vérifier que chaque agent respecte
# les règles communes (déclencheurs, groupe, protocole, N1 existant) — code 1 sinon.
# Variables : REGULATOR_AGENTS_DIR (dossier des agents), REGULATOR_PROGRESS_DIR (points de
# reprise), REGULATOR_MAX (défaut : 4).

set -u
export LC_ALL=C

DIR="${REGULATOR_AGENTS_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/agents}"
PROGRESS_DIR="${REGULATOR_PROGRESS_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/progress}"
LAST_FILE="${REGULATOR_LAST_FILE:-${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/regulator.last}"
HISTORY_FILE="${REGULATOR_HISTORY_FILE:-${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/prompts.log}"
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

# nom<TAB>déclencheurs normalisés « | »<TAB>nombre déclaré<TAB>exclusions<TAB>N1 « | »<TAB>groupe
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
        gsub(/[ \t\r]/, "", a); gsub(/,+/, "|", a); gsub(/[ \t\r]/, "", g)
        printf "%s\t%s\t%d\t%s\t%s\t%s\n", name, out, n, ex, a, g
      }
      name = ""; t = ""; x = ""; a = ""; g = ""
    }
    { sub(/\r$/, "") }  # fins de ligne Windows (agents écrits sous Windows)
    FNR == 1     { flush(); front = ($0 == "---"); next }
    !front       { next }
    $0 == "---"  { front = 0; next }
    /^name:/     { name = $0; sub(/^name:[ \t]*/, "", name) }
    /^triggers:/ { t = $0; sub(/^triggers:[ \t]*/, "", t) }
    /^excludes:/ { x = $0; sub(/^excludes:[ \t]*/, "", x) }
    /^after:/    { a = $0; sub(/^after:[ \t]*/, "", a) }
    /^group:/    { g = $0; sub(/^group:[ \t]*/, "", g) }
    END          { flush() }' "$@"
}

if [[ "${1:-}" == "--audit" ]]; then
  echo "# Audit du régulateur — $DIR"
  # Groupes connus : profiles.conf de la bibliothèque (racine du dépôt ou .claude/ installé).
  GROUPS_KNOWN=""
  if [[ -f "$DIR/../profiles.conf" ]]; then
    GROUPS_KNOWN="$(awk -F'|' '$1 == "group" { printf " %s", $2 }' "$DIR/../profiles.conf")"
  fi
  NO_PROTOCOL="$(grep -L 'agent-protocol\.md' "$DIR"/*.md 2>/dev/null | sed 's#^.*/##; s#\.md$##' | tr '\n' ' ')"
  NO_GUARD="$(grep -L 'garde-fou non négociable' "$DIR"/*.md 2>/dev/null | sed 's#^.*/##; s#\.md$##' | tr '\n' ' ')"
  # Caractères invisibles (largeur nulle, inversion de sens, BOM) : servent à cacher des consignes.
  HIDDEN="$(find "$DIR" "$DIR/../skills" "$DIR/../standards" "$DIR/../workflows" "$DIR/../templates" -name '*.md' \
    -exec grep -lE $'\xe2\x80[\x8b-\x8f\xaa-\xae]|\xe2\x81[\xa0-\xa4\xa6-\xa9]|\xef\xbb\xbf' {} + 2>/dev/null | sed 's#^.*/\.\./##; s#^.*/agents/#agents/#' | tr '\n' ' ')"
  # Plafonds de ce qui est relu à chaque session : au-delà, compresser avec prompt-compressor avant de publier.
  BUDGET=""
  LIB_MD="$DIR/../claude-lib.md"; [[ -f "$LIB_MD" ]] || LIB_MD="$DIR/../CLAUDE.md"
  if [[ -f "$LIB_MD" ]] && (( $(wc -c <"$LIB_MD") > 8192 )); then BUDGET="${LIB_MD##*/} ($(wc -c <"$LIB_MD" | tr -d ' ') octets > 8192)"; fi
  # Longueur en caractères : les octets de continuation UTF-8 ne comptent pas.
  LONG_DESC="$(awk 'FNR == 1 { f = FILENAME; sub(/^.*\//, "", f); sub(/\.md$/, "", f) }
    /^description:/ && FNR < 30 { d = $0; sub(/^description:[ \t]*/, "", d); sub(/\r$/, "", d); gsub(/[\200-\277]/, "", d)
                                   if (length(d) > 300) printf "%s%s (%d)", (n++ ? ", " : ""), f, length(d) }' "$DIR"/*.md)"
  if [[ -n "$LONG_DESC" ]]; then BUDGET="$BUDGET${BUDGET:+ ; }description > 300 caractères : $LONG_DESC"; fi
  registry | awk -F'\t' -v known="$GROUPS_KNOWN" -v noproto="$NO_PROTOCOL" -v noguard="$NO_GUARD" -v hidden="$HIDDEN" -v budget="$BUDGET" '
    { agents++; names[$1] = 1
      if ($3 == 0) missing = missing " " $1
      if ($6 == "") nogroup = nogroup " " $1
      else if (known != "" && index(known " ", " " $6 " ") == 0) badgroup = badgroup " " $1 " (" $6 ")"
      if ($5 != "") after[$1] = $5
      n = split($2, t, "|"); for (i = 2; i <= n; i++) { owners[t[i]] = owners[t[i]] " " $1; count[t[i]]++ } }
    END {
      for (a in after) { m = split(after[a], x, "|"); for (i = 1; i <= m; i++) if (!(x[i] in names)) badafter = badafter " " a " (" x[i] ")" }
      sub(/ +$/, "", noproto); sub(/ +$/, "", noguard); sub(/ +$/, "", hidden)
      printf "%d agents lus.\n", agents
      if (missing != "") printf "Sans déclencheurs (jamais lancés, sauf par leur nom) :%s\n", missing
      if (nogroup != "") printf "Sans groupe (group:, requis par l installation par groupe) :%s\n", nogroup
      if (badgroup != "") printf "Groupe absent de profiles.conf :%s\n", badgroup
      if (noproto != "") printf "Sans protocole commun (standards/agent-protocol.md) : %s\n", noproto
      if (badafter != "") printf "N1 introuvable dans after: :%s\n", badafter
      if (noguard != "") printf "Sans garde-fou (aucun code malveillant, aucune fraude) : %s\n", noguard
      if (hidden != "") printf "Caractères invisibles (consignes cachées ?) : %s\n", hidden
      if (budget != "") printf "Trop long, relu à chaque session (compresser avec prompt-compressor) : %s\n", budget
      for (k in count) if (count[k] > 1) { shared = 1; printf "Déclencheur partagé « %s » :%s\n", k, owners[k] }
      bad = (missing != "" || nogroup != "" || badgroup != "" || noproto != "" || badafter != "" || noguard != "" || hidden != "" || budget != "")
      if (!bad && !shared) print "Aucun problème."
      exit bad
    }'
  exit $?
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

# Collage énorme (journal entier...) : bloqué avant d'atteindre le modèle, donc aucun jeton dépensé.
# Le code 2 efface le message et affiche la raison à l'utilisateur. « [long] » en tête l'envoie tel quel.
MAX_PROMPT="${REGULATOR_MAX_PROMPT:-20000}"
if [[ "$MAX_PROMPT" -gt 0 && ${#PROMPT} -gt "$MAX_PROMPT" && "$PROMPT" != "[long]"* ]]; then
  echo "[Régulateur] Message de ${#PROMPT} caractères bloqué avant envoi au modèle : aucun jeton dépensé. Colle seulement l'extrait utile (par exemple 30 lignes autour de l'erreur), ou commence le message par [long] pour l'envoyer tel quel. Plafond réglable : REGULATOR_MAX_PROMPT (0 = désactivé)." >&2
  exit 2
fi

# Points de reprise laissés par un travail interrompu (coupure de connexion, session fermée).
if [[ -d "$PROGRESS_DIR" ]]; then
  PENDING="$(grep -il '^statut:[[:space:]]*en cours' "$PROGRESS_DIR"/*.md 2>/dev/null | sed 's#^.*/#.claude/progress/#' | awk '{ printf "%s%s", (NR > 1 ? ", " : ""), $0 }')"
  if [[ -n "$PENDING" ]]; then
    echo "[Régulateur] Travail interrompu à reprendre (règle 10) : $PENDING."
  fi
fi

# Demande répétée : le message est comparé aux 200 précédents du projet, dans un journal local
# ignoré par git qui ne garde que les mots normalisés (3 lettres et plus, sans doublon).
# Proche = au moins 6 mots et 75 % de mots communs (indice de Jaccard).
if [[ -d "$(dirname "$HISTORY_FILE")" ]]; then
  WORDS="$(REGULATOR_PROMPT="$PROMPT" awk "$NORMALIZE"'
    BEGIN { n = split(norm(ENVIRON["REGULATOR_PROMPT"]), w, " "); for (i = 1; i <= n; i++) if (length(w[i]) >= 3) u[w[i]] = 1; for (k in u) print k }' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
  if [[ "$(wc -w <<<"$WORDS")" -ge 6 ]]; then
    SAME=""
    if [[ -f "$HISTORY_FILE" ]]; then
      SAME="$(tail -n 200 "$HISTORY_FILE" | WORDS="$WORDS" awk -F'\t' '
        BEGIN { n = split(ENVIRON["WORDS"], w, " "); for (i = 1; i <= n; i++) cur[w[i]] = 1 }
        NF >= 2 { m = split($2, o, " "); c = 0; for (i = 1; i <= m; i++) if (o[i] in cur) c++
                  if (c / (n + m - c) >= 0.75) last = $1 }
        END { print last }')"
    fi
    if [[ -n "$SAME" ]]; then
      echo "[Régulateur] Demande très proche d'un message du $SAME : lance d'abord request-history, puis ne fais que ce qui manque."
    fi
    { [[ -f "$HISTORY_FILE" ]] && tail -n 199 "$HISTORY_FILE"; printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$WORDS"; } >"$HISTORY_FILE.new" 2>/dev/null \
      && mv "$HISTORY_FILE.new" "$HISTORY_FILE"
  fi
fi

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
    if (score) printf "%d\t%s\t%s\t%s\n", score, $1, hits, $5
  }' | sort -t "$(printf '\t')" -k1,1nr -k2,2 | head -n "$MAX")"

# Agents retenus, un nom par ligne, pour le mod agents-status qui les affiche sous la saisie.
if [[ -d "$(dirname "$LAST_FILE")" ]]; then
  printf '%s\n' "$SELECTED" | awk -F'\t' 'NF > 1 { print $2 }' >"$LAST_FILE" 2>/dev/null || true
fi

PROJECT_AGENTS="$(registry | awk -F'\t' '$3 == 0 { printf "%s%s", (n++ ? ", " : ""), $1 }')"
# Sortie minimale, relue à chaque message : les règles d'usage sont dans CLAUDE.md (règles 1, 6, 9, 12).
PROJECT_NOTE="[Régulateur] Agents du projet sans triggers (à lancer seulement si leur description correspond) : $PROJECT_AGENTS."

if [[ -z "$SELECTED" ]]; then
  echo "[Régulateur] Aucun agent de la bibliothèque."
  if [[ -n "$PROJECT_AGENTS" ]]; then echo "$PROJECT_NOTE"; fi
  exit 0
fi

# Niveaux : chaque N2 déclare ses N1 (after:) ; on en déduit le N2 de chaque N1.
PAIRS="$(registry | awk -F'\t' '$5 != "" { n = split($5, a, "|"); for (i = 1; i <= n; i++) printf "%s\t%s\n", a[i], $1 }')"
LIST="$(printf '%s\n' "$SELECTED" | PAIRS="$PAIRS" awk -F'\t' '
  BEGIN { n = split(ENVIRON["PAIRS"], l, "\n")
          for (i = 1; i <= n; i++) if (split(l[i], f, "\t") == 2) n2[f[1]] = n2[f[1]] (n2[f[1]] == "" ? "" : ", ") f[2] }
  {
    lvl = ""
    if ($4 != "") { lvl = $4; gsub(/\|/, ", ", lvl); lvl = " [N2 de " lvl "]" }
    else if ($2 in n2) lvl = " [N1 → " n2[$2] "]"
    printf "%s%s%s%s", (NR > 1 ? " ; " : ""), $2, ($3 != "" ? " (" $3 ")" : " (nommé)"), lvl
  }')"
echo "[Régulateur] Agents retenus : $LIST."
if [[ -n "$PROJECT_AGENTS" ]]; then echo "$PROJECT_NOTE"; fi
