"""
charger_csv_bigquery.py
Charge chaque CSV de data_brute/ comme une table BigQuery, TOUTES LES COLONNES
EN STRING (équivalent de all_varchar=true sur DuckDB) — pour ne rien masquer
avant l'étape de staging, exactement le même principe d'audit qu'en local.
"""

from google.cloud import bigquery
import pandas as pd
from pathlib import Path

# --- Configuration des variables d'environnement ---
PROJET = "shop-503309"
DATASET = "shop_ci"
CLE_JSON = "./.secrets.json"
DOSSIER_CSV = Path("./data_brute")

# --- Initialisation du client BigQuery avec le compte de service ---
client = bigquery.Client.from_service_account_json(CLE_JSON, project=PROJET)

# --- Initialisation de l'espace de stockage (Dataset) ---
# Crée le dataset s'il n'existe pas encore
dataset_id = f"{PROJET}.{DATASET}"
client.create_dataset(dataset_id, exists_ok=True)

# --- Boucle de traitement de chaque fichier CSV trouvé ---
for fichier_csv in DOSSIER_CSV.glob("*.csv"):
    # Extrait le nom du fichier sans extension pour nommer la future table
    nom_table = fichier_csv.stem  # "clients.csv" -> "clients"

    # Lecture en texte brut, comme all_varchar=true sur DuckDB
    # dtype=str force le format texte, keep_default_na=False évite les conversions en NaN
    df = pd.read_csv(fichier_csv, dtype=str, keep_default_na=False)

    # Définition de la destination finale dans BigQuery
    table_id = f"{PROJET}.{DATASET}.{nom_table}"
    
    # Configuration du travail d'importation (Job)
    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE",  # écrase si déjà existant, recharge propre
        autodetect=False,                    # Désactive l'inférence automatique des types
        # Force explicitement le type STRING pour toutes les colonnes détectées par pandas
        schema=[bigquery.SchemaField(col, "STRING") for col in df.columns],
    )
    
    # Exécution asynchrone du chargement des données depuis le DataFrame pandas
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    
    # Blocage du script jusqu'à la fin de l'exécution du Job BigQuery
    job.result()  # attend la fin du chargement
    
    # Affichage du statut de progression dans la console
    print(f"{nom_table} : {len(df)} lignes chargées.")

print("Terminé.")
