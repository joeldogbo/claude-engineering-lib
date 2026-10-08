# Gabarit de rapport d'audit de sécurité

```markdown
# Audit de sécurité — <projet> — <date>

## Synthèse

- **Score : <NN>/100 — Note <A-F>** (méthode de calcul : skill `security-audit`)
- Périmètre : <applications/dossiers analysés>, commit `<sha>`
- Stack : <langages, frameworks, BDD>
- Outils exécutés : <semgrep, gitleaks, osv-scanner, npm audit...> / non disponibles : <...>
- Constats : <n> critiques · <n> élevés · <n> moyens · <n> faibles · <n> informatifs

| Catégorie | Statut | Constats |
|---|---|---|
| Contrôle d'accès (BOLA/BFLA/IDOR) | ✅ / ⚠️ / ❌ | n |
| Authentification et session | | |
| Mass assignment / exposition de données | | |
| Injections (SQL, NoSQL, commande, XSS, path traversal) | | |
| Secrets | | |
| Dépendances (CVE) | | |
| Limitation de débit et ressources | | |
| Configuration (debug, CORS, en-têtes) | | |
| SSRF / API tierces | | |
| Journalisation et surveillance | | |

## Top 3 à corriger en premier

1. <constat> — <pourquoi en premier>
2. ...
3. ...

## Constats détaillés

### [CRITIQUE] SEC-001 — <titre court>

- **Catégorie** : <ex. API1 BOLA> · **CWE** : <CWE-639>
- **Emplacement** : `chemin/fichier.ext:ligne`
- **Preuve** : <extrait de code minimal, secrets masqués>
- **Scénario** : <qui peut faire quoi, et ce qu'il obtient — mécanisme, pas d'exploit prêt à l'emploi>
- **Correctif** :
  - Avant : `<code>`
  - Après : `<code>`
- **Vérification** : <test de non-régression à ajouter>
- **Confiance** : confirmé (testé) / probable (lecture du code) / à vérifier

## Dépendances vulnérables

| Paquet | Version | Vulnérabilité (CVE/GHSA) | Sévérité | Version corrigée | Décision |
|---|---|---|---|---|---|

## Faux positifs écartés

<constats d'outils examinés et rejetés, avec la raison — pour ne pas les re-trier au prochain audit>

## Hors périmètre / limites

<ce qui n'a pas été vérifié et pourquoi>
```

Les secrets découverts ne sont **jamais** recopiés en clair dans le rapport : afficher seulement les 4 premiers caractères suivis de `****`.
