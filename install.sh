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

command -v curl >/dev/null 2>&1 || { echo "curl est requis." >&2; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo "tar est requis." >&2; exit 1; }

if [[ -z "$VERSION" ]]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/' || true)"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -n "$VERSION" ]]; then
  echo "Téléchargement de ${REPO}@${VERSION}..."
  ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
else
  echo "Aucune release trouvée, téléchargement de la branche main..."
  ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
fi

curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/lib.tar.gz"
tar -xzf "$TMP_DIR/lib.tar.gz" -C "$TMP_DIR"
SRC_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d)"

COPY_ITEMS=(agents skills standards templates workflows)
mkdir -p "$TARGET_DIR"

for item in "${COPY_ITEMS[@]}"; do
  if [[ -d "$SRC_DIR/$item" ]]; then
    if [[ -d "$TARGET_DIR/$item" && $FORCE -eq 0 ]]; then
      echo "⚠️  $item/ existe déjà, ignoré (utilise --force pour écraser)."
    else
      rm -rf "$TARGET_DIR/$item"
      cp -R "$SRC_DIR/$item" "$TARGET_DIR/$item"
      echo "✅ $item/ installé."
    fi
  fi
done

if [[ -f "$TARGET_DIR/CLAUDE.md" && $FORCE -eq 0 ]]; then
  cp "$SRC_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.claude-engineering-lib"
  echo "⚠️  CLAUDE.md existe déjà. Le fichier de la bibliothèque a été copié sous CLAUDE.md.claude-engineering-lib — fusionne-le manuellement."
else
  cp "$SRC_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
  echo "✅ CLAUDE.md installé."
fi

echo ""
echo "Installation terminée dans: $TARGET_DIR"
