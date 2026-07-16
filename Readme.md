# Shop_CI — Plateforme Analytics Engineering de bout en bout
 
**dbt · DuckDB · MetricFlow · Power BI · Graphe de connaissances (RDF/OWL/SPARQL) · Serveur MCP**
 
Projet pédagogique et portfolio construit de A à Z : d'un jeu de données brutes volontairement sales jusqu'à un agent IA capable d'interroger les décisions métier de l'entreprise en langage naturel.
 
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
        │           ▼
        │     SERVEUR MCP (4 outils) ──► Claude Desktop (agent IA)
        │
        └──► Power BI *(à venir)*
```
 
L'orchestration (Windows Task Scheduler) exécute quotidiennement : fraîcheur des sources (sentinelle) → snapshots → build.
 
---
 
## 3. Structure du dépôt
 
```
Shop Ci/
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
│   │   └── 03_classify.py      # classification par règles SPARQL CONSTRUCT
│   └── dbt_project.yml
├── mcp/
│   └── serveur_mcp.py          # serveur MCP (4 outils, branché à Claude Desktop)
├── data_brute/                 # sources CSV versionnées
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
 
### Orchestration
`pipeline_quotidien.ps1` : chemins absolus, exécutables de la venv appelés directement, journalisation horodatée (`Start-Transcript`), verdict par codes de sortie, fraîcheur volontairement exclue du jury final (décision documentée).
 
### Graphe de connaissances
Architecture en 3 fichiers (patron ontologie / export / classification, inspiré d'un projet antérieur) :
- **Ontologie** : classes `Client`, `Produit`, `Vente` ; sous-classes de décision (`ClientVIP`, `ClientARisque`, `ClientNonIdentifie`, `ProduitStar`, `ProduitMargeFaible`...) documentées avec leur règle exacte
- **Export** : peuplement des individus réels depuis DuckDB (lecture seule)
- **Classification** : règles SPARQL `CONSTRUCT` appliquées par ordre de priorité, avec contrôle de cohérence automatisé (un seul label par entité)
- Résultat courant : 499 clients (47 VIP, 10 à risque, 6 nouveaux, 1 non identifié, 435 standards) · 20 produits (2 stars, 6 à marge faible, 12 standards)
### Serveur MCP
4 outils exposés à un agent IA (Claude Desktop) : `interroger_graphe` (SPARQL libre), `lister_categorie`, `expliquer_categorie`, `calculer_metrique`. Branché et validé en conditions réelles.
 
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
```
 
Le serveur MCP se configure dans `claude_desktop_config.json` (voir section Limitations pour une contrainte connue).
 
---
 
## 6. Limitations connues et décisions assumées
 
- **Mono-écrivain DuckDB** : un seul processus peut écrire/lire de façon exclusive à la fois. Contrainte structurelle d'une base embarquée ; résolue en production par un warehouse client-serveur (Postgres, etc.).
- **Fraîcheur non bloquante** : les données fictives s'arrêtent en 2025, la fraîcheur déclencherait systématiquement une erreur ; exclue volontairement du verdict final du pipeline (documenté dans le script).
- **MetricFlow non invocable en sous-processus depuis le serveur MCP** : Claude Desktop (version Windows Store) tourne dans un environnement sandboxé (AppContainer) qui bloque la création de processus enfants et certaines opérations bas niveau (gestion de signal). Contournement : `calculer_metrique` calcule `ca_officiel` directement via une requête SPARQL sur le graphe — résultat rigoureusement identique au semantic layer car le même filtre (hors annulées/retournées) est appliqué dès l'export du graphe. *Porte de sortie identifiée : un Semantic Layer hébergé (dbt Cloud, appel HTTP) échapperait structurellement à cette contrainte.*
- **Graphe régénéré, non temps réel** : le `.ttl` est une photo au moment de l'exécution des 3 scripts `owl/`. Le serveur MCP recharge ce fichier à chaque appel (pas de cache), donc toute régénération est immédiatement visible sans redémarrage — mais le graphe n'est pas automatiquement mis à jour en continu (intégration au pipeline planifié à faire).
---
 
## 7. Feuille de route
 
- [ ] Livrable interactif pour 8 clients fictifs (architecture à trancher)
- [ ] Power BI : connexion, cohérence avec le semantic layer, versionnage `.pbip`
- [ ] Intégration de la régénération du graphe au pipeline quotidien
- [ ] Data Vault : hub/link/satellites, comparaison avec les snapshots SCD2
- [ ] Section orchestration enrichie (GitHub Actions, chemin vers un warehouse client-serveur)
---
 
*Voir aussi : [WRITE_UP.md](./WRITE_UP.md) pour le récit du projet et [DICTIONNAIRE.md](./DICTIONNAIRE.md) pour le glossaire des termes techniques.*