# Importation de l'objet de contexte permettant à Dagster de suivre l'état de l'exécution
from dagster import AssetExecutionContext ,define_asset_job
# Importations spécifiques pour piloter dbt en ligne de commande (Cli) et générer les assets
from dagster_dbt import DbtCliResource, dbt_assets

# Chemin absolu vers le répertoire racine de votre projet dbt (contient dbt_project.yml)
# Le 'r' devant la chaîne évite que les antislashs '\' soient interprétés comme des caractères d'échappement par Windows
DBT_PROJECT_DIR = r"C:\Users\Laptop Studio\Documents\Shop Ci\shop_ci_dbt"

# Chemin vers le fichier manifest.json généré par 'dbt parse' ou 'dbt compile'
# Ce fichier contient la carte d'identité (le DAG) de tous vos modèles dbt
MANIFEST_PATH = DBT_PROJECT_DIR + r"\target\manifest.json"


# Ce décorateur demande à Dagster de lire le manifest.json pour créer automatiquement
# une boîte (un Asset Dagster) pour chaque table ou vue présente dans votre projet dbt
@dbt_assets(manifest=MANIFEST_PATH)
def shop_ci_dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    """
    Découvre automatiquement TOUS les modèles dbt de Shop_CI comme des assets
    Dagster, à partir du manifest.json — aucun modèle redéclaré à la main.
    """
    
    # Déclenche l'exécution physique de dbt via sa CLI et renvoie les logs en temps réel à Dagster
    yield from dbt.cli(
        [
            "build",                     # Exécute un pipeline complet (run + test + seed) de manière intelligente
            "--target", "bigquery_dev",   # Envoie les données vers l'environnement BigQuery de développement
            "--full-refresh",            # Force dbt à recréer toutes les tables à partir de zéro (ignore l'incrémental)
            "--no-partial-parse",        # Force dbt à réanalyser tout le projet sans réutiliser de cache de parsing
            "--exclude", "path:snapshots" # Exclut l'exécution des modèles situés dans le dossier snapshots
        ],
        context=context, # Transmet le contexte de l'asset (essentiel pour capturer les métriques d'exécution dans Dagster)
    ).stream() # Envoie les événements d'étape (logs, nombre de lignes insérées, etc.) à l'interface de Dagster au fil de l'eau

# Job : matérialise TOUS les assets dbt découverts (staging -> marts)
shop_ci_job = define_asset_job(
    name="shop_ci_build_job",
    selection="*",  # tous les assets du module dbt_assets
)