# Workflow : Analyse d'architecture

1. **Détecter la stack** et cartographier les modules/dossiers principaux (skill `stack-detection`).
2. **Analyser** avec l'agent `architect` + skill `architecture-review` :
   - Découpage des responsabilités entre modules (voir [solid.md](../standards/solid.md))
   - Dépendances : y a-t-il des dépendances circulaires, ou une couche technique dont dépend directement le métier (voir [clean-architecture-hexagonale.md](../standards/clean-architecture-hexagonale.md)) ?
   - Points de couplage fort qui rendraient une évolution future coûteuse
   - Cohérence du modèle de données avec le domaine métier (voir [ddd-cqrs.md](../standards/ddd-cqrs.md) si pertinent)
3. **Identifier les risques d'évolutivité** : qu'est-ce qui deviendrait difficile si le projet doublait de taille ou d'équipe ?
4. **Restituer** sous forme de constats priorisés (impact × coût de correction), pas un inventaire exhaustif de tout ce qui pourrait théoriquement être amélioré.
5. **Documenter les décisions structurantes** issues de l'analyse via un ADR ([adr.md](../templates/adr.md)) si un changement d'architecture est décidé.

## Points d'attention

- Une architecture "parfaite" pour un besoin qui n'existe pas encore est une sur-ingénierie (voir [dry-kiss-yagni.md](../standards/dry-kiss-yagni.md)) — évaluer le coût réel des problèmes trouvés avant de recommander un changement structurant.
