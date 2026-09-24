#!/usr/bin/env bash
# Installe la bibliothèque claude-engineering-lib dans le dossier .claude/ du dépôt courant.
# Compatible Linux, macOS (bash 3.2 et outils BSD compris), WSL et Git Bash sous Windows.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --force        # écrase les fichiers existants
#   curl -fsSL .../install.sh | bash -s -- --version v1.2.0
#   curl -fsSL .../install.sh | bash -s -- --dir ./mon-projet

set -euo pipefail

REPO="joeldogbo/claude-engineering-lib"
TARGET_DIR="$(pwd)"
FORCE=0
VERSION=""

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
TMP_DIR=""

paint() { # style texte
  if [[ $USE_COLOR -eq 1 ]]; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi
}

die() { # message — affiche l'erreur et quitte (le trap EXIT fait le ménage)
  if [[ $TASK_PENDING -eq 1 ]]; then task_end FAIL; fi
  printf '\n  %s %s\n\n' "$(paint "$BADGE_ERR" ' ERREUR ')" "$1" >&2
  exit 1
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

# Dernière release via la redirection de github.com/<repo>/releases/latest :
# contrairement à l'API GitHub, elle n'est pas limitée à 60 appels par heure.
# Affiche "" si le dépôt n'a encore aucune release ; échoue si GitHub est injoignable.
resolve_latest() {
  local url
  url="$(curl -fsSLI --retry 2 -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest")" || return 1
  case "$url" in
    */releases/tag/*) printf '%s' "${url##*/}" ;;
    *) printf '' ;;
  esac
}

download() { # url destination — avec spinner si la sortie est un terminal
  if [[ $USE_COLOR -eq 0 ]]; then
    curl -fsSL --retry 2 "$1" -o "$2"
    return
  fi
  curl -fsSL --retry 2 "$1" -o "$2" &
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

cleanup() {
  local status=$?
  if [[ $TASK_PENDING -eq 1 ]]; then
    task_end FAIL
    printf '\n  %s %s\n\n' "$(paint "$BADGE_ERR" ' ERREUR ')" "L'installation a échoué (voir le message ci-dessus)." >&2
  fi
  if [[ $USE_COLOR -eq 1 ]]; then printf '\033[?25h'; fi
  if [[ -n "$TMP_DIR" ]]; then rm -rf "$TMP_DIR"; fi
  exit "$status"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --version|--dir)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then die "L'option $1 attend une valeur."; fi
      if [[ "$1" == "--version" ]]; then VERSION="$2"; else TARGET_DIR="$2"; fi
      shift 2 ;;
    *) die "Option inconnue : $1 (options : --force, --version <tag>, --dir <dossier>)." ;;
  esac
done

command -v curl >/dev/null 2>&1 || die "curl est requis : installe-le avec le gestionnaire de paquets du système."
command -v tar  >/dev/null 2>&1 || die "tar est requis : installe-le avec le gestionnaire de paquets du système."

if [[ -z "$VERSION" ]]; then
  VERSION="$(resolve_latest)" || die "Impossible de joindre GitHub pour trouver la dernière version (connexion, proxy ?)."
fi

if [[ "$VERSION" == "main" ]]; then
  banner "main"
  ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
  task_start "Téléchargement" "main"
elif [[ -n "$VERSION" ]]; then
  banner "$VERSION"
  ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
  task_start "Téléchargement" "$VERSION"
else
  banner "main"
  ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
  task_start "Téléchargement" "main (aucune release)"
fi

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t claude-engineering-lib)"
download "$ARCHIVE_URL" "$TMP_DIR/lib.tar.gz" || die "Téléchargement impossible : $ARCHIVE_URL"
tar -xzf "$TMP_DIR/lib.tar.gz" -C "$TMP_DIR" || die "Extraction de l'archive impossible."
task_end DONE
echo
SRC_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

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
    # Copie complète à côté avant de remplacer : un échec en cours de copie
    # laisse l'ancienne version intacte.
    rm -rf "$CLAUDE_DIR/$item.new"
    cp -R "$SRC_DIR/$item" "$CLAUDE_DIR/$item.new"
    rm -rf "${CLAUDE_DIR:?}/${item:?}"
    mv "$CLAUDE_DIR/$item.new" "$CLAUDE_DIR/$item"
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
