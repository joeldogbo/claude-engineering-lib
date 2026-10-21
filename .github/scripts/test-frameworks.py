"""Vérifie que la bibliothèque fonctionne quel que soit le framework du projet :
1. les deux installateurs détectent le bon type de projet (donc le bon jeu d'agents) ;
2. le régulateur oriente une demande qui cite un framework vers l'agent de la bonne discipline ;
3. le skill stack-detection sait reconnaître chaque framework.
Usage : python test-frameworks.py [bash|powershell|pwsh]..."""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]


def pkg(*deps):
    return {"package.json": json.dumps({"dependencies": {d: "*" for d in deps}})}


def csproj(body, sdk="Microsoft.NET.Sdk"):
    return {"App.csproj": f'<Project Sdk="{sdk}"><PropertyGroup>{body}</PropertyGroup></Project>'}


# framework -> (fichiers du projet factice, type attendu)
FIXTURES = {
    # Front web
    "React (Vite)": ({**pkg("react", "vite")}, "web"),
    "Next.js": (pkg("next", "react"), "web"),
    "Vue": (pkg("vue"), "web"),
    "Nuxt": (pkg("nuxt"), "web"),
    "Angular": (pkg("@angular/core"), "web"),
    "Svelte / SvelteKit": (pkg("@sveltejs/kit", "svelte"), "web"),
    "Astro": (pkg("astro"), "web"),
    "Solid": (pkg("solid-js"), "web"),
    "Remix": (pkg("@remix-run/react"), "web"),
    "Preact": (pkg("preact"), "web"),
    # Web côté serveur
    "Laravel": ({"composer.json": '{"require": {"laravel/framework": "^11.0"}}', "artisan": ""}, "web"),
    "Symfony": ({"composer.json": '{"require": {"symfony/framework-bundle": "^7.0"}}'}, "web"),
    "Django": ({"manage.py": "", "requirements.txt": "Django==5.0\n"}, "web"),
    "Django (pyproject)": ({"pyproject.toml": '[project]\ndependencies = [\n  "django>=5",\n]\n'}, "web"),
    "Ruby on Rails": ({"Gemfile": "gem 'rails'\n"}, "web"),
    "Phoenix": ({"mix.exs": "{:phoenix, \"~> 1.7\"}"}, "web"),
    "ASP.NET MVC / Razor": ({**csproj("", "Microsoft.NET.Sdk.Web"), "Views/.keep": ""}, "web"),
    "Blazor": ({**csproj("", "Microsoft.NET.Sdk.Web"), "Components/.keep": ""}, "web"),
    "Spring MVC + Thymeleaf": ({"pom.xml": "<artifactId>spring-boot-starter-thymeleaf</artifactId>"}, "web"),
    # API / backend
    "Express": (pkg("express"), "api"),
    "NestJS": (pkg("@nestjs/core"), "api"),
    "Fastify": (pkg("fastify"), "api"),
    "Flask": ({"requirements.txt": "flask==3.0\n"}, "api"),
    "FastAPI (pyproject)": ({"pyproject.toml": '[project]\ndependencies = ["fastapi"]\n'}, "api"),
    "Spring Boot REST": ({"pom.xml": "<artifactId>spring-boot-starter-web</artifactId>"}, "api"),
    "Ktor": ({"build.gradle.kts": 'implementation("io.ktor:ktor-server-core")'}, "api"),
    "ASP.NET Web API": (csproj("", "Microsoft.NET.Sdk.Web"), "api"),
    "Go (Gin)": ({"go.mod": "module x\nrequire github.com/gin-gonic/gin v1.9.0\n"}, "api"),
    "Rust (Axum)": ({"Cargo.toml": '[package]\nname = "x"\n[dependencies]\naxum = "0.7"\n'}, "api"),
    "Rust (Actix)": ({"Cargo.toml": '[dependencies]\nactix-web = "4"\n'}, "api"),
    "Deno": ({"deno.json": "{}"}, "api"),
    # Mobile
    "Flutter": ({"pubspec.yaml": "name: x\n"}, "mobile"),
    "React Native": (pkg("react-native", "react"), "mobile"),
    "Expo": (pkg("expo", "react"), "mobile"),
    "Ionic / Capacitor": (pkg("@capacitor/core", "@angular/core"), "mobile"),
    "Android natif (Kotlin)": ({"app/src/main/AndroidManifest.xml": "<manifest/>"}, "mobile"),
    "iOS natif (Swift)": ({"App.xcodeproj/project.pbxproj": ""}, "mobile"),
    ".NET MAUI": (csproj("<UseMaui>true</UseMaui>"), "mobile"),
    # Bureau
    "Electron": (pkg("electron", "react"), "desktop"),
    "Tauri": ({**pkg("@tauri-apps/api", "vue"), "src-tauri/Cargo.toml": ""}, "desktop"),
    "WPF": (csproj("<UseWPF>true</UseWPF>"), "desktop"),
    "WinForms": (csproj("<UseWindowsForms>true</UseWindowsForms>"), "desktop"),
    "Avalonia": ({"App.csproj": '<Project><ItemGroup><PackageReference Include="Avalonia" /></ItemGroup></Project>'}, "desktop"),
    "JavaFX": ({"pom.xml": "<groupId>org.openjfx</groupId>"}, "desktop"),
    "Qt (C++)": ({"CMakeLists.txt": "find_package(Qt6 REQUIRED COMPONENTS Widgets)\n"}, "desktop"),
    # Bibliothèque / CLI
    "Crate Rust": ({"Cargo.toml": '[package]\nname = "x"\n[dependencies]\nserde = "1"\n'}, "library"),
    "Paquet Python": ({"pyproject.toml": '[project]\nname = "x"\ndependencies = ["requests"]\n'}, "library"),
    "C++ (CMake)": ({"CMakeLists.txt": "project(x)\n"}, "library"),
}

# demande citant un framework -> agents dont au moins un doit être retenu (la discipline, pas le framework)
PROMPTS = {
    "Ajoute une migration Laravel pour la table des commandes": {"database", "database-builder"},
    "Crée un composant Vue pour le panier": {"frontend"},
    "Ajoute un endpoint Spring Boot pour lister les factures": {"api", "backend"},
    "Écran de connexion Flutter avec formulaire": {"frontend"},
    "Requête N+1 dans l'ORM Django, la page est lente": {"performance"},
    "Écris des tests unitaires pour le service Go": {"testing"},
    "Pipeline CI GitHub Actions pour un projet Rust": {"devops"},
    "Fuite mémoire dans le service ASP.NET, l'application plante": {"debugging", "performance"},
    "Faille XSS dans un template Symfony Twig": {"security"},
    "Monter de version Angular, de la 15 à la 17": {"dependencies", "framework-expert"},
    "Mettre à jour Laravel vers la dernière version": {"dependencies", "framework-expert"},
    "Le webhook Stripe de mon API NestJS arrive deux fois": {"payments"},
    "Optimise les images de mon site Next.js": {"multimedia", "performance"},
    "Refactorise ce contrôleur Rails trop long": {"refactoring"},
    "Accessibilité clavier de la modale React": {"accessibility"},
    "Tests de charge sur l'API FastAPI avant le lancement": {"load-testing"},
}

# Le skill stack-detection doit nommer chaque framework (ou sa famille) qu'il sait reconnaître.
STACK_TERMS = ["React", "Vue", "Angular", "Svelte", "Next", "Nuxt", "Astro", "Solid", "Remix", "Laravel", "Symfony",
               "Django", "Flask", "FastAPI", "Rails", "Phoenix", "Spring", "Ktor", "ASP.NET", "Blazor", "Express",
               "Nest", "Go", "Rust", "Flutter", "React Native", "Expo", "Ionic", "Capacitor", "MAUI", "Electron", "Tauri",
               "WPF", "Avalonia", "JavaFX", "Qt", "Swift", "Kotlin", "Deno", "C++"]


def detect(shell, project):
    if shell == "bash":
        cmd = [shutil.which("bash") or "bash", (ROOT / "install.sh").as_posix(), "--source", ROOT.as_posix(),
               "--dir", pathlib.Path(project).as_posix(), "--yes", "--dry-run"]
    else:
        cmd = [shutil.which(shell) or shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "install.ps1"),
               "-Source", str(ROOT), "-TargetDir", str(project), "-Yes", "-DryRun"]
    out = subprocess.run(cmd, capture_output=True, timeout=300, env=dict(os.environ, NO_COLOR="1"))
    text = re.sub(r"\x1b\[[0-9;]*m", "", out.stdout.decode("utf-8", "replace") + out.stderr.decode("utf-8", "replace"))
    m = re.search(r"Agents : ([^.\n]+)\.", text)
    return m.group(1).strip() if m else f"? (code {out.returncode})"


def regulator(shell, prompt):
    if shell == "bash":
        cmd = [shutil.which("bash") or "bash", (ROOT / "hooks" / "regulator.sh").as_posix()]
    else:
        cmd = [shutil.which(shell) or shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "hooks" / "regulator.ps1")]
    payload = json.dumps({"prompt_text": prompt}, ensure_ascii=False).encode("utf-8")
    env = dict(os.environ, REGULATOR_AGENTS_DIR=str(ROOT / "agents"), REGULATOR_HISTORY_FILE=str(ROOT / "absent" / "p.log"))
    out = subprocess.run(cmd, input=payload, capture_output=True, env=env, timeout=60).stdout.decode("utf-8", "replace")
    line = next((l for l in out.splitlines() if "Agents retenus" in l), "")
    body = line.split(":", 1)[1].rstrip(".") if line else ""
    return {part.strip().split(" ")[0] for part in body.split(";") if part.strip()}


shells = sys.argv[1:] or [s for s in ("bash", "pwsh", "powershell") if shutil.which(s)]
fails = 0
with tempfile.TemporaryDirectory() as work:
    for i, (name, (files, expected)) in enumerate(FIXTURES.items()):
        project = pathlib.Path(work, f"p{i}")
        for rel, content in files.items():
            path = project / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        for shell in shells:
            got = detect(shell, project)
            ok = got == expected
            fails += not ok
            print(f"{'ok  ' if ok else 'FAIL'} [{shell}] type {name} -> {got}" + ("" if ok else f" (attendu : {expected})"))

for shell in shells:
    for prompt, wanted in PROMPTS.items():
        got = regulator(shell, prompt)
        ok = bool(got & wanted)
        fails += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [{shell}] {prompt[:55]!r} -> {sorted(got)}" + ("" if ok else f" (attendu : un de {sorted(wanted)})"))

skill = (ROOT / "skills" / "stack-detection" / "SKILL.md").read_text(encoding="utf-8")
missing = [t for t in STACK_TERMS if t.lower() not in skill.lower()]
fails += bool(missing)
print(f"{'ok  ' if not missing else 'FAIL'} stack-detection reconnaît tous les frameworks" + (f" ; manquants : {missing}" if missing else ""))

print(f"\n{fails} échec(s)." if fails else "\nTous les contrôles sont passés.")
sys.exit(1 if fails else 0)
