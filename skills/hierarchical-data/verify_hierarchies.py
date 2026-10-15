"""Vérifie, sur SQLite, chaque requête des fiches du skill hierarchical-data.

Jeu d'essai : les familles de véhicules de l'article SQLPro (voir sources.md).
Usage : python verify_hierarchies.py  (bibliothèque standard seulement ; code 1 si un contrôle échoue)
"""
import sqlite3

db = sqlite3.connect(":memory:")
db.execute("PRAGMA foreign_keys = ON")
q = lambda sql, *a: db.execute(sql, a).fetchall()
names = lambda rows: sorted(r[0] for r in rows)
fails = 0


def check(what, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + what + ("" if ok else f"\n     got  {got}\n     want {want}"))


# ---------- 1. Liste d'adjacence ----------
db.executescript("""
CREATE TABLE category (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id INTEGER NULL REFERENCES category(id) ON DELETE RESTRICT,
  CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE INDEX category_parent_id ON category(parent_id);
""")
rows = [(0, 'Transport', None), (1, 'Terrestre', 0), (2, 'Marin', 0), (3, 'Aérien', 0), (4, 'Voiture', 1),
        (5, 'Camion', 1), (6, 'Moto', 1), (7, 'Vélo', 1), (8, 'Hélico', 3), (9, 'Avion', 3), (10, 'ULM', 3),
        (11, 'Fusée', 3), (12, 'Parachute', 3), (13, 'Planeur', 3), (14, 'Voilier', 2), (15, 'Paquebot', 2),
        (16, 'Planche à voile', 2), (17, 'Trail', 6), (18, 'Side-car', 6), (19, 'Civil', 9), (20, 'Tourisme', 9),
        (21, 'Militaire', 9)]
db.executemany("INSERT INTO category VALUES (?, ?, ?)", rows)

DESC = """
WITH RECURSIVE subtree(id, name, depth) AS (
  SELECT id, name, 0 FROM category WHERE id = ?
  UNION ALL
  SELECT c.id, c.name, s.depth + 1 FROM category c JOIN subtree s ON c.parent_id = s.id
)
SELECT name, depth FROM subtree WHERE depth > 0"""
check("adjacence : descendants de Terrestre", names(q(DESC, 1)), sorted(['Voiture', 'Camion', 'Moto', 'Vélo', 'Trail', 'Side-car']))

ANC = """
WITH RECURSIVE up(id, name, parent_id, depth) AS (
  SELECT id, name, parent_id, 0 FROM category WHERE id = ?
  UNION ALL
  SELECT c.id, c.name, c.parent_id, u.depth + 1 FROM category c JOIN up u ON c.id = u.parent_id
)
SELECT name FROM up WHERE depth > 0 ORDER BY depth DESC"""
check("adjacence : ancêtres de Trail, racine d'abord", [r[0] for r in q(ANC, 17)], ['Transport', 'Terrestre', 'Moto'])

LEAVES = "SELECT name FROM category p WHERE NOT EXISTS (SELECT 1 FROM category c WHERE c.parent_id = p.id)"
check("adjacence : 16 feuilles", len(q(LEAVES)), 16)

# Cycle : détecté par le chemin parcouru (garde-fou contre une boucle infinie).
CYCLE = """
WITH RECURSIVE walk(start, cur, path) AS (
  SELECT id, parent_id, ',' || id || ',' FROM category WHERE parent_id IS NOT NULL
  UNION ALL
  SELECT w.start, c.parent_id, w.path || c.id || ','
  FROM walk w JOIN category c ON c.id = w.cur
  WHERE c.parent_id IS NOT NULL AND instr(w.path, ',' || c.id || ',') = 0
)
SELECT DISTINCT start FROM walk WHERE cur = start"""
check("adjacence : aucun cycle", q(CYCLE), [])
db.execute("UPDATE category SET parent_id = 17 WHERE id = 6")  # Moto sous Trail, son propre enfant
check("adjacence : cycle Moto <-> Trail détecté", sorted(r[0] for r in q(CYCLE)), [6, 17])
db.execute("UPDATE category SET parent_id = 1 WHERE id = 6")

ORPHANS = """
SELECT c.id FROM category c LEFT JOIN category p ON p.id = c.parent_id
WHERE c.parent_id IS NOT NULL AND p.id IS NULL"""
check("adjacence : aucun parent inexistant", q(ORPHANS), [])
db.commit()  # le pragma ne change pas au milieu d'une transaction
db.execute("PRAGMA foreign_keys = OFF")
db.execute("INSERT INTO category VALUES (99, 'Orphelin', 98)")
check("adjacence : parent inexistant détecté", q(ORPHANS), [(99,)])
db.execute("DELETE FROM category WHERE id = 99")
db.commit()
db.execute("PRAGMA foreign_keys = ON")

# Déplacement interdit sous un descendant : la cible ne doit pas faire partie du sous-arbre.
MOVE_OK = """
WITH RECURSIVE subtree(id) AS (
  SELECT id FROM category WHERE id = :node
  UNION ALL
  SELECT c.id FROM category c JOIN subtree s ON c.parent_id = s.id
)
SELECT NOT EXISTS (SELECT 1 FROM subtree WHERE id = :target)"""
check("adjacence : déplacer Terrestre sous Moto refusé", db.execute(MOVE_OK, {"node": 1, "target": 6}).fetchone()[0], 0)
check("adjacence : déplacer Moto sous Marin permis", db.execute(MOVE_OK, {"node": 6, "target": 2}).fetchone()[0], 1)

# ---------- 2. Représentation intervallaire (nested set) ----------
db.executescript("""
CREATE TABLE nested (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  lft INTEGER NOT NULL,
  rgt INTEGER NOT NULL,
  depth INTEGER NOT NULL,
  CHECK (lft >= 1 AND rgt > lft)
);
CREATE INDEX nested_lft ON nested(lft);
CREATE INDEX nested_rgt ON nested(rgt);
""")

# Construction depuis la liste d'adjacence : parcours en profondeur (ici dans le langage hôte).
children = {}
for i, n, p in rows:
    children.setdefault(p, []).append(i)
order = {0: ['Aérien', 'Terrestre', 'Marin']}  # ordre de l'article, pour retrouver ses bornes
byname = {n: i for i, n, p in rows}
article_order = {
    'Transport': ['Aérien', 'Terrestre', 'Marin'],
    'Aérien': ['Planeur', 'Parachute', 'Hélico', 'Fusée', 'ULM', 'Avion'],
    'Avion': ['Militaire', 'Tourisme', 'Civil'],
    'Terrestre': ['Vélo', 'Voiture', 'Camion', 'Moto'],
    'Moto': ['Side-car', 'Trail'],
    'Marin': ['Planche à voile', 'Paquebot', 'Voilier'],
}
name_of = {i: n for i, n, p in rows}
counter = 0


def build(node, depth):
    global counter
    counter += 1
    lft = counter
    for child in article_order.get(name_of[node], []):
        build(byname[child], depth + 1)
    counter += 1
    db.execute("INSERT INTO nested VALUES (?, ?, ?, ?, ?)", (node, name_of[node], lft, counter, depth))


build(0, 0)
check("intervalles : bornes de l'article (Terrestre 22-35, Moto 29-34)",
      q("SELECT name, lft, rgt FROM nested WHERE name IN ('Terrestre', 'Moto') ORDER BY lft"),
      [('Terrestre', 22, 35), ('Moto', 29, 34)])

check("intervalles : feuilles (rgt = lft + 1)", len(q("SELECT 1 FROM nested WHERE rgt = lft + 1")), 16)
check("intervalles : nœuds internes", len(q("SELECT 1 FROM nested WHERE rgt > lft + 1")), 6)

SUB = """
SELECT c.name FROM nested p JOIN nested c ON c.lft > p.lft AND c.rgt < p.rgt
WHERE p.id = ? ORDER BY c.lft"""
check("intervalles : descendants stricts de Terrestre", [r[0] for r in q(SUB, 1)],
      ['Vélo', 'Voiture', 'Camion', 'Moto', 'Side-car', 'Trail'])

ANCN = """
SELECT a.name FROM nested n JOIN nested a ON a.lft < n.lft AND a.rgt > n.rgt
WHERE n.id = ? ORDER BY a.lft"""
check("intervalles : ancêtres de Moto (l'article affiche à tort 3-46 et 24-37)", [r[0] for r in q(ANCN, 6)],
      ['Transport', 'Terrestre'])

check("intervalles : nombre de descendants = (rgt - lft - 1) / 2",
      q("SELECT (rgt - lft - 1) / 2 FROM nested WHERE id = 1"), [(6,)])
check("intervalles : enfants directs de Terrestre (depth = parent + 1)",
      [r[0] for r in q("""SELECT c.name FROM nested p JOIN nested c ON c.lft > p.lft AND c.rgt < p.rgt
                           AND c.depth = p.depth + 1 WHERE p.id = 1 ORDER BY c.lft""")],
      ['Vélo', 'Voiture', 'Camion', 'Moto'])
check("intervalles : feuilles sous Terrestre au niveau 2 (exemple de l'article)",
      [r[0] for r in q("""SELECT name FROM nested WHERE rgt = lft + 1 AND lft > 22 AND rgt < 35 AND depth = 2
                           ORDER BY lft""")], ['Vélo', 'Voiture', 'Camion'])

INVARIANTS = {
    "bornes 1..2n toutes présentes, sans doublon": """
        SELECT (SELECT COUNT(*) FROM (SELECT lft AS b FROM nested UNION SELECT rgt FROM nested)) = 2 * COUNT(*)
           AND MIN(lft) = 1 AND (SELECT MAX(rgt) FROM nested) = 2 * COUNT(*) FROM nested""",
    "largeur impaire (rgt - lft)": "SELECT COUNT(*) = 0 FROM nested WHERE (rgt - lft) % 2 = 0",
    "aucun chevauchement partiel": """
        SELECT COUNT(*) = 0 FROM nested a JOIN nested b
          ON a.lft < b.lft AND b.lft < a.rgt AND a.rgt < b.rgt""",
    "profondeur = nombre d'ancêtres": """
        SELECT COUNT(*) = 0 FROM nested n
        WHERE n.depth <> (SELECT COUNT(*) FROM nested a WHERE a.lft < n.lft AND a.rgt > n.rgt)""",
}


def invariants(label):
    for what, sql in INVARIANTS.items():
        check(f"invariants {label} : {what}", q(sql)[0][0], 1)


invariants("initiaux")


def insert_last_child(parent_id, node_id, name):
    """Insère en dernier enfant : un seul UPDATE décale les deux bornes, dans une transaction."""
    with db:  # transaction : tout ou rien
        prgt, pdepth = db.execute("SELECT rgt, depth FROM nested WHERE id = ?", (parent_id,)).fetchone()
        db.execute("""UPDATE nested SET
                        lft = CASE WHEN lft >= :x THEN lft + 2 ELSE lft END,
                        rgt = CASE WHEN rgt >= :x THEN rgt + 2 ELSE rgt END
                      WHERE rgt >= :x""", {"x": prgt})
        db.execute("INSERT INTO nested VALUES (?, ?, ?, ?, ?)", (node_id, name, prgt, prgt + 1, pdepth + 1))


insert_last_child(1, 22, 'Roller')
check("insertion : Roller en dernier enfant de Terrestre (35-36)", q("SELECT lft, rgt FROM nested WHERE id = 22"), [(35, 36)])
check("insertion : Terrestre grossit (22-37)", q("SELECT lft, rgt FROM nested WHERE id = 1"), [(22, 37)])
invariants("après insertion")


def delete_subtree(node_id):
    """Supprime le nœud et tout son sous-arbre, puis referme le trou."""
    with db:
        lft, rgt = db.execute("SELECT lft, rgt FROM nested WHERE id = ?", (node_id,)).fetchone()
        width = rgt - lft + 1
        db.execute("DELETE FROM nested WHERE lft BETWEEN ? AND ?", (lft, rgt))
        db.execute("""UPDATE nested SET
                        lft = CASE WHEN lft > :r THEN lft - :w ELSE lft END,
                        rgt = CASE WHEN rgt > :r THEN rgt - :w ELSE rgt END
                      WHERE rgt > :r""", {"r": rgt, "w": width})


delete_subtree(10)  # ULM, une feuille
invariants("après suppression d'une feuille")
delete_subtree(6)   # Moto et ses deux enfants
check("suppression : Moto, Trail, Side-car retirés", q("SELECT COUNT(*) FROM nested WHERE id IN (6, 17, 18)"), [(0,)])
invariants("après suppression d'un sous-arbre")


def move_subtree(node_id, new_parent_id):
    """Déplace un sous-arbre en dernier enfant d'un autre nœud (hors de son propre sous-arbre)."""
    with db:
        lft, rgt, depth = db.execute("SELECT lft, rgt, depth FROM nested WHERE id = ?", (node_id,)).fetchone()
        plft, prgt, pdepth = db.execute("SELECT lft, rgt, depth FROM nested WHERE id = ?", (new_parent_id,)).fetchone()
        if lft <= plft <= rgt:
            raise ValueError("la cible est dans le sous-arbre déplacé")
        width = rgt - lft + 1
        # Un seul UPDATE, calculé sur les anciennes valeurs : aucune contrainte violée en cours de route.
        # MySQL évalue SET de gauche à droite avec les valeurs déjà modifiées : depth (qui lit lft)
        # vient donc avant lft, et chaque borne ne lit qu'elle-même.
        if prgt > rgt:   # vers la droite : le sous-arbre avance, ce qui est entre recule
            lo, hi, d_sub, d_mid = rgt + 1, prgt - 1, prgt - rgt - 1, -width
        else:            # vers la gauche : le sous-arbre recule, ce qui est entre avance
            lo, hi, d_sub, d_mid = prgt, lft - 1, prgt - lft, width
        db.execute("""UPDATE nested SET
                        depth = CASE WHEN lft BETWEEN :l AND :r THEN depth + :dd ELSE depth END,
                        lft = CASE WHEN lft BETWEEN :l AND :r THEN lft + :ds
                                   WHEN lft BETWEEN :lo AND :hi THEN lft + :dm ELSE lft END,
                        rgt = CASE WHEN rgt BETWEEN :l AND :r THEN rgt + :ds
                                   WHEN rgt BETWEEN :lo AND :hi THEN rgt + :dm ELSE rgt END
                      WHERE lft BETWEEN :mn AND :mx OR rgt BETWEEN :mn AND :mx""",
                   {"l": lft, "r": rgt, "lo": lo, "hi": hi, "ds": d_sub, "dm": d_mid,
                    "dd": pdepth + 1 - depth, "mn": min(lft, lo), "mx": max(rgt, hi)})


move_subtree(9, 2)  # Avion (et ses 3 enfants) vers la droite, sous Marin
check("déplacement à droite : ancêtres de Militaire = Transport, Marin, Avion", [r[0] for r in q(ANCN, 21)],
      ['Transport', 'Marin', 'Avion'])
invariants("après déplacement à droite")
move_subtree(2, 3)  # Marin (avec Avion) vers la gauche, sous Aérien
check("déplacement à gauche : ancêtres de Militaire = Transport, Aérien, Marin, Avion",
      [r[0] for r in q(ANCN, 21)], ['Transport', 'Aérien', 'Marin', 'Avion'])
invariants("après déplacement à gauche")
try:
    move_subtree(2, 9)
    check("déplacement sous son propre descendant refusé", "accepté", "refusé")
except ValueError:
    check("déplacement sous son propre descendant refusé", "refusé", "refusé")

# Preuve : un index UNIQUE sur une borne casse le décalage (unicité vérifiée ligne par ligne).
db.executescript("""CREATE TABLE u (b INTEGER); CREATE UNIQUE INDEX u_b ON u(b);
                     INSERT INTO u VALUES (1), (2), (3);""")
try:
    db.execute("UPDATE u SET b = b - 1 WHERE b > 1")
    db.execute("UPDATE u SET b = b + 1 WHERE b >= 1")
    check("index UNIQUE sur une borne : collision pendant le décalage", "aucune", "collision")
except sqlite3.IntegrityError:
    check("index UNIQUE sur une borne : collision pendant le décalage", "collision", "collision")

# ---------- 3. Table de clôture ----------
db.executescript("""
CREATE TABLE node (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE node_closure (
  ancestor_id INTEGER NOT NULL REFERENCES node(id) ON DELETE CASCADE,
  descendant_id INTEGER NOT NULL REFERENCES node(id) ON DELETE CASCADE,
  depth INTEGER NOT NULL CHECK (depth >= 0),
  PRIMARY KEY (ancestor_id, descendant_id)
);
CREATE INDEX node_closure_descendant ON node_closure(descendant_id, ancestor_id);
""")


def closure_insert(node_id, name, parent_id):
    with db:
        db.execute("INSERT INTO node VALUES (?, ?)", (node_id, name))
        db.execute("""INSERT INTO node_closure (ancestor_id, descendant_id, depth)
                      SELECT ancestor_id, :n, depth + 1 FROM node_closure WHERE descendant_id = :p
                      UNION ALL SELECT :n, :n, 0""", {"n": node_id, "p": parent_id})


for i, n, p in rows:  # les parents précèdent leurs enfants dans `rows`
    closure_insert(i, n, p)
check("clôture : descendants de Terrestre",
      names(q("""SELECT n.name FROM node_closure c JOIN node n ON n.id = c.descendant_id
                 WHERE c.ancestor_id = 1 AND c.depth > 0""")),
      sorted(['Voiture', 'Camion', 'Moto', 'Vélo', 'Trail', 'Side-car']))
check("clôture : ancêtres de Trail, racine d'abord",
      [r[0] for r in q("""SELECT n.name FROM node_closure c JOIN node n ON n.id = c.ancestor_id
                         WHERE c.descendant_id = 17 AND c.depth > 0 ORDER BY c.depth DESC""")],
      ['Transport', 'Terrestre', 'Moto'])


def closure_move(node_id, new_parent_id):
    with db:
        if db.execute("SELECT 1 FROM node_closure WHERE ancestor_id = ? AND descendant_id = ?",
                      (node_id, new_parent_id)).fetchone():
            raise ValueError("cycle")
        # Couper les liens entre le sous-arbre et ses anciens ancêtres extérieurs.
        db.execute("""DELETE FROM node_closure
                      WHERE descendant_id IN (SELECT descendant_id FROM node_closure WHERE ancestor_id = :n)
                        AND ancestor_id NOT IN (SELECT descendant_id FROM node_closure WHERE ancestor_id = :n)""",
                   {"n": node_id})
        # Relier chaque ancêtre du nouveau parent à chaque nœud du sous-arbre.
        db.execute("""INSERT INTO node_closure (ancestor_id, descendant_id, depth)
                      SELECT a.ancestor_id, s.descendant_id, a.depth + s.depth + 1
                      FROM node_closure a CROSS JOIN node_closure s
                      WHERE a.descendant_id = :p AND s.ancestor_id = :n""", {"n": node_id, "p": new_parent_id})


closure_move(6, 2)  # Moto sous Marin
check("clôture : après déplacement, ancêtres de Trail = Transport, Marin, Moto",
      [r[0] for r in q("""SELECT n.name FROM node_closure c JOIN node n ON n.id = c.ancestor_id
                         WHERE c.descendant_id = 17 AND c.depth > 0 ORDER BY c.depth DESC""")],
      ['Transport', 'Marin', 'Moto'])
try:
    closure_move(2, 17)
    check("clôture : déplacement créant un cycle refusé", "accepté", "refusé")
except ValueError:
    check("clôture : déplacement créant un cycle refusé", "refusé", "refusé")

# ---------- 4. Chemin matérialisé ----------
db.executescript("CREATE TABLE pathed (id INTEGER PRIMARY KEY, name TEXT NOT NULL, path TEXT NOT NULL UNIQUE)")
paths = {}
for i, n, p in rows:
    paths[i] = (paths[p] if p is not None else "/") + f"{i}/"
    db.execute("INSERT INTO pathed VALUES (?, ?, ?)", (i, n, paths[i]))
db.execute("CREATE INDEX pathed_path ON pathed(path)")
check("chemin : descendants de Terrestre (préfixe /0/1/)",
      names(q("SELECT name FROM pathed WHERE path LIKE (SELECT path FROM pathed WHERE id = 1) || '_%'")),
      sorted(['Voiture', 'Camion', 'Moto', 'Vélo', 'Trail', 'Side-car']))
# Le séparateur final évite qu'un nœud 1 capture le nœud 10 (/0/1/ n'est pas préfixe de /0/10/).
check("chemin : /0/1/ n'attrape pas /0/10/", q("SELECT COUNT(*) FROM pathed WHERE '/0/10/' LIKE '/0/1/' || '%'"), [(0,)])
with db:  # déplacer Moto (et ses enfants) sous Marin : un seul UPDATE réécrit les préfixes
    old, new = paths[6], paths[2] + "6/"
    db.execute("UPDATE pathed SET path = :new || substr(path, length(:old) + 1) WHERE path LIKE :old || '%'",
               {"old": old, "new": new})
check("chemin : Trail déplacé avec Moto", q("SELECT path FROM pathed WHERE id = 17"), [("/0/2/6/17/",)])

print()
print("Tous les contrôles sont passés." if not fails else f"{fails} contrôle(s) en échec.")
raise SystemExit(1 if fails else 0)
