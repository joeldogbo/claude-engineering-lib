#!/usr/bin/env python3
"""Résume la consommation de jetons de Claude Code à partir de ses journaux locaux.

Lit les fichiers <dossier de config>/projects/**/*.jsonl et additionne le champ
message.usage des réponses, sans jamais afficher le contenu des conversations.
Une même réponse peut occuper plusieurs lignes : elle est comptée une seule fois.

Usage : python3 token_usage.py [--days 7] [--project texte] [--root dossier]
"""
import argparse
import collections
import datetime as dt
import json
import os
import pathlib
import sys

FIELDS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")


def default_root():
    base = os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude"
    return pathlib.Path(base) / "projects"


def fmt(n):
    return f"{n:,}".replace(",", " ")


def main():
    # Sous Windows, une sortie redirigée utilise sinon l'ancienne page de code et casse les accents.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, default=7, help="période analysée, en jours (défaut : 7)")
    parser.add_argument("--project", default="", help="ne garder que les projets dont le dossier contient ce texte")
    parser.add_argument("--root", default=None, help="dossier des journaux (défaut : ~/.claude/projects)")
    args = parser.parse_args()

    root = pathlib.Path(args.root) if args.root else default_root()
    if not root.is_dir():
        print(f"Aucun journal Claude Code trouvé dans {root}.")
        return 1

    since = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=args.days)
    seen = set()
    total = collections.Counter()
    by_day = collections.defaultdict(collections.Counter)
    by_project = collections.defaultdict(collections.Counter)
    by_model = collections.defaultdict(collections.Counter)
    by_session = collections.defaultdict(collections.Counter)
    by_origin = collections.defaultdict(collections.Counter)
    responses = 0

    for path in root.rglob("*.jsonl"):
        project = path.relative_to(root).parts[0]
        if args.project and args.project.lower() not in project.lower():
            continue
        if dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc) < since:
            continue
        with path.open(encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                msg = entry.get("message")
                if entry.get("type") != "assistant" or not isinstance(msg, dict) or not isinstance(msg.get("usage"), dict):
                    continue
                key = (msg.get("id"), entry.get("requestId"))
                if key != (None, None):
                    if key in seen:
                        continue
                    seen.add(key)
                try:
                    when = dt.datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00"))
                except (KeyError, ValueError, AttributeError):
                    continue
                if when < since:
                    continue
                usage = collections.Counter({f: int(msg["usage"].get(f) or 0) for f in FIELDS})
                responses += 1
                total.update(usage)
                by_day[when.date().isoformat()].update(usage)
                by_project[project].update(usage)
                by_model[msg.get("model") or "inconnu"].update(usage)
                by_session[entry.get("sessionId") or path.stem].update(usage)
                by_origin["sous-agents" if entry.get("isSidechain") else "conversation principale"].update(usage)

    if not responses:
        print(f"Aucune réponse enregistrée sur les {args.days} derniers jours.")
        return 0

    def tot(c):
        return sum(c[f] for f in FIELDS)

    def table(title, groups, limit=None):
        print(f"\n## {title}")
        print(f"{'':42} {'total':>14} {'entrée':>10} {'cache écrit':>13} {'cache lu':>14} {'sortie':>11}")
        rows = sorted((kv for kv in groups.items() if tot(kv[1])), key=lambda kv: tot(kv[1]), reverse=True)
        for name, c in rows[:limit]:
            print(f"{str(name)[:42]:42} {fmt(tot(c)):>14} {fmt(c['input_tokens']):>10} "
                  f"{fmt(c['cache_creation_input_tokens']):>13} {fmt(c['cache_read_input_tokens']):>14} {fmt(c['output_tokens']):>11}")

    print(f"# Consommation Claude Code — {args.days} derniers jours ({responses} réponses)")
    print(f"Total : {fmt(tot(total))} jetons")
    cached_input = total["cache_read_input_tokens"]
    all_input = cached_input + total["input_tokens"] + total["cache_creation_input_tokens"]
    if all_input:
        print(f"Part de l'entrée relue depuis le cache : {100 * cached_input / all_input:.0f} %")
    table("Par jour", dict(sorted(by_day.items())))
    table("Par projet (10 premiers)", by_project, 10)
    table("Par modèle", by_model)
    table("Conversation principale / sous-agents", by_origin)
    table("Sessions les plus coûteuses (5 premières)", by_session, 5)
    return 0


if __name__ == "__main__":
    sys.exit(main())
