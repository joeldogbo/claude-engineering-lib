# OWASP API Security Top 10 (édition 2023)

Checklist propre aux API (REST, GraphQL, gRPC, WebSocket), à appliquer **en plus** de [owasp-top10.md](owasp-top10.md) dès que le projet expose une API — y compris l'API « interne » consommée par un front SPA ou une application mobile, qui reste appelable directement.

1. **API1 — BOLA (Broken Object Level Authorization)** · CWE-639 : chaque accès à un objet par identifiant (`/orders/{id}`, argument GraphQL, message WebSocket) vérifie que l'utilisateur courant a le droit sur *cet* objet. Chercher les requêtes du type `find(id)` sans filtre par propriétaire/tenant.
2. **API2 — Broken Authentication** · CWE-287/798 : pas de mot de passe ni de token en dur, pas de token statique partagé, JWT vérifié (signature, `alg`, expiration, audience), pas de token dans l'URL, protection anti brute-force sur login/OTP/reset.
3. **API3 — BOPLA (Broken Object Property Level Authorization)** : regroupe deux problèmes.
   - *Mass assignment* · CWE-915 : le corps de requête n'est jamais injecté tel quel dans le modèle ; liste blanche explicite des champs modifiables (jamais `role`, `isAdmin`, `owner_id`, `price`, `status`...).
   - *Excessive data exposure* · CWE-213 : la réponse ne renvoie que les champs prévus (DTO/serializer dédié), jamais l'entité complète (hash de mot de passe, tokens, champs internes, PII d'autres utilisateurs).
4. **API4 — Unrestricted Resource Consumption** · CWE-770 : limitation de débit (rate limiting) par utilisateur/IP sur les endpoints sensibles et coûteux, pagination plafonnée, taille de payload et d'upload bornée, timeouts, profondeur/complexité des requêtes GraphQL limitée, coûts d'API tierces (SMS, e-mail, IA) plafonnés.
5. **API5 — BFLA (Broken Function Level Authorization)** · CWE-285 : les fonctions d'administration ou de rôle élevé vérifient le rôle côté serveur, pas seulement en masquant le bouton côté client ; méthodes HTTP non prévues refusées (un `DELETE` ou `PUT` oublié).
6. **API6 — Accès non restreint aux flux métier sensibles** : achat, inscription, parrainage, réservation, envoi de messages protégés contre l'automatisation abusive (limites métier, captcha, détection d'anomalies).
7. **API7 — SSRF** · CWE-918 : toute URL fournie par l'utilisateur (webhook, import, aperçu de lien) passe par une allowlist ; blocage des IP internes et des métadonnées cloud (`169.254.169.254`), redirections non suivies aveuglément.
8. **API8 — Security Misconfiguration** · CWE-16 : mode debug désactivé en production, CORS restrictif (jamais `*` avec credentials), en-têtes de sécurité, messages d'erreur sans stack trace, TLS partout, méthodes HTTP inutiles désactivées.
9. **API9 — Improper Inventory Management** : inventaire des endpoints et versions exposés ; pas d'anciennes versions (`/v1`), d'endpoints de debug, de documentation Swagger/GraphiQL ou d'environnements de test ouverts en production.
10. **API10 — Unsafe Consumption of APIs** · CWE-20 : les réponses des API tierces sont validées comme une entrée utilisateur (schéma, taille, redirections, TLS), jamais considérées comme fiables par défaut.
