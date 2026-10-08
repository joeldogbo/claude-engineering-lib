"""Vérifie que les deux versions du régulateur (bash et PowerShell) prennent les bonnes
décisions, et les mêmes, sur une série de prompts. Usage : python test-regulator.py [bash|powershell|pwsh]..."""
import json
import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
AGENTS = str(ROOT / "agents")

# prompt -> (agents attendus dans la liste, agents qui ne doivent pas y être) ; None = « aucun agent »
CASES = {
    "Le webhook de paiement CinetPay arrive deux fois et l'élève est payé mais n'a pas d'accès": ({"payments"}, set()),
    "mon pc est très lent et la batterie se vide vite": ({"system-monitor"}, {"performance"}),
    "Ajoute un écran de profil avec un formulaire": ({"frontend"}, set()),
    "Combien de tokens consommés cette semaine ? je dépasse ma limite d'utilisation": ({"token-monitor"}, set()),
    "Merci, c'est parfait": None,
    "Explique-moi la différence entre random et une constante": None,
    "Lance l'agent seo sur la page d'accueil": ({"seo"}, set()),
    "corrige l'erreur 500 sur la route /api/orders": ({"debugging", "api"}, set()),
    "SÉCURITÉ : vérifie les failles XSS du formulaire": ({"security"}, set()),
    "/workflow release": "silence",
}


def run(shell, prompt):
    payload = json.dumps({"prompt_text": prompt, "hook_event_name": "UserPromptSubmit",
                          "cwd": "/tmp/agent-ia-chatbot-paiement"})  # le cwd ne doit jamais compter
    env = dict(os.environ, REGULATOR_AGENTS_DIR=AGENTS)
    # Chemin complet via le PATH : sous Windows, un nom nu trouverait le bash de WSL (System32) avant Git Bash.
    if shell == "bash":
        cmd = [shutil.which("bash") or "bash", (ROOT / "hooks" / "regulator.sh").as_posix()]
    else:
        cmd = [shutil.which(shell) or shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "hooks" / "regulator.ps1")]
    out = subprocess.run(cmd, input=payload.encode("utf-8"), capture_output=True, env=env, timeout=60)
    if out.returncode != 0:
        raise RuntimeError(f"{shell} a échoué : {out.stderr.decode('utf-8', 'replace')}")
    return out.stdout.decode("utf-8", "replace").strip()


def selected(output):
    line = next((l for l in output.splitlines() if "Agents retenus" in l), "")
    body = line.split(":", 1)[1].rstrip(".") if line else ""
    return {part.strip().split(" ")[0] for part in body.split(";") if part.strip()}


shells = sys.argv[1:] or [s for s in ("bash", "pwsh", "powershell") if shutil.which(s)]
fails = 0
results = {}
for shell in shells:
    for prompt, expected in CASES.items():
        out = run(shell, prompt)
        got = selected(out)
        results.setdefault(prompt, {})[shell] = got
        if expected == "silence":
            ok = out == ""
        elif expected is None:
            ok = "Aucun agent" in out
        else:
            must, must_not = expected
            ok = must <= got and not (must_not & got) and len(got) <= 4
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] {prompt[:60]!r} -> {sorted(got) or out[:60]}")

for prompt, by_shell in results.items():
    if len({frozenset(v) for v in by_shell.values()}) > 1:
        fails += 1
        print(f"FAIL versions en désaccord sur {prompt[:60]!r} : {by_shell}")

audit = subprocess.run([shutil.which("bash") or "bash", (ROOT / "hooks" / "regulator.sh").as_posix(), "--audit"], capture_output=True,
                       env=dict(os.environ, REGULATOR_AGENTS_DIR=AGENTS)).stdout.decode("utf-8", "replace") \
    if "bash" in shells else ""
if "Sans déclencheurs" in audit:
    fails += 1
    print("FAIL agents sans déclencheurs :\n" + audit)
print(f"\n{fails} échec(s)." if fails else "\nTous les contrôles sont passés.")
sys.exit(1 if fails else 0)
