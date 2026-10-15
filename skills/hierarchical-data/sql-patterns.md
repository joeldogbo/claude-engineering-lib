# Requêtes vérifiées

Toutes les requêtes ci-dessous sont exécutées par [verify_hierarchies.py](verify_hierarchies.py) sur SQLite, avec le jeu d'essai de l'article de référence (familles de véhicules). La syntaxe est standard sauf mention contraire. Les paramètres sont nommés (`:node`) : utilise le mécanisme de requêtes préparées du projet, jamais la concaténation.

## 1. Liste d'adjacence

```sql
CREATE TABLE category (
  id        BIGINT PRIMARY KEY,
  name      VARCHAR(150) NOT NULL,
  parent_id BIGINT NULL REFERENCES category(id) ON DELETE RESTRICT,
  CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE INDEX category_parent_id ON category(parent_id);
```

**Descendants** (avec leur profondeur relative) :

```sql
WITH RECURSIVE subtree(id, name, depth) AS (
  SELECT id, name, 0 FROM category WHERE id = :node
  UNION ALL
  SELECT c.id, c.name, s.depth + 1 FROM category c JOIN subtree s ON c.parent_id = s.id
)
SELECT name, depth FROM subtree WHERE depth > 0;
```

**Ancêtres**, racine d'abord :

```sql
WITH RECURSIVE up(id, name, parent_id, depth) AS (
  SELECT id, name, parent_id, 0 FROM category WHERE id = :node
  UNION ALL
  SELECT c.id, c.name, c.parent_id, u.depth + 1 FROM category c JOIN up u ON c.id = u.parent_id
)
SELECT name FROM up WHERE depth > 0 ORDER BY depth DESC;
```

**Feuilles** :

```sql
SELECT name FROM category p
WHERE NOT EXISTS (SELECT 1 FROM category c WHERE c.parent_id = p.id);
```

**Déplacement autorisé ?** La cible ne doit pas appartenir au sous-arbre déplacé, sinon on crée un cycle :

```sql
WITH RECURSIVE subtree(id) AS (
  SELECT id FROM category WHERE id = :node
  UNION ALL
  SELECT c.id FROM category c JOIN subtree s ON c.parent_id = s.id
)
SELECT NOT EXISTS (SELECT 1 FROM subtree WHERE id = :target);
```

Puis `UPDATE category SET parent_id = :target WHERE id = :node`, dans la même transaction que la vérification. La détection des cycles déjà présents est dans [integrity.md](integrity.md).

SQL Server : `WITH` sans `RECURSIVE`, et `+` pour concaténer. MySQL : `WITH RECURSIVE` à partir de la version 8.0.

## 2. Représentation intervallaire (*nested set*)

```sql
CREATE TABLE nested (
  id    BIGINT PRIMARY KEY,
  name  VARCHAR(150) NOT NULL,
  lft   INT NOT NULL,
  rgt   INT NOT NULL,
  depth INT NOT NULL,
  CHECK (lft >= 1 AND rgt > lft)
);
CREATE INDEX nested_lft ON nested(lft);   -- index simples, pas UNIQUE : voir integrity.md
CREATE INDEX nested_rgt ON nested(rgt);
```

Numérotation : parcours en profondeur, un numéro en entrant dans un nœud (`lft`), un en sortant (`rgt`). Les bornes vont de 1 à 2 × n ; on les **calcule**, on ne les saisit jamais à la main.

| Besoin | Condition |
|---|---|
| feuilles | `rgt = lft + 1` |
| nœuds internes | `rgt > lft + 1` |
| nombre de descendants | `(rgt - lft - 1) / 2` |
| descendants stricts de P | `c.lft > p.lft AND c.rgt < p.rgt` |
| sous-arbre de P, P compris | `c.lft >= p.lft AND c.rgt <= p.rgt` |
| ancêtres de N | `a.lft < n.lft AND a.rgt > n.rgt` |
| enfants directs de P | descendants stricts `AND c.depth = p.depth + 1` |
| hors du sous-arbre de P | `c.lft < p.lft OR c.rgt > p.rgt` |

```sql
-- Descendants stricts, dans l'ordre de l'arbre
SELECT c.name FROM nested p JOIN nested c ON c.lft > p.lft AND c.rgt < p.rgt
WHERE p.id = :node ORDER BY c.lft;
```

**Insérer en dernier enfant** de P, dans une transaction. `:x` est le `rgt` de P, relu dans cette transaction :

```sql
UPDATE nested SET
  lft = CASE WHEN lft >= :x THEN lft + 2 ELSE lft END,
  rgt = CASE WHEN rgt >= :x THEN rgt + 2 ELSE rgt END
WHERE rgt >= :x;
INSERT INTO nested (id, name, lft, rgt, depth) VALUES (:id, :name, :x, :x + 1, :parent_depth + 1);
```

**Supprimer un sous-arbre** (une feuille est un sous-arbre de largeur 2) et refermer le trou. `:l`, `:r` sont les bornes du nœud, `:w = :r - :l + 1` :

```sql
DELETE FROM nested WHERE lft BETWEEN :l AND :r;
UPDATE nested SET
  lft = CASE WHEN lft > :r THEN lft - :w ELSE lft END,
  rgt = CASE WHEN rgt > :r THEN rgt - :w ELSE rgt END
WHERE rgt > :r;
```

**Déplacer un sous-arbre** [`:l`, `:r`] en dernier enfant d'un nœud de borne droite `:p` (hors du sous-arbre) : un seul `UPDATE`, calculé sur les anciennes valeurs.

- Vers la droite (`:p > :r`) : `lo = :r + 1`, `hi = :p - 1`, décalage du sous-arbre `ds = :p - :r - 1`, du reste `dm = -(:r - :l + 1)`.
- Vers la gauche (`:p < :l`) : `lo = :p`, `hi = :l - 1`, `ds = :p - :l`, `dm = :r - :l + 1`.

```sql
UPDATE nested SET
  depth = CASE WHEN lft BETWEEN :l AND :r THEN depth + :dd ELSE depth END,
  lft   = CASE WHEN lft BETWEEN :l AND :r THEN lft + :ds
               WHEN lft BETWEEN :lo AND :hi THEN lft + :dm ELSE lft END,
  rgt   = CASE WHEN rgt BETWEEN :l AND :r THEN rgt + :ds
               WHEN rgt BETWEEN :lo AND :hi THEN rgt + :dm ELSE rgt END
WHERE lft BETWEEN :mn AND :mx OR rgt BETWEEN :mn AND :mx;
-- :dd = profondeur du nouveau parent + 1 - profondeur du nœud ; :mn = min(:l, :lo) ; :mx = max(:r, :hi)
```

MySQL évalue les affectations de `SET` de gauche à droite avec les valeurs déjà modifiées : garde cet ordre (`depth`, qui lit `lft`, avant `lft`), et fais lire à chaque borne sa propre valeur seulement.

L'ancienne technique « passer le sous-arbre en bornes négatives » viole une contrainte `CHECK (lft >= 1)` : préfère l'`UPDATE` unique ci-dessus.

## 3. Table de clôture

```sql
CREATE TABLE node (id BIGINT PRIMARY KEY, name VARCHAR(150) NOT NULL);
CREATE TABLE node_closure (
  ancestor_id   BIGINT NOT NULL REFERENCES node(id) ON DELETE CASCADE,
  descendant_id BIGINT NOT NULL REFERENCES node(id) ON DELETE CASCADE,
  depth         INT NOT NULL CHECK (depth >= 0),
  PRIMARY KEY (ancestor_id, descendant_id)
);
CREATE INDEX node_closure_descendant ON node_closure(descendant_id, ancestor_id);
```

Chaque nœud a une ligne vers lui-même (`depth = 0`).

```sql
-- Insérer :n sous :p
INSERT INTO node (id, name) VALUES (:n, :name);
INSERT INTO node_closure (ancestor_id, descendant_id, depth)
SELECT ancestor_id, :n, depth + 1 FROM node_closure WHERE descendant_id = :p
UNION ALL SELECT :n, :n, 0;

-- Descendants de :n
SELECT descendant_id FROM node_closure WHERE ancestor_id = :n AND depth > 0;
-- Ancêtres de :n, racine d'abord
SELECT ancestor_id FROM node_closure WHERE descendant_id = :n AND depth > 0 ORDER BY depth DESC;
```

**Déplacer** le sous-arbre de `:n` sous `:p`. D'abord refuser si `:p` est un descendant de `:n` (`SELECT 1 FROM node_closure WHERE ancestor_id = :n AND descendant_id = :p`), puis :

```sql
DELETE FROM node_closure
WHERE descendant_id IN (SELECT descendant_id FROM node_closure WHERE ancestor_id = :n)
  AND ancestor_id NOT IN (SELECT descendant_id FROM node_closure WHERE ancestor_id = :n);
INSERT INTO node_closure (ancestor_id, descendant_id, depth)
SELECT a.ancestor_id, s.descendant_id, a.depth + s.depth + 1
FROM node_closure a CROSS JOIN node_closure s
WHERE a.descendant_id = :p AND s.ancestor_id = :n;
```

MySQL refuse une sous-requête sur la table modifiée par un `DELETE` : passe par une table dérivée (`SELECT … FROM (SELECT …) AS t`) ou une table temporaire.

## 4. Chemin matérialisé

```sql
CREATE TABLE pathed (id BIGINT PRIMARY KEY, name VARCHAR(150) NOT NULL, path VARCHAR(1000) NOT NULL UNIQUE);
CREATE INDEX pathed_path ON pathed(path);
-- path = '/0/1/6/' : chaque identifiant suivi du séparateur, y compris le dernier
```

```sql
-- Descendants de :n
SELECT name FROM pathed WHERE path LIKE (SELECT path FROM pathed WHERE id = :n) || '_%';
-- Déplacer :n et son sous-arbre : réécrire le préfixe
UPDATE pathed SET path = :new_prefix || substr(path, length(:old_prefix) + 1) WHERE path LIKE :old_prefix || '%';
```

Le séparateur final est indispensable : sans lui, `/0/1` serait préfixe de `/0/10`. Concaténation : `||` en standard, `CONCAT()` en MySQL, `+` en SQL Server. Pour que `LIKE 'préfixe%'` utilise l'index : classement binaire ou `text_pattern_ops` en PostgreSQL, ou le type `ltree`.
