#!/usr/bin/env bash
# Installe la bibliothèque claude-engineering-lib dans le dossier .claude/ du dépôt courant.
# Compatible Linux, macOS (bash 3.2 et outils BSD compris), WSL et Git Bash sous Windows.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --force        # écrase les fichiers existants
#   curl -fsSL .../install.sh | bash -s -- --version v1.2.0
#   curl -fsSL .../install.sh | bash -s -- --dir ./mon-projet
#   bash install.sh --source ./claude-engineering-lib   # depuis une copie locale (tests, CI)
#
# Choix des agents (groupes et profils décrits dans profiles.conf) :
#   --type web|mobile|api|desktop|library   agents adaptés au type de projet
#   --groups security,performance           groupes d'agents (core est toujours installé)
#   --agents seo,geo                        agents précis, à ajouter à une installation existante
#   --all                                   tous les agents
#   --yes                                   sans menu : type détecté (tout si rien n'est reconnu)
# Sans option, un menu propose le type détecté dans le projet. Les mêmes choix passent par
# CLAUDE_LIB_TYPE, CLAUDE_LIB_GROUPS, CLAUDE_LIB_AGENTS, CLAUDE_LIB_ALL=1, CLAUDE_LIB_YES=1.

set -euo pipefail

REPO="joeldogbo/claude-engineering-lib"
TARGET_DIR="$(pwd)"
FORCE=0
VERSION=""
TYPE="${CLAUDE_LIB_TYPE:-}"
GROUPS_WANTED="${CLAUDE_LIB_GROUPS:-}"
AGENTS_WANTED="${CLAUDE_LIB_AGENTS:-}"
ALL="${CLAUDE_LIB_ALL:-0}"
YES="${CLAUDE_LIB_YES:-0}"

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
    --all) ALL=1; shift ;;
    --yes) YES=1; shift ;;
    --version|--dir|--source|--type|--groups|--agents)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then die "L'option $1 attend une valeur."; fi
      case "$1" in
        --version) VERSION="$2" ;;
        --dir) TARGET_DIR="$2" ;;
        --source) SOURCE="$2" ;;
        --type) TYPE="$2" ;;
        --groups) GROUPS_WANTED="$2" ;;
        --agents) AGENTS_WANTED="$2" ;;
      esac
      shift 2 ;;
    *) die "Option inconnue : $1 (options : --force, --version <tag>, --dir <dossier>, --source <copie locale>, --type <type>, --groups <g1,g2>, --agents <a1,a2>, --all, --yes)." ;;
  esac
done

if [[ -n "${SOURCE:-}" ]]; then
  # Installation depuis une copie locale de la bibliothèque (tests, CI, dépôt cloné).
  [[ -f "$SOURCE/CLAUDE.md" && -d "$SOURCE/agents" ]] || die "$SOURCE n'est pas une copie de la bibliothèque."
  banner "copie locale"
  SRC_DIR="$(cd "$SOURCE" && pwd)"
else
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
fi

# --- Choix des agents : groupes et profils de profiles.conf, groupe de chaque agent ---
# Listes séparées par des espaces (bash 3.2 de macOS : pas de tableaux associatifs).
PROFILES_FILE="$SRC_DIR/profiles.conf"
GROUP_LIST=""; PROFILE_LIST=""
conf_field() { # type nom numéro-de-champ
  awk -F'|' -v k="$1" -v n="$2" -v f="$3" '{ sub(/\r$/, "") } $1 == k && $2 == n { print $f; exit }' "$PROFILES_FILE"
}
if [[ -f "$PROFILES_FILE" ]]; then
  GROUP_LIST="$(awk -F'|' '$1 == "group" { printf "%s ", $2 }' "$PROFILES_FILE")"
  PROFILE_LIST="$(awk -F'|' '$1 == "profile" { printf "%s ", $2 }' "$PROFILES_FILE")"
fi
# nom<TAB>groupe pour chaque agent, en un seul processus (Git Bash est lent à en lancer).
AGENT_TABLE="$(awk 'FNR == 1 { front = ($0 ~ /^---/); n = FILENAME; sub(/.*\//, "", n); sub(/\.md$/, "", n); g = "" }
  front && FNR > 1 && /^---/ { print n "\t" g; front = 0 }
  front && /^group:/ { g = $0; sub(/^group:[ \t]*/, "", g); sub(/[ \t\r]+$/, "", g) }' "$SRC_DIR"/agents/*.md)"
AGENT_LIST="$(printf '%s\n' "$AGENT_TABLE" | cut -f1 | tr '\n' ' ')"
in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; } # élément liste
agents_of_groups() { # "g1 g2" → agents de ces groupes
  printf '%s\n' "$AGENT_TABLE" | awk -F'\t' -v gs=" $1 " 'index(gs, " " $2 " ") { printf "%s ", $1 }'
}
# shellcheck disable=SC2086  # découpage en mots voulu
count_words() { set -- $1; echo $#; }
# shellcheck disable=SC2086
nth_word() { local n="$1"; set -- $2; shift $((n - 1)); printf '%s' "$1"; } # numéro liste

# Type de projet d'après les fichiers présents ; DETECTED_WHY dit pourquoi.
DETECTED=""; DETECTED_WHY=""
detect_type() {
  local d="$TARGET_DIR" pkg=""
  [[ -f "$d/package.json" ]] && pkg="$(cat "$d/package.json")"
  has_dep() { case "$pkg" in *"\"$1"*) return 0 ;; esac; return 1; }
  if [[ -f "$d/pubspec.yaml" ]]; then DETECTED=mobile; DETECTED_WHY="pubspec.yaml (Flutter)"
  elif has_dep react-native || has_dep expo\" || has_dep @capacitor/ || has_dep @ionic/; then DETECTED=mobile; DETECTED_WHY="package.json (mobile)"
  elif [[ -f "$d/app/src/main/AndroidManifest.xml" || -d "$d/ios" && -d "$d/android" ]] || ls -d "$d"/*.xcodeproj >/dev/null 2>&1; then DETECTED=mobile; DETECTED_WHY="projet Android ou iOS"
  elif has_dep electron\" || has_dep @tauri-apps/ || [[ -d "$d/src-tauri" ]]; then DETECTED=desktop; DETECTED_WHY="Electron ou Tauri"
  elif grep -qsE '<Use(WPF|WindowsForms)>true' "$d"/*.csproj; then DETECTED=desktop; DETECTED_WHY="WPF ou WinForms"
  elif has_dep react\" || has_dep vue\" || has_dep @angular/core || has_dep svelte || has_dep next\" || has_dep nuxt || has_dep astro || has_dep vite\"; then DETECTED=web; DETECTED_WHY="package.json (front web)"
  elif [[ -f "$d/composer.json" || -f "$d/manage.py" || -f "$d/Gemfile" || -f "$d/index.html" ]]; then DETECTED=web; DETECTED_WHY="framework web côté serveur"
  elif [[ -f "$d/go.mod" || -f "$d/pom.xml" || -f "$d/build.gradle" || -f "$d/build.gradle.kts" || -f "$d/requirements.txt" || -f "$d/package.json" ]] || ls "$d"/*.csproj >/dev/null 2>&1; then DETECTED=api; DETECTED_WHY="backend sans interface détectée"
  elif [[ -f "$d/Cargo.toml" || -f "$d/pyproject.toml" || -f "$d/setup.py" || -f "$d/CMakeLists.txt" ]]; then DETECTED=library; DETECTED_WHY="bibliothèque ou CLI"
  fi
}

# Saisie du menu sur le terminal, même via « curl | bash » ; CLAUDE_LIB_TTY la remplace (tests).
TTY_IN="${CLAUDE_LIB_TTY:-/dev/tty}"
TRIES=0
retry() { # message — au-delà de 3 réponses invalides, l'installation s'arrête au lieu de boucler
  TRIES=$((TRIES + 1))
  if (( TRIES >= 3 )); then die "Choix invalide. Relance avec --type, --groups, --agents ou --all."; fi
  printf '  %s\n' "$(paint "$YELLOW" "$1")"
}
ask() { # question défaut — lit le descripteur 3, ouvert une fois sur TTY_IN par le menu
  local reply="" question
  question="$(printf '  %s %s ' "$(paint 1 "$1")" "$(paint "$GRAY" "[$2]")")"
  # Hors de la sortie standard, capturée par $(ask ...) ; descripteur 2 et non /dev/stderr,
  # qui rouvrirait le fichier journal depuis le début.
  if [[ -n "${CLAUDE_LIB_TTY:-}" ]]; then printf '%s ' "$question" >&2; else printf '%s ' "$question" >/dev/tty; fi
  IFS= read -r reply <&3 || reply=""
  printf '%s' "${reply:-$2}"
}

choose_menu() {
  local i=0 p choice desc nums n g extra
  echo
  if [[ -n "$DETECTED" ]]; then
    printf '  Type de projet détecté : %s %s\n\n' "$(paint "1;$GREEN" "$DETECTED")" "$(paint "$GRAY" "($DETECTED_WHY)")"
  else
    printf '  %s\n\n' "Aucun type de projet reconnu dans ce dossier."
  fi
  local default=0
  for p in $PROFILE_LIST; do
    i=$((i + 1)); if [[ "$p" == "$DETECTED" ]]; then default=$i; fi
    n="$(count_words "$(agents_of_groups "core $(conf_field profile "$p" 4)")")"
    printf '    %s  %-10s %s  %s\n' "$(paint "1;$GREEN" "$i")" "$p" "$(paint "$GRAY" "$(printf '%2s agents' "$n")")" "$(conf_field profile "$p" 3)"
  done
  printf '    %s  %-10s %s  %s\n' "$(paint "1;$GREEN" $((i + 1)))" "tout" "$(paint "$GRAY" "$(printf '%2s agents' "$(count_words "$AGENT_LIST")")")" "Tous les agents"
  printf '    %s  %-10s %s  %s\n\n' "$(paint "1;$GREEN" $((i + 2)))" "sur mesure" "$(paint "$GRAY" "         ")" "Choisir les groupes et les agents"
  if [[ $default -eq 0 ]]; then default=$((i + 1)); fi
  while :; do
    choice="$(ask "Ton choix" "$default")"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= i + 2 )); then break; fi
    retry "Entre un numéro entre 1 et $((i + 2))."
  done
  echo
  if (( choice <= i )); then TYPE="$(nth_word "$choice" "$PROFILE_LIST")"; return 0; fi
  if (( choice == i + 1 )); then ALL=1; return 0; fi
  printf '  %s\n' "Groupes (core est toujours installé) :"
  local optional="${GROUP_LIST/core /}"
  i=0
  for g in $optional; do
    i=$((i + 1))
    printf '    %s  %-12s %s  %s\n' "$(paint "1;$GREEN" "$(printf '%2s' "$i")")" "$g" "$(paint "$GRAY" "($(count_words "$(agents_of_groups "$g")"))")" "$(conf_field group "$g" 3)"
  done
  echo
  while :; do
    nums="$(ask "Numéros des groupes, séparés par des espaces" "aucun")"; GROUPS_WANTED=""
    if [[ "$nums" == aucun ]]; then break; fi
    for n in $nums; do
      if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= i )); then GROUPS_WANTED="$GROUPS_WANTED,$(nth_word "$n" "$optional")"; else GROUPS_WANTED="!"; break; fi
    done
    if [[ "$GROUPS_WANTED" != "!" ]]; then break; fi
    retry "Numéros entre 1 et $i, séparés par des espaces."
  done
  extra="$(ask "Agents en plus, séparés par des virgules (ex. seo,payments)" "aucun")"
  if [[ "$extra" != aucun ]]; then AGENTS_WANTED="$extra"; fi
  echo
  return 0
}

SELECTED_AGENTS=""; SELECTION_LABEL=""
if [[ -z "$PROFILE_LIST" ]]; then
  # Version de la bibliothèque sans profiles.conf : tous les agents, comme avant.
  SELECTED_AGENTS="$AGENT_LIST"; SELECTION_LABEL="tous"
else
  detect_type
  if [[ $ALL != 1 && -z "$TYPE$GROUPS_WANTED$AGENTS_WANTED" ]]; then
    if [[ $YES != 1 && ( -n "${CLAUDE_LIB_TTY:-}" || -t 1 ) ]] && { exec 3<"$TTY_IN"; } 2>/dev/null; then
      choose_menu
      exec 3<&-
    elif [[ -n "$DETECTED" ]]; then
      TYPE="$DETECTED"
    else
      ALL=1
    fi
  fi
  if [[ $ALL == 1 || "$TYPE" == all || "$TYPE" == tout ]]; then
    SELECTED_AGENTS="$AGENT_LIST"; SELECTION_LABEL="tous"
  else
    WANTED_GROUPS="core"
    if [[ -n "$TYPE" ]]; then
      in_list "$TYPE" "$PROFILE_LIST" || die "Type de projet inconnu : $TYPE (types : ${PROFILE_LIST}all)."
      WANTED_GROUPS="$WANTED_GROUPS $(conf_field profile "$TYPE" 4)"; SELECTION_LABEL="$TYPE"
    fi
    for g in $(printf '%s' "$GROUPS_WANTED" | tr ',' ' '); do
      in_list "$g" "$GROUP_LIST" || die "Groupe inconnu : $g (groupes : ${GROUP_LIST% })."
      WANTED_GROUPS="$WANTED_GROUPS $g"
    done
    if [[ -n "$GROUPS_WANTED" ]]; then
      SELECTION_LABEL="${SELECTION_LABEL:-core} + $(printf '%s' "$GROUPS_WANTED" | tr -s ',' ' ' | sed 's/^ //; s/ $//; s/ /, /g')"
    fi
    SELECTED_AGENTS="$(agents_of_groups "$WANTED_GROUPS")"
    for a in $(printf '%s' "$AGENTS_WANTED" | tr ',' ' '); do
      in_list "$a" "$AGENT_LIST" || die "Agent inconnu : $a (voir la liste dans CLAUDE.md)."
      in_list "$a" "$SELECTED_AGENTS" || SELECTED_AGENTS="$SELECTED_AGENTS$a "
    done
    if [[ -n "$AGENTS_WANTED" ]]; then SELECTION_LABEL="${SELECTION_LABEL:-core} + $(printf '%s' "$AGENTS_WANTED" | sed 's/,/, /g')"; fi
    SELECTION_LABEL="${SELECTION_LABEL:-core}"
  fi
fi

COPY_ITEMS=(skills standards templates workflows hooks)
SKIPPED=""
CLAUDE_DIR="$TARGET_DIR/.claude"
mkdir -p "$CLAUDE_DIR"

# Agents choisis, un par un : ceux déjà installés sont gardés (remplacés avec --force), et
# un agent installé auparavant n'est jamais supprimé — on peut donc en ajouter plus tard.
mkdir -p "$CLAUDE_DIR/agents"
added=0; kept=0
for a in $SELECTED_AGENTS; do
  if [[ -f "$CLAUDE_DIR/agents/$a.md" && $FORCE -eq 0 ]]; then
    kept=$((kept + 1))
  else
    cp "$SRC_DIR/agents/$a.md" "$CLAUDE_DIR/agents/$a.md.new"
    mv "$CLAUDE_DIR/agents/$a.md.new" "$CLAUDE_DIR/agents/$a.md"
    added=$((added + 1))
  fi
done
task_start ".claude/agents/" "($(count_words "$SELECTED_AGENTS")/$(count_words "$AGENT_LIST") · $SELECTION_LABEL)"
if [[ $added -eq 0 ]]; then
  SKIPPED="${SKIPPED:+$SKIPPED, }.claude/agents/"
  task_end SKIP
else
  task_end DONE
fi
if [[ -f "$PROFILES_FILE" ]]; then cp "$PROFILES_FILE" "$CLAUDE_DIR/profiles.conf"; fi

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

# Hook du régulateur dans .claude/settings.json : ajouté à l'existant, sans rien écraser.
# Sans outil capable de fusionner du JSON (python3, jq), la configuration est mise à côté.
HOOK_MERGE=""
# Premier Python 3 qui fonctionne vraiment : sous Windows, « python3 » peut n'être qu'un raccourci du Microsoft Store.
PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then
    PY="$candidate"; break
  fi
done
if [[ -f "$SRC_DIR/hooks/regulator.sh" ]]; then
  SETTINGS="$CLAUDE_DIR/settings.json"
  # shellcheck disable=SC2016  # ${CLAUDE_PROJECT_DIR} est développé par Claude Code, pas par ce script.
  HOOK='{"type": "command", "command": "bash", "args": ["${CLAUDE_PROJECT_DIR}/.claude/hooks/regulator.sh"], "timeout": 30}'
  # Sous Windows (Git Bash, MSYS, Cygwin), Claude Code peut trouver le bash de WSL, qui ne lit pas
  # les chemins « d:\... » : le hook passe par PowerShell, toujours présent, comme avec install.ps1.
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      # shellcheck disable=SC2016
      HOOK='{"type": "command", "command": "powershell", "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "${CLAUDE_PROJECT_DIR}/.claude/hooks/regulator.ps1"], "timeout": 30}' ;;
  esac
  task_start ".claude/settings.json" "(régulateur)"
  if [[ ! -f "$SETTINGS" ]]; then
    printf '{\n  "hooks": {\n    "UserPromptSubmit": [\n      { "hooks": [%s] }\n    ]\n  }\n}\n' "$HOOK" >"$SETTINGS"
    task_end DONE
  elif [[ "$HOOK" == *regulator.ps1* ]] && grep -q 'regulator\.sh' "$SETTINGS"; then
    # Installation Windows antérieure avec le hook bash : remplacé par le hook PowerShell.
    # shellcheck disable=SC2016
    sed -i.bak 's#"command": *"bash", *"args": *\["${CLAUDE_PROJECT_DIR}/.claude/hooks/regulator.sh"\]#"command": "powershell", "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "${CLAUDE_PROJECT_DIR}/.claude/hooks/regulator.ps1"]#' "$SETTINGS" && rm -f "$SETTINGS.bak"
    if grep -q 'regulator\.ps1' "$SETTINGS"; then task_end DONE; else task_end SKIP; fi
  elif grep -Eq 'regulator\.(sh|ps1)' "$SETTINGS"; then
    task_end SKIP
  elif [[ -n "$PY" ]] && "$PY" - "$SETTINGS" "$HOOK" <<'PY' 2>/dev/null
import json, sys
path, hook = sys.argv[1], json.loads(sys.argv[2])
with open(path, encoding="utf-8") as fh:
    settings = json.load(fh)
settings.setdefault("hooks", {}).setdefault("UserPromptSubmit", []).append({"hooks": [hook]})
with open(path, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
  then
    task_end DONE
  elif command -v jq >/dev/null 2>&1 && jq --argjson h "$HOOK" '.hooks.UserPromptSubmit += [{"hooks": [$h]}]' "$SETTINGS" >"$SETTINGS.new" 2>/dev/null; then
    mv "$SETTINGS.new" "$SETTINGS"
    task_end DONE
  else
    rm -f "$SETTINGS.new"
    HOOK_MERGE="$CLAUDE_DIR/settings.regulator.json"
    printf '{\n  "hooks": {\n    "UserPromptSubmit": [\n      { "hooks": [%s] }\n    ]\n  }\n}\n' "$HOOK" >"$HOOK_MERGE"
    task_end MERGE
  fi
fi

echo
printf '  %s Bibliothèque installée dans %s\n' "$(paint "$BADGE_OK" ' SUCCESS ')" "$(paint 1 "$TARGET_DIR")"
if [[ "$SELECTION_LABEL" != tous ]]; then
  printf '  %s Agents : %s. Pour en ajouter plus tard : %s ou %s.\n' "$(paint "$BADGE_WARN" ' INFO ')" "$SELECTION_LABEL" \
    "$(paint 1 '--agents <nom>')" "$(paint 1 '--groups <groupe>')"
fi
if [[ -n "$SKIPPED" ]]; then
  printf '  %s Déjà présents, conservés : %s. Relance avec %s pour les écraser.\n' \
    "$(paint "$BADGE_WARN" ' INFO ')" "$SKIPPED" "$(paint 1 '--force')"
fi
if [[ $CLAUDE_MD_KEPT -eq 1 ]]; then
  printf '  %s .claude/CLAUDE.md existant conservé : la version de la bibliothèque est dans %s, à fusionner.\n' \
    "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 '.claude/CLAUDE.md.claude-engineering-lib')"
fi
if [[ -n "$HOOK_MERGE" ]]; then
  printf '  %s .claude/settings.json laissé intact : le hook du régulateur est dans %s, à fusionner.\n' \
    "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 '.claude/settings.regulator.json')"
fi
echo
printf '  %s Ouvre Claude Code ici et décris ta tâche : %s\n' "$(paint "$GREEN" '→')" "$(paint "1;$GREEN" 'les agents se lancent tout seuls.')"
printf '  %s Claude Code déjà ouvert dans ce dossier (terminal ou VS Code) : %s, les agents ne sont chargés qu'"'"'au démarrage.\n' "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 'redémarre la session')"
printf '  %s %s\n\n' "$(paint "$GREEN" '★')" "$(paint "$GRAY" "github.com/${REPO}")"
