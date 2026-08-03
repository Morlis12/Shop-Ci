# Dictionnaire — Shop_CI
 
Glossaire des termes techniques employés dans le projet, organisé par domaine. Document vivant.
 
---
 
## dbt & modélisation générale
 
**Modèle** — Une table ou vue produite par dbt.
 
**Membre inconnu (Unknown Member)** — Ligne spéciale (id = -1) accueillant les faits à clé étrangère orpheline, convention Kimball.
 
**Macro cross-database** — Fonction Jinja traduite automatiquement selon la cible active (DuckDB, BigQuery).
 
---
 
## Data Vault (Hub / Link / Satellite)
 
**Hub** — Table contenant l'identité pure d'un concept métier ayant une existence indépendante (Client, Produit, Commande) : hash key, business key, `load_date`, `record_source` — jamais d'attribut descriptif.
 
**Test du "nom commun"** — Critère de choix d'un Hub : *"cette chose peut-elle exister et avoir un sens même si rien d'autre ne lui était jamais associé ?"* Si oui → Hub. Si l'existence dépend de la rencontre d'autres entités → Link.
 
**Link** — Table documentant une relation entre plusieurs Hubs (N-aire si plus de deux), au grain d'un événement (une vente, un paiement) ou d'une décision de rapprochement (same-as) — jamais de mesure.
 
**Link same-as** — Type de Link documentant qu'une entité doit être rapprochée d'une autre (ex. : deux `id_client` désignant la même personne), sans jamais fusionner les identités concernées — contrairement à une réconciliation Kimball classique, qui applique directement le rapprochement dans les marts finaux.
 
**Satellite** — Table portant le contexte descriptif (attributs qui varient) rattaché à un Hub ou un Link, avec un `hash_diff` permettant de détecter un changement entre deux chargements.
 
**`hash_diff`** — Hash calculé sur l'ensemble des attributs descriptifs d'un Satellite, recalculé à chaque étape d'ajout de colonne — sert à détecter efficacement si quelque chose a changé, sans comparer colonne par colonne.
 
**`dbt_utils.generate_surrogate_key([...])`** — Macro du package `dbt-utils` calculant une hash key déterministe à partir d'une ou plusieurs colonnes : la même entrée produit toujours le même hash, permettant des jointures stables entre Hubs, Links et Satellites.
 
**Data Vault part toujours du staging, jamais des marts** — Règle centrale : un mart Kimball contient déjà des décisions métier accumulées (re-routage, exclusions) ; construire le Data Vault par-dessus reviendrait à en hériter silencieusement plutôt que de garantir une couche d'audit indépendante.
 
**`load_date` / `record_source`** — Métadonnées obligatoires sur chaque table Data Vault : quand la ligne a été chargée, et de quel système source elle provient.
 
**Coexistence Kimball / Data Vault** — Les deux modélisations partagent le même staging mais restent indépendantes l'une de l'autre, répondant à des besoins différents (restitution rapide vs audit et traçabilité) plutôt que l'une remplaçant l'autre.
 
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
 
**Workflow / Runner / Règle de protection de branche** — Voir chapitres précédents.
 
---
 
## Orchestration (Dagster)
 
**Asset / `dbt_assets` / Job / Schedule / `DAGSTER_HOME`** — Voir chapitre Dagster.
 
---
 
## Conteneurisation (Docker)
 
**Image / Conteneur / `Dockerfile` / `.dockerignore` / Volume monté / Secret jamais copié dans l'image** — Voir chapitre Docker.
 
---
 
## Power BI & intégration BI
 
**ODBC / `.pbip` / Mesure DAX** — Voir chapitres précédents.
 