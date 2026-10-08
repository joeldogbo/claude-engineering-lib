---
name: security-audit
description: Audit de sécurité en 6 phases — périmètre, scan automatisé local, dépendances (CVE via OSV), revue manuelle OWASP Web + API (BOLA, BFLA, mass assignment, exposition de données, injections, secrets, rate limiting, configuration), score /100 et note A-F, rapport avec correctifs avant/après. Utiliser avant une mise en production, quand du code touche à l'auth/permissions/entrées utilisateur/données sensibles, ou pour un audit de sécurité explicite.
---

# Audit de sécurité

Références : [owasp-top10.md](../../standards/owasp-top10.md) (web) et [owasp-api-top10.md](../../standards/owasp-api-top10.md) (dès qu'une API est exposée). Gabarit de restitution : [rapport-securite.md](../../templates/rapport-securite.md).

Tout reste **local** : aucun code, extrait ou secret n'est envoyé à un service externe sans accord explicite de l'utilisateur.

## Phase 1 — Périmètre

1. Détecter la stack (skill `stack-detection`) et lister **chaque** application du dépôt (monorepo : front, back, mobile, workers, fonctions serverless).
2. Cartographier la surface d'attaque : routes/endpoints/resolvers, middlewares d'authentification, rôles, points d'upload, webhooks entrants, appels sortants (HTTP, SDK tiers), tâches planifiées.
3. Noter le commit analysé : un audit est daté et rattaché à une version.

## Phase 2 — Scan automatisé (si les outils sont disponibles)

Vérifier avec `command -v` ce qui est installé et exécuter ce qui l'est. Ne **jamais** installer un outil globalement sans accord de l'utilisateur ; proposer la commande d'installation à la place.

| Besoin | Outils (par ordre de préférence) |
|---|---|
| Analyse statique multi-langages | `semgrep scan --config auto` (ou `p/owasp-top-ten`), `bandit` (Python), `gosec` (Go), `brakeman` (Rails) |
| Secrets, y compris dans l'historique git | `gitleaks detect` (historique) / `gitleaks dir` (fichiers), `trufflehog git file://.` |
| Dépendances vs base OSV | `osv-scanner scan -r .` |
| Dépendances par écosystème | `npm audit` / `pnpm audit` / `yarn npm audit`, `pip-audit`, `composer audit`, `cargo audit`, `bundle audit`, `govulncheck ./...`, `dotnet list package --vulnerable`, `mvn`/`gradle` dependency-check |
| Infrastructure (Docker, Terraform, K8s) | `trivy fs .`, `checkov -d .` |

**Repli sans outil** : recherches ciblées avec Grep, par exemple :
- secrets : `(api[_-]?key|secret|token|passw(or)?d)\s*[:=]\s*['"][^'"]{8,}`, `AKIA[0-9A-Z]{16}`, `sk_live_`, `-----BEGIN .*PRIVATE KEY-----`, `ghp_[A-Za-z0-9]{36}` ; fichiers `.env*` versionnés ;
- injections : concaténation ou interpolation dans `query(`, `execute(`, `raw(`, `exec(`, `system(`, `eval(`, `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `|safe`, `{!! !!}` ;
- configuration : `DEBUG\s*=\s*True`, `APP_DEBUG=true`, `origin:\s*['"]\*`, `Access-Control-Allow-Origin: *`, `verify\s*=\s*False`, `rejectUnauthorized:\s*false`.

Chaque résultat d'outil est **trié à la main** : confirmer, déclasser ou marquer comme faux positif avec la raison. Un outil ne remplace jamais la revue de la phase 4.

## Phase 3 — Dépendances

1. Croiser les manifestes et fichiers de verrouillage avec la base OSV (via `osv-scanner` ou l'audit de l'écosystème), pour **chaque** application.
2. Distinguer dépendance directe / transitive et utilisée en production / en développement seulement.
3. Pour chaque CVE : version corrigée disponible ? Code vulnérable réellement atteint ? Décision documentée (mettre à jour / surcharger la version / accepter le risque, avec la raison).
4. Signaler aussi : paquets abandonnés, fichier de verrouillage absent, versions non épinglées, scripts `postinstall` suspects.

## Phase 4 — Revue manuelle par catégorie

Pour chaque catégorie, chercher activement — ne pas se contenter de l'absence d'alerte d'un outil.

1. **BOLA / IDOR** (API1, CWE-639) : chaque lecture/modification/suppression par identifiant filtre par propriétaire ou tenant côté serveur.
2. **BFLA** (API5, CWE-285) : chaque fonction d'administration vérifie le rôle côté serveur ; méthodes HTTP non prévues refusées.
3. **Authentification** (API2, CWE-287/798) : pas d'identifiant en dur ni de token statique, JWT vérifié (signature, `alg`, expiration), session expirée et renouvelée, anti brute-force sur login/OTP/reset, hachage bcrypt/argon2.
4. **Mass assignment** (API3, CWE-915) : liste blanche des champs modifiables ; jamais de `Model.update(req.body)` ou équivalent.
5. **Exposition excessive de données** (API3, CWE-213) : réponses construites par DTO/serializer ; aucun hash, token, champ interne ou donnée d'un autre utilisateur.
6. **Injections** (CWE-89/78/79/22/94) : SQL/NoSQL paramétré, aucune commande système construite depuis une entrée, sortie HTML échappée, chemins normalisés et confinés, aucun `eval` de donnée externe, désérialisation sûre.
7. **Validation des entrées** (CWE-20) : schéma validé côté serveur (type, longueur, format, énumérations) sur chaque point d'entrée, y compris webhooks et messages de file.
8. **Limitation de débit et ressources** (API4, CWE-770) : rate limiting sur login, inscription, reset, OTP, endpoints coûteux et appels d'API payantes ; pagination plafonnée ; taille d'upload bornée ; complexité GraphQL limitée.
9. **Secrets** (CWE-798/200) : aucun secret versionné **ni présent dans l'historique git** ; aucun secret dans le code livré au client (bundle front, variables `NEXT_PUBLIC_`/`VITE_`/`REACT_APP_`, application mobile). Un secret trouvé dans l'historique est considéré comme compromis : le **révoquer et le régénérer**, réécrire l'historique ne suffit pas.
10. **Configuration** (API8, CWE-16) : debug désactivé en production, CORS restrictif, en-têtes de sécurité (CSP, HSTS, X-Content-Type-Options, frame-ancestors), cookies `Secure`/`HttpOnly`/`SameSite`, erreurs sans stack trace, TLS vérifié.
11. **CSRF** (CWE-352) : actions qui modifient l'état protégées par jeton ou SameSite + vérification d'origine.
12. **SSRF et API tierces** (API7/API10, CWE-918/20) : allowlist d'hôtes, IP internes et métadonnées cloud bloquées, réponses tierces validées.
13. **Webhooks entrants** : signature vérifiée, horodatage contrôlé contre le rejeu, traitement idempotent.
14. **Inventaire** (API9) : pas d'endpoint de debug, de Swagger/GraphiQL ou d'ancienne version d'API ouverts en production.
15. **Journalisation** (CWE-778/532) : connexions, échecs répétés et changements de droits journalisés ; aucun mot de passe, token ou donnée sensible dans les logs.

**Pièges fréquents du code généré par IA** — à vérifier en priorité sur du code récent : contrôle d'accès uniquement côté client, `find(id)` sans filtre propriétaire, `req.body` passé tel quel à l'ORM, clé d'API collée « pour tester », CORS `*` et debug laissés actifs, validation absente « à ajouter plus tard », dépendances inventées ou mal orthographiées (vérifier que chaque paquet existe et est le bon).

## Phase 5 — Sévérité et score

Sévérité de chaque constat = **exploitabilité × impact** :
- **Critique** : exploitable sans authentification ou par n'importe quel utilisateur, avec fuite massive, prise de contrôle de compte, exécution de code ou secret de production exposé.
- **Élevé** : exploitable par un utilisateur authentifié sur les données d'autres utilisateurs, ou CVE exploitable atteinte par le code.
- **Moyen** : exploitation conditionnelle ou impact limité (absence de rate limiting, en-tête manquant sur une surface sensible).
- **Faible** : défense en profondeur manquante sans scénario d'exploitation direct.
- **Info** : bonne pratique, sans pénalité.

Indiquer aussi la **confiance** : confirmé (testé), probable (lu dans le code), à vérifier.

**Score sur 100**, transparent et reproductible : partir de 100 et retirer 25 par critique, 10 par élevé, 4 par moyen, 1 par faible (minimum 0). Les constats « à vérifier » comptent pour moitié.
**Note** : A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, F < 60. **Plafonds** : au moins un critique → note maximale D ; un secret de production exposé ou un BOLA exploitable sans authentification → F.
Toujours afficher le détail du calcul pour que le score puisse être contesté.

## Phase 6 — Restitution et correctifs

1. Remplir [rapport-securite.md](../../templates/rapport-securite.md) : synthèse, score, tableau par catégorie, **top 3 à corriger en premier**, constats détaillés (catégorie OWASP, CWE, fichier:ligne, preuve, scénario, correctif **avant/après**, test de non-régression), dépendances, faux positifs écartés, limites.
2. Masquer tout secret découvert (4 premiers caractères puis `****`).
3. Si l'utilisateur le demande ou pour la CI, produire aussi `security-report.json` (score, note, liste des constats avec `id`, `severity`, `category`, `cwe`, `file`, `line`, `confidence`, `status`) pour suivre l'évolution d'un audit à l'autre.
4. Ne jamais fournir d'exploit fonctionnel prêt à l'emploi : décrire le mécanisme, pas une arme.
