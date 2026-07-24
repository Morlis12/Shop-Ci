"""
owl/02_export.py — EXPORT DES DONNEES SHOP_CI
Peuple le graphe avec les INDIVIDUS reels : un noeud par client, par produit,
par ligne de vente, avec leurs attributs (DatatypeProperty) et leurs liens
(ObjectProperty aPourClient/aPourProduit). Aucun label metier ici : la
classification est deduite ensuite (fichier 03_classify.py).
Source : BigQuery, requetes en LECTURE SEULE.
"""
from google.cloud import bigquery
from rdflib import Graph, Namespace, RDF, XSD, Literal

SHOP = Namespace("http://shop-ci.ci/ontologie#")
PROJET = "shop-503309"
DATASET = "shop_ci_dev"
CLE_JSON = "../../.secrets.json"

client = bigquery.Client.from_service_account_json(CLE_JSON, project=PROJET)

g = Graph()
g.bind("shop", SHOP)

# ---- CLIENTS ----
requete_clients = f"""
    SELECT id_client, nom_complet, nb_commandes, ca_total, jours_inactivite, anciennete_jours
    FROM `{PROJET}.{DATASET}.mart_decision_clients`
"""
for row in client.query(requete_clients).result():
    d = dict(row.items())
    uri = SHOP[f"client_{d['id_client']}"]
    g.add((uri, RDF.type, SHOP.Client))
    g.add((uri, SHOP.aIdClient, Literal(int(d["id_client"]), datatype=XSD.integer)))
    g.add((uri, SHOP.aCaTotal, Literal(float(d["ca_total"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aNbCommandes, Literal(int(d["nb_commandes"]), datatype=XSD.integer)))
    g.add((uri, SHOP.aNomClient, Literal(str(d["nom_complet"]), datatype=XSD.string)))
    if d["jours_inactivite"] is not None:
        g.add((uri, SHOP.aJoursInactivite, Literal(int(d["jours_inactivite"]), datatype=XSD.integer)))
    if d["anciennete_jours"] is not None:
        g.add((uri, SHOP.aAncienneteJours, Literal(int(d["anciennete_jours"]), datatype=XSD.integer)))

# ---- PRODUITS ----
requete_produits = f"""
    SELECT id_produit, nom_produit, ca_total, taux_marge_pct, quantite_vendue
    FROM `{PROJET}.{DATASET}.mart_decision_produits`
"""
for row in client.query(requete_produits).result():
    d = dict(row.items())
    uri = SHOP[f"produit_{d['id_produit']}"]
    g.add((uri, RDF.type, SHOP.Produit))
    g.add((uri, SHOP.aCaProduit, Literal(float(d["ca_total"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aTauxMarge, Literal(float(d["taux_marge_pct"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aQuantiteVendue, Literal(int(d["quantite_vendue"]), datatype=XSD.integer)))
    g.add((uri, SHOP.aNomProduit, Literal(str(d["nom_produit"]), datatype=XSD.string)))

# ---- VENTES (relie Client <-> Produit via ObjectProperty) ----
requete_ventes = f"""
    SELECT id_ligne, id_client, id_produit, montant_ligne, marge_ligne, jour_commande
    FROM `{PROJET}.{DATASET}.fait_ventes`
    WHERE statut NOT IN ('annulee', 'retournee')
"""
for row in client.query(requete_ventes).result():
    d = dict(row.items())
    uri = SHOP[f"vente_{d['id_ligne']}"]
    g.add((uri, RDF.type, SHOP.Vente))
    g.add((uri, SHOP.aMontantVente, Literal(float(d["montant_ligne"]), datatype=XSD.decimal)))
    g.add((uri, SHOP.aDateVente, Literal(str(d["jour_commande"]), datatype=XSD.date)))
    g.add((uri, SHOP.aPourClient, SHOP[f"client_{d['id_client']}"]))
    g.add((uri, SHOP.aPourProduit, SHOP[f"produit_{d['id_produit']}"]))
    g.add((uri, SHOP.aMargeVente, Literal(float(d["marge_ligne"]), datatype=XSD.decimal)))

contenu = g.serialize(format="turtle")
with open("shop_ci_data.ttl", "w", encoding="utf-8") as f:
    f.write(contenu)
print(f"Donnees exportees : {len(g)} triplets total")