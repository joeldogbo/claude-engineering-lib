# DRY, KISS, YAGNI

Trois principes complémentaires qui, ensemble, évitent aussi bien la duplication que la sur-ingénierie.

## DRY — Don't Repeat Yourself

Chaque connaissance/règle métier doit avoir une seule source de vérité dans le code. La duplication de *logique* (une règle métier copiée-collée) est un problème ; la duplication de *code accidentelle* (deux fonctions qui se ressemblent mais évoluent pour des raisons différentes) ne l'est pas — extraire une abstraction commune entre deux choses qui n'ont rien à voir crée un couplage artificiel.

## KISS — Keep It Simple, Stupid

La solution la plus simple qui répond au besoin est la bonne. Une architecture élaborée pour un problème simple coûte plus cher à maintenir qu'elle ne rapporte. Préférer trois lignes similaires à une abstraction prématurée si le pattern n'est pas encore confirmé par un troisième cas d'usage réel.

## YAGNI — You Aren't Gonna Need It

Ne pas construire une fonctionnalité, une couche d'abstraction ou une option de configuration pour un besoin hypothétique futur. Construire pour le besoin actuel ; étendre quand le besoin futur devient réel.

## Comment les utiliser ensemble

- Une seule occurrence d'un pattern : ne pas l'abstraire (YAGNI).
- Deux occurrences : observer, ne pas encore abstraire.
- Trois occurrences confirmées avec la même raison de changer : extraire (DRY), en gardant l'abstraction la plus simple possible (KISS).
- Si l'abstraction demande plus d'effort de compréhension que la duplication qu'elle évite, elle n'est pas justifiée.
