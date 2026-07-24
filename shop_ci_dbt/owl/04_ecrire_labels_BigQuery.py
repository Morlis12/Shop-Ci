"""
owl/04_ecrire_labels_bigquery.py
Réinjecte la classification du graphe (shop_ci_classified.ttl) dans BigQuery,
sous forme de table plate 'mart_decisions' — consommable par Power BI
sans avoir besoin de comprendre SPARQL.

Source : shop_ci_classified.ttl (généré par 03_classify.py)
Destination : BigQuery, table mart_decisions (recréée à chaque run via WRITE_TRUNCATE).
"""

from rdflib import Graph, Namespace
import pandas as pd
from google.cloud import bigquery

# Définition de l'espace de noms (Namespace) propre à l'ontologie du projet
SHOP = Namespace("http://shop-ci.ci/ontologie#")

# Paramètres BigQuery
PROJET = "shop-503309"
DATASET = "shop_ci_dev"
CLE_JSON = "../../.secrets.json"  # <-- à remplacer par le nom réel

# --- 1. Charger le graphe déjà classifié ---
g = Graph()
g.parse("shop_ci_classified.ttl", format="turtle")


def extraire_labels(classe_racine: str) -> list[tuple]:
    """
    Pour une classe racine donnée (Client ou Produit), extrait chaque
    individu et son label de décision (ex: ClientVIP), en excluant
    la classe racine elle-même du résultat.
    """
    requete = f"""
    PREFIX shop: <http://shop-ci.ci/ontologie#>
    SELECT ?entite ?label WHERE {{
        ?entite a ?label .
        ?entite a shop:{classe_racine} .
        FILTER(?label != shop:{classe_racine})
    }}
    """
    lignes = []
    for row in g.query(requete):
        # row.entite ressemble à : "http://shop-ci.ci/ontologie#client_305"
        entite_id_texte = str(row.entite).split("#")[-1]       # "client_305"
        entite_id_numerique = int(entite_id_texte.split("_")[-1])  # 305

        # row.label ressemble à : "http://shop-ci.ci/ontologie#ClientVIP"
        label = str(row.label).split("#")[-1]                  # "ClientVIP"

        lignes.append((classe_racine, entite_id_numerique, label))

    return lignes


# --- 2. Extraire pour les deux classes ---
lignes_clients = extraire_labels("Client")
lignes_produits = extraire_labels("Produit")
toutes_lignes = lignes_clients + lignes_produits

print(f"{len(lignes_clients)} clients classifiés, {len(lignes_produits)} produits classifiés.")

# --- 3. Écrire dans BigQuery ---
client = bigquery.Client.from_service_account_json(CLE_JSON, project=PROJET)

df = pd.DataFrame(toutes_lignes, columns=["entity_type", "entity_id", "label"])

table_id = f"{PROJET}.{DATASET}.mart_decisions"
job_config = bigquery.LoadJobConfig(
    write_disposition="WRITE_TRUNCATE",  # recrée la table à chaque run
    schema=[
        bigquery.SchemaField("entity_type", "STRING"),
        bigquery.SchemaField("entity_id", "INTEGER"),
        bigquery.SchemaField("label", "STRING"),
    ],
)
job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
job.result()  # attend la fin du chargement

resultat = client.query(f"SELECT COUNT(*) as total FROM `{table_id}`").result()
total = list(resultat)[0]["total"]
print(f"mart_decisions créée : {total} lignes écrites.")