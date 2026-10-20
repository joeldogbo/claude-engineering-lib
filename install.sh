#!/usr/bin/env bash
# Installe la bibliothèque claude-engineering-lib dans le dossier .claude/ du dépôt courant.
# Compatible Linux, macOS (bash 3.2 et outils BSD compris), WSL et Git Bash sous Windows.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --update       # met à jour une installation existante
#   curl -fsSL .../install.sh | bash -s -- --dry-run      # montre ce qui changerait, sans rien écrire
#   curl -fsSL .../install.sh | bash -s -- --force        # remplace aussi les fichiers modifiés (sauvegardés)
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
# CLAUDE_LIB_TYPE, CLAUDE_LIB_GROUPS, CLAUDE_LIB_AGENTS, CLAUDE_LIB_ALL=1, CLAUDE_LIB_YES=1,
# CLAUDE_LIB_UPDATE=1 et CLAUDE_LIB_DRY_RUN=1.
#
# Mise à jour : relancer l'installateur dans un projet déjà équipé le met à jour (--update
# l'exige). Le manifeste .claude/.claude-lib.manifest garde la version et l'empreinte de
# chaque fichier installé, ce qui permet de distinguer, pour chaque fichier :
#   - inchangé chez toi, nouvelle version dans la bibliothèque → remplacé (ancien sauvegardé) ;
#   - modifié chez toi → conservé, nouvelle version dans .claude/updates/<fichier>.new
#     (--force le remplace, après sauvegarde) ;
#   - retiré de la bibliothèque → supprimé s'il n'a pas été modifié, conservé sinon ;
#   - agent supprimé par toi → pas réinstallé (sauf --agents <nom>) ;
#   - nouvel agent d'un groupe installé → ajouté ; tes propres fichiers → jamais touchés.
# Revenir à une version plus ancienne que celle installée exige --force.
# Toute erreur en cours d'écriture restaure l'état d'avant ; les fichiers remplacés restent
# dans .claude/backups/<date>/ (les 5 dernières sauvegardes sont gardées).

set -euo pipefail

REPO="joeldogbo/claude-engineering-lib"
TARGET_DIR="$(pwd)"
FORCE=0
UPDATE="${CLAUDE_LIB_UPDATE:-0}"
DRY_RUN="${CLAUDE_LIB_DRY_RUN:-0}"
VERSION=""
TYPE="${CLAUDE_LIB_TYPE:-}"
GROUPS_WANTED="${CLAUDE_LIB_GROUPS:-}"
AGENTS_WANTED="${CLAUDE_LIB_AGENTS:-}"
ALL="${CLAUDE_LIB_ALL:-0}"
YES="${CLAUDE_LIB_YES:-0}"
SUMS_FILE=""
INTEGRITY_NOTE=""

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
# État de l'écriture, pour défaire ce qui a été fait si l'installation échoue en cours de route.
APPLYING=0
LOCKED=0
CREATED_CLAUDE_DIR=0
CLAUDE_DIR=""
BACKUP_DIR=""
STAGE=""
JOURNAL=""

paint() { # style texte
  if [[ $USE_COLOR -eq 1 ]]; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi
}

die() { # message — affiche l'erreur et quitte (le trap EXIT fait le ménage)
  if [[ $TASK_PENDING -eq 1 ]]; then task_end FAIL; fi
  printf '\n  %s %s\n\n' "$(paint "$BADGE_ERR" ' ERREUR ')" "$1" >&2
  exit 1
}

# Bannière DOGBO Engineering Library : logo « D » au </> en dégradé bleu, puis DOGBO en blanc.
# Un pixel = deux caractères ; « C » marque les trois pixels du </>. Largeur : 78 colonnes.
pixels() { local line="${1// /  }"; printf '%s' "${line//X/██}"; }

banner() {
  local logo=(
    'XXXXX  '
    'XX  XX '
    'XX   XX'
    'XXCXX'
    'XX   XX'
    'XX  XX '
    'XXXXX  '
  )
  local word=(
    '                             '
    'XXXX   XXX   XXXX XXXX   XXX '
    'X   X X   X X     X   X X   X'
    'X   X X   X X  XX XXXX  X   X'
    'X   X X   X X   X X   X X   X'
    'XXXX   XXX   XXXX XXXX   XXX '
    '                             '
  )
  local shades=('38;5;51' '38;5;45' '38;5;39' '38;5;33' '38;5;33' '38;5;27' '38;5;27')
  local i mark
  echo
  for i in "${!logo[@]}"; do
    if [[ "${logo[$i]}" == *C* ]]; then
      mark="$(paint "${shades[$i]}" "$(pixels "${logo[$i]%%C*}")")$(paint '1;97' ' </>  ')$(paint "${shades[$i]}" "$(pixels "${logo[$i]#*C}")")"
    else
      mark="$(paint "${shades[$i]}" "$(pixels "${logo[$i]}")")"
    fi
    printf '  %s    %s\n' "$mark" "$(paint '1;97' "$(pixels "${word[$i]}")")"
  done
  echo
  printf '  %s  %s\n' "$(paint '1;38;5;39' 'E N G I N E E R I N G   L I B R A R Y')" "$(paint "$GRAY" "$1")"
  printf '  %s\n' "$(paint '38;5;45' "La bibliothèque d'agents IA, de compétences et de workflows")"
  printf '  %s\n' "$(paint '38;5;45' 'pour le développement logiciel.')"
  printf '  %s %s\n\n' "$(paint "$GRAY" "Code · Automatise · Construis l'avenir — by")" "$(paint '1;38;5;39' 'joeldogbo')"
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

# Défait les écritures du journal, dans l'ordre inverse : fichiers créés retirés, fichiers
# remplacés ou supprimés recopiés depuis la sauvegarde. Au mieux : une erreur n'arrête pas la suite.
rollback() {
  local act p
  if [[ -n "$JOURNAL" && -f "$JOURNAL" ]]; then
    while IFS=$'\t' read -r act p; do
      case "$act" in
        created) rm -f "$CLAUDE_DIR/$p" ;;
        saved) mkdir -p "$(dirname "$CLAUDE_DIR/$p")" && cp -p "$BACKUP_DIR/$p" "$CLAUDE_DIR/$p" ;;
      esac
    done < <(awk '{ l[NR] = $0 } END { for (i = NR; i > 0; i--) print l[i] }' "$JOURNAL")
  fi
  rm -rf "$CLAUDE_DIR/updates"
  if [[ -d "$TMP_DIR/old-updates" ]]; then mv "$TMP_DIR/old-updates" "$CLAUDE_DIR/updates"; fi
  # Dossiers créés pour des fichiers retirés : supprimés s'ils sont restés vides.
  for p in agents skills standards templates workflows hooks; do
    if [[ -d "$CLAUDE_DIR/$p" ]]; then find "$CLAUDE_DIR/$p" -mindepth 1 -type d -empty -delete 2>/dev/null; fi
  done
  if [[ -n "$STAGE" ]]; then rm -rf "$STAGE"; fi
  if [[ $CREATED_CLAUDE_DIR -eq 1 ]]; then rm -rf "$CLAUDE_DIR"; fi
}

cleanup() {
  local status=$?
  set +e
  if [[ $TASK_PENDING -eq 1 ]]; then
    task_end FAIL
    printf '\n  %s %s\n\n' "$(paint "$BADGE_ERR" ' ERREUR ')" "L'installation a échoué (voir le message ci-dessus)." >&2
  fi
  if [[ $status -ne 0 && $APPLYING -eq 1 ]]; then
    rollback
    printf '  %s %s\n\n' "$(paint "$BADGE_WARN" ' INFO ')" "Rien n'a changé : les fichiers déjà écrits ont été retirés ou restaurés." >&2
  elif [[ $status -ne 0 && $CREATED_CLAUDE_DIR -eq 1 ]]; then
    rm -rf "$CLAUDE_DIR"
  fi
  if [[ -n "$STAGE" ]]; then rm -rf "$STAGE"; fi
  if [[ $LOCKED -eq 1 ]]; then rm -rf "$CLAUDE_DIR/.claude-lib.lock"; fi
  if [[ $USE_COLOR -eq 1 ]]; then printf '\033[?25h'; fi
  if [[ -n "$TMP_DIR" ]]; then rm -rf "$TMP_DIR"; fi
  exit "$status"
}
trap cleanup EXIT
# Ctrl+C ou arrêt : sortie normale, pour que le nettoyage et la restauration aient lieu.
trap 'exit 130' INT
trap 'exit 143' TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --update) UPDATE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
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
    *) die "Option inconnue : $1 (options : --update, --dry-run, --force, --version <tag>, --dir <dossier>, --source <copie locale>, --type <type>, --groups <g1,g2>, --agents <a1,a2>, --all, --yes)." ;;
  esac
done

# --- Vérifications avant tout téléchargement ---
if [[ -e "$TARGET_DIR" && ! -d "$TARGET_DIR" ]]; then die "$TARGET_DIR existe mais n'est pas un dossier."; fi
if command -v sha256sum >/dev/null 2>&1; then HASH_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then HASH_CMD="shasum -a 256"
else die "sha256sum ou shasum est requis pour comparer les fichiers installés (paquet coreutils ou perl)."
fi
TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t claude-engineering-lib)" || die "Impossible de créer un dossier temporaire (disque plein ?)."

# --- Installation existante : manifeste (version, groupes, empreintes) ou, avant lui, fichiers présents ---
CLAUDE_DIR="$TARGET_DIR/.claude"
MANIFEST="$CLAUDE_DIR/.claude-lib.manifest"
EXISTING=0; LEGACY=0; OLD_VERSION=""; OLD_GROUPS=""; OLD_EXTRA=""; OLD_EXCLUDED=""
manifest_get() { awk -v k="@$1" '$1 == k { $1 = ""; sub(/^ +/, ""); print; exit }' "$MANIFEST"; }
if [[ -f "$MANIFEST" ]]; then
  EXISTING=1
  OLD_VERSION="$(manifest_get version)"; OLD_GROUPS="$(manifest_get groups)"
  OLD_EXTRA="$(manifest_get agents)"; OLD_EXCLUDED="$(manifest_get excluded)"
elif [[ -f "$CLAUDE_DIR/hooks/regulator.sh" || -f "$CLAUDE_DIR/hooks/regulator.ps1" || -f "$CLAUDE_DIR/skills/workflow/SKILL.md" ]]; then
  EXISTING=1; LEGACY=1
fi
if [[ $UPDATE -eq 1 && $EXISTING -eq 0 ]]; then
  die "Aucune installation de la bibliothèque dans $TARGET_DIR : relance sans --update pour l'installer."
fi

# Vrai si la version $1 est strictement antérieure à $2 (formes vX.Y.Z ; sinon : faux).
semver_lt() {
  local a="${1#v}" b="${2#v}"
  [[ "$a" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$b" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  awk -v a="$a" -v b="$b" 'BEGIN { split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) { if (x[i] + 0 < y[i] + 0) exit 0; if (x[i] + 0 > y[i] + 0) exit 1 }
    exit 1 }'
}

if [[ -n "${SOURCE:-}" ]]; then
  # Installation depuis une copie locale de la bibliothèque (tests, CI, dépôt cloné).
  [[ -f "$SOURCE/CLAUDE.md" && -d "$SOURCE/agents" ]] || die "$SOURCE n'est pas une copie de la bibliothèque."
  banner "copie locale"
  SRC_DIR="$(cd "$SOURCE" && pwd)"
  NEW_VERSION="local"
else
  command -v curl >/dev/null 2>&1 || die "curl est requis : installe-le avec le gestionnaire de paquets du système."
  command -v tar  >/dev/null 2>&1 || die "tar est requis : installe-le avec le gestionnaire de paquets du système."

  if [[ -z "$VERSION" ]]; then
    VERSION="$(resolve_latest)" || die "Impossible de joindre GitHub pour trouver la dernière version (connexion, proxy ?)."
  fi
  NEW_VERSION="${VERSION:-main}"
  if [[ $EXISTING -eq 1 && $FORCE -eq 0 ]] && semver_lt "$NEW_VERSION" "$OLD_VERSION"; then
    die "La version installée ($OLD_VERSION) est plus récente que $NEW_VERSION : relance avec --force pour revenir en arrière."
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

  download "$ARCHIVE_URL" "$TMP_DIR/lib.tar.gz" || die "Téléchargement impossible : $ARCHIVE_URL (version inexistante, connexion ou proxy ?)"
  mkdir -p "$TMP_DIR/src"
  tar -xzf "$TMP_DIR/lib.tar.gz" -C "$TMP_DIR/src" || die "Extraction de l'archive impossible (archive corrompue ou disque plein ?)."
  SRC_DIR="$(find "$TMP_DIR/src" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [[ -n "$SRC_DIR" && -f "$SRC_DIR/CLAUDE.md" && -d "$SRC_DIR/agents" ]] || die "Archive incomplète : CLAUDE.md ou agents/ manquant."
  task_end DONE
  # Empreintes publiées avec la release : un fichier altéré (miroir, proxy, tag déplacé) est refusé.
  if [[ -n "$VERSION" && "$VERSION" != main ]]; then
    task_start "Intégrité" "(SHA256SUMS)"
    if curl -fsSL --retry 2 "https://github.com/${REPO}/releases/download/${VERSION}/SHA256SUMS" -o "$TMP_DIR/SHA256SUMS" 2>/dev/null; then
      SUMS_FILE="$TMP_DIR/SHA256SUMS"; task_end DONE
    else
      task_end SKIP; INTEGRITY_NOTE="Release sans empreintes publiées (SHA256SUMS) : intégrité non vérifiée."
    fi
  else
    INTEGRITY_NOTE="Branche main : pas d'empreintes publiées, intégrité non vérifiée. Préfère une release (--version vX.Y.Z)."
  fi
  echo
fi
# Réservé aux tests : fichier d'empreintes local, à la place de celui de la release.
if [[ -n "${CLAUDE_LIB_TEST_SUMS:-}" ]]; then SUMS_FILE="$CLAUDE_LIB_TEST_SUMS"; INTEGRITY_NOTE=""; fi
if [[ $EXISTING -eq 1 ]]; then
  if [[ $LEGACY -eq 1 ]]; then
    printf '  %s %s\n' "$(paint "$BADGE_WARN" ' UPDATE ')" "Installation existante sans manifeste (version antérieure) → $NEW_VERSION"
  else
    printf '  %s %s\n' "$(paint "$BADGE_WARN" ' UPDATE ')" "Installation existante : ${OLD_VERSION:-?} → $NEW_VERSION"
  fi
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
  local i=0 p choice nums n g extra
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

union() { local out="" w; for w in $1 $2; do in_list "$w" "$out" || out="$out$w "; done; printf '%s' "${out% }"; } # liste liste

SELECTED_AGENTS=""; SELECTION_LABEL=""; RECORD_GROUPS=""; RECORD_EXTRA=""; RECORD_EXCLUDED=""
EXPLICIT=0
if [[ $ALL == 1 || -n "$TYPE$GROUPS_WANTED$AGENTS_WANTED" ]]; then EXPLICIT=1; fi
if [[ -z "$PROFILE_LIST" ]]; then
  # Version de la bibliothèque sans profiles.conf : tous les agents, comme avant.
  SELECTED_AGENTS="$AGENT_LIST"; SELECTION_LABEL="tous"; RECORD_GROUPS="all"
else
  detect_type
  # Mise à jour sans option : pas de menu, la sélection vient de l'installation existante.
  if [[ $EXPLICIT -eq 0 && $EXISTING -eq 0 ]]; then
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
    SELECTED_AGENTS="$AGENT_LIST"; SELECTION_LABEL="tous"; RECORD_GROUPS="all"
  elif [[ $EXPLICIT -eq 1 || $EXISTING -eq 0 ]]; then
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
    RECORD_GROUPS="$(union "$WANTED_GROUPS" "")"; RECORD_EXTRA="$(printf '%s' "$AGENTS_WANTED" | tr ',' ' ')"
  fi
fi

# Mise à jour : agents déjà installés, plus les nouveaux agents des groupes installés,
# sauf ceux que l'utilisateur a supprimés (sauf s'il les redemande avec --agents ou --groups).
if [[ $EXISTING -eq 1 ]]; then
  installed=""
  for a in $AGENT_LIST; do if [[ -f "$CLAUDE_DIR/agents/$a.md" ]]; then installed="$installed$a "; fi; done
  if [[ $LEGACY -eq 0 ]]; then
    excluded="$OLD_EXCLUDED"
    for a in $(awk '!/^[@#]/ && NF >= 2 { print $2 }' "$MANIFEST" | sed -n 's#^agents/\(.*\)\.md$#\1#p'); do
      if [[ ! -f "$CLAUDE_DIR/agents/$a.md" ]]; then excluded="$(union "$excluded" "$a")"; fi
    done
    RECORD_EXCLUDED=""
    for a in $excluded; do in_list "$a" "$SELECTED_AGENTS" || RECORD_EXCLUDED="$RECORD_EXCLUDED$a "; done
    if [[ "$OLD_GROUPS" == all ]]; then from_groups="$AGENT_LIST"; else from_groups="$(agents_of_groups "$OLD_GROUPS") $OLD_EXTRA"; fi
    for a in $from_groups; do
      if in_list "$a" "$AGENT_LIST" && ! in_list "$a" "$RECORD_EXCLUDED"; then installed="$installed$a "; fi
    done
    if [[ "$OLD_GROUPS" == all || "$RECORD_GROUPS" == all ]]; then RECORD_GROUPS="all"; else RECORD_GROUPS="$(union "$OLD_GROUPS" "$RECORD_GROUPS")"; fi
    RECORD_EXTRA="$(union "$OLD_EXTRA" "$RECORD_EXTRA")"
  elif [[ "$RECORD_GROUPS" != all ]]; then
    # Sans manifeste, les groupes installés sont ceux dont tous les agents sont présents.
    for g in $GROUP_LIST; do
      full=1
      for a in $(agents_of_groups "$g"); do in_list "$a" "$installed" || full=0; done
      if [[ $full -eq 1 ]]; then RECORD_GROUPS="$(union "$RECORD_GROUPS" "$g")"; fi
    done
  fi
  for a in $installed; do in_list "$a" "$SELECTED_AGENTS" || SELECTED_AGENTS="$SELECTED_AGENTS$a "; done
  if [[ $EXPLICIT -eq 1 ]]; then SELECTION_LABEL="mise à jour + ${SELECTION_LABEL#core + }"; else SELECTION_LABEL="mise à jour"; fi
fi

COPY_ITEMS=(skills standards templates workflows hooks)
# Consignes de la bibliothèque quand le projet a déjà son propre .claude/CLAUDE.md.
LIB_MD=claude-lib.md

# --- Préparation de l'écriture : dossier accessible, une seule installation à la fois ---
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ ! -d "$CLAUDE_DIR" ]]; then
    mkdir -p "$CLAUDE_DIR" 2>/dev/null || die "Impossible de créer $CLAUDE_DIR (droits d'écriture sur le dossier ?)."
    CREATED_CLAUDE_DIR=1
  fi
  probe="$CLAUDE_DIR/.claude-lib-write-test.$$"
  { : >"$probe"; } 2>/dev/null || die "Pas de droit d'écriture dans $CLAUDE_DIR."
  rm -f "$probe"
  mkdir "$CLAUDE_DIR/.claude-lib.lock" 2>/dev/null \
    || die "Une autre installation est en cours dans ce projet. Si ce n'est pas le cas, supprime $CLAUDE_DIR/.claude-lib.lock et relance."
  LOCKED=1
fi

# --- Plan : chaque fichier de la bibliothèque comparé à la copie installée et au manifeste ---
# Empreinte<TAB>chemin de chaque fichier de la liste $2 présent dans le dossier $1, en un seul processus.
hash_files() {
  if [[ ! -d "$1" ]]; then return 0; fi
  # shellcheck disable=SC2086  # HASH_CMD peut contenir des options (shasum -a 256)
  (cd "$1" && while IFS= read -r p; do if [[ -f "$p" ]]; then printf '%s\0' "$p"; fi; done <"$2" | xargs -0 $HASH_CMD) \
    | awk '{ h = $1; sub(/^\\/, "", h); $1 = ""; sub(/^ +\*?/, ""); if ($0 != "-") print h "\t" $0 }'
}

{
  for a in $SELECTED_AGENTS; do printf 'agents/%s.md\n' "$a"; done
  if [[ -f "$SRC_DIR/profiles.conf" ]]; then echo profiles.conf; fi
  for item in "${COPY_ITEMS[@]}"; do
    if [[ -d "$SRC_DIR/$item" ]]; then (cd "$SRC_DIR" && find "$item" -type f | LC_ALL=C sort); fi
  done
  echo CLAUDE.md
} >"$TMP_DIR/files"
: >"$TMP_DIR/manifest"
if [[ $LEGACY -eq 0 && -f "$MANIFEST" ]]; then
  awk '!/^[@#]/ && NF >= 2 { h = $1; $1 = ""; sub(/^ +/, ""); print h "\t" $0 }' "$MANIFEST" >"$TMP_DIR/manifest"
fi
{ cat "$TMP_DIR/files"; cut -f2 "$TMP_DIR/manifest"; } >"$TMP_DIR/paths"
hash_files "$SRC_DIR" "$TMP_DIR/files" >"$TMP_DIR/hash-src"
hash_files "$CLAUDE_DIR" "$TMP_DIR/paths" | LC_ALL=C sort -u >"$TMP_DIR/hash-dst"
if [[ "$(wc -l <"$TMP_DIR/hash-src")" -ne "$(wc -l <"$TMP_DIR/files")" ]]; then
  die "Fichiers de la bibliothèque illisibles dans la source (archive incomplète ?)."
fi
# Intégrité : chaque fichier à installer doit avoir l'empreinte publiée avec la release.
if [[ -n "$SUMS_FILE" ]]; then
  ALTERED="$(awk -F'\t' '
    FILENAME == ARGV[1] { split($0, f, " "); h = f[1]; p = $0; sub(/^[^ ]+ +\*?/, "", p); sub(/^\.\//, "", p); sub(/\r$/, "", p); sum[p] = tolower(h); next }
    sum[$2] != tolower($1) { printf "%s%s", (n++ ? ", " : ""), $2 }' "$SUMS_FILE" "$TMP_DIR/hash-src")"
  [[ -z "$ALTERED" ]] || die "Intégrité : fichier(s) différent(s) de la release publiée, installation refusée : $ALTERED."
fi

# Une ligne par fichier : action<TAB>chemin<TAB>empreinte source<TAB>empreinte du manifeste.
#   add      absent chez toi                       → copié
#   same     identique à la bibliothèque           → rien
#   update   non modifié depuis l'installation     → remplacé (ancien sauvegardé)
#   force    modifié chez toi, --force             → remplacé (ancien sauvegardé)
#   kept     modifié chez toi, inchangé dans la bibliothèque → conservé
#   conflict modifié chez toi et dans la bibliothèque → conservé, nouvelle version dans updates/
#   remove   retiré de la bibliothèque, non modifié → supprimé (sauvegardé)
#   orphan   retiré de la bibliothèque, modifié     → conservé
#   import   .claude/CLAUDE.md propre au projet    → conservé ; la bibliothèque va dans
#            claude-lib.md, importé par une ligne @claude-lib.md ajoutée à la fin du sien
# Sans manifeste (installation antérieure), un fichier différent est une ancienne version :
# remplacé après sauvegarde, sauf CLAUDE.md, souvent personnalisé.
awk -F'\t' -v force="$FORCE" -v legacy="$LEGACY" '
  FILENAME == ARGV[1] { m[$2] = $1; next }
  FILENAME == ARGV[2] { d[$2] = $1; next }
  { s[$2] = $1; order[++n] = $2 }
  END {
    for (i = 1; i <= n; i++) {
      p = order[i]
      if (!(p in d)) act = "add"
      else if (d[p] == s[p]) act = "same"
      else if ((p in m) && d[p] == m[p]) act = "update"
      else if (p == "CLAUDE.md" && !(p in m) && legacy == 0) act = "import"
      else if (force == 1) act = "force"
      else if ((p in m) && s[p] == m[p]) act = "kept"
      else if (legacy == 1 && p != "CLAUDE.md") act = "update"
      else act = "conflict"
      print act "\t" p "\t" s[p] "\t" m[p]
    }
    for (p in m) if (!(p in s) && (p in d)) print (d[p] == m[p] ? "remove" : "orphan") "\t" p "\t\t" m[p]
  }' "$TMP_DIR/manifest" "$TMP_DIR/hash-dst" "$TMP_DIR/hash-src" >"$TMP_DIR/plan"

count_act() { awk -F'\t' -v a=" $1 " 'index(a, " " $1 " ") { n++ } END { print n + 0 }' "$TMP_DIR/plan"; } # "act1 act2"
list_act() { awk -F'\t' -v a=" $1 " 'index(a, " " $1 " ") { printf "%s%s", (n++ ? ", " : ""), $2 }' "$TMP_DIR/plan"; }
# Import déjà en place (claude-lib.md à jour, ligne présente) : rien à écrire.
if [[ "$(count_act import)" -gt 0 ]] && cmp -s "$SRC_DIR/CLAUDE.md" "$CLAUDE_DIR/$LIB_MD" && grep -q "^@$LIB_MD" "$CLAUDE_DIR/CLAUDE.md"; then
  awk -F'\t' -v OFS='\t' '$1 == "import" { $1 = "linked" } 1' "$TMP_DIR/plan" >"$TMP_DIR/plan.new" && mv "$TMP_DIR/plan.new" "$TMP_DIR/plan"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  printf '\n  %s Simulation : rien n'"'"'est écrit. Agents : %s.\n\n' "$(paint "$BADGE_WARN" ' DRY-RUN ')" "$SELECTION_LABEL"
  awk -F'\t' '
    $1 == "add"      { print "    + " $2 "   (ajouté)" }
    $1 == "update"   { print "    ~ " $2 "   (mis à jour, ancien sauvegardé)" }
    $1 == "force"    { print "    ~ " $2 "   (modifié chez toi, remplacé : --force)" }
    $1 == "kept"     { print "    = " $2 "   (modifié chez toi, inchangé dans la bibliothèque : conservé)" }
    $1 == "conflict" { print "    ! " $2 "   (modifié chez toi : conservé, nouvelle version dans .claude/updates/)" }
    $1 == "import"   { print "    + claude-lib.md   (ton CLAUDE.md est conservé et l'"'"'importe)" }
    $1 == "remove"   { print "    - " $2 "   (retiré de la bibliothèque)" }
    $1 == "orphan"   { print "    ? " $2 "   (retiré de la bibliothèque, modifié chez toi : conservé)" }' "$TMP_DIR/plan"
  printf '\n  Ajoutés %s · mis à jour %s · conflits %s · supprimés %s · inchangés %s\n\n' \
    "$(count_act add)" "$(count_act 'update force')" "$(count_act conflict)" "$(count_act remove)" "$(count_act same)"
  exit 0
fi

# --- Écriture en trois temps : copie à côté, sauvegarde, remplacement — défaite si une étape échoue ---
STAGE="$CLAUDE_DIR/.claude-lib-staging"
rm -rf "$STAGE"
while IFS=$'\t' read -r act p _; do
  case "$act" in add | update | force | conflict | import)
    { mkdir -p "$(dirname "$STAGE/$p")" && cp "$SRC_DIR/$p" "$STAGE/$p"; } 2>/dev/null \
      || die "Copie impossible de $p dans $CLAUDE_DIR (disque plein ou droits ?)."
  esac
done <"$TMP_DIR/plan"

BACKUP_DIR="$CLAUDE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
JOURNAL="$TMP_DIR/journal"
: >"$JOURNAL"
APPLYING=1
backup() { # chemin relatif à .claude — copié dans la sauvegarde avant d'être remplacé ou supprimé
  mkdir -p "$(dirname "$BACKUP_DIR/$1")"
  cp -p "$CLAUDE_DIR/$1" "$BACKUP_DIR/$1"
  printf 'saved\t%s\n' "$1" >>"$JOURNAL"
}
created() { printf 'created\t%s\n' "$1" >>"$JOURNAL"; }

# Copies de conflits d'une installation précédente : mises de côté (régénérées si besoin, remises en cas d'échec).
if [[ -d "$CLAUDE_DIR/updates" ]]; then mv "$CLAUDE_DIR/updates" "$TMP_DIR/old-updates"; fi
applied=0
while IFS=$'\t' read -r act p _; do
  case "$act" in
    add) mkdir -p "$(dirname "$CLAUDE_DIR/$p")"; created "$p"; mv -f "$STAGE/$p" "$CLAUDE_DIR/$p" ;;
    update | force) backup "$p"; mv -f "$STAGE/$p" "$CLAUDE_DIR/$p" ;;
    remove) backup "$p"; rm -f "$CLAUDE_DIR/$p" ;;
    conflict) mkdir -p "$(dirname "$CLAUDE_DIR/updates/$p")"; created "updates/$p.new"; mv -f "$STAGE/$p" "$CLAUDE_DIR/updates/$p.new" ;;
    import)
      if [[ -f "$CLAUDE_DIR/$LIB_MD" ]]; then backup "$LIB_MD"; else created "$LIB_MD"; fi
      mv -f "$STAGE/$p" "$CLAUDE_DIR/$LIB_MD"
      if ! grep -q "^@$LIB_MD" "$CLAUDE_DIR/$p"; then
        backup "$p"
        printf '\n<!-- Bibliothèque d'"'"'ingénierie (agents, régulateur, workflows) : ne pas retirer cette ligne. -->\n@%s\n' "$LIB_MD" >>"$CLAUDE_DIR/$p"
      fi ;;
    *) continue ;;
  esac
  applied=$((applied + 1))
  # Réservé aux tests : simule une panne après N écritures pour vérifier la restauration.
  if [[ -n "${CLAUDE_LIB_TEST_FAIL_AT:-}" && $applied -ge ${CLAUDE_LIB_TEST_FAIL_AT} ]]; then die "Panne simulée (CLAUDE_LIB_TEST_FAIL_AT)."; fi
done <"$TMP_DIR/plan"
for item in "${COPY_ITEMS[@]}"; do
  if [[ -d "$CLAUDE_DIR/$item" ]]; then find "$CLAUDE_DIR/$item" -mindepth 1 -type d -empty -delete 2>/dev/null || true; fi
done

# Vérification : chaque fichier écrit est identique à celui de la bibliothèque.
awk -F'\t' '$1 ~ /^(add|update|force)$/ { print $2 }' "$TMP_DIR/plan" >"$TMP_DIR/written"
awk -F'\t' '$1 ~ /^(add|update|force)$/ { print $3 "\t" $2 }' "$TMP_DIR/plan" | LC_ALL=C sort >"$TMP_DIR/expected"
hash_files "$CLAUDE_DIR" "$TMP_DIR/written" | LC_ALL=C sort >"$TMP_DIR/actual"
cmp -s "$TMP_DIR/expected" "$TMP_DIR/actual" || die "Vérification après copie échouée : un fichier écrit diffère de la bibliothèque."
if [[ "$(count_act import)" -gt 0 ]] && ! cmp -s "$SRC_DIR/CLAUDE.md" "$CLAUDE_DIR/$LIB_MD"; then
  die "Vérification après copie échouée : $LIB_MD diffère de la bibliothèque."
fi

report_item() { # libellé détail préfixe — DONE si quelque chose a changé, MERGE si conflit, SKIP sinon
  local changed conflicts
  changed="$(awk -F'\t' -v p="$3" 'index($2, p) == 1 && $1 ~ /^(add|update|force|remove|import)$/ { n++ } END { print n + 0 }' "$TMP_DIR/plan")"
  conflicts="$(awk -F'\t' -v p="$3" 'index($2, p) == 1 && $1 == "conflict" { n++ } END { print n + 0 }' "$TMP_DIR/plan")"
  task_start "$1" "$2"
  if [[ $conflicts -gt 0 ]]; then task_end MERGE
  elif [[ $changed -gt 0 ]]; then task_end DONE
  else task_end SKIP
  fi
}
report_item ".claude/agents/" "($(count_words "$SELECTED_AGENTS")/$(count_words "$AGENT_LIST") · $SELECTION_LABEL)" "agents/"
for item in "${COPY_ITEMS[@]}"; do
  if [[ -d "$SRC_DIR/$item" ]]; then
    report_item ".claude/$item/" "($(find "$SRC_DIR/$item" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '))" "$item/"
  fi
done
if [[ "$(count_act import)" -gt 0 ]]; then
  report_item ".claude/CLAUDE.md" "(le tien, qui importe $LIB_MD)" "CLAUDE.md"
else
  report_item ".claude/CLAUDE.md" "" "CLAUDE.md"
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
    created settings.json
    printf '{\n  "hooks": {\n    "UserPromptSubmit": [\n      { "hooks": [%s] }\n    ]\n  }\n}\n' "$HOOK" >"$SETTINGS"
    task_end DONE
  elif [[ "$HOOK" == *regulator.ps1* ]] && grep -q 'regulator\.sh' "$SETTINGS"; then
    # Installation Windows antérieure avec le hook bash : remplacé par le hook PowerShell.
    backup settings.json
    # shellcheck disable=SC2016
    sed -i.bak 's#"command": *"bash", *"args": *\["${CLAUDE_PROJECT_DIR}/.claude/hooks/regulator.sh"\]#"command": "powershell", "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "${CLAUDE_PROJECT_DIR}/.claude/hooks/regulator.ps1"]#' "$SETTINGS" && rm -f "$SETTINGS.bak"
    if grep -q 'regulator\.ps1' "$SETTINGS"; then task_end DONE; else task_end SKIP; fi
  elif grep -Eq 'regulator\.(sh|ps1)' "$SETTINGS"; then
    task_end SKIP
  elif backup settings.json && [[ -n "$PY" ]] && "$PY" - "$SETTINGS" "$HOOK" <<'PY' 2>/dev/null
import json, os, sys
path, hook = sys.argv[1], json.loads(sys.argv[2])
with open(path, encoding="utf-8") as fh:
    settings = json.load(fh)
settings.setdefault("hooks", {}).setdefault("UserPromptSubmit", []).append({"hooks": [hook]})
# Écrit à côté puis remplace : un arrêt en cours d'écriture ne laisse pas un fichier tronqué.
with open(path + ".new", "w", encoding="utf-8") as fh:
    json.dump(settings, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
os.replace(path + ".new", path)
PY
  then
    task_end DONE
  elif command -v jq >/dev/null 2>&1 && jq --argjson h "$HOOK" '.hooks.UserPromptSubmit += [{"hooks": [$h]}]' "$SETTINGS" >"$SETTINGS.new" 2>/dev/null; then
    mv "$SETTINGS.new" "$SETTINGS"
    task_end DONE
  else
    rm -f "$SETTINGS.new"
    HOOK_MERGE="$CLAUDE_DIR/settings.regulator.json"
    created settings.regulator.json
    printf '{\n  "hooks": {\n    "UserPromptSubmit": [\n      { "hooks": [%s] }\n    ]\n  }\n}\n' "$HOOK" >"$HOOK_MERGE"
    task_end MERGE
  fi
fi

# --- Manifeste, écrit en dernier : il ne décrit que ce qui est réellement installé ---
{
  echo "# claude-engineering-lib : version installée et empreinte de chaque fichier de la bibliothèque."
  echo "# Sert aux mises à jour (fichiers modifiés chez toi détectés et conservés). Ne pas modifier à la main."
  echo "@version $NEW_VERSION"
  echo "@date $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "@groups $RECORD_GROUPS"
  echo "@agents $RECORD_EXTRA"
  echo "@excluded $RECORD_EXCLUDED"
  awk -F'\t' '$1 ~ /^(add|same|update|force)$/ { print $3 "  " $2 } $1 ~ /^(kept|conflict|orphan)$/ && $4 != "" { print $4 "  " $2 }' "$TMP_DIR/plan"
} >"$MANIFEST.new"
if [[ -f "$MANIFEST" ]]; then backup .claude-lib.manifest; else created .claude-lib.manifest; fi
mv -f "$MANIFEST.new" "$MANIFEST"
APPLYING=0
# Sauvegarde qui ne contient que l'ancien manifeste (gardé pour la restauration) : inutile une fois fini.
if ! awk -F'\t' '$1 == "saved" && $2 != ".claude-lib.manifest" { found = 1 } END { exit !found }' "$JOURNAL"; then
  rm -rf "$BACKUP_DIR"
  rmdir "$CLAUDE_DIR/backups" 2>/dev/null || true
fi

# Sauvegardes et copies de conflits hors de git ; seules les 5 dernières sauvegardes sont gardées.
for d in backups updates; do
  if [[ -d "$CLAUDE_DIR/$d" ]]; then printf '*\n' >"$CLAUDE_DIR/$d/.gitignore"; fi
done
if [[ -d "$CLAUDE_DIR/backups" ]]; then
  find "$CLAUDE_DIR/backups" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort \
    | awk '{ l[NR] = $0 } END { for (i = 1; i <= NR - 5; i++) print l[i] }' \
    | while IFS= read -r old; do rm -rf "$old"; done
fi

N_ADD="$(count_act add)"; N_UPD="$(count_act 'update force')"; N_DEL="$(count_act remove)"
N_CONFLICT="$(count_act conflict)"; N_ORPHAN="$(count_act orphan)"; N_SAME="$(count_act same)"

echo
if [[ $EXISTING -eq 1 ]]; then
  printf '  %s Bibliothèque mise à jour dans %s (%s → %s)\n' "$(paint "$BADGE_OK" ' SUCCESS ')" "$(paint 1 "$TARGET_DIR")" "${OLD_VERSION:-sans manifeste}" "$NEW_VERSION"
else
  printf '  %s Bibliothèque installée dans %s\n' "$(paint "$BADGE_OK" ' SUCCESS ')" "$(paint 1 "$TARGET_DIR")"
fi
printf '  %s Ajoutés %s · mis à jour %s · supprimés %s · inchangés %s · tes modifications conservées %s\n' \
  "$(paint "$BADGE_WARN" ' INFO ')" "$N_ADD" "$N_UPD" "$N_DEL" "$N_SAME" "$(count_act 'kept conflict orphan')"
if [[ "$SELECTION_LABEL" != tous && $EXISTING -eq 0 ]]; then
  printf '  %s Agents : %s. Pour en ajouter plus tard : %s ou %s.\n' "$(paint "$BADGE_WARN" ' INFO ')" "$SELECTION_LABEL" \
    "$(paint 1 '--agents <nom>')" "$(paint 1 '--groups <groupe>')"
fi
if [[ "$(count_act import)" -gt 0 ]]; then
  printf '  %s Ton .claude/CLAUDE.md est conservé : les consignes de la bibliothèque sont dans %s, importé par la ligne %s ajoutée à la fin.\n' \
    "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 ".claude/$LIB_MD")" "$(paint 1 "@$LIB_MD")"
fi
if [[ $N_CONFLICT -gt 0 && $EXISTING -eq 0 ]]; then
  printf '  %s %s fichier(s) du projet portant le même nom qu'"'"'un fichier de la bibliothèque, conservé(s) : %s. La version de la bibliothèque est dans %s ; %s la met à la place (après sauvegarde).\n' \
    "$(paint "$BADGE_WARN" ' MERGE ')" "$N_CONFLICT" "$(list_act conflict)" "$(paint 1 '.claude/updates/<fichier>.new')" "$(paint 1 '--force')"
elif [[ $N_CONFLICT -gt 0 ]]; then
  printf '  %s %s fichier(s) modifié(s) chez toi, conservé(s) : %s. La nouvelle version est dans %s, à fusionner ; %s les remplace (après sauvegarde).\n' \
    "$(paint "$BADGE_WARN" ' MERGE ')" "$N_CONFLICT" "$(list_act conflict)" "$(paint 1 '.claude/updates/<fichier>.new')" "$(paint 1 '--force')"
fi
if [[ $N_ORPHAN -gt 0 ]]; then
  printf '  %s Retiré(s) de la bibliothèque mais modifié(s) chez toi, conservé(s) : %s.\n' "$(paint "$BADGE_WARN" ' INFO ')" "$(list_act orphan)"
fi
if [[ -d "$BACKUP_DIR" ]]; then
  printf '  %s Anciennes versions sauvegardées dans %s.\n' "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 ".claude/backups/${BACKUP_DIR##*/}")"
fi
if [[ -n "$INTEGRITY_NOTE" ]]; then
  printf '  %s %s\n' "$(paint "$BADGE_WARN" ' INFO ')" "$INTEGRITY_NOTE"
fi
if [[ -n "$HOOK_MERGE" ]]; then
  printf '  %s .claude/settings.json laissé intact : le hook du régulateur est dans %s, à fusionner.\n' \
    "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 '.claude/settings.regulator.json')"
fi
echo
printf '  %s Ouvre Claude Code ici et décris ta tâche : %s\n' "$(paint "$GREEN" '→')" "$(paint "1;$GREEN" 'les agents se lancent tout seuls.')"
printf '  %s Mise à jour plus tard : relance la même commande (ou %s pour voir ce qui changerait).\n' "$(paint "$GREEN" '↻')" "$(paint 1 '--dry-run')"
printf '  %s Claude Code déjà ouvert dans ce dossier (terminal ou VS Code) : %s, les agents ne sont chargés qu'"'"'au démarrage.\n' "$(paint "$BADGE_WARN" ' INFO ')" "$(paint 1 'redémarre la session')"
printf '  %s %s\n\n' "$(paint "$GREEN" '★')" "$(paint "$GRAY" "github.com/${REPO}")"
