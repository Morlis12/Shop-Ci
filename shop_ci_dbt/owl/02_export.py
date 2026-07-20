"""
owl/02_export.py — EXPORT DES DONNEES SHOP_CI
Peuple le graphe avec les INDIVIDUS reels : un noeud par client, par produit,
par ligne de vente, avec leurs attributs (DatatypeProperty) et leurs liens
(ObjectProperty aPourClient/aPourProduit). Aucun label metier ici : la
classification est deduite ensuite (fichier 03_classify.py).
Source : DuckDB en LECTURE SEULE (mono-ecrivain -> jamais en collision
avec le pipeline dbt planifie).
"""
import duckdb, os
from rdflib import Graph, Namespace, RDF, XSD, Literal

SHOP = Namespace("http://shop-ci.ci/ontologie#")
DB_PATH = r"C:\Users\Laptop Studio\Documents\Shop Ci\shop_ci_dbt\dev.duckdb"  # ton chemin

con = duckdb.connect(DB_PATH, read_only=True)

g = Graph()
g.bind("shop", SHOP)

# ---- CLIENTS ----
clients = con.execute("""
    SELECT id_client, nom_complet , nb_commandes, ca_total, jours_inactivite, anciennete_jours
    FROM mart_decision_clients
""").fetchall()
ccols = [d[0] for d in con.description]

for row in clients:
    d = dict(zip(ccols, row))
    uri = SHOP[f"client_{d['id_client']}"]
    g.add((uri, RDF.type, SHOP.Client))
    g.add((uri, SHOP.aIdClient, Literal(int(d["id_client"]), datatype=XSD.integer)))
    g.add((uri, SHOP.aCaTotal, Literal(float(d["ca_total"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aNbCommandes, Literal(int(d["nb_commandes"]), datatype=XSD.integer)))
    g.add((uri, SHOP.aNomClient, Literal(str(d["nom_complet"]), datatype=XSD.string)))
    # NULL (membre -1) -> on N'AJOUTE PAS le triplet, plutot qu'une valeur factice
    if d["jours_inactivite"] is not None:
        g.add((uri, SHOP.aJoursInactivite, Literal(int(d["jours_inactivite"]), datatype=XSD.integer)))
    if d["anciennete_jours"] is not None:
        g.add((uri, SHOP.aAncienneteJours, Literal(int(d["anciennete_jours"]), datatype=XSD.integer)))

# ---- PRODUITS ----
produits = con.execute("""
    SELECT id_produit, nom_produit, ca_total, taux_marge_pct, quantite_vendue
    FROM mart_decision_produits
""").fetchall()
pcols = [d[0] for d in con.description]

for row in produits:
    d = dict(zip(pcols, row))
    uri = SHOP[f"produit_{d['id_produit']}"]
    g.add((uri, RDF.type, SHOP.Produit))
    g.add((uri, SHOP.aCaProduit, Literal(float(d["ca_total"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aTauxMarge, Literal(float(d["taux_marge_pct"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aQuantiteVendue, Literal(int(d["quantite_vendue"]), datatype=XSD.integer)))
    g.add((uri, SHOP.aNomProduit, Literal(str(d["nom_produit"]), datatype=XSD.string)))

# ---- VENTES (relie Client <-> Produit via ObjectProperty) ----
ventes = con.execute("""
    SELECT id_ligne, id_client, id_produit, montant_ligne, marge_ligne, jour_commande
    FROM fait_ventes
    WHERE statut NOT IN ('annulee', 'retournee')
""").fetchall()
vcols = [d[0] for d in con.description]

for row in ventes:
    d = dict(zip(vcols, row))
    uri = SHOP[f"vente_{d['id_ligne']}"]
    g.add((uri, RDF.type, SHOP.Vente))
    g.add((uri, SHOP.aMontantVente, Literal(float(d["montant_ligne"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aDateVente, Literal(str(d["jour_commande"]), datatype=XSD.date)))
    g.add((uri, SHOP.aPourClient, SHOP[f"client_{d['id_client']}"]))
    g.add((uri, SHOP.aPourProduit, SHOP[f"produit_{d['id_produit']}"]))
    g.add((uri, SHOP.aMargeVente, Literal(float(d["marge_ligne"]), datatype=XSD.decimal)))

con.close()
contenu = g.serialize(format="turtle")
with open("shop_ci_data.ttl", "w", encoding="utf-8") as f:
    f.write(contenu)
print(f"Donnees exportees : {len(g)} triplets total")