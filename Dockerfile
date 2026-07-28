# --- ÉTAPE 1 : L'ENVIRONNEMENT DE BASE ---
# On démarre avec une image Linux officielle et légère contenant Python 3.12
FROM python:3.12-slim

# On crée et on se positionne dans le dossier principal de l'application
WORKDIR /app


# --- ÉTAPE 2 : LES DÉPENDANCES (LE CODE EXTÉRIEUR) ---
# On copie la liste de tes packages (dbt, connecteurs, etc.) depuis ton PC
COPY requirements.txt .

# On installe les dépendances. Grâce au cache Docker, cette étape ne se relance 
# QUE si tu modifies ton fichier requirements.txt (gain de temps énorme !)
RUN pip install --no-cache-dir -r requirements.txt


# --- ÉTAPE 3 : TON CODE SOURCE ---
# On copie le dossier de ton projet dbt
COPY shop_ci_dbt/ ./shop_ci_dbt/

# On copie le dossier contenant tes données brutes au format CSV
COPY data_brute/ ./data_brute/

# On copie ton script Python d'ingestion vers BigQuery
COPY charger_csv_bigquery.py .


# --- ÉTAPE 4 : LA SÉCURITÉ & CONFIGURATION ---
# On indique à Google Cloud où chercher la clé d'accès (le fichier .secrets.json)
# Note : Ce fichier n'est PAS dans l'image (bloqué par .dockerignore), 
# il sera injecté de manière sécurisée uniquement au moment du lancement
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/.secrets.json

# Génère le profil dbt directement dans l'image (pas de vrai secret ici).
# La clé BigQuery elle-même reste montée au lancement, elle n'est jamais copiée.
# Note : Le champ 'project' utilise 'env_var' pour s'adapter automatiquement au projet du client !
RUN mkdir -p /root/.dbt && \
    printf 'shop_ci_dbt:\n  target: bigquery_dev\n  outputs:\n    bigquery_dev:\n      type: bigquery\n      method: service-account\n      project: "{{ env_var('\''GCP_PROJECT_ID'\'', '\''shop-503309'\'') }}"\n      dataset: shop_ci_dev\n      threads: 4\n      keyfile: /app/.secrets.json\n      location: US\n' > /root/.dbt/profiles.yml


# --- ÉTAPE 5 : L'EXÉCUTION ---
# On se déplace à l'intérieur du dossier dbt pour pouvoir lancer les commandes
WORKDIR /app/shop_ci_dbt

# La commande automatique qui s'exécute quand le conteneur démarre.
# Elle va compiler et exécuter tout ton projet dbt sur BigQuery en mode "full refresh"
CMD ["dbt", "build", "--target", "bigquery_dev", "--full-refresh", "--no-partial-parse", "--exclude", "path:snapshots"]
