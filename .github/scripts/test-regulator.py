"""Vérifie que les deux versions du régulateur (bash et PowerShell) prennent les bonnes
décisions, et les mêmes, sur une série de prompts. Usage : python test-regulator.py [bash|powershell|pwsh]..."""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

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
    "Rédige le manuel utilisateur et le manuel de déploiement": ({"manuals"}, set()),
    "traduis l'interface en anglais": ({"language"}, set()),
}

# prompt -> fragments attendus dans la sortie : chaîne N1 → N2 affichée au contrôleur
LEVELS = {
    "audite la sécurité et corrige les failles XSS":
        ["security (", "[N1 → security-fixer]", "security-fixer (", "[N2 de security]"],
    "Ajoute un écran de profil avec un formulaire": ["[N2 de ux-ui, accessibility]"],
}


def command(shell, *args):
    # Chemin complet via le PATH : sous Windows, un nom nu trouverait le bash de WSL (System32) avant Git Bash.
    if shell == "bash":
        return [shutil.which("bash") or "bash", (ROOT / "hooks" / "regulator.sh").as_posix(), *args]
    return [shutil.which(shell) or shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "hooks" / "regulator.ps1"), *args]


def raw_run(shell, prompt, **env):
    payload = json.dumps({"prompt_text": prompt}, ensure_ascii=False).encode("utf-8")
    out = subprocess.run(command(shell), input=payload, capture_output=True, timeout=60,
                         env=dict(os.environ, REGULATOR_AGENTS_DIR=AGENTS, REGULATOR_HISTORY_FILE=str(ROOT / "absent" / "p.log"), **env))
    return out.returncode, out.stdout.decode("utf-8", "replace"), out.stderr.decode("utf-8", "replace")


def run(shell, prompt, progress=None, history=None, agents=AGENTS):
    payload = json.dumps({"prompt_text": prompt, "hook_event_name": "UserPromptSubmit",
                          "cwd": "/tmp/agent-ia-chatbot-paiement"},  # le cwd ne doit jamais compter
                         ensure_ascii=False)  # UTF-8 brut, comme Claude Code (Node)
    env = dict(os.environ, REGULATOR_AGENTS_DIR=agents, REGULATOR_PROGRESS_DIR=progress or str(ROOT / "absent"),
               REGULATOR_HISTORY_FILE=history or str(ROOT / "absent" / "prompts.log"))
    # Chemin complet via le PATH : sous Windows, un nom nu trouverait le bash de WSL (System32) avant Git Bash.
    if shell == "bash":
        cmd = [shutil.which("bash") or "bash", (ROOT / "hooks" / "regulator.sh").as_posix()]
    else:
        cmd = [shutil.which(shell) or shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "hooks" / "regulator.ps1")]
    out = subprocess.run(cmd, input=payload.encode("utf-8"), capture_output=True, env=env, timeout=60)
    if out.returncode != 0:
        raise RuntimeError(f"{shell} a échoué : {out.stderr.decode('utf-8', 'replace')}")
    return out.stdout.decode("utf-8", "replace").replace("\r\n", "\n").strip()


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
            # Relu à chaque message : une ligne, courte (les règles d'usage sont dans CLAUDE.md).
            ok = must <= got and not (must_not & got) and len(got) <= 4 and len(out.splitlines()) == 1 and len(out) <= 300
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] {prompt[:60]!r} -> {sorted(got) or out[:60]}")

    for prompt, fragments in LEVELS.items():
        out = run(shell, prompt)
        results.setdefault(prompt, {})[shell] = out
        ok = all(f in out for f in fragments)
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] niveaux {prompt[:50]!r}" + ("" if ok else f" -> {out}"))

    # Travail interrompu : seul le fichier « en cours » est signalé, même sans agent retenu.
    with tempfile.TemporaryDirectory() as progress:
        pathlib.Path(progress, "migration.md").write_text("# Migration\nstatut: en cours\n- [x] 1. schéma\n", encoding="utf-8")
        pathlib.Path(progress, "ancien.md").write_text("# Ancien\nstatut: terminé\n", encoding="utf-8")
        out = run(shell, "Merci", progress)
        ok = "Travail interrompu" in out and "migration.md" in out and "ancien.md" not in out and "Aucun agent" in out
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] reprise d'un travail interrompu" + ("" if ok else f" -> {out}"))
        ok = run(shell, "/workflow release", progress) == ""
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] commande slash silencieuse malgré la reprise")

    # Agents propres au projet, sans déclencheurs (fins de ligne Windows) : signalés, avec ou sans agent retenu.
    with tempfile.TemporaryDirectory() as agents:
        shutil.copytree(AGENTS, agents, dirs_exist_ok=True)
        pathlib.Path(agents, "maison.md").write_bytes(b"---\r\nname: maison\r\ndescription: agent du projet\r\n---\r\nconsignes\r\n")
        none = run(shell, "Merci, c'est parfait", agents=agents)
        some = run(shell, "Ajoute un écran de profil avec un formulaire", agents=agents)
        ok = ("Aucun agent de la bibliothèque" in none and "maison" in none
              and "frontend" in selected(some) and "Agents du projet sans triggers" in some and "maison." in some)
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] agents du projet sans déclencheurs signalés" + ("" if ok else f" -> {none} | {some}"))

    # Collage énorme : bloqué (code 2, raison sur stderr) avant le modèle ; « [long] » ou plafond à 0 le laissent passer.
    huge = "erreur dans le journal " * 1000
    code, _, err = raw_run(shell, huge)
    passed = [raw_run(shell, "[long] " + huge)[0], raw_run(shell, huge, REGULATOR_MAX_PROMPT="0")[0], raw_run(shell, "corrige le bug")[0]]
    ok = code == 2 and "bloqué" in err and passed == [0, 0, 0]
    fails += not ok
    print(f"{'ok  ' if ok else 'FAIL'} [{shell}] collage énorme bloqué avant le modèle" + ("" if ok else f" -> {code} {err!r} {passed}"))

    # Agents encore au travail : signalés si la liste est fraîche, ignorés si elle date d'une session passée.
    with tempfile.TemporaryDirectory() as hooks:
        running = pathlib.Path(hooks, "agents.running")
        running.write_text("frontend\nbackend\n", encoding="utf-8")
        fresh = raw_run(shell, "ajoute un bouton", REGULATOR_RUNNING_FILE=str(running))[1]
        os.utime(running, (running.stat().st_atime - 300, running.stat().st_mtime - 300))
        stale = raw_run(shell, "ajoute un bouton", REGULATOR_RUNNING_FILE=str(running))[1]
        ok = "Agents encore au travail : frontend, backend" in fresh and "encore au travail" not in stale
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] agents encore au travail signalés" + ("" if ok else f" -> {fresh!r} | {stale!r}"))

    # Demande répétée : signalée au second envoi d'un message reformulé, jamais pour un message différent ou court.
    with tempfile.TemporaryDirectory() as hooks:
        history = str(pathlib.Path(hooks, "prompts.log"))
        first = run(shell, "Configure SQLite pour Laravel et crée une route API de test pour vérifier le backend", history=history)
        again = run(shell, "Configure SQLite pour Laravel puis crée une route API de test pour vérifier que le backend fonctionne", history=history)
        other = run(shell, "Ajoute la pagination à la liste des employés avec un filtre par service", history=history)
        short = run(shell, "Ajoute un bouton", history=history)
        lines = pathlib.Path(history).read_text(encoding="utf-8").splitlines()
        ok = ("Demande très proche" not in first and "Demande très proche" in again and "request-history" in again
              and "Demande très proche" not in other and "Demande très proche" not in short and len(lines) == 3)
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] demande répétée" + ("" if ok else f" -> {again} | {lines}"))

for prompt, by_shell in results.items():
    if len({v if isinstance(v, str) else frozenset(v) for v in by_shell.values()}) > 1:
        fails += 1
        print(f"FAIL versions en désaccord sur {prompt[:60]!r} : {by_shell}")

# Règles communes obligatoires pour tout agent, ancien ou nouveau : déclencheurs (le contrôleur
# doit pouvoir le retenir), groupe (installation par groupe), protocole commun, N1 existant.
for shell in shells:
    if shell == "bash":
        cmd = [shutil.which("bash") or "bash", (ROOT / "hooks" / "regulator.sh").as_posix(), "--audit"]
    else:
        cmd = [shutil.which(shell) or shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "hooks" / "regulator.ps1"), "-Audit"]
    audit = subprocess.run(cmd, capture_output=True, env=dict(os.environ, REGULATOR_AGENTS_DIR=AGENTS))
    ok = audit.returncode == 0
    fails += not ok
    print(f"{'ok  ' if ok else 'FAIL'} [{shell}] audit des règles communes des agents"
          + ("" if ok else ":\n" + audit.stdout.decode("utf-8", "replace")))

    # Plafonds de ce qui est relu à chaque session : une description trop longue bloque l'audit.
    with tempfile.TemporaryDirectory() as lib:
        shutil.copytree(AGENTS, pathlib.Path(lib, "agents"))
        shutil.copy(ROOT / "CLAUDE.md", lib)
        git = pathlib.Path(lib, "agents", "git.md")
        text = git.read_text(encoding="utf-8")
        git.write_text(text.replace("description: ", "description: " + "très long " * 40, 1), encoding="utf-8")
        audit = subprocess.run(cmd, capture_output=True, env=dict(os.environ, REGULATOR_AGENTS_DIR=str(pathlib.Path(lib, "agents"))))
        out = audit.stdout.decode("utf-8", "replace")
        ok = audit.returncode == 1 and "Trop long" in out and "git (" in out
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] audit : plafond des descriptions" + ("" if ok else ":\n" + out))
print(f"\n{fails} échec(s)." if fails else "\nTous les contrôles sont passés.")
sys.exit(1 if fails else 0)
