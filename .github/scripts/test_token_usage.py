"""Vérifie token_usage.py sur des journaux fictifs : totaux exacts, réponse sur plusieurs
lignes comptée une seule fois, sous-agents séparés, entrées anciennes ignorées."""
import datetime as dt
import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "skills" / "token-usage" / "token_usage.py"
now = dt.datetime.now(dt.timezone.utc)


def response(msg_id, request_id, usage, sidechain=False, days_ago=0):
    return json.dumps({
        "type": "assistant", "isSidechain": sidechain, "sessionId": "s1", "requestId": request_id,
        "timestamp": (now - dt.timedelta(days=days_ago)).isoformat().replace("+00:00", "Z"),
        "message": {"id": msg_id, "model": "modele-test", "content": [{"type": "text", "text": "SECRET"}],
                    "usage": usage},
    })


usage = {"input_tokens": 10, "cache_creation_input_tokens": 100, "cache_read_input_tokens": 1000, "output_tokens": 5}
lines = [
    response("m1", "r1", usage),
    response("m1", "r1", usage),  # même réponse sur une seconde ligne : à ne pas recompter
    response("m2", "r2", usage, sidechain=True),
    response("m3", "r3", usage, days_ago=30),  # hors période
    json.dumps({"type": "user", "message": {"content": "question"}}),
    "ligne invalide",
]

with tempfile.TemporaryDirectory() as tmp:
    project = pathlib.Path(tmp) / "mon-projet"
    project.mkdir()
    (project / "session.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    out = subprocess.run([sys.executable, str(SCRIPT), "--root", tmp, "--days", "7"],
                         capture_output=True, text=True, encoding="utf-8", check=True).stdout

print(out)
checks = {
    "2 réponses comptées (doublon et entrée ancienne exclus)": "(2 réponses)" in out,
    "total exact : 2 x 1115 = 2 230 jetons": "Total : 2 230 jetons" in out,
    "sous-agents comptés à part": "sous-agents" in out and "conversation principale" in out,
    "aucun contenu de conversation affiché": "SECRET" not in out and "question" not in out,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("ok   - " if ok else "FAIL - ") + name)
sys.exit(1 if failed else 0)
