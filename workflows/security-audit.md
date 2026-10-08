# Workflow : Audit de sécurité

Suit les 6 phases du skill `security-audit`. Tout reste local : aucun code ni secret envoyé à un service externe sans accord explicite.

1. **Périmètre** : détecter la stack (skill `stack-detection`), lister chaque application du dépôt et cartographier la surface d'attaque (routes, rôles, uploads, webhooks, appels sortants). Noter le commit audité. Si un rapport précédent existe (`security-report.json`), le charger pour comparer.
2. **Scan automatisé** avec les outils déjà installés (analyse statique, secrets **y compris dans l'historique git**, dépendances vs OSV, infrastructure). Proposer l'installation de ceux qui manquent sans l'imposer. Trier chaque résultat : confirmé, déclassé ou faux positif motivé.
3. **Dépendances** : audit de **chaque** application avec l'outil de l'écosystème ou `osv-scanner` ; pour toute vulnérabilité, documenter la décision (corriger / surcharger la version / accepter le risque, avec la raison).
4. **Revue manuelle** avec l'agent `security`, en suivant [owasp-top10.md](../standards/owasp-top10.md) et, si une API est exposée, [owasp-api-top10.md](../standards/owasp-api-top10.md) :
   - Authentification et gestion de session
   - Autorisation par objet (BOLA/IDOR) et par fonction (BFLA)
   - Mass assignment et exposition excessive de données dans les réponses
   - Validation des entrées (injections, XSS, path traversal, SSRF)
   - Limitation de débit et consommation de ressources
   - Secrets et configuration — y compris l'**exposition côté client** : aucun secret dans le code livré au navigateur ou à l'application mobile (bundle, variables d'environnement publiques)
   - Webhooks entrants (signature, rejeu), inventaire des endpoints exposés, journalisation
5. **Tests d'intrusion ciblés sur le contrôle d'accès** (environnement de développement ou de recette uniquement, **jamais la production**) — vérifier par des appels réels, pas seulement à la lecture du code :
   - contournement des règles d'accès en appelant directement l'API ou le SDK, sans passer par l'interface ;
   - escalade de rôle (un utilisateur standard qui obtient des droits d'administration) ;
   - IDOR : accès à la ressource d'un autre utilisateur en changeant un identifiant ;
   - mass assignment : écriture de champs protégés (rôle, statut, montant, propriétaire) via une requête de mise à jour ;
   - lecture massive (énumération d'une collection entière), absence de limitation de débit, et téléversement de fichiers non autorisé.
   Un constat vérifié ici passe en confiance « confirmé ».
6. **Sévérité et score** : classer par sévérité réelle (exploitabilité × impact), pas par facilité de correction, puis calculer le score /100 et la note A-F selon le skill, avec le détail du calcul. En cas d'audit précédent, indiquer l'évolution (constats corrigés, nouveaux, score avant/après).
7. **Reporter** au format [rapport-securite.md](../templates/rapport-securite.md) : top 3 à corriger en premier, puis chaque constat avec catégorie OWASP, CWE, fichier:ligne, scénario concret et correctif avant/après — pas de généralité type « améliorer la sécurité ». Produire aussi `security-report.json` si l'utilisateur veut suivre l'évolution ou brancher la CI.
8. **Corriger** les constats critiques/élevés en priorité avec l'agent `security-fixer` (et `backend`/`api`/`frontend` selon la couche si le correctif dépasse la faille), avec accord de l'utilisateur, puis enchaîner sur `/workflow bug-fix` pour chaque correctif avec un test de non-régression. Révoquer et régénérer tout secret exposé.
9. **Re-scanner** après correction pour confirmer la disparition des constats et mettre à jour le score.
10. **Proposer une barrière en CI** (agent `devops`, skill `cicd-pipeline`) pour que le niveau ne régresse pas : scan de secrets et de dépendances à chaque PR, échec du pipeline sur tout nouveau constat critique ou élevé, ou sous un score minimal convenu avec l'utilisateur. Ne jamais l'activer sans son accord.
11. **Ne jamais publier** de preuve de concept d'exploitation fonctionnelle dans un rapport partagé largement — décrire le mécanisme, pas fournir un exploit clé en main.

## Points d'attention

- Un audit de sécurité est un contexte d'usage défensif/autorisé (test interne, revue de code du propre projet) — pas une reconnaissance offensive sur un système tiers sans autorisation.
- Les secrets découverts ne sont jamais recopiés en clair, ni dans le rapport ni dans la conversation.
