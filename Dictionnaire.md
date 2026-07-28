# Dictionnaire — Shop_CI
 
Glossaire des termes techniques employés dans le projet, organisé par domaine. Document vivant.
 
---
 
## dbt & modélisation
 
**Modèle** — Une table ou vue produite par dbt.
 
**Membre inconnu (Unknown Member)** — Ligne spéciale (id = -1) accueillant les faits à clé étrangère orpheline.
 
**Contrat de modèle** — Verrouillage du nom, du type et du nombre de colonnes avant matérialisation.
 
**Modèle incrémental** — Matérialisation ne retraitant que les nouvelles lignes, avec upsert.
 
---
 
## Portabilité multi-warehouse (DuckDB ↔ BigQuery)
 
**Macro cross-database** — Fonction Jinja de dbt-core traduite automatiquement dans le bon dialecte SQL selon la cible active.
 
**`generate_schema_name`** — Macro déterminant le schéma cible réel selon la cible active, isolant dev et prod sur un même warehouse.
 
---
 
## Semantic Layer (MetricFlow)
 
**Métrique gouvernée** — Définition unique d'un indicateur métier, garantissant un chiffre cohérent partout — répliquée manuellement en SPARQL et en DAX dans Shop_CI.
 
---
 
## Graphe de connaissances (RDF / OWL / SPARQL)
 
**Triplet** — Un fait atomique *sujet → relation → objet*.
 
**SPARQL CONSTRUCT** — Fabrique de nouveaux triplets à partir d'un motif trouvé — le mécanisme de classification.
 
**Membre inconnu (graphe)** — `ClientNonIdentifie`, priorité absolue dans les règles de classification.
 
---
 
## Serveur MCP (Model Context Protocol)
 
**MCP** — Protocole standard permettant à un agent IA d'appeler des outils externes.
 
**Rechargement à la demande** — Relire une source à chaque appel d'outil plutôt qu'au démarrage.
 
---
 
## CI/CD (GitHub Actions)
 
**Workflow** — Fichier YAML décrivant quand et comment exécuter des tâches automatisées.
 
**Runner** — Machine virtuelle vierge prêtée par GitHub, détruite après chaque run.
 
**Règle de protection de branche** — Rend un status check obligatoire avant fusion.
 
---
 
## Power BI & intégration BI
 
**ODBC** — Protocole de connexion à une base de données, passage obligé pour DuckDB.
 
**`mart_decisions`** — Table plate réinjectant la classification du graphe.
 
**`.pbip`** — Format de sauvegarde éclatant le modèle en fichiers texte/JSON versionnables.
 
---
 
## Orchestration (Dagster)
 
**Asset** — Un objet de données (table, fichier) que Dagster sait construire, surveiller et relier à ses dépendances — l'unité de raisonnement centrale de Dagster, à la différence d'une simple suite de commandes.
 
**`dbt_assets`** — Décorateur de `dagster-dbt` qui découvre automatiquement chaque modèle dbt comme un asset, à partir du `manifest.json` — aucune redéclaration manuelle.
 
**`DbtCliResource`** — Ressource Dagster qui invoque `dbt` en ligne de commande, en respectant les mêmes flags qu'un run manuel (cible, `--full-refresh`, exclusions).
 
**Job** — Regroupement d'assets à exécuter ensemble (ex : tout le pipeline dbt en une fois).
 
**Schedule** — Déclencheur temporel d'un job, défini en syntaxe cron (ex : `0 6 * * *` = chaque jour à 6h) — l'équivalent Dagster d'une tâche planifiée Windows.
 
**`Definitions`** — L'objet racine qui enregistre ensemble les assets, jobs, schedules et ressources d'un projet Dagster, point d'entrée unique lu par `dagster dev`.
 
**Import qualifié vs relatif vs absolu (contexte Dagster)** — Dagster résout les modules Python locaux depuis le **répertoire de travail externe**, pas depuis le sous-dossier où vit réellement le fichier — d'où la nécessité d'un import qualifié complet (`from dagster_shop_ci.assets import ...`) plutôt qu'un simple `from assets import ...`.
 
**`DAGSTER_HOME`** — Variable d'environnement fixant l'emplacement persistant de l'historique des runs et de l'état des schedules ; sans elle, Dagster utilise un dossier temporaire effacé à chaque fermeture.
 
**Processus de premier plan** — Un serveur comme `dagster dev` reste attaché au terminal qui l'a lancé ; le fermer (ou fermer VS Code s'il l'héberge) arrête le serveur — comportement normal d'un outil de développement, pas un bug.
 
**Conflit de port (`Errno 10048`)** — Erreur signalant qu'un ancien processus (souvent mal arrêté, fenêtre fermée plutôt que Ctrl+C) occupe déjà le port qu'un nouveau serveur tente d'utiliser.