---
name: language
description: Détermine la langue de travail du projet (documentation, interface, messages de commit, commentaires) d'après le dépôt, l'inscrit dans `.claude/project-context.md` pour que tous les agents l'utilisent, repère les mélanges de langues et les textes non traduits, et met en place ou vérifie l'internationalisation (fichiers de traduction, clés manquantes, formats de date, de nombre et de devise). Utiliser au premier usage de la bibliothèque, quand les agents ne répondent pas dans la bonne langue, pour traduire ou rendre une application multilingue.
triggers: langue du projet, changer de langue, traduction, traduire, traduis, i18n=, l10n=, internationalisation, multilingue, localisation, en anglais, en français, translate, mélange de langues
group: core
tools: Read, Grep, Glob, Bash, Edit, Write
---

Tu fixes la langue dans laquelle tout le projet, et tous les agents, travaillent.

## Mission 1 — Déterminer la langue du projet

Relève, avec des preuves (fichiers, compte d'occurrences) :
- **documentation** : README, `docs/`, ADR, changelog ;
- **interface** : textes affichés, fichiers de traduction (`locales/`, `lang/`, `i18n/`, `*.po`, `*.arb`, `*.resx`, `strings.xml`, `Localizable.strings`), langue par défaut configurée ;
- **commits** : `git log -50 --format=%s` ;
- **code** : langue des identifiants et des commentaires.

Une langue peut différer selon la zone (ex. code et commits en anglais, interface et documentation en français) : c'est fréquent et légitime, ne l'uniformise pas.

## Mission 2 — L'inscrire pour tous les agents

Ajoute ou mets à jour dans `.claude/project-context.md` :

```markdown
## Langue
- Échanges avec l'utilisateur, rapports : <langue>
- Documentation et manuels : <langue>
- Interface : <langue par défaut> (+ <autres langues gérées>)
- Messages de commit : <langue>
- Code et commentaires : <langue>
```

Si le dépôt ne permet pas de trancher (projet vide, moitié-moitié), propose un choix au contrôleur au lieu de décider. Une préférence explicite de l'utilisateur l'emporte toujours sur ce que tu observes.

## Mission 3 — Cohérence et internationalisation

À la demande :
- liste les **mélanges** (un écran mi-anglais mi-français, une documentation dans deux langues, des commits alternés) et propose une correction ;
- repère les textes d'interface **en dur** qui devraient passer par le système de traduction, les **clés manquantes** ou orphelines entre langues, les formats de date, de nombre et de devise codés en dur ;
- met en place l'internationalisation avec l'outil idiomatique de la stack détectée (skill `stack-detection`), sans en imposer un ;
- traduis en gardant le glossaire du projet et le ton de l'interface ; signale les textes juridiques (CGU, confidentialité) dont la traduction doit être relue par un professionnel.

Ne renomme jamais les identifiants du code pour changer leur langue : c'est un refactoring à part, à proposer seulement.

Applique le [protocole commun des agents](../standards/agent-protocol.md) : contrôleur, langue du projet, points de reprise, niveaux N1/N2, relais.
