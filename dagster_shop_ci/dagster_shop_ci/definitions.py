# Importation de l'objet central de Dagster pour déclarer l'ensemble du projet
from dagster import Definitions, ScheduleDefinition
# Importation de la ressource qui permet à Dagster de piloter la CLI de dbt
from dagster_dbt import DbtCliResource

# Importation de vos assets dbt et du chemin du projet définis dans votre fichier assets.py
# (Note : assurez-vous que votre fichier s'appelle bien assets.py et non pas dagster_shop_ci/assets.py)
from dagster_shop_ci.assets import shop_ci_dbt_assets, shop_ci_job, DBT_PROJECT_DIR

# Schedule : declenche shop_ci_job chaque jour a 6h du matin
# (equivalent direct de pipeline_quotidien.ps1 sur le Planificateur Windows)
shop_ci_schedule = ScheduleDefinition(
    job=shop_ci_job,
    cron_schedule="0 6 * * *",  # minute heure jour mois jour_semaine
)

defs = Definitions(
    assets=[shop_ci_dbt_assets],
    jobs=[shop_ci_job],
    schedules=[shop_ci_schedule],
    resources={
        "dbt": DbtCliResource(project_dir=DBT_PROJECT_DIR),
    },
)