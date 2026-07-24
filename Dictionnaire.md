Dictionnaire · MD
# Dictionnaire — Shop_CI
 
Glossaire des termes techniques employés dans le projet, organisé par domaine. Document vivant, complété au fil des chantiers.
 
---
 
## dbt & modélisation
 
**Modèle** — Une table ou vue produite par dbt (staging, intermediate, mart).
 
**Staging** — Couche de nettoyage 1-pour-1 : une source = un modèle staging. Typage, normalisation, flags de qualité. Ne croise jamais deux sources.
 
**Intermediate** — Couche de logique inter-tables, réutilisable par plusieurs marts. Exemple : `int_correspondance_clients`, qui re-route les commandes des clients dédoublonnés.
 
**Mart** — Interface publique consommée par le BI, le semantic layer, ou l'IA. Seule couche exposée aux consommateurs finaux.
 
**Grain** — La définition précise de ce que représente une ligne d'une table de faits. Première décision à prendre en modélisation Kimball.
 
**Membre inconnu (Unknown Member)** — Convention Kimball : une ligne spéciale dans une dimension (id = -1) qui accueille les faits dont la clé étrangère est orpheline.
 
**Mock (simulacre)** — Donnée factice fabriquée pour remplacer une vraie source le temps d'un test, contenant uniquement les colonnes réellement lues par le code testé.
 
**Contrat de modèle (`contract: enforced`)** — Verrouillage du nom, du type et du nombre de colonnes d'un modèle avant sa matérialisation.
 
**Snapshot** — Objet dbt à mémoire, historisant les changements d'une table source selon le pattern SCD Type 2, insert-only.
 
**Modèle incrémental** — Matérialisation qui ne retraite que les nouvelles lignes à chaque exécution, avec une clé unique pour gérer les mises à jour (upsert).
 
---
 
## Portabilité multi-warehouse (DuckDB ↔ BigQuery)
 
**Macro cross-database** — Fonction Jinja fournie par dbt-core (namespace `dbt.`) qui se traduit automatiquement dans le bon dialecte SQL selon la cible active — un seul code source, un comportement correct sur plusieurs moteurs.
 
**`dbt.type_string()` / `dbt.type_int()`** — Types de données universels : se traduisent en `varchar`/`integer` sur DuckDB, `STRING`/`INT64` sur BigQuery.
 
**`dbt.safe_cast(valeur, type)`** — Conversion de type tolérante aux erreurs, portable, équivalent cross-database de `try_cast`.
 
**`dbt.split_part()` / `dbt.dateadd()`** — Fonctions de manipulation de texte/date universelles, évitant d'appeler une fonction propre à un seul moteur.
 
**Routage conditionnel Jinja (`{% if target.type == '...' %}`)** — Bascule entre deux implémentations natives dans le même fichier, utilisé quand aucune macro cross-database générique n'existe pour un cas précis (ex : génération de calendrier).
 
**Limite du parsing YAML** — L'objet Jinja `dbt` (et ses macros) n'existe qu'au moment de la compilation SQL, pas au moment du parsing des fichiers de contrat (`schema.yml`) — d'où l'usage de types SQL standards en dur (`int64`, `string`) dans les contrats plutôt que de macros.
 
**Ordre d'exécution SQL strict (BigQuery)** — Contrairement à DuckDB, BigQuery interdit de filtrer un `WHERE` sur un alias défini dans le même `SELECT` — il faut filtrer sur la colonne source réelle.
 
**`generate_schema_name`** — Macro surchargeable qui détermine le schéma cible réel d'un modèle selon la cible active (`target.name`), garantissant l'isolation entre dev et prod sur un même warehouse.
 
**Ingestion CSV → cloud (`charger_csv_bigquery.py`)** — Script maison dans l'esprit d'un outil d'ingestion (type Fivetran) : lit les CSV locaux, force toutes les colonnes en `STRING`, pousse physiquement les données comme tables dans le dataset cloud — nécessaire car un warehouse cloud n'a pas de notion de "fichier local à lire à la volée".
 
**Palier gratuit BigQuery (sandbox)** — Mode sans carte bancaire interdisant les requêtes DML/MERGE, bloquant nativement les modèles incrémentaux et les snapshots — contrainte temporaire d'environnement, pas une limite du code.
 
---
 
## Semantic Layer (MetricFlow)
 
**Métrique gouvernée** — Définition unique et centralisée d'un indicateur métier (ex. : `ca_officiel`), garantissant que tous les consommateurs obtiennent le même chiffre — répliquée manuellement en SPARQL et en DAX dans Shop_CI, faute d'un Semantic Layer hébergé unique.
 
**Métrique simple / ratio / dérivée** — Trois types de métriques MetricFlow.
 
**Time spine** — Table calendrier déclarée comme référence temporelle pour les agrégations.
 
---
 
## Graphe de connaissances (RDF / OWL / SPARQL)
 
**Triplet** — Un fait atomique de la forme *sujet → relation → objet*.
 
**Ontologie** — Déclaration des classes et relations autorisées dans un graphe.
 
**ObjectProperty** — Relation qui relie un individu à un autre individu, permettant les traversées à plusieurs sauts (ex. : Client → Vente → Produit).
 
**SPARQL SELECT / CONSTRUCT** — SELECT interroge et affiche ; CONSTRUCT fabrique de nouveaux triplets à partir d'un motif trouvé.
 
**FILTER NOT EXISTS** — Exclut les résultats pour lesquels un motif secondaire existe déjà — cascade de priorité des règles de classification.
 
**Chemin de propriété (`+`, `*`, `/`, `|`)** — Rendent une relation transitive, chaînée, ou alternative sans réécrire plusieurs triplets.
 
**Membre inconnu (graphe)** — Équivalent Kimball transposé au graphe : la classe `ClientNonIdentifie`, priorité absolue dans les règles de classification.
 
---
 
## Serveur MCP (Model Context Protocol)
 
**MCP** — Protocole standard permettant à un agent IA d'appeler des outils externes exposés par un serveur local ou distant.
 
**Outil (`@mcp.tool()`)** — Fonction Python transformée en capacité appelable par l'agent IA ; sa docstring sert de description à l'IA.
 
**Rechargement à la demande** — Pattern consistant à relire une source de données à chaque appel d'outil plutôt qu'une seule fois au démarrage.
 
**Sandboxing / AppContainer** — Mécanisme d'isolation Windows restreignant certaines opérations système pour des raisons de sécurité.
 
---
 
## Méthodologie de diagnostic
 
**Doute méthodique** — Ne jamais supposer la cause d'un problème, mais la vérifier systématiquement par un test isolé et reproductible.
 
**Reproduire avant de blâmer** — Reproduire manuellement le comportement d'un outil externe complexe avant de l'accuser d'un dysfonctionnement.
 
**Environnement neuf comme révélateur** — Une machine vierge (CI, nouvel utilisateur, nouveau warehouse) expose des dépendances cachées à un état local qu'on ne remarque jamais en travaillant toujours sur le même moteur.
 
---
 
## CI/CD (GitHub Actions)
 
**Workflow** — Fichier YAML (`.github/workflows/`) décrivant quand et comment exécuter des tâches automatisées.
 
**Runner** — Machine virtuelle entièrement vierge prêtée par GitHub pour exécuter le workflow, détruite après chaque run.
 
**`on: pull_request`** — Déclencheur qui lance le workflow à chaque ouverture ou mise à jour d'une Pull Request.
 
**Dépendance transitive** — Un paquet requis non pas directement par le code, mais par un autre paquet dont on dépend.
 
**Chemin relatif vs absolu — le vrai critère** — Absolu si le processus est démarré par un tiers sans contrôle du dossier de départ. Relatif si le script est lancé manuellement depuis un dossier connu.
 
**Règle de protection de branche** — Configuration GitHub rendant un status check obligatoire avant fusion.
 
---
 
## Power BI & intégration BI
 
**ODBC (Open Database Connectivity)** — Protocole standard de connexion à une base de données ; passage obligé pour connecter Power BI à DuckDB.
 
**DSN (Data Source Name)** — Configuration nommée d'une connexion ODBC.
 
**`mart_decisions`** — Table plate réinjectant la classification du graphe dans DuckDB, consommable par tout outil SQL/BI sans SPARQL.
 
**Chargement en parallèle des tables** — Comportement par défaut de Power BI ouvrant plusieurs connexions simultanées ; à désactiver face à une base mono-écrivain.
 
**`.pbip` (Power BI Project)** — Format de sauvegarde éclatant le modèle en fichiers texte/JSON versionnables.
 
**Mesure DAX** — Calcul défini dans le modèle Power BI, traduction manuelle d'une métrique du semantic layer.
 
**`DIVIDE()`** — Fonction DAX de division sécurisée, avec une valeur de repli explicite en cas de division par zéro.