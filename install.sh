#!/usr/bin/env bash
# Installe la bibliothèque claude-engineering-lib dans le dépôt courant.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --force        # écrase les fichiers existants
#   curl -fsSL .../install.sh | bash -s -- --version v1.2.0

set -euo pipefail

REPO="joeldogbo/claude-engineering-lib"
TARGET_DIR="$(pwd)"
FORCE=0
VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --version) VERSION="$2"; shift 2 ;;
    --dir) TARGET_DIR="$2"; shift 2 ;;
    *) echo "Option inconnue: $1" >&2; exit 1 ;;
  esac
done

# --- Affichage : couleurs ANSI 256, désactivées hors terminal ou avec NO_COLOR ---
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then USE_COLOR=1; else USE_COLOR=0; fi
GREEN='38;5;41'
GRAY='38;5;245'
YELLOW='38;5;214'
RED='38;5;203'
BADGE_OK='1;38;5;16;48;5;41'
BADGE_WARN='1;38;5;16;48;5;214'
BADGE_ERR='1;97;48;5;160'
WIDTH=46
TASK_PENDING=0

paint() { # style texte
  if [[ $USE_COLOR -eq 1 ]]; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi
}

banner() {
  local rows=(
    ' XXXX X      XXX  X   X XXXX  XXXXX'
    'X     X     X   X X   X X   X X    '
    'X     X     XXXXX X   X X   X XXXX '
    'X     X     X   X X   X X   X X    '
    ' XXXX XXXXX X   X  XXX  XXXX  XXXXX'
  )
  local shades=('38;5;120' '38;5;84' '38;5;48' '38;5;41' '38;5;35')
  local i line
  echo
  for i in "${!rows[@]}"; do
    line="${rows[$i]// /  }"
    line="${line//X/██}"
    printf '  %s\n' "$(paint "${shades[$i]}" "$line")"
  done
  echo
  printf '  %s  %s\n' "$(paint "1;$GREEN" 'E N G I N E E R I N G   L I B')" "$(paint "$GRAY" "$1")"
  printf '  %s\n' "$(paint "$GRAY" 'Agents, skills & workflows pour Claude Code, quelle que soit la stack.')"
  printf '  %s %s\n\n' "$(paint "$GRAY" 'by')" "$(paint "1;$GREEN" 'joeldogbo')"
}

task_start() { # label [détail]
  local label="$1" detail="${2:-}" used n
  used=${#label}
  if [[ -n "$detail" ]]; then used=$(( used + ${#detail} + 1 )); fi
  n=$(( WIDTH - used ))
  if (( n < 3 )); then n=3; fi
  printf '  %s' "$(paint 1 "$label")"
  if [[ -n "$detail" ]]; then printf ' %s' "$(paint "$GRAY" "$detail")"; fi
  printf ' %s ' "$(paint "$GRAY" "$(printf '%*s' "$n" '' | tr ' ' '.')")"
  TASK_PENDING=1
}

task_end() { # DONE | SKIP | MERGE | FAIL
  local style="1;$YELLOW"
  case "$1" in
    DONE) style="1;$GREEN" ;;
    FAIL) style="1;$RED" ;;
  esac
  printf '%s\n' "$(paint "$style" "$1")"
  TASK_PENDING=0
}

download() { # url destination — avec spinner si la sortie est un terminal
  if [[ $USE_COLOR -eq 0 ]]; then
    curl -fsSL "$1" -o "$2"
    return
  fi
  curl -fsSL "$1" -o "$2" &
  local pid=$! i=0
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  printf '\033[?25l'
  while kill -0 "$pid" 2>/dev/null; do
    printf '%s\b' "$(paint "$GREEN" "${frames[i++ % 10]}")"
    sleep 0.08
  done
  printf ' \b\033[?25h'
  wait "$pid"
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  local status=$?
  if [[ $TASK_PENDING -eq 1 ]]; then
    task_end FAIL
    printf '\n  %s %s\n\n' "$(paint "$BADGE_ERR" ' ERREUR ')" "L'installation a échoué (voir le message ci-dessus)."
  fi
  if [[ $USE_COLOR -eq 1 ]]; then printf '\033[?25h'; fi
  rm -rf "$TMP_DIR"
  exit "$status"
}
trap cleanup EXIT

command -v curl >/dev/null 2>&1 || { echo "curl est requis." >&2; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo "tar est requis." >&2; exit 1; }

if [[ -z "$VERSION" ]]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/' || true)"
fi

if [[ -n "$VERSION" ]]; then
  banner "$VERSION"
  ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
  task_start "Téléchargement" "$VERSION"
else
  banner "main"
  ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
  task_start "Téléchargement" "main (aucune release)"
fi

download "$ARCHIVE_URL" "$TMP_DIR/lib.tar.gz"
tar -xzf "$TMP_DIR/lib.tar.gz" -C "$TMP_DIR"
task_end DONE
echo
SRC_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d)"

COPY_ITEMS=(agents skills standards templates workflows)
SKIPPED=""
CLAUDE_DIR="$TARGET_DIR/.claude"
mkdir -p "$CLAUDE_DIR"

for item in "${COPY_ITEMS[@]}"; do
  if [[ ! -d "$SRC_DIR/$item" ]]; then continue; fi
  count="$(find "$SRC_DIR/$item" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  task_start ".claude/$item/" "($count)"
  if [[ -d "$CLAUDE_DIR/$item" && $FORCE -eq 0 ]]; then
    SKIPPED="${SKIPPED:+$SKIPPED, }.claude/$item/"
    task_end SKIP
  else
    rm -rf "$CLAUDE_DIR/$item"
    cp -R "$SRC_DIR/$item" "$CLAUDE_DIR/$item"
    task_end DONE
  fi
done

CLAUDE_MD_KEPT=0
task_start ".claude/CLAUDE.md"
if [[ -f "$CLAUDE_DIR/CLAUDE.md" && $FORCE -eq 0 ]]; then
  CLAUDE_MD_KEPT=1
  cp "$SRC_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.claude-engineering-lib"
  task_end MERGE
else
  cp "$SRC_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  task_end DONE
fi

echo
printf '  %s Bibliothèque installée dans %s\n' "$(paint "$BADGE_OK" ' SUCCESS ')" "$(paint 1 "$TARGET_DIR")"
if [[ -n "$SKIPPED" ]]; then
  printf '  %s Déjà présents, conservés : %s. Relance avec %s pour les écraser.\n' \
    "$(paint "$BADGE_WARN" ' INFO ')" "$SKIPPED" "$(paint 1 '--force')"
fi
if [[ $CLAUDE_MD_KEPT -eq 1 ]]; then
  printf '  %s .claude/CLAUDE.md existant conservé : la version de la bibliothèque est dans %s, à fusionner.\n' \
    "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 '.claude/CLAUDE.md.claude-engineering-lib')"
fi
echo
printf '  %s Ouvre Claude Code ici et décris ta tâche : %s\n' "$(paint "$GREEN" '→')" "$(paint "1;$GREEN" 'les agents se lancent tout seuls.')"
printf '  %s %s\n\n' "$(paint "$GREEN" '★')" "$(paint "$GRAY" "github.com/${REPO}")"
