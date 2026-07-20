from rdflib import Graph, Namespace, RDF, RDFS, OWL, XSD, Literal
import os

SHOP = Namespace("http://shop-ci.ci/ontologie#")
g = Graph()
g.bind("shop", SHOP); g.bind("owl", OWL); g.bind("rdfs", RDFS)

# --- HELPERS (identiques aux tiens) ---
def classe(nom, parent=None, label=None, comment=None):
    uri = SHOP[nom]
    g.add((uri, RDF.type, OWL.Class))
    if parent:  g.add((uri, RDFS.subClassOf, parent))
    if label:   g.add((uri, RDFS.label, Literal(label, lang="fr")))
    if comment: g.add((uri, RDFS.comment, Literal(comment, lang="fr")))
    return uri

def data_prop(nom, domaine, xsd_type, comment=None):
    uri = SHOP[nom]
    g.add((uri, RDF.type, OWL.DatatypeProperty))
    g.add((uri, RDFS.domain, domaine)); g.add((uri, RDFS.range, xsd_type))
    if comment: g.add((uri, RDFS.comment, Literal(comment, lang="fr")))
    return uri

def obj_prop(nom, domaine, range_, comment=None):
    # Contrairement a data_prop (range = un TYPE XSD comme XSD.decimal),
    # ici range_ = une CLASSE du graphe (Client, Produit, Vente...).
    # C'est ce qui permet a SPARQL de "traverser" : Client -> Vente -> Produit.
    uri = SHOP[nom]
    g.add((uri, RDF.type, OWL.ObjectProperty))
    g.add((uri, RDFS.domain, domaine)); g.add((uri, RDFS.range, range_))
    if comment: g.add((uri, RDFS.comment, Literal(comment, lang="fr")))
    return uri

# --- CLASSES MÈRES ---
Client  = classe("Client",  label="Client Shop_CI",
    comment="Equivalent de mart_decision_clients. Grain : un client.")
Produit = classe("Produit", label="Produit Shop_CI",
    comment="Equivalent de mart_decision_produits. Grain : un produit.")
Vente = classe("Vente",label="Evenement de vente",
    comment="Equivalent d'une ligne de fait_ventes. Grain : un produit "
    "dans une commande. Relie un Client a un Produit via aAchete.")

# --- PROPRIÉTÉS CLIENT ---
data_prop("aCaTotal", Client, XSD.decimal, "ca_total. CA officiel cumulé.")
data_prop("aNbCommandes", Client, XSD.integer, "Fréquence RFM.")
data_prop("aJoursInactivite", Client, XSD.integer, "Récence RFM. NULL pour -1.")
data_prop("aAncienneteJours", Client, XSD.integer, "Depuis inscription. NULL pour -1.")
data_prop("aIdClient", Client, XSD.integer, "-1 = membre inconnu.")
data_prop("aNomClient", Client, XSD.string, "dim_clients.nom_complet.")

# --- PROPRIÉTÉS PRODUIT ---
data_prop("aCaProduit", Produit, XSD.decimal, "CA officiel du produit.")
data_prop("aTauxMarge", Produit, XSD.decimal, ">=45 fort, <35 faible.")
data_prop("aQuantiteVendue", Produit, XSD.integer, "Volume.")
data_prop("aNomProduit", Produit, XSD.string, "dim_produits.nom_produit.")

# --- PROPRIÉTÉS VENTES ---
data_prop("aMontantVente", Vente, XSD.decimal,
    "fait_ventes.montant_ligne de cette vente precise.")
data_prop("aDateVente", Vente, XSD.date,
    "fait_ventes.jour_commande de cette vente precise.")
data_prop("aMargeVente", Vente, XSD.decimal, "marge_ligne de cette vente précise.")

# ===========================================
# CLASSE VENTE + OBJECTPROPERTY
# Une ObjectProperty relie un INDIVIDU a un AUTRE INDIVIDU du graphe
# (contrairement a une DatatypeProperty qui relie a une simple valeur).
# On l'utilise ici car on veut que le graphe sache QUI a achete QUOI,
# pas seulement les stats agregees separees de chaque cote.
# Equivalent dbt : fait_ventes (grain : une ligne de commande).
# ===========================================

obj_prop("aPourClient", Vente, Client,
    "Le client qui a passe cette vente. = fait_ventes.id_client.")
obj_prop("aPourProduit", Vente, Produit,
    "Le produit vendu dans cette vente. = fait_ventes.id_produit.")


# --- SOUS-CLASSES CLIENT (5, par ordre de priorité) ---
classe("ClientNonIdentifie", Client, "Client non identifié (membre inconnu)",
    "PRIORITE 1. aIdClient = -1. Masse ~2M XOF. Décision : identifier.")
classe("ClientVIP", Client, "Client à haute valeur",
    "PRIORITE 2. aCaTotal >= 500000 ET aNbCommandes >= 8.")
classe("ClientARisque", Client, "Bon client en voie de perte",
    "PRIORITE 3. aCaTotal >= 300000 ET aJoursInactivite > 365.")
classe("NouveauClient", Client, "Client récemment acquis",
    "PRIORITE 4. aAncienneteJours <= 180 ET aNbCommandes <= 2.")
classe("ClientStandard", Client, "Client sans signal", "DEFAUT.")

# --- SOUS-CLASSES PRODUIT (3) ---
classe("ProduitStar", Produit, "Produit vedette",
    "PRIORITE 1. aCaProduit >= 15000000 ET aTauxMarge >= 45.")
classe("ProduitMargeFaible", Produit, "Produit à marge faible",
    "PRIORITE 2. aTauxMarge < 35.")
classe("ProduitStandard", Produit, "Produit sans signal", "DEFAUT.")

# --- DISJONCTIONS ---
g.add((SHOP.ClientVIP, OWL.disjointWith, SHOP.ClientStandard))
g.add((SHOP.ClientVIP, OWL.disjointWith, SHOP.ClientARisque))
g.add((SHOP.ClientNonIdentifie, OWL.disjointWith, SHOP.ClientVIP))
g.add((SHOP.ProduitStar, OWL.disjointWith, SHOP.ProduitMargeFaible))
g.add((SHOP.ProduitStar, OWL.disjointWith, SHOP.ProduitStandard))

os.makedirs("owl", exist_ok=True)
g.serialize(destination="shop_ci_schema.ttl", format="turtle")
print(f"Schema : {len(g)} triplets")