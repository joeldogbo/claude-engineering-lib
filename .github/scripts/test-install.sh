#!/usr/bin/env bash
# Vérifie install.sh de bout en bout : installation, relance, --force, branche main,
# lancement via stdin (curl | bash) et cas d'erreur. Sort en 1 si un contrôle échoue.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
INSTALL="$PWD/install.sh"
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t install-test)"
FAILS=0

check() { # description commande...
  local what="$1"; shift
  if "$@"; then echo "ok   - $what"; else echo "FAIL - $what"; FAILS=$((FAILS + 1)); fi
}
run() { # dossier-log args... — lance l'installateur, renvoie son code de sortie
  local log="$1"; shift
  bash "$INSTALL" "$@" >"$log" 2>&1
}

# 1. Installation dans un projet qui a déjà son propre CLAUDE.md
P="$WORK/projet"
mkdir -p "$P" && echo "projet perso" >"$P/CLAUDE.md"
run "$WORK/1.log" --dir "$P"; code=$?
check "installation : code de sortie 0" test "$code" -eq 0
check "installation : agents dans .claude/agents" test -n "$(ls "$P/.claude/agents"/*.md 2>/dev/null)"
check "installation : routeur de workflows présent" test -f "$P/.claude/skills/workflow/SKILL.md"
check "installation : .claude/CLAUDE.md présent" test -f "$P/.claude/CLAUDE.md"
check "installation : CLAUDE.md du projet intact" test "$(cat "$P/CLAUDE.md")" = "projet perso"
check "installation : rien copié à la racine" test ! -e "$P/agents"

check "installation : manifeste écrit" grep -q '^@version ' "$P/.claude/.claude-lib.manifest"

# 2. Relance : mise à jour, rien à changer
run "$WORK/2.log" --dir "$P"; code=$?
check "relance : code de sortie 0" test "$code" -eq 0
check "relance : détectée comme mise à jour" grep -q 'Installation existante' "$WORK/2.log"
check "relance : rien à faire (SKIP)" grep -q SKIP "$WORK/2.log"
check "relance : aucune sauvegarde inutile" test ! -e "$P/.claude/backups"

# 3. --force remplace les fichiers modifiés, après sauvegarde ; les fichiers de l'utilisateur restent
touch "$P/.claude/skills/marqueur"
echo "agent perso" >"$P/.claude/agents/perso.md"
echo "modifié" >"$P/.claude/agents/git.md"
run "$WORK/3.log" --dir "$P" --force; code=$?
check "--force : code de sortie 0" test "$code" -eq 0
check "--force : fichier de l'utilisateur conservé" test -e "$P/.claude/skills/marqueur"
check "--force : agent de la bibliothèque remplacé" grep -q '^name: git' "$P/.claude/agents/git.md"
check "--force : ancienne version sauvegardée" grep -rq 'modifié' "$P/.claude/backups"
check "--force : agent de l'utilisateur conservé" test -f "$P/.claude/agents/perso.md"
check "--force : aucun résidu de copie" test -z "$(ls -d "$P"/.claude/.claude-lib-staging "$P"/.claude/.claude-lib.lock 2>/dev/null)"

# 4. Branche main et lancement via stdin, comme `curl ... | bash -s --`
run "$WORK/4.log" --version main --dir "$WORK/main"; code=$?
check "--version main : code de sortie 0" test "$code" -eq 0
bash -s -- --dir "$WORK/stdin" <"$INSTALL" >"$WORK/5.log" 2>&1; code=$?
check "via stdin : code de sortie 0" test "$code" -eq 0
check "via stdin : .claude/CLAUDE.md présent" test -f "$WORK/stdin/.claude/CLAUDE.md"

# 5. Erreurs : code non nul, message lisible, rien d'écrit
run "$WORK/6.log" --version v0.0.0-inexistante --dir "$WORK/ko"; code=$?
check "version inexistante : code de sortie non nul" test "$code" -ne 0
check "version inexistante : message ERREUR" grep -q ERREUR "$WORK/6.log"
check "version inexistante : aucun dossier créé" test ! -e "$WORK/ko/.claude"
run "$WORK/7.log" --version; code=$?
check "--version sans valeur : code de sortie non nul" test "$code" -ne 0
run "$WORK/8.log" --option-inconnue; code=$?
check "option inconnue : code de sortie non nul" test "$code" -ne 0

# 6. Copie locale (--source) : la version du commit testé, hook du régulateur compris
mkdir -p "$WORK/src/.claude" && echo '{ "permissions": { "allow": ["Bash(ls)"] } }' >"$WORK/src/.claude/settings.json"
run "$WORK/9.log" --source "$PWD" --dir "$WORK/src"; code=$?
check "--source : code de sortie 0" test "$code" -eq 0
check "--source : hook du régulateur copié" test -f "$WORK/src/.claude/hooks/regulator.sh"
check "--source : hook enregistré dans settings.json" grep -Eq 'regulator.(sh|ps1)' "$WORK/src/.claude/settings.json"
check "--source : réglages existants conservés" grep -q 'Bash(ls)' "$WORK/src/.claude/settings.json"
run "$WORK/10.log" --source "$PWD" --dir "$WORK/src"
check "--source : hook enregistré une seule fois" test "$(grep -Ec 'regulator.(sh|ps1)' "$WORK/src/.claude/settings.json")" -eq 1

# 7. Choix des agents selon le type de projet, les groupes, ou agent par agent
agents_in() { ls "$1/.claude/agents" 2>/dev/null | sed 's/\.md$//' | tr '\n' ' '; }
has_agents() { local d="$1" a; shift; for a in "$@"; do case " $(agents_in "$d") " in *" $a "*) ;; *) return 1 ;; esac; done; }
lacks_agents() { local d="$1" a; shift; for a in "$@"; do case " $(agents_in "$d") " in *" $a "*) return 1 ;; esac; done; }
total="$(ls "$PWD"/agents/*.md | wc -l | tr -d ' ')"

mkdir -p "$WORK/mobile" && touch "$WORK/mobile/pubspec.yaml"
run "$WORK/11.log" --source "$PWD" --dir "$WORK/mobile"; code=$?
check "type détecté (Flutter) : code de sortie 0" test "$code" -eq 0
check "type détecté (Flutter) : agents mobile" has_agents "$WORK/mobile" frontend backend security project-context language
check "type détecté (Flutter) : pas de SEO" lacks_agents "$WORK/mobile" seo geo

mkdir -p "$WORK/api" && echo '{ "dependencies": { "express": "4" } }' >"$WORK/api/package.json"
run "$WORK/12.log" --source "$PWD" --dir "$WORK/api" --yes
check "type détecté (API) : pas d'agent d'interface" lacks_agents "$WORK/api" frontend ux-ui seo
check "type détecté (API) : agents serveur" has_agents "$WORK/api" backend api database

run "$WORK/13.log" --source "$PWD" --dir "$WORK/groupes" --groups security,seo
check "--groups : socle + groupes demandés" has_agents "$WORK/groupes" project-context code-reviewer security security-fixer seo geo
check "--groups : rien d'autre" lacks_agents "$WORK/groupes" frontend payments
check "--groups : profiles.conf copié pour l'audit" test -f "$WORK/groupes/.claude/profiles.conf"

run "$WORK/14.log" --source "$PWD" --dir "$WORK/groupes" --agents payments,manuals; code=$?
check "--agents : ajout à une installation existante" has_agents "$WORK/groupes" payments manuals security seo

run "$WORK/15.log" --source "$PWD" --dir "$WORK/tout" --type library --all
check "--all : tous les agents" test "$(ls "$WORK/tout/.claude/agents" | wc -l | tr -d ' ')" -eq "$total"

run "$WORK/16.log" --source "$PWD" --dir "$WORK/ko2" --type inconnu; code=$?
check "type inconnu : code de sortie non nul" test "$code" -ne 0
check "type inconnu : aucun dossier créé" test ! -e "$WORK/ko2/.claude"
run "$WORK/17.log" --source "$PWD" --dir "$WORK/ko2" --agents nimporte; code=$?
check "agent inconnu : code de sortie non nul" test "$code" -ne 0

# Menu : « sur mesure », groupes 1 (docs) et 5 (performance), puis un agent en plus.
mkdir -p "$WORK/menu" && echo '{ "dependencies": { "react-native": "0.74" } }' >"$WORK/menu/package.json"
printf '7\n1 5\nseo\n' >"$WORK/menu.in"
CLAUDE_LIB_TTY="$WORK/menu.in" bash "$INSTALL" --source "$PWD" --dir "$WORK/menu" >"$WORK/18.log" 2>&1; code=$?
check "menu : code de sortie 0" test "$code" -eq 0
check "menu : type détecté affiché" grep -q 'détecté : .*mobile' "$WORK/18.log"
check "menu : sélection sur mesure" has_agents "$WORK/menu" project-context documentation manuals performance load-testing seo
check "menu : rien hors sélection" lacks_agents "$WORK/menu" frontend security geo
printf 'x\ny\nz\n' >"$WORK/menu-ko.in"
CLAUDE_LIB_TTY="$WORK/menu-ko.in" bash "$INSTALL" --source "$PWD" --dir "$WORK/menu-ko" >"$WORK/19.log" 2>&1; code=$?
check "menu : réponses invalides, arrêt sans boucler" test "$code" -ne 0
check "menu : réponses invalides, rien d'écrit" test ! -e "$WORK/menu-ko/.claude"

# 8. Mise à jour : une « nouvelle version » de la bibliothèque, préparée dans une copie
V1="$WORK/v1"; V2="$WORK/v2"; U="$WORK/maj"
mkdir -p "$V1" "$U"
cp -R "$PWD"/CLAUDE.md "$PWD"/agents "$PWD"/skills "$PWD"/standards "$PWD"/templates "$PWD"/workflows "$PWD"/hooks "$PWD"/profiles.conf "$V1/"
cp -R "$V1" "$V2"
run "$WORK/20.log" --source "$V1" --dir "$U" --groups security
echo "évolution" >>"$V2/agents/git.md"                                   # changé dans la bibliothèque seulement
echo "évolution" >>"$V2/agents/code-reviewer.md"; echo "perso" >>"$U/.claude/agents/code-reviewer.md" # des deux côtés
echo "perso" >>"$U/.claude/agents/refactoring.md"                        # chez l'utilisateur seulement
rm "$V2/agents/security-fixer.md"                                        # retiré de la bibliothèque
printf -- '---\nname: nouveau\ndescription: x\ntriggers: zzz\ngroup: security\n---\nx\n' >"$V2/agents/nouveau.md"
rm "$U/.claude/agents/debugging.md"                                      # supprimé par l'utilisateur
cp -R "$U" "$WORK/maj-avant"

run "$WORK/21.log" --source "$V2" --dir "$U" --dry-run; code=$?
check "--dry-run : code de sortie 0" test "$code" -eq 0
check "--dry-run : plan affiché" grep -q 'agents/git.md' "$WORK/21.log"
check "--dry-run : rien d'écrit" diff -r "$U" "$WORK/maj-avant"

CLAUDE_LIB_TEST_FAIL_AT=2 bash "$INSTALL" --source "$V2" --dir "$U" >"$WORK/22.log" 2>&1; code=$?
check "panne en cours d'écriture : code de sortie non nul" test "$code" -ne 0
check "panne en cours d'écriture : état d'avant restauré" diff -r -x backups "$U" "$WORK/maj-avant"

run "$WORK/23.log" --source "$V2" --dir "$U" --update; code=$?
check "--update : code de sortie 0" test "$code" -eq 0
check "--update : fichier non modifié mis à jour" grep -q 'évolution' "$U/.claude/agents/git.md"
check "--update : ancienne version sauvegardée" test -n "$(find "$U/.claude/backups" -name git.md)"
check "--update : modification de l'utilisateur conservée" grep -q 'perso' "$U/.claude/agents/code-reviewer.md"
check "--update : conflit signalé (MERGE)" grep -q MERGE "$WORK/23.log"
check "--update : nouvelle version mise à côté" grep -q 'évolution' "$U/.claude/updates/agents/code-reviewer.md.new"
check "--update : modification sans conflit conservée" grep -q 'perso' "$U/.claude/agents/refactoring.md"
check "--update : pas de copie à fusionner sans conflit" test ! -e "$U/.claude/updates/agents/refactoring.md.new"
check "--update : agent retiré de la bibliothèque supprimé" test ! -e "$U/.claude/agents/security-fixer.md"
check "--update : nouvel agent d'un groupe installé ajouté" test -f "$U/.claude/agents/nouveau.md"
check "--update : agent supprimé par l'utilisateur non réinstallé" test ! -e "$U/.claude/agents/debugging.md"
check "--update : sauvegardes hors de git" test -f "$U/.claude/backups/.gitignore"

run "$WORK/24.log" --source "$V2" --dir "$U" --agents debugging
check "--agents : agent supprimé réinstallé à la demande" test -f "$U/.claude/agents/debugging.md"
run "$WORK/25.log" --source "$V2" --dir "$U" --force
check "--force : conflit remplacé" grep -q 'évolution' "$U/.claude/agents/code-reviewer.md"

run "$WORK/26.log" --source "$V2" --dir "$WORK/rien" --update; code=$?
check "--update sans installation : code de sortie non nul" test "$code" -ne 0
check "--update sans installation : aucun dossier créé" test ! -e "$WORK/rien/.claude"
sed -i.bak 's/^@version .*/@version v99.0.0/' "$U/.claude/.claude-lib.manifest"
run "$WORK/27.log" --version v1.0.0 --dir "$U"; code=$?
check "version plus ancienne : refusée sans --force" test "$code" -ne 0
check "version plus ancienne : message explicite" grep -q 'plus récente' "$WORK/27.log"
mkdir "$U/.claude/.claude-lib.lock"
run "$WORK/28.log" --source "$V2" --dir "$U"; code=$?
check "installation simultanée : refusée" test "$code" -ne 0
rmdir "$U/.claude/.claude-lib.lock"

# Installation antérieure au manifeste : les anciennes versions sont remplacées après sauvegarde
rm "$U/.claude/.claude-lib.manifest"
echo "ancienne" >>"$U/.claude/agents/testing.md"
run "$WORK/29.log" --source "$V2" --dir "$U"; code=$?
check "sans manifeste : code de sortie 0" test "$code" -eq 0
check "sans manifeste : ancienne version remplacée" test -z "$(grep 'ancienne' "$U/.claude/agents/testing.md")"
check "sans manifeste : manifeste créé" test -f "$U/.claude/.claude-lib.manifest"

if [[ $FAILS -gt 0 ]]; then
  echo
  echo "$FAILS contrôle(s) en échec. Journaux :"
  for f in "$WORK"/*.log; do echo "----- $f"; cat "$f"; done
  exit 1
fi
echo
echo "Tous les contrôles sont passés."
