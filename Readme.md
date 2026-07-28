# Shop_CI — Plateforme Analytics Engineering de bout en bout
 
**dbt · DuckDB · BigQuery · MetricFlow · Power BI · Graphe de connaissances (RDF/OWL/SPARQL) · Serveur MCP · CI/CD GitHub Actions · Dagster · Docker**
 
Projet pédagogique et portfolio construit de A à Z : d'un jeu de données brutes volontairement sales jusqu'à un agent IA capable d'interroger les décisions métier de l'entreprise en langage naturel — avec une chaîne CI/CD complète, une restitution Power BI, une portabilité multi-warehouse, une orchestration moderne, et un pipeline conteneurisé prouvant sa reproductibilité sur trois environnements indépendants.
 
> Statut : document vivant, mis à jour au fil de l'avancement du projet.
 
---
 
## 1. Contexte
 
**BoutiqueCI** est une entreprise e-commerce fictive basée à Abidjan, vendant des produits artisanaux en Côte d'Ivoire et en Europe. Le projet simule un cas réel d'analytics engineering, avec ses pièges volontaires pour s'exercer sur des problèmes authentiques plutôt que des données déjà propres.
 
**Répartition des rôles pendant la construction** : Claude écrit et teste le code, explique chaque décision ; l'architecte du projet audite, challenge, valide et tranche les choix métier.
 
---
 
## 2. Architecture générale
 
```
CSV bruts (data_brute/)
        │
        ▼
  INGESTION — charger_csv_bigquery.py (mini-Fivetran maison, all-STRING)
        │
        ▼
  STAGING (vues)          — nettoyage 1-pour-1, typage, flags
        │                    portable DuckDB ↔ BigQuery (macros dbt.*)
        ▼
  INTERMEDIATE            — logique inter-tables (réconciliation clients)
        │
        ▼
  MARTS (Kimball)          — dim_clients, dim_produits, dim_calendrier,
        │                     fait_ventes, fait_paiements
        ├──► SEMANTIC LAYER (MetricFlow) — métriques gouvernées (ca_officiel...)
        │
        ├──► MARTS DE DÉCISION — mart_decision_clients, mart_decision_produits
        │           │
        │           ▼
        │     GRAPHE DE CONNAISSANCES (RDF/OWL/SPARQL, sur BigQuery)
        │           │
        │           ├──► SERVEUR MCP (4 outils) ──► Claude Desktop (agent IA)
        │           │
        │           └──► mart_decisions ──► POWER BI (ODBC, DAX)
 
REPRODUCTIBILITÉ VALIDÉE SUR 3 ENVIRONNEMENTS INDÉPENDANTS :
  Local (Windows)  →  CI/CD (GitHub Actions, machine vierge)  →  Docker (conteneur isolé)
  Résultat identique dans les 3 cas : PASS=79 WARN=1 (101 commandes orphelines, connu) ERROR=0
 
ORCHESTRATION — 3 niveaux de maturité :
  Niveau 1 — pipeline_quotidien.ps1 (Windows Task Scheduler, local)
  Niveau 2 — CI/CD GitHub Actions (build/test/graphe sur chaque PR, branche protégée)
  Niveau 3 — Dagster OSS (assets dbt auto-découverts, job + schedule quotidien)
 
WAREHOUSES SUPPORTÉS : DuckDB (local, prototypage) et BigQuery (bigquery_dev / bigquery_prod)
```
 
---
 
## 3. Structure du dépôt
 
```
Shop Ci/
├── .github/workflows/ci.yml      # CI GitHub Actions
├── .dockerignore                  # exclut secrets, venv, caches de l'image Docker
├── Dockerfile                     # image du pipeline, autosuffisante
├── .secrets.json                  # clé de service BigQuery (gitignoré)
├── charger_csv_bigquery.py        # ingestion CSV → tables BigQuery
├── dagster_shop_ci/
│   └── dagster_shop_ci/
│       ├── assets.py              # dbt_assets (auto-découverte) + job
│       ├── definitions.py         # Definitions + schedule quotidien
│       └── __init__.py
├── shop_ci_dbt/
│   ├── models/{staging,intermediate,marts}/
│   ├── macros/                    # nettoyer_date.sql, generate_schema_name.sql
│   ├── snapshots/                 # SCD Type 2
│   ├── owl/                       # graphe de connaissances (généré, gitignoré)
│   ├── powerbi/Shop_CI.pbip       # modèle Power BI versionné
│   └── dbt_project.yml
├── mcp/serveur_mcp.py             # serveur MCP (4 outils)
├── data_brute/                    # sources CSV versionnées
├── tests_pedagogiques/            # 18 tests HTML interactifs
├── pipeline_quotidien.ps1         # orchestration Windows (niveau 1)
├── requirements.txt
└── logs/                          # journaux d'exécution (gitignoré)
```
 
---
 
## 4. Fonctionnalités livrées
 
### Pipeline dbt
Staging, intermediate, marts Kimball, 63+ tests, contrats de modèle, snapshots SCD2, modèles incrémentaux — grain explicite, membre inconnu toujours conservé.
 
### Portabilité multi-warehouse (DuckDB ↔ BigQuery)
Macros cross-database dbt (`type_string`, `safe_cast`, `split_part`, `dateadd`), routage conditionnel Jinja pour les cas sans équivalent générique, environnements dev/prod sur le même moteur.
 
### Semantic Layer (MetricFlow)
6 métriques gouvernées, dont `ca_officiel`.
 
### Orchestration — 3 niveaux
Local (PowerShell) → CI/CD (GitHub Actions) → Dagster OSS (assets auto-découverts, lineage visuel, schedule cron).
 
### CI/CD (GitHub Actions)
Machine vierge à chaque Pull Request, branche protégée, génération complète du graphe incluse.
 
### Conteneurisation (Docker)
- **Image autosuffisante** : le profil dbt (`profiles.yml`) est généré directement dans l'image au moment du build — le conteneur n'a besoin d'aucun fichier de configuration externe pour fonctionner, seulement de la clé BigQuery.
- **Secret jamais copié dans l'image** : la clé de service est injectée exclusivement au lancement via `docker run -v` (volume monté), jamais via `COPY` — vérifié concrètement par une recherche exhaustive à l'intérieur de l'image construite, pas seulement supposé.
- **Mise en cache des couches** : `requirements.txt` copié et installé avant le reste du code, pour que Docker ne réinstalle jamais les dépendances lors d'une simple modification d'un modèle `.sql`.
- **`.dockerignore` strict** : exclut secrets, environnement virtuel, caches Dagster/Python, cibles dbt déjà compilées.
- **Validé en conditions réelles** : `dbt build --target bigquery_dev` complet depuis le conteneur, résultat rigoureusement identique au run local et à la CI (`PASS=79 WARN=1 ERROR=0`).
### Graphe de connaissances
4 fichiers (ontologie / export / classification / réinjection), sur BigQuery. 499 clients et 20 produits classifiés.
 
### Serveur MCP
4 outils exposés à un agent IA (Claude Desktop).
 
### Power BI
Connexion ODBC, mesures DAX répliquant le semantic layer, format `.pbip` versionnable.
 
---
 
## 5. Démarrage rapide
 
```powershell
# Environnement
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
 
# --- Pipeline dbt (BigQuery, en local) ---
python charger_csv_bigquery.py
cd shop_ci_dbt
dbt build --target bigquery_dev --full-refresh --no-partial-parse --exclude path:snapshots
 
# --- Graphe de connaissances ---
cd owl
python 01_schema.py && python 02_export.py && python 03_classify.py && python 04_ecrire_labels_BigQuery.py
 
# --- Orchestration Dagster ---
cd ..\..\dagster_shop_ci
dagster dev -f dagster_shop_ci\definitions.py   # puis http://127.0.0.1:3000
 
# --- Exécution conteneurisée (Docker) ---
cd ..
docker build -t shop-ci-pipeline .
docker run --rm -v "$(pwd)\.secrets.json:/app/.secrets.json" shop-ci-pipeline
 
# --- CI/CD : automatique sur chaque Pull Request vers main ---
```
 
---
 
## 6. Limitations connues et décisions assumées
 
- **Palier gratuit BigQuery sans DML/MERGE** : `--full-refresh --exclude path:snapshots` appliqué uniformément sur les 4 modes d'exécution (manuel, CI, Dagster, Docker).
- **Le graphe (`owl/`) n'est pas encore conteneurisé ni intégré comme assets Dagster** : reste exécuté manuellement en dehors de ces deux chantiers — une extension possible, non encore réalisée.
- **Le profil dbt est généré en dur dans le Dockerfile** (sans secret réel, juste la structure de connexion) plutôt que monté depuis l'extérieur — choix délibéré pour une image autosuffisante, au prix d'une modification du Dockerfile si la configuration de connexion change.
- **Avertissement Docker `SecretsUsedInArgOrEnv`** sur la ligne `ENV GOOGLE_APPLICATION_CREDENTIALS` : un faux positif vérifié — cette variable ne contient qu'un chemin de fichier, jamais le secret lui-même ; confirmé par une recherche exhaustive à l'intérieur de l'image construite.
- **MetricFlow non invocable en sous-processus depuis le serveur MCP** : contournement documenté via calcul SPARQL direct sur le graphe.
- **Trois consommateurs, une seule vérité — mais reproduite, pas partagée** : `ca_officiel` défini une fois, répliqué manuellement en DAX et en SPARQL.
- **Dagster tourne en processus de premier plan**, lié au terminal qui l'a lancé.
---
 
## 7. Feuille de route
 
- [ ] Data Vault — chantier théorique exploré, implémentation réelle à mener
- [ ] Intégrer le graphe (`owl/`) à l'image Docker et/ou comme assets Dagster
- [ ] Activer le schedule Dagster (actuellement configuré mais désactivé par défaut)
- [ ] Étendre `calculer_metrique` (MCP) pour couvrir `marge`
- [ ] Gouvernance/RGPD — application concrète non commencée
- [ ] Activer la facturation BigQuery (palier gratuit permanent) pour lever la contrainte DML/MERGE
- [ ] Serveurs MCP officiels Power BI (Microsoft) — piste explorée, non implémentée
---
 
*Voir aussi : [WRITE_UP.md](./WRITE_UP.md), [DICTIONNAIRE.md](./DICTIONNAIRE.md), et [tests_pedagogiques/](./tests_pedagogiques/) pour 19 modules de révision interactifs.*