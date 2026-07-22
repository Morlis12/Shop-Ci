# Shop_CI — Plateforme Analytics Engineering de bout en bout
 
**dbt · DuckDB · MetricFlow · Power BI · Graphe de connaissances (RDF/OWL/SPARQL) · Serveur MCP · CI/CD GitHub Actions**
 
Projet pédagogique et portfolio construit de A à Z : d'un jeu de données brutes volontairement sales jusqu'à un agent IA capable d'interroger les décisions métier de l'entreprise en langage naturel, avec une chaîne CI/CD complète et une restitution Power BI.
 
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
  STAGING (vues)          — nettoyage 1-pour-1, typage, flags
        │
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
        │     GRAPHE DE CONNAISSANCES (RDF/OWL/SPARQL)
        │     ontologie → export → classification métier
        │           │
        │           ├──► SERVEUR MCP (4 outils) ──► Claude Desktop (agent IA)
        │           │
        │           └──► 04_ecrire_labels_duckdb.py ──► mart_decisions
        │                        │
        │                        ▼
        └──────────────────► POWER BI (ODBC, DAX répliquant le semantic layer)
 
CI/CD (GitHub Actions) : sur chaque Pull Request → dbt build/test → génération
du graphe → règle de protection de branche bloquant toute fusion non validée
```
 
L'orchestration locale (Windows Task Scheduler) exécute quotidiennement : fraîcheur des sources (sentinelle) → snapshots → build. La CI GitHub Actions, elle, valide chaque changement de code avant fusion, sur une machine neuve, indépendamment de l'état local.
 
---
 
## 3. Structure du dépôt
 
```
Shop Ci/
├── .github/
│   └── workflows/
│       └── ci.yml              # CI GitHub Actions : build, test, graphe
├── shop_ci_dbt/
│   ├── models/
│   │   ├── staging/            # nettoyage 1-pour-1
│   │   ├── intermediate/       # réconciliation clients
│   │   └── marts/              # dimensions, faits, marts de décision, semantic layer
│   ├── macros/                 # nettoyer_date.sql
│   ├── snapshots/              # SCD Type 2 (clients, produits)
│   ├── owl/                    # graphe de connaissances (généré, gitignoré)
│   │   ├── 01_schema.py        # ontologie : classes, sous-classes, propriétés
│   │   ├── 02_export.py        # peuplement des individus depuis DuckDB
│   │   ├── 03_classify.py      # classification par règles SPARQL CONSTRUCT
│   │   └── 04_ecrire_labels_duckdb.py  # réinjecte les labels dans DuckDB (mart_decisions)
│   ├── powerbi/                # modèle Power BI versionné (.pbip)
│   │   └── Shop_CI.pbip
│   └── dbt_project.yml
├── mcp/
│   └── serveur_mcp.py          # serveur MCP (4 outils, branché à Claude Desktop)
├── data_brute/                 # sources CSV versionnées
├── tests_pedagogiques/         # 18 tests HTML interactifs (révision, certification, entretien)
├── pipeline_quotidien.ps1      # orchestration Windows planifiée
├── requirements.txt
└── logs/                       # journaux d'exécution (gitignoré)
```
 
---
 
## 4. Fonctionnalités livrées
 
### Pipeline dbt
- **Staging** : dédoublonnage déterministe, macro `nettoyer_date` (cascade de formats non ambiguës), flags de qualité (paiements en retry, etc.)
- **Intermediate** : réconciliation des clients dédoublonnés vers un survivant unique
- **Marts Kimball** : grain explicite par table de faits, membre inconnu `id=-1` conservé (jamais de disparition silencieuse de CA)
- **Qualité** : 63+ data tests, 4 unit tests (dont un test du filtre incrémental avec mock de `{{ this }}`), contrats de modèle sur tous les marts, freshness (warn 12h / error 24h, volontairement non bloquante sur données fictives)
- **Historisation** : snapshots SCD Type 2 sur clients et produits
- **Performance** : deux tables de faits en incrémental, fenêtre de rattrapage de 3 jours
### Semantic Layer (MetricFlow)
6 métriques gouvernées, dont `ca_officiel` — LA définition de référence du chiffre d'affaires (exclut annulées/retournées).
 
### Orchestration locale
`pipeline_quotidien.ps1` : chemins absolus, exécutables de la venv appelés directement, journalisation horodatée (`Start-Transcript`), verdict par codes de sortie, fraîcheur volontairement exclue du jury final (décision documentée).
 
### CI/CD (GitHub Actions)
- Déclenchement automatique sur chaque Pull Request vers `main`
- Machine virtuelle neuve à chaque exécution : `dbt run` → `dbt test` → génération complète du graphe de connaissances (`01_schema.py` → `02_export.py` → `03_classify.py`)
- **Règle de protection de branche** active : `main` ne peut recevoir aucune fusion tant que la CI n'est pas verte — un vrai garde-fou structurel, pas un simple indicateur
- A révélé et corrigé en conditions réelles : un bug de mock de test invisible en local (colonne manquante dans le mock de `{{ this }}`), une dépendance Windows-only (`pywin32`) jamais nécessaire au projet, plusieurs chemins absolus non portables
### Graphe de connaissances
Architecture en 3 fichiers (patron ontologie / export / classification, inspiré d'un projet antérieur) :
- **Ontologie** : classes `Client`, `Produit`, `Vente` ; sous-classes de décision (`ClientVIP`, `ClientARisque`, `ClientNonIdentifie`, `ProduitStar`, `ProduitMargeFaible`...) documentées avec leur règle exacte
- **Export** : peuplement des individus réels depuis DuckDB (lecture seule), incluant désormais `aMargeVente` en plus du montant
- **Classification** : règles SPARQL `CONSTRUCT` appliquées par ordre de priorité, avec contrôle de cohérence automatisé (un seul label par entité)
- Résultat courant : 499 clients (47 VIP, 10 à risque, 6 nouveaux, 1 non identifié, 435 standards) · 20 produits (2 stars, 6 à marge faible, 12 standards)
### Serveur MCP
4 outils exposés à un agent IA (Claude Desktop) : `interroger_graphe` (SPARQL libre), `lister_categorie`, `expliquer_categorie`, `calculer_metrique`. Branché et validé en conditions réelles.
 
### Power BI
- Connexion **ODBC** vers `dev.duckdb` (aucun connecteur natif DuckDB, passage obligé par le pilote ODBC officiel)
- Script `04_ecrire_labels_duckdb.py` : réinjecte la classification du graphe (499+20 lignes) dans DuckDB sous forme de table plate `mart_decisions(entity_type, entity_id, label)`, consommable sans SPARQL
- Modèle relationnel en étoile autour de `fait_ventes`, avec deux requêtes filtrées (`decisions_clients`, `decisions_produits`) dérivées de `mart_decisions` pour éviter toute ambiguïté de jointure entre identifiants clients et produits
- Mesures DAX répliquant fidèlement le semantic layer : `ca_officiel`, `marge`, `taux_marge`, `nb_commandes_officiel`, `panier_moyen` — même filtre (hors annulées/retournées) que MetricFlow et le graphe
- Format de sauvegarde **`.pbip`** (Power BI Project) plutôt que `.pbix` : éclate le modèle en fichiers texte/JSON versionnables et diff-ables dans Git, contrairement au binaire opaque `.pbix`
---
 
## 5. Démarrage rapide
 
```powershell
# Environnement
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
 
# Pipeline dbt
cd shop_ci_dbt
dbt build
dbt docs generate
 
# Semantic layer
mf query --metrics ca_officiel
 
# Graphe de connaissances (depuis owl/, dans l'ordre)
cd owl
python 01_schema.py
python 02_export.py
python 03_classify.py
python 04_ecrire_labels_duckdb.py   # réinjecte les labels pour Power BI
 
# CI/CD : toute Pull Request vers main déclenche automatiquement
# .github/workflows/ci.yml (build, test, génération du graphe)
```
 
Le serveur MCP se configure dans `claude_desktop_config.json` (voir section Limitations pour une contrainte connue). Power BI se connecte via ODBC (DSN `dev.duckdb`, pilote officiel DuckDB) — voir la section Limitations pour un piège de configuration fréquent.
 
---
 
## 6. Limitations connues et décisions assumées
 
- **Mono-écrivain DuckDB** : un seul processus peut écrire/lire de façon exclusive à la fois. Contrainte rencontrée à plusieurs reprises (processus Python zombies, Power BI ouvrant plusieurs connexions parallèles au chargement) ; résolue en désactivant le chargement parallèle des tables dans Power BI, et par une vigilance systématique sur les processus en arrière-plan. En production réelle, résolue par un warehouse client-serveur (Postgres, etc.).
- **Fraîcheur non bloquante** : les données fictives s'arrêtent en 2025, la fraîcheur déclencherait systématiquement une erreur ; exclue volontairement du verdict final du pipeline (documenté dans le script).
- **MetricFlow non invocable en sous-processus depuis le serveur MCP** : Claude Desktop (version Windows Store) tourne dans un environnement sandboxé (AppContainer) qui bloque la création de processus enfants et certaines opérations bas niveau (gestion de signal). Contournement : `calculer_metrique` calcule `ca_officiel` directement via une requête SPARQL sur le graphe — résultat rigoureusement identique au semantic layer car le même filtre (hors annulées/retournées) est appliqué dès l'export du graphe. `marge` n'a pas encore ce contournement : la propriété a été ajoutée à l'export du graphe, mais l'outil MCP ne l'exploite pas encore.
- **Trois consommateurs, une seule vérité — mais reproduite, pas partagée** : `ca_officiel` est défini une fois dans `_semantic.yml`, mais répliqué manuellement en DAX pour Power BI et en SPARQL pour le graphe, faute d'un vrai Semantic Layer hébergé unique interrogé par tous. Le jour où la définition change, il faut la corriger aux trois endroits — un risque de divergence assumé et documenté, pas résolu.
- **CI/CD sans `state:modified`** : chaque exécution reconstruit l'intégralité du projet depuis zéro, plutôt que de ne retraiter que les modèles modifiés — un luxe technique absent, largement suffisant à l'échelle de Shop_CI.
- **Graphe régénéré, non temps réel** : le `.ttl` est une photo au moment de l'exécution des scripts `owl/`. Le serveur MCP recharge ce fichier à chaque appel (pas de cache), mais le graphe lui-même n'est pas encore intégré au pipeline quotidien planifié — étape restant à faire.
- **Piège de configuration ODBC/Power BI documenté** : le champ "Database" du DSN DuckDB peut se corrompre silencieusement (caractères parasites, chemins concaténés au dossier d'installation de Power BI) — toujours resaisir le chemin proprement en cas d'erreur `SQLDriverConnect` peu claire.
---
 
## 7. Feuille de route
 
- [ ] Livrable interactif pour 8 clients fictifs — **évalué et volontairement écarté** : la version réaliste (sans chat IA en direct, pour éviter d'exposer une clé API côté client) apportait trop peu de valeur d'ingénierie analytics par rapport à son coût de construction
- [ ] Étendre `calculer_metrique` (MCP) pour couvrir `marge` en plus de `ca_officiel`, maintenant que la propriété est exportée dans le graphe
- [ ] Intégrer la régénération du graphe (`owl/`) et de `mart_decisions` au `pipeline_quotidien.ps1`, après le `dbt build`
- [ ] Data Vault — chantier théorique exploré (test dédié), implémentation réelle (hub/link/satellite sur clients-commandes) non commencée
- [ ] Gouvernance/RGPD — chantier théorique exploré (test dédié), application concrète (classification `meta: {pii: true}`, éventuel hashing) non commencée
- [ ] Serveurs MCP officiels Power BI (Microsoft, confirmés à Ignite 2025) — piste explorée en discussion, non implémentée : un agent IA orchestrant simultanément le serveur MCP Shop_CI et le serveur MCP Power BI Modeling pour créer des mesures DAX depuis le langage naturel
---
 
*Voir aussi : [WRITE_UP.md](./WRITE_UP.md) pour le récit du projet, [DICTIONNAIRE.md](./DICTIONNAIRE.md) pour le glossaire des termes techniques, et [tests_pedagogiques/](./tests_pedagogiques/) pour 18 modules de révision interactifs couvrant l'intégralité du projet.*