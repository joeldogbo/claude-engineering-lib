---
name: security-audit
description: Audit de sécurité en 6 phases — périmètre, scan automatisé local, dépendances (CVE via OSV), revue manuelle OWASP Web + API (BOLA, BFLA, mass assignment, exposition de données, injections, secrets y compris dans le bundle client, prix fixés côté serveur, règles d'accès des bases exposées au client comme RLS ou Firebase Rules, rate limiting, configuration), pièges du code généré par IA, score /100 et note A-F, rapport avec correctifs avant/après. Utiliser avant une mise en production, quand du code touche à l'auth/permissions/entrées utilisateur/données sensibles, ou pour un audit de sécurité explicite.
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

1. **BOLA / IDOR** (API1, CWE-639) : chaque lecture/modification/suppression par identifiant filtre par propriétaire ou tenant côté serveur. L'identité vient de la **session**, jamais de la requête : un `userId` reçu dans le corps, la query ou un en-tête est une affirmation, pas un fait. Masquer un bouton dans l'interface ne protège pas la donnée. Lister chaque route et indiquer où elle vérifie que l'appelant possède la ressource ; signaler toute route qui fait confiance à un identifiant d'utilisateur envoyé par le client.
2. **BFLA** (API5, CWE-285) : chaque fonction d'administration vérifie le rôle côté serveur ; méthodes HTTP non prévues refusées.
3. **Authentification** (API2, CWE-287/798) : pas d'identifiant en dur ni de token statique, JWT vérifié (signature, `alg`, expiration), session expirée et renouvelée, anti brute-force sur login/OTP/reset, hachage bcrypt/argon2.
4. **Mass assignment** (API3, CWE-915) : liste blanche des champs modifiables ; jamais de `Model.update(req.body)` ou équivalent. Chaque route d'écriture valide le corps avec un schéma **strict qui rejette les champs inconnus** (400), et les champs fixés uniquement par le serveur (`role`, `credits`, `plan`, `isAdmin`, `ownerId`, statut de paiement...) sont listés par route et jamais acceptés du client.
5. **Exposition excessive de données** (API3, CWE-213) : réponses construites par DTO/serializer ; aucun hash, token, champ interne ou donnée d'un autre utilisateur.
6. **Injections** (CWE-89/78/79/22/94) : SQL/NoSQL paramétré, aucune commande système construite depuis une entrée, sortie HTML échappée, chemins normalisés et confinés, aucun `eval` de donnée externe, désérialisation sûre.
7. **Validation des entrées** (CWE-20) : schéma validé côté serveur (type, longueur, format, énumérations) sur chaque point d'entrée, y compris webhooks et messages de file.
8. **Limitation de débit et ressources** (API4, CWE-770) : rate limiting sur login, inscription, reset, OTP, endpoints coûteux et appels d'API payantes ; pagination plafonnée ; taille d'upload bornée ; complexité GraphQL limitée. Clé de limitation adaptée : **par IP** pour les routes d'authentification (l'appelant n'est pas encore connu), **par utilisateur** pour les routes payantes (une route IA ou SMS sans limite = force brute gratuite et facture surprise). Dépassement → `429` ; la limite de chaque route est documentée.
9. **Secrets** (CWE-798/200) : aucun secret versionné **ni présent dans l'historique git** ; aucun secret dans le code livré au client (bundle front, variables `NEXT_PUBLIC_`/`VITE_`/`REACT_APP_`/`EXPO_PUBLIC_`/`PUBLIC_`, application mobile). Lister chaque variable d'environnement et celles qui atteignent le navigateur ; si un build existe, chercher les préfixes de clés dans le code généré (`dist/`, `.next/static/`, `build/`). Une clé d'API tierce payante reste côté serveur : le client appelle une route du projet, qui appelle le fournisseur. Un secret trouvé dans le bundle ou l'historique est considéré comme compromis : le déplacer ne suffit pas, il faut le **révoquer et le régénérer** ; réécrire l'historique ne suffit pas non plus.
10. **Configuration** (API8, CWE-16) : debug désactivé en production, CORS restrictif, en-têtes de sécurité (CSP, HSTS, X-Content-Type-Options, frame-ancestors), cookies `Secure`/`HttpOnly`/`SameSite`, erreurs sans stack trace, TLS vérifié.
11. **CSRF** (CWE-352) : actions qui modifient l'état protégées par jeton ou SameSite + vérification d'origine.
12. **SSRF et API tierces** (API7/API10, CWE-918/20) : allowlist d'hôtes, IP internes et métadonnées cloud bloquées, réponses tierces validées.
13. **Webhooks entrants et paiement** (CWE-345/602) : signature vérifiée sur le corps brut, horodatage contrôlé contre le rejeu, traitement idempotent. Le prix et le montant ne viennent **jamais du navigateur** : le client envoie un identifiant de produit et une quantité, le serveur lit le prix dans son catalogue. Tracer d'où vient chaque montant transmis au prestataire de paiement.
14. **Inventaire** (API9) : pas d'endpoint de debug, de Swagger/GraphiQL ou d'ancienne version d'API ouverts en production.
15. **Journalisation** (CWE-778/532) : connexions, échecs répétés et changements de droits journalisés ; aucun mot de passe, token ou donnée sensible dans les logs.
16. **Base exposée directement au client** (CWE-284/862) : quand le navigateur ou l'app mobile interroge la base sans serveur intermédiaire (Supabase, Firebase/Firestore, Appwrite, PocketBase, Hasura...), les règles de la base sont **le seul garde**. La clé publique (`anon key`, config Firebase) est publique par conception : la protection, ce sont les règles, pas la clé. Vérifier que chaque table ou collection exposée a ses règles activées (Row Level Security sous Supabase/PostgreSQL, Security Rules sous Firebase) avec des politiques de lecture **et** d'écriture limitées au propriétaire (`auth.uid()`, `request.auth.uid`) ; aucune règle `allow read, write: if true`, aucune table publique sans politique. Utiliser le lint de sécurité de la plateforme s'il existe (Security Advisor de Supabase).

**Pièges fréquents du code généré par IA** — à vérifier en priorité sur du code récent. Pour chacun : ce qu'on cherche, le correctif attendu, et la preuve.

| # | Piège | Ce qu'on cherche | Correctif | Preuve |
|---|---|---|---|---|
| 1 | Secret dans le bundle client | Clé derrière `NEXT_PUBLIC_`/`VITE_`..., `Authorization` construit côté navigateur | Route serveur qui porte le secret, clé révoquée et régénérée | Préfixe de clé absent du build |
| 2 | Contrôle de propriété absent | `find`/`update`/`delete` par id sans filtre propriétaire, `userId` lu dans la requête | Filtre `id` + identifiant issu de la session | Test : B reçoit 403/404 sur la ressource de A |
| 3 | Base sans règles d'accès | Table publique sans RLS, règles Firebase ouvertes | Règles activées, politiques propriétaire en lecture et écriture | Requête avec un autre compte (ou la clé anonyme) refusée |
| 4 | Mass assignment | `req.body` passé tel quel à l'ORM | Schéma strict, champs inconnus → 400 | Envoyer `role: "admin"` est rejeté ou ignoré |
| 5 | Paiement piloté par le navigateur | Montant reçu du client, webhook sans vérification de signature | Prix lu côté serveur par identifiant de produit, signature vérifiée | Montant falsifié sans effet, webhook non signé refusé |
| 6 | Pas de limite de débit | Login, inscription, reset ou route d'API payante sans limite | Limite par IP (auth) et par utilisateur (payant), `429` | Test de dépassement → `429` |
| 7 | « C'est protégé » sans preuve | Affirmation de l'IA ou commentaire, aucun test d'autorisation | Test qui échoue sur la faille, puis passe après correctif | Sortie du test exécuté |

Autres pièges : CORS `*` et debug laissés actifs, validation absente « à ajouter plus tard », dépendances inventées ou mal orthographiées (vérifier que chaque paquet existe et est le bon).

**Une affirmation n'est pas une preuve.** « Toutes les routes sont protégées », qu'elle vienne d'une IA, d'un commentaire ou d'une documentation, ne vaut rien sans test. Un constat de contrôle d'accès n'est « confirmé » (ou un correctif validé) qu'avec un test exécuté : l'utilisateur A crée une ressource, l'utilisateur B tente de la lire, la modifier et la supprimer, chaque tentative doit renvoyer 403 ou 404. Un test rouge est une preuve ; un « oui » ne l'est pas.

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
