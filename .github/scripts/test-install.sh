#!/usr/bin/env bash
# Vérifie install.sh de bout en bout : installation, relance, --force, branche main,
# lancement via stdin (curl | bash) et cas d'erreur. Sort en 1 si un contrôle échoue.
set -uo pipefail

cd "$(dirname "$0")/../.."
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

# 2. Relance sans --force : rien n'est écrasé
run "$WORK/2.log" --dir "$P"; code=$?
check "relance : code de sortie 0" test "$code" -eq 0
check "relance : dossiers existants ignorés (SKIP)" grep -q SKIP "$WORK/2.log"
check "relance : CLAUDE.md de la bibliothèque mis à côté" test -f "$P/.claude/CLAUDE.md.claude-engineering-lib"

# 3. --force remplace proprement
touch "$P/.claude/agents/marqueur"
run "$WORK/3.log" --dir "$P" --force; code=$?
check "--force : code de sortie 0" test "$code" -eq 0
check "--force : ancien contenu remplacé" test ! -e "$P/.claude/agents/marqueur"
check "--force : aucun dossier .new résiduel" test -z "$(ls -d "$P"/.claude/*.new 2>/dev/null)"

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

if [[ $FAILS -gt 0 ]]; then
  echo
  echo "$FAILS contrôle(s) en échec. Journaux :"
  for f in "$WORK"/*.log; do echo "----- $f"; cat "$f"; done
  exit 1
fi
echo
echo "Tous les contrôles sont passés."
