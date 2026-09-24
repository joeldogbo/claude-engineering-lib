---
name: security-audit
description: Audit de sécurité — validation des entrées, authentification, autorisation, gestion des secrets, injections, XSS, CSRF, SSRF, path traversal, configuration. Utiliser avant une mise en production, quand du code touche à l'auth/permissions/données sensibles, ou pour un audit de sécurité explicite.
---

# Audit de sécurité

## Instructions

Vérifier systématiquement chaque point de [owasp-top10.md](../../standards/owasp-top10.md) :

1. **Autorisation** : chaque endpoint/action vérifie-t-il que l'utilisateur courant a le droit sur *cette* ressource précise (pas seulement qu'il est authentifié) ? Chercher les IDOR (accès à une ressource d'un autre utilisateur en changeant un identifiant).
2. **Authentification** : gestion de session robuste, pas de mot de passe faible accepté, protection contre le brute-force.
3. **Injection** : requêtes paramétrées partout, aucune concaténation de chaîne avec une entrée utilisateur (SQL, commande, LDAP...).
4. **XSS** : toute sortie injectée dans du HTML/JS est échappée ou passe par un moteur qui échappe par défaut.
5. **CSRF** : actions qui modifient l'état protégées par jeton anti-CSRF ou équivalent.
6. **SSRF / Path Traversal** : toute URL ou chemin de fichier construit à partir d'une entrée utilisateur est validé/restreint.
7. **Secrets** : aucune clé/mot de passe/token en dur dans le code versionné.
8. **Configuration** : pas de mode debug actif en production, pas de stack trace exposée, dépendances à jour sans CVE connue.

## Restitution

Constats classés par sévérité réelle (exploitabilité × impact), avec fichier:ligne, scénario d'exploitation concret et correctif proposé. Contexte défensif uniquement — ne pas fournir d'exploit fonctionnel prêt à l'emploi dans le rapport.
