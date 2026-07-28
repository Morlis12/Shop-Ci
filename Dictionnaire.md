# Dictionnaire — Shop_CI
 
Glossaire des termes techniques employés dans le projet, organisé par domaine. Document vivant.
 
---
 
## dbt & modélisation
 
**Modèle** — Une table ou vue produite par dbt.
 
**Membre inconnu (Unknown Member)** — Ligne spéciale (id = -1) accueillant les faits à clé étrangère orpheline.
 
**Macro cross-database** — Fonction Jinja traduite automatiquement selon la cible active (DuckDB, BigQuery).
 
---
 
## Semantic Layer (MetricFlow)
 
**Métrique gouvernée** — Définition unique d'un indicateur métier, répliquée manuellement en SPARQL et en DAX dans Shop_CI.
 
---
 
## Graphe de connaissances (RDF / OWL / SPARQL)
 
**Triplet** — Un fait atomique *sujet → relation → objet*.
 
**SPARQL CONSTRUCT** — Fabrique de nouveaux triplets à partir d'un motif trouvé.
 
---
 
## Serveur MCP
 
**MCP** — Protocole standard permettant à un agent IA d'appeler des outils externes.
 
---
 
## CI/CD (GitHub Actions)
 
**Workflow** — Fichier YAML décrivant quand et comment exécuter des tâches automatisées.
 
**Runner** — Machine virtuelle vierge prêtée par GitHub, détruite après chaque run.
 
**Règle de protection de branche** — Rend un status check obligatoire avant fusion.
 
---
 
## Orchestration (Dagster)
 
**Asset** — Objet de données que Dagster sait construire, surveiller et relier à ses dépendances.
 
**`dbt_assets`** — Découverte automatique des modèles dbt comme assets, via `manifest.json`.
 
**Job / Schedule** — Regroupement d'assets à exécuter ensemble / déclencheur temporel en syntaxe cron.
 
**`DAGSTER_HOME`** — Variable d'environnement fixant la persistance de l'historique des runs.
 
---
 
## Power BI & intégration BI
 
**ODBC** — Protocole de connexion à une base de données.
 
**`.pbip`** — Format de sauvegarde éclatant le modèle Power BI en fichiers texte/JSON versionnables.
 
---
 
## Conteneurisation (Docker)
 
**Image** — Un artefact figé contenant un environnement complet (OS minimal, dépendances, code) — le "plan de construction" d'un conteneur.
 
**Conteneur** — Une instance en cours d'exécution d'une image, isolée du système hôte.
 
**`Dockerfile`** — Fichier texte décrivant, étape par étape, comment construire une image (`FROM`, `COPY`, `RUN`, `CMD`...).
 
**`.dockerignore`** — Liste des fichiers/dossiers à exclure lors de la construction de l'image — exactement l'équivalent de `.gitignore`, appliqué à Docker.
 
**Couche (layer) Docker** — Chaque instruction du Dockerfile produit une couche mise en cache ; réordonner les instructions (dépendances avant code) évite de réinstaller inutilement à chaque modification du code.
 
**Volume monté (`docker run -v`)** — Pont temporaire entre un chemin local et un chemin dans le conteneur, actif uniquement pendant l'exécution — jamais copié dans l'image elle-même.
 
**Secret jamais copié dans l'image** — Principe de sécurité : un secret (clé API, credentials) ne doit jamais apparaître dans une instruction `COPY` ou `ENV` contenant sa vraie valeur, seulement injecté au lancement via un volume.
 
**`SecretsUsedInArgOrEnv`** — Avertissement Docker signalant qu'une variable `ENV`/`ARG` au nom évocateur (ex : `*CREDENTIALS*`) pourrait contenir un secret — à vérifier au cas par cas : un chemin de fichier vers un secret monté n'est pas le secret lui-même.
 
**Image autosuffisante** — Une image qui ne dépend d'aucune configuration externe à l'exécution (hormis les secrets injectés) — ici, `profiles.yml` généré directement dans l'image plutôt que monté depuis l'extérieur.
 
**Reproductibilité multi-environnement** — La preuve qu'un même pipeline produit un résultat identique sur plusieurs environnements totalement indépendants (local, CI/CD, conteneur) — la démonstration la plus forte de fiabilité construite dans Shop_CI.
 