# Workflow : Audit de sécurité

1. **Détecter la stack** (skill `stack-detection`) — les vecteurs d'attaque pertinents dépendent du langage/framework (ex. injection SQL brute vs ORM, XSS côté SPA vs rendu serveur).
2. **Auditer** avec l'agent `security` + skill `security-audit`, en suivant systématiquement [owasp-top10.md](../standards/owasp-top10.md) :
   - Authentification et gestion de session
   - Autorisation (contrôle d'accès par ressource, pas seulement par route)
   - Validation des entrées (injection, XSS, path traversal, SSRF)
   - Gestion des secrets et de la configuration — y compris l'**exposition côté client** : aucun secret dans le code livré au navigateur ou à l'application mobile (bundle, variables d'environnement publiques)
   - Dépendances vulnérables/obsolètes, avec l'outil d'audit de l'écosystème (npm audit, pip-audit, composer audit, cargo audit...) sur **chaque** application du dépôt ; pour toute vulnérabilité sans correctif, documenter la décision (corriger / surcharger la version / accepter le risque, avec la raison)
3. **Tests d'intrusion ciblés sur le contrôle d'accès** (environnement de développement ou de recette uniquement, **jamais la production**) — vérifier par des appels réels, pas seulement à la lecture du code :
   - contournement des règles d'accès en appelant directement l'API ou le SDK, sans passer par l'interface ;
   - escalade de rôle (un utilisateur standard qui obtient des droits d'administration) ;
   - IDOR : accès à la ressource d'un autre utilisateur en changeant un identifiant ;
   - mass assignment : écriture de champs protégés (rôle, statut, montant, propriétaire) via une requête de mise à jour ;
   - lecture massive (énumération d'une collection entière) et téléversement de fichiers non autorisé.
4. **Prioriser les constats** par sévérité réelle (exploitabilité × impact), pas par facilité de correction.
5. **Reporter** chaque constat avec fichier:ligne, scénario d'exploitation concret, et correctif proposé — pas de généralité type "améliorer la sécurité".
6. **Corriger** les constats critiques/élevés en priorité (agent `backend`/`api` selon la couche), puis enchaîner sur `/workflow bug-fix` pour chaque correctif avec un test de non-régression.
7. **Ne jamais publier** de preuve de concept d'exploitation fonctionnelle dans un rapport partagé largement — décrire le mécanisme, pas fournir un exploit clé en main.

## Points d'attention

- Un audit de sécurité est un contexte d'usage défensif/autorisé (test interne, revue de code du propre projet) — pas une reconnaissance offensive sur un système tiers sans autorisation.
