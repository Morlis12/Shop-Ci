# Shop_CI — Plateforme Analytics Engineering de bout en bout
 
**dbt · DuckDB · BigQuery · MetricFlow · Power BI · Graphe de connaissances (RDF/OWL/SPARQL) · Serveur MCP · CI/CD GitHub Actions · Dagster · Docker · Data Vault**
 
Projet pédagogique et portfolio construit de A à Z : d'un jeu de données brutes volontairement sales jusqu'à un agent IA capable d'interroger les décisions métier de l'entreprise en langage naturel — avec une chaîne CI/CD complète, une restitution Power BI, une portabilité multi-warehouse, une orchestration moderne, un pipeline conteneurisé, et deux modélisations coexistantes (Kimball et Data Vault) pour la même donnée source.
 
> Statut : document vivant, mis à jour au fil de l'avancement du projet.
 
---
 
## 1. Contexte
 
**BoutiqueCI** est une entreprise e-commerce fictive basée à Abidjan. Le projet simule un cas réel d'analytics engineering, avec ses pièges volontaires pour s'exercer sur des problèmes authentiques plutôt que des données déjà propres.
 
**Répartition des rôles** : Claude écrit et teste le code, explique chaque décision ; l'architecte du projet audite, challenge, valide et tranche les choix métier.
 
---
 
## 2. Architecture générale
 
```
CSV bruts (data_brute/)
        │
        ▼
  INGESTION — charger_csv_bigquery.py
        │
        ▼
  STAGING (vues)          — nettoyage 1-pour-1, portable DuckDB ↔ BigQuery
        │
        ├──► INTERMEDIATE → MARTS (Kimball)          — restitution rapide
        │         dim_clients, fait_ventes...            et intuitive
        │
        └──► DATA VAULT (models/vault/)              — audit et traçabilité
                  ├── hubs/       (client, produit, commande)
                  ├── links/      (vente, paiement, client_same_as)
                  └── satellites/ (contexte + hash_diff)
 
        Les deux modélisations partagent le MÊME staging, mais ne se
        construisent JAMAIS l'une depuis l'autre — le Data Vault repart
        systématiquement de la source brute, pour ne jamais hériter
        silencieusement d'une décision métier déjà prise par Kimball.
 
        ├──► SEMANTIC LAYER (MetricFlow) — métriques gouvernées
        ├──► GRAPHE DE CONNAISSANCES (RDF/OWL/SPARQL, sur BigQuery)
        │         ├──► SERVEUR MCP ──► Claude Desktop (agent IA)
        │         └──► mart_decisions ──► POWER BI
 
REPRODUCTIBILITÉ VALIDÉE SUR 3 ENVIRONNEMENTS : Local · CI/CD · Docker
ORCHESTRATION — 3 niveaux : PowerShell · GitHub Actions · Dagster OSS
```
 
---
 
## 3. Structure du dépôt
 
```
Shop Ci/
├── .github/workflows/ci.yml
├── Dockerfile · .dockerignore
├── .secrets.json                  # gitignoré
├── charger_csv_bigquery.py
├── dagster_shop_ci/
├── shop_ci_dbt/
│   ├── packages.yml                # dbt-utils (generate_surrogate_key)
│   ├── models/
│   │   ├── staging/                 # source commune aux deux modélisations
│   │   ├── intermediate/            # réconciliation clients (Kimball)
│   │   ├── marts/                   # dimensions, faits (Kimball)
│   │   └── vault/                   # Data Vault (Hub/Link/Satellite)
│   │       ├── hubs/
│   │       ├── links/
│   │       ├── satellites/
│   │       └── _tests_vault.yml
│   ├── macros/
│   ├── snapshots/
│   ├── owl/
│   ├── powerbi/Shop_CI.pbip
│   └── dbt_project.yml
├── mcp/serveur_mcp.py
├── data_brute/
├── tests_pedagogiques/
├── pipeline_quotidien.ps1
├── requirements.txt
└── logs/
```
 
---
 
## 4. Fonctionnalités livrées
 
### Pipeline dbt (Kimball)
Staging, intermediate, marts, 63+ tests, contrats de modèle, snapshots SCD2, modèles incrémentaux.
 
### Data Vault (nouveau)
- **3 Hubs** (`hub_client`, `hub_produit`, `hub_commande`) : identité pure, hash key calculée via `dbt_utils.generate_surrogate_key`, business key, `load_date`, `record_source`. `hub_client` couvre volontairement les **510 identités brutes** (avant le dédoublonnage de `stg_clients`), pas seulement les 500 survivants — un Hub ne fait jamais disparaître une identité rencontrée, même une identité qui s'avère être un doublon.
- **3 Links** : `link_vente` (N-aire, relie les 3 Hubs, grain d'une ligne de vente), `link_paiement` (rattaché au seul `hub_commande`, inclut les tentatives en retry), `link_client_same_as` (documente explicitement les 10 doublons clients de façon traçable et réversible, sans jamais fusionner silencieusement — contrairement à `int_correspondance_clients` côté Kimball, qui fait la même réconciliation mais en l'appliquant directement).
- **5 Satellites** : contexte descriptif + `hash_diff` (détection de changement), reconstruits systématiquement depuis la **source brute**, jamais depuis un mart Kimball déjà décidé — y compris `sat_client`, qui recalcule lui-même `nom_complet` (concaténation prénom+nom) plutôt que d'hériter de `stg_clients`.
- **9 tests d'intégrité** (`relationships` sur chaque hash key) : 8 PASS, 1 WARN documenté — 91 vraies commandes orphelines (référençant un `id_client` qui n'a jamais existé, même en brut), un chiffre plus précis que les 101 connus côté Kimball, qui mélangeaient doublons éliminés et vrais orphelins.
- **Coexiste avec Kimball**, sans le remplacer — les deux modélisations restent disponibles, chacune répondant à un besoin différent (restitution rapide vs audit/traçabilité).
### Portabilité multi-warehouse, Orchestration (3 niveaux), CI/CD, Conteneurisation
Voir chapitres précédents — inchangés par ce chantier.
 
### Graphe de connaissances, Serveur MCP, Power BI
Inchangés — branchés sur les marts Kimball, pas (encore) sur le Data Vault.
 
---
 
## 5. Démarrage rapide
 
```powershell
# Environnement
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
 
cd shop_ci_dbt
dbt deps   # installe dbt_utils
 
# --- Pipeline Kimball ---
dbt build --select marts staging intermediate --target bigquery_dev --full-refresh --exclude path:snapshots
 
# --- Data Vault ---
dbt build --select vault --target bigquery_dev --full-refresh --exclude path:snapshots
dbt test --select vault --target bigquery_dev
 
# --- Graphe, Dagster, Docker, CI/CD : voir chapitres précédents ---
```
 
---
 
## 6. Limitations connues et décisions assumées
 
- **Le Data Vault n'est pas (encore) branché sur le graphe, MCP, ou Power BI** — ces trois consommateurs restent sur les marts Kimball ; brancher le Data Vault dessus est une extension possible, non réalisée.
- **`hash_diff` calculé mais jamais exploité en historisation réelle** : avec un seul chargement de données, aucun Satellite n'a encore eu l'occasion de détecter un vrai changement — la mécanique est en place, sa valeur apparaîtra avec de vrais rechargements répétés.
- **Le Data Vault duplique une partie de la logique de nettoyage déjà présente en staging** (concaténation nom+prénom, cast des prix) plutôt que de la réutiliser — un compromis assumé : partir de la source brute protège contre l'héritage de décisions de *périmètre* (suppression, fusion), au prix de dupliquer les nettoyages *techniques* purs.
- **`link_client_same_as` documente la réconciliation sans jamais l'appliquer** — contrairement à Kimball, où `int_correspondance_clients` fusionne directement. Une future couche de restitution devrait explicitement consulter ce Link pour regrouper les identités si besoin.
- Voir les chapitres précédents pour les limitations BigQuery, Dagster, Docker déjà documentées.
---
 
## 7. Feuille de route
 
- [ ] MCP Power BI officiel (Microsoft) — connecter simultanément le serveur MCP Shop_CI et le serveur MCP Power BI Modeling
- [ ] Superset — restitution BI open source, alternative à Power BI
- [ ] OpenClaw — diffusion proactive de KPI et interrogation conversationnelle via Telegram (WhatsApp en extension prudente)
- [ ] Brancher le graphe/MCP/Power BI sur le Data Vault, en complément des marts Kimball
- [ ] Étendre `calculer_metrique` (MCP) pour couvrir `marge`
- [ ] Gouvernance/RGPD — application concrète non commencée
- [ ] Second projet dédié : packages dbt pour la certification (`dbt_expectations`, `dbt_project_evaluator`, `codegen`)
---
 
*Voir aussi : [WRITE_UP.md](./WRITE_UP.md), [DICTIONNAIRE.md](./DICTIONNAIRE.md), et [tests_pedagogiques/](./tests_pedagogiques/).*