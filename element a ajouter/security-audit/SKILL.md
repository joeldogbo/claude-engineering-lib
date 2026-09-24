---
name: security-audit
description: >
  Orchestre un audit de sécurité complet OWASP A01-A10 suivi de tests d'intrusion.
  Déclencher avant une release, après l'ajout d'un endpoint sensible, ou à la demande
  d'un audit de sécurité, de vérification des vulnérabilités ou des dépendances.
---

Lire CLAUDE.md pour connaître le stack, les mécanismes de sécurité et les dépendances du projet.

Lancer le workflow WF-3 via l'Orchestrateur dans cet ordre strict :
1. Auditeur Sécurité → audit des Security Rules (refus par défaut, ownership, isAdmin, validation) + OWASP A01–A10 appliqué à Firebase
2. Auditeur Sécurité → exposition côté client (aucun secret dans le bundle) + dépendances (npm audit deux apps)
   → pour chaque CVE sans fix : documenter la décision (fix / override / wontfix)
3. Pentester         → bypass de rules + escalade de rôle (customer → admin) + IDOR Firestore via SDK
4. Pentester         → mass assignment (status/total) + lecture massive + upload Storage non autorisé
5. Réviseur          → priorisation des vulnérabilités par criticité
6. Rapport sécurité  → document complet avec corrections recommandées (rules)

Environnement cible : développement et staging uniquement. Jamais sur la production.
