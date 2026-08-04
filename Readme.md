# Shop_CI — Plateforme Analytics Engineering de bout en bout
 
**dbt · DuckDB · BigQuery · MetricFlow · Power BI · MCP Power BI officiel (Microsoft) · Graphe de connaissances (RDF/OWL/SPARQL) · Serveur MCP · CI/CD GitHub Actions · Dagster · Docker · Data Vault**
 
Projet pédagogique et portfolio construit de A à Z : d'un jeu de données brutes volontairement sales jusqu'à un agent IA capable d'interroger les décisions métier de l'entreprise en langage naturel — avec une chaîne CI/CD complète, une restitution Power BI pilotée en partie par l'IA, une portabilité multi-warehouse démontrée, une orchestration moderne, un pipeline conteneurisé, et deux modélisations coexistantes (Kimball et Data Vault) pour la même donnée source.
 
> Statut : document vivant, mis à jour au fil de l'avancement du projet.
 
---
 
## 1. Contexte
 
**BoutiqueCI** est une entreprise e-commerce fictive basée à Abidjan, vendant des produits artisanaux en Côte d'Ivoire et en Europe. Le projet simule un cas réel d'analytics engineering, avec ses pièges volontaires (dates multi-formats, doublons clients, clés orphelines, paiements en retry...) pour s'exercer sur des problèmes authentiques plutôt que des données déjà propres.
 
**Répartition des rôles pendant la construction** : Claude écrit et teste le code, explique chaque décision technique ; l'architecte du projet audite, challenge, valide et tranche les choix métier.
 
---
 
## 2. Architecture générale
 
```
CSV bruts (data_brute/)
        │
        ▼
  INGESTION — charger_csv_bigquery.py (mini-Fivetran maison, all-STRING)
        │
        ▼
  STAGING (vues)          — nettoyage 1-pour-1, typage, flags qualité
        │                    portable DuckDB ↔ BigQuery (macros dbt.*)
        │
        ├──► INTERMEDIATE → MARTS (Kimball)          — restitution rapide
        │         dim_clients, dim_produits,             et intuitive
        │         dim_calendrier, fait_ventes,
        │         fait_paiements, mart_decision_*
        │
        └──► DATA VAULT (models/vault/)               — audit et traçabilité
                  ├── hubs/       (client, produit, commande)
                  ├── links/      (vente, paiement, client_same_as)
                  └── satellites/ (contexte descriptif + hash_diff)
 
        Les deux modélisations partagent le MÊME staging, mais ne se
        construisent JAMAIS l'une depuis l'autre — le Data Vault repart
        systématiquement de la source brute.
 
        ├──► SEMANTIC LAYER (MetricFlow) — métriques gouvernées (ca_officiel...)
        │
        ├──► GRAPHE DE CONNAISSANCES (RDF/OWL/SPARQL, sur BigQuery)
        │     ontologie → export → classification métier → réinjection
        │           │
        │           ├──► SERVEUR MCP SHOP_CI (4 outils) ─┐
        │           │                                       ├──► Claude Desktop
        │           └──► MCP POWER BI OFFICIEL (Microsoft)─┘   (2 serveurs simultanés)
        │                 (local, XMLA, lit/écrit le .pbip ouvert)
        │                        │
        └──────────────────► POWER BI (ODBC + mesures DAX, certaines écrites par l'IA)
 
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
├── .github/
│   └── workflows/
│       └── ci.yml                 # CI GitHub Actions : deps, build, test, graphe
├── .dockerignore                   # exclut secrets, venv, caches de l'image Docker
├── Dockerfile                      # image du pipeline, autosuffisante
├── .secrets.json                   # clé de service BigQuery (gitignoré)
├── charger_csv_bigquery.py         # ingestion CSV → tables BigQuery
├── dagster_shop_ci/
│   └── dagster_shop_ci/
│       ├── assets.py               # dbt_assets (auto-découverte) + job
│       ├── definitions.py          # Definitions + schedule quotidien
│       └── __init__.py
├── shop_ci_dbt/
│   ├── packages.yml                 # dbt-utils (generate_surrogate_key)
│   ├── models/
│   │   ├── staging/                  # nettoyage 1-pour-1, source commune
│   │   ├── intermediate/             # réconciliation clients (Kimball)
│   │   ├── marts/                    # dimensions, faits, semantic layer
│   │   └── vault/                    # Data Vault (Hub/Link/Satellite)
│   │       ├── hubs/
│   │       ├── links/
│   │       ├── satellites/
│   │       └── _tests_vault.yml
│   ├── macros/                      # nettoyer_date.sql, generate_schema_name.sql
│   ├── snapshots/                   # SCD Type 2 (clients, produits)
│   ├── owl/                         # graphe de connaissances (généré, gitignoré)
│   │   ├── 01_schema.py             # ontologie : classes, sous-classes, propriétés
│   │   ├── 02_export.py             # peuplement des individus depuis BigQuery
│   │   ├── 03_classify.py           # classification par règles SPARQL CONSTRUCT
│   │   └── 04_ecrire_labels_BigQuery.py  # réinjecte les labels (mart_decisions)
│   ├── powerbi/
│   │   └── Shop_CI.pbip             # modèle Power BI versionné, texte/JSON
│   └── dbt_project.yml
├── mcp/
│   └── serveur_mcp.py               # serveur MCP maison (4 outils)
├── data_brute/                      # sources CSV versionnées
├── tests_pedagogiques/              # 19 tests HTML interactifs
├── pipeline_quotidien.ps1           # orchestration Windows planifiée (niveau 1)
├── requirements.txt
└── logs/                            # journaux d'exécution (gitignoré)
 
Hors dépôt (config système) :
%APPDATA%\Claude\claude_desktop_config.json  # déclare shop-ci ET powerbi-modeling-mcp
```
 
---
 
## 4. Fonctionnalités livrées — détail par chantier
 
### 4.1 Pipeline dbt (Kimball)
- **Staging** : dédoublonnage déterministe (email, `ROW_NUMBER()`), macro `nettoyer_date` (cascade de formats non ambiguës), flags de qualité (`is_missing_*`, paiements en retry via `row_number() over (partition by id_commande, statut_paiement)`).
- **Intermediate** : `int_correspondance_clients`, réconciliation des clients dédoublonnés vers un survivant unique, table de re-routage `id_client → id_client_valide`.
- **Marts Kimball** : grain explicite par table de faits, membre inconnu `id=-1` conservé dans `dim_clients` (jamais de disparition silencieuse de CA), `dim_calendrier` avec portabilité conditionnelle DuckDB/BigQuery.
- **Qualité** : 63+ data tests, 4 unit tests (dont un test du filtre incrémental avec mock de `{{ this }}`), contrats de modèle sur tous les marts, freshness (warn 12h / error 24h).
- **Historisation** : snapshots SCD Type 2 sur clients et produits.
- **Performance** : `fait_ventes` et `fait_paiements` en incrémental, fenêtre de rattrapage de 3 jours.
### 4.2 Portabilité multi-warehouse (DuckDB ↔ BigQuery)
- **Ingestion cloud** : `charger_csv_bigquery.py`, mini-outil d'ingestion (esprit Fivetran) forçant tout en `STRING` — préserve le principe d'audit-avant-transformation même hors DuckDB.
- **Code source unique, deux cibles** : macros cross-database dbt (`dbt.type_string()`, `dbt.safe_cast()`, `dbt.split_part()`, `dbt.dateadd()`) plutôt que des types/fonctions spécifiques à un moteur.
- **Routage conditionnel ciblé** : `{% if target.type == 'bigquery' %}` pour `dim_calendrier`, seul cas sans équivalent cross-database générique (fonctions `range`, `strftime`, `isodow` propres à DuckDB).
- **`_sources.yml` simplifié** : après deux tentatives de double compatibilité DuckDB/BigQuery (routage Jinja structurel dans le YAML, puis macro intermédiaire `source_brut()`), la décision finale a été d'abandonner la double compatibilité — une seule déclaration de source, pointant sur BigQuery, cohérente avec le choix de production.
- **Environnements dev/prod sur le même moteur** : `bigquery_dev` (schéma personnel isolé) et `bigquery_prod`, jamais DuckDB=dev vs BigQuery=prod — macro `generate_schema_name` personnalisée garantissant l'isolation.
### 4.3 Semantic Layer (MetricFlow)
6 métriques gouvernées, dont `ca_officiel` — LA définition de référence du chiffre d'affaires (exclut annulées/retournées). A révélé un écart de 13% entre deux calculs indépendants du même CA avant sa mise en place.
 
### 4.4 Orchestration — 3 niveaux de maturité
- **Niveau 1 (local)** : `pipeline_quotidien.ps1`, Windows Task Scheduler, chemins absolus, exécutables de la venv appelés directement, journalisation horodatée (`Start-Transcript`), verdict par codes de sortie explicite, fraîcheur volontairement exclue du jury final.
- **Niveau 2 (CI/CD cloud)** : GitHub Actions, machine vierge à chaque run, branche protégée.
- **Niveau 3 (orchestrateur dédié)** : **Dagster OSS**, local et gratuit sans limite de temps.
  - `dbt_assets` découvre automatiquement les modèles dbt depuis `manifest.json` — aucun asset redéclaré à la main.
  - Un `job` (`define_asset_job`) regroupe tous les assets ; un `schedule` (cron `0 6 * * *`) reproduit l'horaire de `pipeline_quotidien.ps1`.
  - Interface web locale (`dagster dev`), lineage visuel interactif, historique des runs persistant grâce à `DAGSTER_HOME` fixé en variable d'environnement permanente.
  - Mêmes contraintes que le build manuel : `--full-refresh --exclude path:snapshots` (sandbox BigQuery gratuit sans DML/MERGE).
### 4.5 CI/CD (GitHub Actions)
- Déclenchement automatique sur chaque Pull Request vers `main`.
- Machine virtuelle neuve à chaque exécution : `dbt deps` → `dbt build` (BigQuery) → génération complète du graphe de connaissances.
- **Règle de protection de branche** active : `main` ne peut recevoir aucune fusion tant que la CI n'est pas verte.
- A révélé et corrigé en conditions réelles : un bug de mock de test invisible en local (colonne manquante dans le mock de `{{ this }}` — `date_commande_chargement` vs `jour_commande`), une dépendance Windows-only (`pywin32`, dépendance transitive de `mcp`, jamais nécessaire au projet), plusieurs chemins absolus non portables, et un oubli de `dbt deps` après l'introduction du Data Vault (`dbt_utils`).
### 4.6 Conteneurisation (Docker) — orchestration embarquée
- **Dagster désormais embarqué dans l'image**, pas seulement le pipeline dbt : le conteneur devient un vrai service autonome, exécutant simultanément `dagster-webserver` (interface de supervision, optionnelle) et `dagster-daemon` (le vrai processus qui déclenche les schedules) — un client final n'a besoin que de `docker run`, jamais d'installer Python, dbt, ou Dagster.
- **`manifest.json` généré au démarrage du conteneur**, pas au moment du build : impossible de le générer plus tôt, puisque la clé BigQuery n'est injectée qu'au lancement (`docker run -v`), jamais présente pendant `docker build`.
- **Chemins rendus portables** : `DBT_PROJECT_DIR` et `MANIFEST_PATH` utilisent `os.environ.get(...)` et `os.path.join(...)` plutôt que des chemins Windows codés en dur — un chemin de repli local pour l'usage sur la machine de développement, une variable `ENV` Docker pour le conteneur, sans jamais casser l'un ou l'autre.
- **`dagster.yaml`** (fichier de configuration d'instance, distinct de `definitions.py`) copié explicitement à l'emplacement attendu par `DAGSTER_HOME` — déclare le `DagsterDaemonScheduler` et le `QueuedRunCoordinator`, indispensables pour qu'un schedule se déclenche réellement en arrière-plan.
- **Limite honnête et non négociable** : l'orchestration ne tourne que **tant que le conteneur (et donc la machine hôte) reste allumé**. Contrairement à la CI GitHub Actions, hébergée par GitHub indépendamment de toute machine personnelle, ce conteneur Docker tourne physiquement sur la machine qui l'exécute — l'éteindre arrête le daemon, donc l'orchestration. Une vraie continuité 24/7 exigerait un hébergement cloud (VPS, Dagster+, ou Cloud Scheduler/Cloud Run) — non implémenté à ce stade, volontairement documenté plutôt que dissimulé.
### 4.7 Conteneurisation (Docker) — le socle initial
- **Image autosuffisante** : le profil dbt (`profiles.yml`) est généré directement dans l'image au moment du build — aucun fichier de configuration externe requis, seulement la clé BigQuery.
- **Secret jamais copié dans l'image** : clé de service injectée exclusivement au lancement via `docker run -v` (volume monté), jamais via `COPY` — vérifié concrètement par une recherche exhaustive à l'intérieur de l'image construite (`find / -name "*.secrets*"`), sans résultat.
- **Mise en cache des couches** : `requirements.txt` copié et installé avant le reste du code.
- **`.dockerignore` strict** : secrets, environnement virtuel, caches Dagster/Python, cibles dbt déjà compilées.
- **Avertissement `SecretsUsedInArgOrEnv` compris, pas ignoré** : faux positif confirmé — la variable `ENV GOOGLE_APPLICATION_CREDENTIALS` ne contient qu'un chemin de fichier, jamais le secret lui-même.
- **Validé en conditions réelles** : `dbt build --target bigquery_dev` complet depuis le conteneur, résultat rigoureusement identique au run local et à la CI (`PASS=79 WARN=1 ERROR=0`).
### 4.8 Graphe de connaissances (RDF/OWL/SPARQL)
Architecture en 4 fichiers (patron ontologie / export / classification / réinjection), entièrement sur BigQuery :
- **Ontologie** (`01_schema.py`) : classes `Client`, `Produit`, `Vente` ; sous-classes de décision (`ClientVIP`, `ClientARisque`, `ClientNonIdentifie`, `ProduitStar`, `ProduitMargeFaible`...) documentées avec leur règle exacte.
- **Export** (`02_export.py`) : peuplement des individus réels depuis BigQuery (client officiel `google-cloud-bigquery`, lecture structurelle sans écriture).
- **Classification** (`03_classify.py`) : règles SPARQL `CONSTRUCT` appliquées par ordre de priorité, contrôle de cohérence automatisé.
- **Réinjection** (`04_ecrire_labels_BigQuery.py`) : réécrit la classification dans BigQuery sous forme de table plate `mart_decisions`, via un load job (`WRITE_TRUNCATE`) — distinct d'une requête DML, donc autorisé même sur le sandbox gratuit.
- Résultat courant : 499 clients (47 VIP, 10 à risque, 6 nouveaux, 1 non identifié, 435 standards) · 20 produits (2 stars, 6 à marge faible, 12 standards).
### 4.9 Serveur MCP maison
4 outils exposés à un agent IA (Claude Desktop) : `interroger_graphe` (SPARQL libre), `lister_categorie`, `expliquer_categorie`, `calculer_metrique`. Contournement documenté : MetricFlow non invocable en sous-processus (sandboxing Windows Store / AppContainer) — `calculer_metrique` recalcule `ca_officiel` directement via SPARQL, résultat rigoureusement identique car le même filtre est appliqué dès l'export du graphe.
 
### 4.10 Power BI
- Connexion **ODBC** vers `dev.duckdb` (pilote officiel DuckDB, piège de configuration documenté sur le champ "Database" du DSN).
- Table `mart_decisions` réinjectée, modèle relationnel en étoile avec deux requêtes filtrées (`decisions_clients`, `decisions_produits`) pour éviter toute ambiguïté de jointure entre identifiants clients et produits.
- Mesures DAX répliquant fidèlement le semantic layer : `ca_officiel`, `marge`, `taux_marge`, `nb_commandes_officiel`, `panier_moyen`.
- Format de sauvegarde **`.pbip`** plutôt que `.pbix` : versionnable en texte/JSON.
- Chargement en parallèle désactivé (option Power BI) pour respecter la contrainte mono-écrivain de DuckDB.
### 4.11 Data Vault (Hub / Link / Satellite)
- **3 Hubs** (`hub_client`, `hub_produit`, `hub_commande`) : identité pure, hash key via `dbt_utils.generate_surrogate_key`, business key, `load_date`, `record_source`. `hub_client` couvre volontairement les **510 identités brutes** (avant dédoublonnage de `stg_clients`), pas seulement les 500 survivants.
- **3 Links** : `link_vente` (N-aire, 3 hubs, 7373 lignes), `link_paiement` (rattaché au seul `hub_commande`, inclut les retries, 2896 lignes), `link_client_same_as` (documente les 10 doublons de façon traçable et réversible, sans jamais fusionner — contrairement à `int_correspondance_clients` côté Kimball).
- **5 Satellites** : contexte descriptif + `hash_diff`, reconstruits systématiquement depuis la source brute — `sat_client` recalcule lui-même `nom_complet` (concaténation prénom+nom) plutôt que d'hériter de `stg_clients`.
- **9 tests d'intégrité** (`relationships` sur chaque hash key, imbriqués sous `columns:`) : 8 PASS, 1 WARN documenté — 91 vraies commandes orphelines, un chiffre plus précis que les 101 connus côté Kimball.
- **Coexiste avec Kimball**, sans le remplacer.
### 4.12 MCP Power BI officiel (Microsoft)
- **Deux serveurs MCP actifs simultanément** dans la même session Claude Desktop : `shop-ci` (maison) et `powerbi-modeling-mcp` (extension VS Code officielle Microsoft, connexion locale via XMLA au fichier `.pbip` ouvert dans Power BI Desktop).
- **Lecture confirmée** : 14 tables et 6 mesures DAX listées, identiques à ce qui existait déjà.
- **Vérification croisée validée** : `ca_officiel` calculé indépendamment par le graphe SPARQL et par Power BI DAX donne le même résultat (157 449 600).
- **Écriture réelle validée** : création de `ca_clients_vip` (combinant `ca_officiel` et `decisions_clients[label] = "ClientVIP"`), confirmée visuellement dans Power BI Desktop, pas seulement affirmée par l'agent.
- **Limite honnête** : pas de synchronisation automatique de définitions entre MetricFlow et Power BI — la vraie portée du chantier est l'orchestration à deux serveurs et la vérification croisée, pas une synchronisation bidirectionnelle.
---
 
## 5. Démarrage rapide
 
```powershell
# Environnement
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
 
cd shop_ci_dbt
dbt deps   # installe dbt_utils, indispensable depuis le Data Vault
 
# --- Pipeline Kimball ---
dbt build --select marts staging intermediate --target bigquery_dev --full-refresh --no-partial-parse --exclude path:snapshots
 
# --- Data Vault ---
dbt build --select vault --target bigquery_dev --full-refresh --exclude path:snapshots
dbt test --select vault --target bigquery_dev
 
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
 
# --- MCP Power BI ---
# 1. Installer l'extension VS Code "Power BI Modeling MCP (Analysis Services)"
# 2. Ouvrir Shop_CI.pbip dans Power BI Desktop (doit rester ouvert)
# 3. Ajouter "powerbi-modeling-mcp" dans claude_desktop_config.json, à côté de "shop-ci"
# 4. Redémarrer Claude Desktop complètement
# 5. Tester en lecture seule d'abord ("liste mes tables", "liste mes mesures")
 
# --- CI/CD : automatique sur chaque Pull Request vers main ---
```
 
---
 
## 6. Limitations connues et décisions assumées
 
- **L'orchestration Docker ne tourne que tant que la machine hôte est allumée** — contrairement à la CI GitHub Actions (hébergée indépendamment par GitHub), le conteneur Dagster tourne physiquement sur la machine qui l'exécute. Éteindre l'ordinateur ou fermer Docker Desktop arrête le daemon, donc l'orchestration. Une vraie continuité 24/7 exigerait un hébergement cloud (VPS, Dagster+, ou Cloud Scheduler/Cloud Run) — non implémenté, documenté honnêtement plutôt que présenté comme résolu.
- **Palier gratuit BigQuery sans DML/MERGE** : `--full-refresh --exclude path:snapshots` appliqué uniformément sur les 4 modes d'exécution (manuel, CI, Dagster, Docker) — contournement temporaire, résolu par l'activation de la facturation (en restant dans le palier gratuit permanent de traitement).
- **MetricFlow non invocable en sous-processus depuis le serveur MCP** : contournement via SPARQL direct sur le graphe pour `ca_officiel`. `marge` a la donnée exportée mais pas encore l'outil MCP correspondant.
- **Trois consommateurs, une seule vérité — mais reproduite, pas partagée** : `ca_officiel` défini une fois dans `_semantic.yml`, répliqué manuellement en DAX pour Power BI et en SPARQL pour le graphe. Le chantier MCP Power BI a démontré une vérification croisée de cohérence, pas une résolution complète de cette tension.
- **Le graphe (`owl/`) n'est pas conteneurisé ni intégré comme assets Dagster** — reste exécuté manuellement.
- **Le Data Vault n'est pas branché sur le graphe, MCP, ou Power BI** — ces trois consommateurs restent sur les marts Kimball.
- **`hash_diff` calculé mais jamais exploité en historisation réelle** : sa valeur apparaîtra avec de vrais rechargements répétés.
- **`link_client_same_as` documente sans jamais appliquer** — une future couche de restitution devrait l'exploiter explicitement.
- **Dagster tourne en processus de premier plan**, lié au terminal (ou à VS Code) qui l'a lancé — comportement normal, pas un bug.
- **Power BI Desktop doit rester ouvert** pour que le serveur MCP Modeling fonctionne (connexion XMLA locale).
- **Piège de configuration ODBC/Power BI documenté** : le champ "Database" du DSN DuckDB peut se corrompre silencieusement.
- **CI/CD sans `state:modified`** : chaque exécution reconstruit l'intégralité du projet depuis zéro.
---
 
## 7. Feuille de route
 
- [ ] Hébergement cloud de l'orchestration Docker (VPS, Dagster+, ou Cloud Scheduler/Cloud Run) pour une continuité 24/7 indépendante d'une machine personnelle
- [ ] Superset — restitution BI open source, alternative à Power BI (contexte PME/licence)
- [ ] OpenClaw — diffusion proactive de KPI et interrogation conversationnelle via Telegram (WhatsApp en extension prudente, risque de bannissement documenté pour les bridges non officiels)
- [ ] Étendre la démonstration MCP Power BI : mesures dérivées du Data Vault
- [ ] Brancher le graphe/MCP/Power BI sur le Data Vault, en complément des marts Kimball
- [ ] Étendre `calculer_metrique` (MCP) pour couvrir `marge`
- [ ] Intégrer la régénération du graphe au pipeline Dagster/quotidien
- [ ] Activer le schedule Dagster (configuré, désactivé par défaut)
- [ ] Activer la facturation BigQuery pour lever la contrainte DML/MERGE
- [ ] Gouvernance/RGPD — classification `meta: {pii: true}`, hashing email en staging
- [ ] Second projet dédié : packages dbt pour la certification (`dbt_expectations`, `dbt_project_evaluator`, `codegen`, `dbt-audit-helper`)
---
 
*Voir aussi : [WRITE_UP.md](./WRITE_UP.md) pour le récit complet du projet, [DICTIONNAIRE.md](./DICTIONNAIRE.md) pour le glossaire technique, et [tests_pedagogiques/](./tests_pedagogiques/) pour 19 modules de révision interactifs couvrant l'intégralité du projet.*