"""
owl/03_classify.py — CLASSIFICATION SHOP_CI
A executer DEPUIS le dossier owl/. Applique les regles metier (SPARQL
CONSTRUCT) dans l'ORDRE DE PRIORITE fixe par l'ontologie.

Regle d'or : chaque regle EXCLUT (FILTER NOT EXISTS) les entites deja
classees par une regle plus prioritaire -> equivalent d'un
CASE WHEN ... WHEN ... ELSE SQL : le premier qui matche gagne.
"""
from rdflib import Graph, Namespace

SHOP = Namespace("http://shop-ci.ci/ontologie#")
g = Graph()
g.parse("shop_ci_schema.ttl", format="turtle")
g.parse("shop_ci_data.ttl",   format="turtle")
g.bind("shop", SHOP)
print(f"Base chargee : {len(g)} triplets\n")

regles_clients = [
    ("ClientNonIdentifie", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?c a shop:ClientNonIdentifie . }
        WHERE { ?c a shop:Client ; shop:aIdClient ?id . FILTER(?id = -1) }
    """),
    ("ClientVIP", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?c a shop:ClientVIP . }
        WHERE {
            ?c a shop:Client ; shop:aCaTotal ?ca ; shop:aNbCommandes ?nb .
            FILTER(?ca >= 500000 && ?nb >= 8)
            FILTER NOT EXISTS { ?c a shop:ClientNonIdentifie . }
        }
    """),
    ("ClientARisque", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?c a shop:ClientARisque . }
        WHERE {
            ?c a shop:Client ; shop:aCaTotal ?ca ; shop:aJoursInactivite ?inact .
            FILTER(?ca >= 300000 && ?inact > 365)
            FILTER NOT EXISTS { ?c a shop:ClientNonIdentifie . }
            FILTER NOT EXISTS { ?c a shop:ClientVIP . }
        }
    """),
    ("NouveauClient", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?c a shop:NouveauClient . }
        WHERE {
            ?c a shop:Client ; shop:aAncienneteJours ?anc ; shop:aNbCommandes ?nb .
            FILTER(?anc <= 180 && ?nb <= 2)
            FILTER NOT EXISTS { ?c a shop:ClientNonIdentifie . }
            FILTER NOT EXISTS { ?c a shop:ClientVIP . }
            FILTER NOT EXISTS { ?c a shop:ClientARisque . }
        }
    """),
    ("ClientStandard", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?c a shop:ClientStandard . }
        WHERE {
            ?c a shop:Client .
            FILTER NOT EXISTS { ?c a shop:ClientNonIdentifie . }
            FILTER NOT EXISTS { ?c a shop:ClientVIP . }
            FILTER NOT EXISTS { ?c a shop:ClientARisque . }
            FILTER NOT EXISTS { ?c a shop:NouveauClient . }
        }
    """),
]

regles_produits = [
    ("ProduitStar", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?p a shop:ProduitStar . }
        WHERE {
            ?p a shop:Produit ; shop:aCaProduit ?ca ; shop:aTauxMarge ?marge .
            FILTER(?ca >= 15000000 && ?marge >= 45.0)
        }
    """),
    ("ProduitMargeFaible", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?p a shop:ProduitMargeFaible . }
        WHERE {
            ?p a shop:Produit ; shop:aTauxMarge ?marge .
            FILTER(?marge < 35.0)
            FILTER NOT EXISTS { ?p a shop:ProduitStar . }
        }
    """),
    ("ProduitStandard", """
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        CONSTRUCT { ?p a shop:ProduitStandard . }
        WHERE {
            ?p a shop:Produit .
            FILTER NOT EXISTS { ?p a shop:ProduitStar . }
            FILTER NOT EXISTS { ?p a shop:ProduitMargeFaible . }
        }
    """),
]

print("=== CLASSIFICATION DES CLIENTS ===")
for nom, regle in regles_clients:
    triplets = list(g.query(regle))
    for t in triplets: g.add(t)
    print(f"  {nom:20} -> {len(triplets)} client(s)")

print("\n=== CLASSIFICATION DES PRODUITS ===")
for nom, regle in regles_produits:
    triplets = list(g.query(regle))
    for t in triplets: g.add(t)
    print(f"  {nom:20} -> {len(triplets)} produit(s)")

print("\n=== CONTROLE : un seul label par entite ? ===")
for entite, classe_mere, labels in [
    ("Clients", "Client", [n for n,_ in regles_clients]),
    ("Produits", "Produit", [n for n,_ in regles_produits]),
]:
    q = f"""
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        SELECT ?e (COUNT(?label) as ?nb) WHERE {{
            ?e a shop:{classe_mere} ; a ?label .
            FILTER(?label != shop:{classe_mere})
            FILTER(STRSTARTS(STR(?label), STR(shop:)))
        }} GROUP BY ?e HAVING (COUNT(?label) != 1)
    """
    anomalies = list(g.query(q))
    statut = "OK" if not anomalies else f"ANOMALIE : {len(anomalies)} entite(s)"
    print(f"  {entite:10} : {statut}")

g.serialize(destination="shop_ci_classified.ttl", format="turtle")
print(f"\nFichier final : {len(g)} triplets")