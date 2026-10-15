# Intégrité, transactions et concurrence

## Invariants

**Tous les modèles**

- Chaque parent référencé existe : clé étrangère, jamais seulement une vérification dans le code.
- Aucun nœud n'est son propre ancêtre : pas de cycle.
- Une seule racine, ou un nombre de racines conforme au métier.
- Règle explicite pour la suppression d'un nœud qui a des enfants : interdite (`ON DELETE RESTRICT`), en cascade, ou enfants rattachés au grand-parent.

**Représentation intervallaire**

- Les bornes forment exactement l'ensemble 1 … 2n, sans doublon ni trou.
- `rgt - lft` est impair pour chaque nœud.
- Deux intervalles sont soit imbriqués, soit disjoints, jamais en chevauchement partiel.
- `depth` égale le nombre d'ancêtres.

## Requêtes d'audit

Chacune doit renvoyer **zéro ligne** (ou vrai). Toutes sont vérifiées par [verify_hierarchies.py](verify_hierarchies.py).

```sql
-- Parents inexistants (utile quand la clé étrangère manque)
SELECT c.id FROM category c LEFT JOIN category p ON p.id = c.parent_id
WHERE c.parent_id IS NOT NULL AND p.id IS NULL;

-- Nœuds pris dans un cycle (le garde-fou sur le chemin empêche une boucle infinie)
WITH RECURSIVE walk(start, cur, path) AS (
  SELECT id, parent_id, ',' || id || ',' FROM category WHERE parent_id IS NOT NULL
  UNION ALL
  SELECT w.start, c.parent_id, w.path || c.id || ','
  FROM walk w JOIN category c ON c.id = w.cur
  WHERE c.parent_id IS NOT NULL AND instr(w.path, ',' || c.id || ',') = 0
)
SELECT DISTINCT start FROM walk WHERE cur = start;
```

`instr` existe en SQLite et MySQL ; en PostgreSQL, utilise `strpos` ou la clause `CYCLE` (version 14 et plus), en SQL Server `CHARINDEX`. Cette requête ne liste que les membres du cycle ; un nœud qui *mène* à un cycle sans en faire partie n'est pas signalé.

```sql
-- Intervalles : bornes 1..2n complètes et sans doublon (vrai attendu)
SELECT (SELECT COUNT(*) FROM (SELECT lft AS b FROM nested UNION SELECT rgt FROM nested) t) = 2 * COUNT(*)
   AND MIN(lft) = 1 AND (SELECT MAX(rgt) FROM nested) = 2 * COUNT(*)
FROM nested;

-- Intervalles : largeur paire (anomalie)
SELECT id FROM nested WHERE (rgt - lft) % 2 = 0;

-- Intervalles : chevauchement partiel (anomalie)
SELECT a.id, b.id FROM nested a JOIN nested b ON a.lft < b.lft AND b.lft < a.rgt AND a.rgt < b.rgt;

-- Intervalles : profondeur incohérente (anomalie)
SELECT n.id FROM nested n
WHERE n.depth <> (SELECT COUNT(*) FROM nested a WHERE a.lft < n.lft AND a.rgt > n.rgt);
```

Lance ces audits dans les tests après chaque écriture, et périodiquement en production (tâche planifiée, agent `integrations`) si l'arbre est modifié par plusieurs chemins. Une anomalie se répare en **recalculant** le modèle dérivé (bornes, clôture, chemins) depuis la source de vérité `parent_id`, dans une transaction, après sauvegarde.

## Index UNIQUE sur les bornes : à éviter

Décaler des bornes (`SET rgt = rgt + 2 WHERE rgt >= :x`) crée temporairement des doublons. Selon le SGBD :

| SGBD | Vérification de l'unicité | Conséquence |
|---|---|---|
| SQLite, MySQL (InnoDB) | ligne par ligne | collision selon l'ordre de mise à jour : erreur aléatoire |
| PostgreSQL | ligne par ligne, sauf contrainte `DEFERRABLE INITIALLY DEFERRED` | erreur, sauf contrainte différée |
| SQL Server | en fin d'instruction | passe |

Recommandation : index simples sur `lft` et `rgt`, et les invariants ci-dessus en tests et en audit. En PostgreSQL, une contrainte `UNIQUE (lft) DEFERRABLE INITIALLY DEFERRED` est possible si l'équipe tient à la garantie en base. Le script de vérification reproduit la collision.

## Transactions et concurrence

- Chaque opération (insertion, suppression, déplacement) est **une transaction** : lecture des bornes ou du parent, vérifications, écritures. Une erreur annule tout.
- **Représentation intervallaire** : deux insertions simultanées lisent la même borne et corrompent l'arbre. Sérialise les écritures : verrou sur la ligne racine (`SELECT … FOR UPDATE`), verrou applicatif (`pg_advisory_xact_lock`, `GET_LOCK`, `sp_getapplock`) ou niveau `SERIALIZABLE` avec reprise automatique en cas de conflit.
- **Liste d'adjacence et table de clôture** : la vérification « pas de cycle » et le déplacement doivent se faire dans la même transaction, sinon deux déplacements croisés peuvent créer un cycle. Verrouille les lignes concernées ou utilise `SERIALIZABLE`.
- Les écritures sur un grand arbre en intervalles verrouillent beaucoup de lignes : regroupe les insertions massives (import) en reconstruisant les bornes une seule fois à la fin.
