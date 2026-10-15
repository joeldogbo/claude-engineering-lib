# Cas de test

À écrire avec le framework de test du projet (agent `testing`), sur une vraie base du même SGBD que la production (ou un conteneur), pas sur une base en mémoire d'un autre moteur. Utilise un petit arbre connu, par exemple celui de [verify_hierarchies.py](verify_hierarchies.py) : 22 nœuds, 3 niveaux sous la racine, 16 feuilles.

## Lecture

- [ ] La racine est trouvée ; elle n'a pas d'ancêtre.
- [ ] Les feuilles sont exactement celles attendues (16 dans le jeu d'essai).
- [ ] Les descendants d'un nœud interne sont complets, sans le nœud lui-même, puis avec quand c'est demandé.
- [ ] Les ancêtres d'une feuille profonde sortent dans l'ordre, racine d'abord.
- [ ] Les enfants directs ne contiennent pas les petits-enfants.
- [ ] Un nœud inexistant renvoie un résultat vide, pas une erreur.

## Écriture

- [ ] Insertion d'une feuille : le parent et tous les ancêtres l'englobent ; les invariants restent vrais.
- [ ] Insertion sous la racine et sous une feuille (qui devient nœud interne).
- [ ] Suppression d'une feuille, puis d'un sous-arbre entier : plus aucune trace, aucun trou (intervalles), aucune ligne orpheline (clôture).
- [ ] Suppression d'un nœud qui a des enfants : comportement conforme à la règle choisie (refus, cascade ou rattachement).
- [ ] Déplacement d'un sous-arbre vers la droite **et** vers la gauche (intervalles) : ancêtres, profondeurs et invariants corrects.
- [ ] Déplacement sous son propre descendant : **refusé**, base inchangée.
- [ ] Un nœud ne peut pas être son propre parent (contrainte `CHECK`).

## Intégrité et robustesse

- [ ] Après chaque écriture, les requêtes d'audit de [integrity.md](integrity.md) renvoient zéro anomalie.
- [ ] Une erreur au milieu d'une opération (simulée) annule tout : la transaction est bien utilisée.
- [ ] Deux insertions concurrentes sous le même parent : les deux réussissent ou l'une est rejouée, jamais d'arbre corrompu.
- [ ] Un cycle introduit directement en base (données héritées) est détecté par l'audit, sans boucle infinie.

## Performance

- [ ] Lecture d'un sous-arbre et des ancêtres sur un volume représentatif (au moins le volume de production prévu à un an) : temps et plan d'exécution relevés, index utilisés.
- [ ] Coût d'une insertion et d'un déplacement sur ce volume, surtout en représentation intervallaire.
