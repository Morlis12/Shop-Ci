# Shop_CI — Plateforme Analytics Engineering de bout en bout
 
**dbt · DuckDB · BigQuery · MetricFlow · Power BI · Graphe de connaissances (RDF/OWL/SPARQL) · Serveur MCP · CI/CD GitHub Actions · Dagster**
 
Projet pédagogique et portfolio construit de A à Z : d'un jeu de données brutes volontairement sales jusqu'à un agent IA capable d'interroger les décisions métier de l'entreprise en langage naturel, avec une chaîne CI/CD complète, une restitution Power BI, une portabilité multi-warehouse démontrée, et une orchestration moderne.
 
> Statut : document vivant, mis à jour au fil de l'avancement du projet.
 
---
 
## 1. Contexte
 
**BoutiqueCI** est une entreprise e-commerce fictive basée à Abidjan, vendant des produits artisanaux en Côte d'Ivoire et en Europe. Le projet simule un cas réel d'analytics engineering, avec ses pièges volontaires (dates multi-formats, doublons clients, clés orphelines, paiements en retry...) pour s'exercer sur des problèmes authentiques plutôt que des données déjà propres.
 
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
        │     ontologie → export → classification métier
        │           │
        │           ├──► SERVEUR MCP (4 outils) ──► Claude Desktop (agent IA)
        │           │
        │           └──► 04_ecrire_labels_BigQuery.py ──► mart_decisions
        │                        │
        │                        ▼
        └──────────────────► POWER BI (ODBC, DAX répliquant le semantic layer)
 
ORCHESTRATION :
  Niveau 1 — pipeline_quotidien.ps1 (Windows Task Scheduler, local)
  Niveau 2 — CI/CD GitHub Actions (build/test/graphe sur chaque PR, branche protégée)
  Niveau 3 — Dagster OSS (assets dbt auto-découverts, job + schedule quotidien)
 
WAREHOUSES SUPPORTÉS (même code source, cible au choix) :
  target: dev            → DuckDB local, bac à sable rapide, hors-ligne
  target: bigquery_dev    → BigQuery, schéma personnel isolé (shop_ci_dev)
  target: bigquery_prod   → BigQuery, schéma de production (shop_ci_prod)
```
 
---
 
## 3. Structure du dépôt
 
```
Shop Ci/
├── .github/
│   └── workflows/
│       └── ci.yml              # CI GitHub Actions : build, test, graphe
├── .secrets.json                 # clé de service BigQuery (gitignoré)
├── charger_csv_bigquery.py       # ingestion CSV → tables BigQuery (all-STRING)
├── dagster_shop_ci/
│   └── dagster_shop_ci/
│       ├── assets.py             # dbt_assets (auto-découverte) + job
│       ├── definitions.py        # Definitions + schedule quotidien
│       └── __init__.py
├── shop_ci_dbt/
│   ├── models/
│   │   ├── staging/              # nettoyage 1-pour-1, portable multi-warehouse
│   │   ├── intermediate/         # réconciliation clients
│   │   └── marts/                # dimensions, faits, marts de décision, semantic layer
│   ├── macros/                   # nettoyer_date.sql, generate_schema_name.sql
│   ├── snapshots/                # SCD Type 2 (clients, produits)
│   ├── owl/                      # graphe de connaissances (généré, gitignoré)
│   │   ├── 01_schema.py          # ontologie : classes, sous-classes, propriétés
│   │   ├── 02_export.py          # peuplement des individus depuis BigQuery
│   │   ├── 03_classify.py        # classification par règles SPARQL CONSTRUCT
│   │   └── 04_ecrire_labels_BigQuery.py  # réinjecte les labels (mart_decisions)
│   ├── powerbi/                  # modèle Power BI versionné (.pbip)
│   │   └── Shop_CI.pbip
│   └── dbt_project.yml
├── mcp/
│   └── serveur_mcp.py            # serveur MCP (4 outils, branché à Claude Desktop)
├── data_brute/                   # sources CSV versionnées
├── tests_pedagogiques/           # 18 tests HTML interactifs (révision, certification, entretien)
├── pipeline_quotidien.ps1        # orchestration Windows planifiée (niveau 1)
├── requirements.txt
└── logs/                         # journaux d'exécution (gitignoré)
```
 
---
 
## 4. Fonctionnalités livrées
 
### Pipeline dbt
- **Staging** : dédoublonnage déterministe, macro `nettoyer_date` (cascade de formats non ambiguës), flags de qualité (paiements en retry, etc.)
- **Intermediate** : réconciliation des clients dédoublonnés vers un survivant unique
- **Marts Kimball** : grain explicite par table de faits, membre inconnu `id=-1` conservé (jamais de disparition silencieuse de CA)
- **Qualité** : 63+ data tests, 4 unit tests, contrats de modèle sur tous les marts, freshness (warn 12h / error 24h)
- **Historisation** : snapshots SCD Type 2 sur clients et produits
- **Performance** : deux tables de faits en incrémental, fenêtre de rattrapage de 3 jours
### Portabilité multi-warehouse (DuckDB ↔ BigQuery)
- **Ingestion cloud** : `charger_csv_bigquery.py`, un mini-outil d'ingestion (esprit Fivetran) forçant tout en `STRING`
- **Code source unique, deux cibles** : macros cross-database dbt (`dbt.type_string()`, `dbt.safe_cast()`, `dbt.split_part()`, `dbt.dateadd()`)
- **Routage conditionnel ciblé** : Jinja `{% if target.type == 'bigquery' %}` pour les cas sans équivalent générique
- **Environnements dev/prod sur le même moteur** : `bigquery_dev` et `bigquery_prod`, jamais DuckDB=dev vs BigQuery=prod
### Semantic Layer (MetricFlow)
6 métriques gouvernées, dont `ca_officiel` — LA définition de référence du chiffre d'affaires (exclut annulées/retournées).
 
### Orchestration — 3 niveaux de maturité
- **Niveau 1 (local)** : `pipeline_quotidien.ps1`, Windows Task Scheduler, codes de sortie, verdict explicite
- **Niveau 2 (CI/CD cloud)** : GitHub Actions, machine vierge à chaque run, branche protégée
- **Niveau 3 (orchestrateur dédié)** : **Dagster OSS**, local et gratuit sans limite de temps
  - `dbt_assets` découvre automatiquement les 13 modèles dbt depuis `manifest.json` — aucun asset redéclaré à la main
  - Un `job` regroupe tous les assets ; un `schedule` (cron `0 6 * * *`) reproduit l'horaire de `pipeline_quotidien.ps1`
  - Interface web locale (`dagster dev`) avec lineage visuel interactif, historique des runs persistant (`DAGSTER_HOME` fixé)
  - Mêmes contraintes que le build manuel : `--full-refresh --exclude path:snapshots` (sandbox BigQuery gratuit sans DML/MERGE)
### CI/CD (GitHub Actions)
- Déclenchement automatique sur chaque Pull Request vers `main`
- Machine virtuelle neuve à chaque exécution : `dbt build` (BigQuery) → génération complète du graphe de connaissances
- **Règle de protection de branche** active
- A révélé et corrigé en conditions réelles : un bug de mock de test invisible en local, une dépendance Windows-only (`pywin32`), plusieurs chemins absolus non portables
### Graphe de connaissances
Architecture en 4 fichiers (ontologie / export / classification / réinjection), désormais entièrement sur BigQuery :
- Résultat courant : 499 clients (47 VIP, 10 à risque, 6 nouveaux, 1 non identifié, 435 standards) · 20 produits (2 stars, 6 à marge faible, 12 standards)
### Serveur MCP
4 outils exposés à un agent IA (Claude Desktop) : `interroger_graphe`, `lister_categorie`, `expliquer_categorie`, `calculer_metrique`.
 
### Power BI
Connexion ODBC, table `mart_decisions` réinjectée, mesures DAX répliquant fidèlement le semantic layer, format `.pbip` versionnable.
 
---
 
## 5. Démarrage rapide
 
```powershell
# Environnement
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
 
# --- Pipeline dbt (BigQuery) ---
python charger_csv_bigquery.py
cd shop_ci_dbt
dbt build --target bigquery_dev --full-refresh --no-partial-parse --exclude path:snapshots
 
# --- Graphe de connaissances ---
cd owl
python 01_schema.py
python 02_export.py
python 03_classify.py
python 04_ecrire_labels_BigQuery.py
 
# --- Orchestration Dagster (interface web locale) ---
cd ..\..\dagster_shop_ci
dagster dev -f dagster_shop_ci\definitions.py
# puis ouvrir http://127.0.0.1:3000
 
# --- CI/CD : automatique sur chaque Pull Request vers main ---
```
 
---
 
## 6. Limitations connues et décisions assumées
 
- **Mono-écrivain DuckDB** : résolu par migration vers BigQuery pour la production ; Power BI nécessite de désactiver le chargement parallèle des tables.
- **Palier gratuit BigQuery sans DML/MERGE** : `--full-refresh --exclude path:snapshots` sur toutes les cibles BigQuery (build manuel, CI, ET Dagster) — un contournement temporaire, pas une solution de production.
- **MetricFlow non invocable en sous-processus depuis le serveur MCP** : contournement documenté via calcul SPARQL direct sur le graphe pour `ca_officiel`. `marge` a la donnée exportée mais pas encore l'outil MCP correspondant.
- **Trois consommateurs, une seule vérité — mais reproduite, pas partagée** : `ca_officiel` défini une fois, répliqué manuellement en DAX et en SPARQL.
- **Dagster tourne en processus de premier plan** : lancé depuis le terminal intégré VS Code, il s'arrête si VS Code se ferme (comportement normal d'un serveur de dev, pas un bug) — un terminal PowerShell autonome ou un processus détaché résout ce point pour un usage prolongé.
- **`DAGSTER_HOME` fixé en variable d'environnement permanente** : nécessaire pour que l'historique des runs et l'état du schedule survivent entre les sessions ; sans elle, Dagster utilise un dossier temporaire effacé à chaque fermeture.
- **CI/CD sans `state:modified`** : chaque exécution reconstruit l'intégralité du projet depuis zéro.
---
 
## 7. Feuille de route
 
- [ ] Activer le schedule Dagster (actuellement configuré mais désactivé par défaut)
- [ ] Conteneuriser le pipeline avec Docker
- [ ] Data Vault — chantier théorique exploré (test dédié), implémentation réelle à mener
- [ ] Étendre `calculer_metrique` (MCP) pour couvrir `marge` en plus de `ca_officiel`
- [ ] Gouvernance/RGPD — chantier théorique exploré (test dédié), application concrète non commencée
- [ ] Activer la facturation BigQuery (palier gratuit permanent) pour lever la contrainte DML/MERGE
- [ ] Serveurs MCP officiels Power BI (Microsoft) — piste explorée, non implémentée
---
 
*Voir aussi : [WRITE_UP.md](./WRITE_UP.md) pour le récit du projet, [DICTIONNAIRE.md](./DICTIONNAIRE.md) pour le glossaire des termes techniques, et [tests_pedagogiques/](./tests_pedagogiques/) pour 18 modules de révision interactifs.*