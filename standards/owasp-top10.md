# OWASP Top 10 (référence 2021, toujours la base 2024+)

Checklist de risques de sécurité web, indépendante du langage/framework.

1. **Broken Access Control** : vérifier que chaque endpoint contrôle l'autorisation (pas seulement l'authentification) — un utilisateur A ne doit jamais accéder/modifier les ressources de l'utilisateur B en changeant un ID dans l'URL (IDOR).
2. **Cryptographic Failures** : données sensibles (mots de passe, tokens, PII) jamais en clair au repos ou en transit ; algorithmes de hash adaptés aux mots de passe (bcrypt/argon2, jamais MD5/SHA1 seul) ; HTTPS partout.
3. **Injection** (SQL, NoSQL, commande OS, LDAP...) : toujours des requêtes paramétrées/préparées, jamais de concaténation de chaîne avec une entrée utilisateur.
4. **Insecure Design** : les failles ne sont pas toutes des bugs d'implémentation — vérifier que le design même (flux métier, limites de taux, validation) prévoit les cas d'abus.
5. **Security Misconfiguration** : pas de comptes/mots de passe par défaut, pas de stack trace exposée en prod, en-têtes de sécurité HTTP présents, permissions de fichiers/cloud strictes.
6. **Vulnerable and Outdated Components** : dépendances à jour, pas de CVE connue non corrigée dans les librairies utilisées.
7. **Identification and Authentication Failures** : gestion de session robuste (expiration, rotation de token), protection contre le brute-force, pas de mot de passe faible accepté.
8. **Software and Data Integrity Failures** : vérifier l'intégrité des mises à jour/dépendances/CI-CD (pas de pipeline qui exécute du code non vérifié), désérialisation non sécurisée à éviter.
9. **Security Logging and Monitoring Failures** : les actions sensibles (connexion, changement de permission, échec d'auth répété) doivent être journalisées et surveillables, sans logger de données sensibles en clair.
10. **Server-Side Request Forgery (SSRF)** : toute requête serveur déclenchée par une URL fournie par l'utilisateur doit être validée/restreinte (allowlist d'hôtes), jamais suivie aveuglément.

## À vérifier systématiquement en plus

- **XSS** : toute sortie injectée dans du HTML/JS doit être échappée ou passer par un moteur de template qui échappe par défaut.
- **CSRF** : les actions qui modifient l'état côté serveur doivent être protégées par un jeton anti-CSRF ou l'équivalent (SameSite cookies + vérification d'origine).
- **Path Traversal** : toute construction de chemin de fichier à partir d'une entrée utilisateur doit être normalisée et restreinte à un répertoire autorisé.
- **Secrets** : jamais de clé/API token/mot de passe en dur dans le code versionné ; toujours via variables d'environnement ou gestionnaire de secrets.
