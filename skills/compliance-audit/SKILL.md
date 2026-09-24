---
name: compliance-audit
description: Checklist d'audit de conformité d'un site web — pages légales, données personnelles, cookies et consentement, minimisation des formulaires, exposition de données. Utiliser pour préparer la conformité d'un site avant ouverture au public, ou vérifier ce qui manque. Ne remplace jamais l'avis d'un juriste.
---

# Audit de conformité

## Avertissement, à répéter dans toute restitution

Cette checklist prépare la conformité **technique**. Elle ne l'établit pas : le droit applicable dépend du pays d'établissement, du pays des utilisateurs, du secteur et d'engagements contractuels que le code ne contient pas. Ne jamais conclure qu'un site est conforme ou « 100 % légal ».

## Règles de rédaction, sans exception

1. **Rien d'inventé** : raison sociale, adresse, immatriculation, représentant légal, juridiction, autorité de contrôle, durée de conservation, délai de remboursement, sous-traitant. Ce que le projet ne dit pas devient un `TODO` visible.
2. **Aucune citation de mémoire** d'un numéro de loi, d'un article, d'une date de texte ou d'une autorité de régulation. Lister les *sujets* à faire vérifier.
3. **Aucune déclaration non vérifiée dans le code** : ni un cookie absent du projet, ni une donnée non collectée, ni un droit sans procédure réelle.
4. **Classer chaque constat** : `[À VALIDER JURIDIQUEMENT]` / `[BONNE PRATIQUE]` / `[UX]`.

## Checklist

### 1. Pages légales — agent `legal`

Existence, route stable, accès sans authentification, lien depuis le pied de page de toute page publique : mentions légales (éditeur, hébergeur, contact), conditions d'utilisation, politique de confidentialité, politique de cookies, politique de remboursement si le site vend. Vérifier que chaque clause décrit **ce que le code fait vraiment** — une clause de résiliation sans suppression de compte implémentée est un écart.

### 2. Données personnelles — agent `privacy`

Inventaire depuis le schéma, les validations serveur, la configuration des services tiers, les réponses d'API et les journaux. Puis, pour chaque champ : usage réel dans le code, caractère obligatoire, sensibilité, lieu et forme de stockage, durée de conservation et mécanisme de suppression, transmission à un tiers. Un champ jamais lu par le code se supprime, il ne se documente pas.

Vérifier l'existence d'un chemin réel pour consulter, corriger, supprimer, s'opposer, retirer un consentement, exporter.

### 3. Cookies et consentement — agent `consent`

Inventaire réel des cookies serveur, du stockage navigateur et des scripts tiers. Classement nécessaires / préférences / statistiques / marketing / tiers.

Le point décisif, et le seul objectivement testable : **aucun traceur non nécessaire ne se déclenche avant le choix**. Onglet réseau et stockage vides de tout non-nécessaire à la première visite, avant interaction.

Interface : accepter / refuser / personnaliser, refus au même coût et à la même prominence qu'accepter, aucune case pré-cochée hors nécessaires, fermeture ≠ acceptation, choix réversible par un point d'entrée permanent. Consentement enregistré avec date, version et détail par catégorie.

### 4. Accessibilité — agent `accessibility`

Déléguer intégralement. Ne pas retraiter ici.

### 5. Sécurité et exposition de données — agent `security`

Déléguer intégralement pour l'OWASP. Lui transmettre en plus les constats d'exposition de données personnelles repérés par `privacy` (réponse d'API trop large, page publique, journal applicatif, trace d'erreur), pour qualification en sévérité.

### 6. Ergonomie et langue — agent `ux-ui`

Lisibilité, contraste, taille de texte, messages d'erreur utiles, formulaires, navigation, mobile, accès aux documents légaux depuis le pied de page. Cohérence et correction du français sur les libellés, erreurs, notifications et e-mails — sans jamais modifier le sens d'un texte à portée juridique.

## Restitution

Par axe : constats classés en `CRITIQUE` / `ÉLEVÉ` / `MOYEN` / `FAIBLE` / `BON`, avec fichier:ligne et correction proposée. Puis deux listes séparées et explicites : **informations à fournir par le propriétaire** et **points à faire valider par un juriste**.

Conclusion imposée : « conformité technique améliorée, sous réserve de validation juridique des éléments signalés ».
