# SOLID

Cinq principes de conception orientée objet. À appliquer avec discernement — un principe qui complexifie une petite fonctionnalité sans bénéfice réel ne doit pas être forcé.

- **S — Single Responsibility** : une classe/module a une seule raison de changer. Si tu décris son rôle avec "et", c'est un signal de découpage.
- **O — Open/Closed** : ouvert à l'extension, fermé à la modification. Ajouter un comportement ne devrait pas nécessiter de modifier du code existant qui fonctionne (favoriser interfaces/stratégies plutôt que des `if/switch` qui grossissent indéfiniment).
- **L — Liskov Substitution** : une sous-classe doit pouvoir remplacer sa classe de base sans casser le comportement attendu par l'appelant (pas de pré-conditions renforcées, pas de post-conditions affaiblies).
- **I — Interface Segregation** : préférer plusieurs interfaces petites et spécifiques à une interface large que les clients n'utilisent que partiellement.
- **D — Dependency Inversion** : dépendre d'abstractions, pas d'implémentations concrètes. Les modules de haut niveau ne doivent pas dépendre des détails de bas niveau.

## Signaux qu'un principe est violé

- Classe de plusieurs centaines de lignes avec des méthodes non liées entre elles (SRP).
- Ajout de fonctionnalité = modification d'un fichier "central" à chaque fois (OCP).
- Code appelant qui doit tester le type concret avant d'appeler une méthode (LSP).
- Une classe implémente une interface mais lève des exceptions "non supporté" sur la moitié des méthodes (ISP).
- Un service instancie directement ses dépendances (`new`) au lieu de les recevoir en paramètre (DIP).

## Quand ne pas appliquer

Sur un script utilitaire, un prototype, ou une fonctionnalité qui ne changera probablement jamais, l'abstraction préventive ajoute de la complexité sans bénéfice (voir aussi [dry-kiss-yagni.md](dry-kiss-yagni.md)).
