# Workflow : Audit de conformité

Audit d'ensemble d'un site — pages légales, données personnelles, consentement aux traceurs, accessibilité, sécurité, ergonomie. Piloté par l'agent `compliance`, qui répartit et arbitre ; les axes sont traités par les agents spécialisés.

> **Ce workflow prépare la conformité technique. Il ne l'établit pas.** Le droit applicable dépend du pays d'établissement, du pays des utilisateurs, du secteur et d'engagements que le code ne contient pas. Aucune étape ne conclut qu'un site est conforme.

## Phase 1 — Audit, avant toute modification

1. **Détecter la stack** (skill `stack-detection`) — le mécanisme des pages statiques, des formulaires, du stockage navigateur et du chargement des scripts en dépend entièrement.
2. **Cartographier l'existant**, sans rien modifier : routes, schéma de données, validations serveur, formulaires côté client, configuration des services tiers, e-mails, pages légales déjà présentes, cookies et traceurs réellement posés.
3. **Répartir les fichiers** (agent `compliance`) : dresser la liste des fichiers que chaque axe va toucher et attribuer chacun à **un seul** propriétaire. C'est cette étape qui évite les correctifs contradictoires sur le pied de page, les formulaires et les fichiers de traduction.
4. **Lancer les axes** avec le skill `compliance-audit` comme checklist commune :
   - `legal` — pages légales, CGU, remboursement, mentions ;
   - `privacy` — inventaire des données, minimisation, droits, politique de confidentialité ;
   - `consent` — inventaire des traceurs, blocage préalable, bandeau, politique de cookies ;
   - `accessibility` — WCAG (analyse seule) ;
   - `security` — OWASP + exposition de données personnelles (analyse seule) ;
   - `ux-ui` — ergonomie, mobile, libellés et qualité du français (analyse seule).
5. **Consolider** en un rapport unique, chaque constat classé `CRITIQUE` / `ÉLEVÉ` / `MOYEN` / `FAIBLE` / `BON`, et en `[À VALIDER JURIDIQUEMENT]` / `[BONNE PRATIQUE]` / `[UX]`.

## Phase 2 — Plan priorisé

Classer les constats, en séparant le risque réel de la facilité de correction :

| Niveau | Contenu |
|---|---|
| **P0** | Risque critique : exposition de données personnelles, traceur non nécessaire déclenché avant consentement, faille exploitable |
| **P1** | Conformité : pages légales absentes ou inaccessibles, politique décrivant un site différent du code, droit annoncé sans procédure |
| **P2** | Accessibilité et ergonomie : blocage clavier, contraste, labels, messages d'erreur |
| **P3** | Améliorations : cohérence des libellés, confort de navigation |

Pour chaque entrée : problème, fichier concerné, risque, justification, correction proposée, propriétaire, statut.

**Faire valider le plan avant la phase 3** dès qu'il touche au contenu des pages légales, à la suppression d'un champ collecté, ou au comportement d'un tunnel de paiement.

## Phase 3 — Implémentation

Dans l'ordre de priorité, et en respectant l'attribution des fichiers de la phase 1 :

1. Pages légales manquantes, routes, liens en pied de page (`legal`).
2. Politique de confidentialité issue de l'inventaire réel, suppression des champs collectés sans usage (`privacy`, correctifs serveur par `backend`).
3. Blocage préalable des traceurs, puis bandeau et page de préférences (`consent`).
4. Correctifs d'accessibilité (`frontend`, sur constats d'`accessibility`).
5. Correctifs de sécurité par sévérité (`backend`/`api`, sur constats de `security`).
6. Ergonomie, libellés, français (`frontend`, sur constats d'`ux-ui`).

Règle de risque : **corriger directement** ce qui ne peut rien casser (texte alternatif manquant, label non associé, lien non explicite, faute d'orthographe hors texte juridique) ; **proposer et documenter** ce qui touche au comportement, aux données stockées, à l'argent ou au sens d'une clause.

## Phase 4 — Vérification

- Suite de tests du projet au vert, avant et après — aucune fonctionnalité existante cassée.
- Tests ajoutés sur ce qui est vérifiable automatiquement : atteignabilité des pages légales sans authentification, présence des liens en pied de page, enregistrement et réversibilité du consentement, validations de formulaire modifiées.
- Vérification manuelle du point non automatisable et pourtant décisif : **première visite, onglets réseau et stockage vides de tout traceur non nécessaire, avant toute interaction**.
- Parcours clavier complet sur les écrans modifiés, et rendu mobile.

## Livrable

1. **Scores indicatifs** par axe (conformité technique, données personnelles, accessibilité, UX, sécurité) — une mesure de couverture technique, utile pour prioriser et suivre des progrès, **sans valeur juridique**.
2. **Problèmes corrigés**, avec fichier et nature de la correction.
3. **Problèmes restants**, avec raison du report.
4. **Informations à fournir par le propriétaire** : raison sociale, adresse, contact, hébergeur, responsable du traitement, durées de conservation, conditions commerciales et de remboursement, liste des prestataires réellement utilisés.
5. **Points à faire valider par un juriste**, listés explicitement.

Conclusion imposée : « conformité technique améliorée, sous réserve de validation juridique des éléments signalés ».

## Points d'attention

- Une politique de confidentialité rédigée depuis un modèle générique décrit un autre site : elle se déduit du code, jamais l'inverse.
- Un bandeau de consentement qui s'affiche pendant que le traceur s'est déjà déclenché ne sert à rien — le blocage préalable est le cœur du sujet, le bandeau n'en est que la façade.
- Si l'inventaire ne révèle **que** des cookies strictement nécessaires, la conclusion honnête peut être qu'aucun bandeau n'a lieu d'être : ne pas en installer un par réflexe.
- Un score élevé n'est pas une conformité. Il mesure ce que le code peut montrer, pas ce que le droit exige.
