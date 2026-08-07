# Dictionnaire — Shop_CI
 
Glossaire des termes techniques employés dans le projet, organisé par domaine. Document vivant, complété au fil des chantiers.
 
---
 
## dbt & modélisation générale
 
**Modèle** — Une table ou vue produite par dbt (staging, intermediate, mart, vault).
 
**Staging** — Couche de nettoyage 1-pour-1 : une source = un modèle staging. Typage, normalisation, flags de qualité. Ne croise jamais deux sources.
 
**Intermediate** — Couche de logique inter-tables, réutilisable par plusieurs marts. Exemple : `int_correspondance_clients`, qui re-route les commandes des clients dédoublonnés.
 
**Mart** — Interface publique consommée par le BI, le semantic layer, ou l'IA.
 
**Grain** — La définition précise de ce que représente une ligne d'une table de faits.
 
**Membre inconnu (Unknown Member)** — Convention Kimball : une ligne spéciale dans une dimension (id = -1) qui accueille les faits dont la clé étrangère est orpheline.
 
**Mock (simulacre)** — Donnée factice fabriquée pour remplacer une vraie source le temps d'un test, contenant uniquement les colonnes réellement lues par le code testé.
 
**Contrat de modèle (`contract: enforced`)** — Verrouillage du nom, du type et du nombre de colonnes d'un modèle avant sa matérialisation.
 
**Snapshot** — Objet dbt à mémoire, historisant les changements d'une table source selon le pattern SCD Type 2, insert-only.
 
**Modèle incrémental** — Matérialisation qui ne retraite que les nouvelles lignes à chaque exécution, avec une clé unique pour gérer les mises à jour (upsert).
 
---
 
## Portabilité multi-warehouse (DuckDB ↔ BigQuery)
 
**Macro cross-database** — Fonction Jinja fournie par dbt-core (namespace `dbt.`) qui se traduit automatiquement dans le bon dialecte SQL selon la cible active.
 
**`dbt.type_string()` / `dbt.type_int()`** — Types de données universels : `varchar`/`integer` sur DuckDB, `STRING`/`INT64` sur BigQuery.
 
**`dbt.safe_cast(valeur, type)`** — Conversion de type tolérante aux erreurs, équivalent cross-database de `try_cast`.
 
**`dbt.split_part()` / `dbt.dateadd()`** — Fonctions de manipulation de texte/date universelles.
 
**Routage conditionnel Jinja (`{% if target.type == '...' %}`)** — Bascule entre deux implémentations natives dans le même fichier `.sql`, utilisé quand aucune macro cross-database générique n'existe.
 
**Limite du Jinja structurel en YAML** — Contrairement aux fichiers `.sql`, un fichier `.yml` de dbt n'a pas un support Jinja complet : on peut y substituer une valeur simple, pas y ajouter/retirer des clés entières selon une condition — d'où l'échec d'un `{% if %}` structurel directement dans `_sources.yml`.
 
**Limite du parsing YAML (macros indisponibles)** — L'objet Jinja `dbt` (et ses macros) n'existe qu'au moment de la compilation SQL, pas au moment du parsing des fichiers de contrat (`schema.yml`) — d'où l'usage de types SQL standards en dur (`int64`, `string`) dans les contrats.
 
**Ordre d'exécution SQL strict (BigQuery)** — Contrairement à DuckDB, BigQuery interdit de filtrer un `WHERE` sur un alias défini dans le même `SELECT`.
 
**`generate_schema_name`** — Macro surchargeable qui détermine le schéma cible réel d'un modèle selon la cible active, garantissant l'isolation entre dev et prod sur un même warehouse.
 
**Ingestion CSV → cloud (`charger_csv_bigquery.py`)** — Script maison dans l'esprit d'un outil d'ingestion (type Fivetran) : lit les CSV locaux, force toutes les colonnes en `STRING`, pousse physiquement les données comme tables dans le dataset cloud.
 
**Palier gratuit BigQuery (sandbox)** — Mode sans carte bancaire interdisant les requêtes DML/MERGE, bloquant nativement les modèles incrémentaux et les snapshots.
 
**Load job vs requête DML** — Un chargement complet de données (`WRITE_TRUNCATE` via `load_table_from_dataframe`) est autorisé sur le sandbox gratuit ; une modification en place (`MERGE`/`UPDATE`) ne l'est pas — distinction confirmée empiriquement, pas supposée.
 
---
 
## Semantic Layer (MetricFlow)
 
**Métrique gouvernée** — Définition unique et centralisée d'un indicateur métier (ex. : `ca_officiel`), répliquée manuellement en SPARQL et en DAX dans Shop_CI, faute d'un Semantic Layer hébergé unique.
 
**Métrique simple / ratio / dérivée** — Trois types de métriques MetricFlow.
 
**Time spine** — Table calendrier déclarée comme référence temporelle pour les agrégations.
 
---
 
## Graphe de connaissances (RDF / OWL / SPARQL)
 
**Triplet** — Un fait atomique de la forme *sujet → relation → objet*.
 
**Ontologie** — Déclaration des classes et relations autorisées dans un graphe.
 
**ObjectProperty** — Relation qui relie un individu à un autre individu, permettant les traversées à plusieurs sauts.
 
**SPARQL SELECT / CONSTRUCT** — SELECT interroge et affiche ; CONSTRUCT fabrique de nouveaux triplets à partir d'un motif trouvé — le mécanisme d'inférence utilisé pour la classification.
 
**FILTER NOT EXISTS** — Exclut les résultats pour lesquels un motif secondaire existe déjà — utilisé pour la cascade de priorité des règles de classification.
 
**Chemin de propriété (`+`, `*`, `/`, `|`)** — Rendent une relation transitive, chaînée, ou alternative sans réécrire plusieurs triplets.
 
**Membre inconnu (graphe)** — La classe `ClientNonIdentifie`, priorité absolue dans les règles de classification.
 
**Patron en 4 fichiers** — Ontologie (`01_schema.py`) → Export (`02_export.py`) → Classification (`03_classify.py`) → Réinjection (`04_ecrire_labels_BigQuery.py`), chacun avec une seule responsabilité, testable indépendamment.
 
---
 
## Serveur MCP (Model Context Protocol)
 
**MCP** — Protocole standard permettant à un agent IA d'appeler des outils externes exposés par un serveur local ou distant.
 
**Outil (`@mcp.tool()`)** — Fonction Python transformée en capacité appelable par l'agent IA ; sa docstring sert de description à l'IA pour savoir quand l'utiliser.
 
**Rechargement à la demande** — Pattern consistant à relire une source de données à chaque appel d'outil plutôt qu'une seule fois au démarrage.
 
**Sandboxing / AppContainer** — Mécanisme d'isolation Windows restreignant certaines opérations système (création de processus enfants) pour des raisons de sécurité — la cause du contournement MetricFlow.
 
**Deux serveurs MCP simultanés** — `claude_desktop_config.json` peut déclarer plusieurs serveurs dans le même bloc `mcpServers` ; Claude voit alors tous leurs outils combinés dans une seule session.
 
---
 
## Méthodologie de diagnostic
 
**Doute méthodique** — Ne jamais supposer la cause d'un problème, mais la vérifier systématiquement par un test isolé et reproductible.
 
**Reproduire avant de blâmer** — Reproduire manuellement le comportement d'un outil externe complexe avant de l'accuser d'un dysfonctionnement.
 
**Environnement neuf comme révélateur** — Une machine vierge (CI, nouvel utilisateur, nouveau warehouse) expose des dépendances cachées à un état local qu'on ne remarque jamais en travaillant toujours sur la même machine.
 
**Vérification hors-agent** — Confirmer une action affirmée par un agent IA en l'observant directement dans l'outil concerné, plutôt que de se fier uniquement à sa déclaration.
 
---
 
## CI/CD (GitHub Actions)
 
**Workflow** — Fichier YAML (`.github/workflows/`) décrivant quand et comment exécuter des tâches automatisées ; doit impérativement être à la racine du dépôt.
 
**Runner** — Machine virtuelle entièrement vierge prêtée par GitHub pour exécuter le workflow, détruite après chaque run.
 
**`on: pull_request`** — Déclencheur qui lance le workflow à chaque ouverture ou mise à jour d'une Pull Request.
 
**`working-directory`** — Précise depuis quel sous-dossier une étape s'exécute, indépendamment de la racine du repo.
 
**Dépendance transitive** — Un paquet requis non pas directement par le code, mais par un autre paquet dont on dépend (ex. : `pywin32`, requis par `mcp` sur Windows uniquement).
 
**Marqueur PEP 508** — Syntaxe conditionnelle dans `requirements.txt` pour installer un paquet selon la plateforme — pas toujours suffisante en pratique.
 
**Chemin relatif vs absolu — le vrai critère** — Absolu si le processus est démarré par un tiers sans contrôle du dossier de départ. Relatif si le script est lancé manuellement depuis un dossier connu.
 
**Status check** — Le résultat (✅/❌) d'un job CI affiché sur une Pull Request. Sans règle de protection, un simple indicateur ignorable.
 
**Règle de protection de branche** — Configuration GitHub rendant un status check obligatoire avant fusion.
 
---
 
## Orchestration (Dagster)
 
**Asset** — Un objet de données que Dagster sait construire, surveiller et relier à ses dépendances — l'unité de raisonnement centrale, à la différence d'une simple suite de commandes.
 
**`dbt_assets`** — Décorateur de `dagster-dbt` qui découvre automatiquement chaque modèle dbt comme un asset, à partir du `manifest.json`.
 
**`DbtCliResource`** — Ressource Dagster qui invoque `dbt` en ligne de commande, en respectant les mêmes flags qu'un run manuel.
 
**Job** — Regroupement d'assets à exécuter ensemble (`define_asset_job`).
 
**Schedule** — Déclencheur temporel d'un job, en syntaxe cron (`0 6 * * *` = chaque jour à 6h).
 
**`Definitions`** — L'objet racine qui enregistre ensemble assets, jobs, schedules et ressources.
 
**Résolution de module (Dagster)** — Dagster résout les imports locaux depuis le répertoire de travail **externe**, pas depuis le sous-dossier interne du fichier — d'où la nécessité d'un import qualifié (`from dagster_shop_ci.assets import ...`).
 
**`DAGSTER_HOME`** — Variable d'environnement fixant l'emplacement persistant de l'historique des runs et de l'état des schedules ; sans elle, dossier temporaire effacé à chaque fermeture.
 
**Processus de premier plan** — Un serveur comme `dagster dev` reste attaché au terminal qui l'a lancé ; le fermer arrête le serveur.
 
**Conflit de port (`Errno 10048`)** — Erreur signalant qu'un ancien processus, mal arrêté, occupe déjà le port qu'un nouveau serveur tente d'utiliser.
 
---
 
## Conteneurisation (Docker)
 
**Image** — Un artefact figé contenant un environnement complet — le "plan de construction" d'un conteneur.
 
**Conteneur** — Une instance en cours d'exécution d'une image, isolée du système hôte.
 
**`Dockerfile`** — Fichier texte décrivant, étape par étape, comment construire une image (`FROM`, `COPY`, `RUN`, `CMD`...).
 
**`.dockerignore`** — Liste des fichiers/dossiers à exclure lors de la construction de l'image — équivalent de `.gitignore` pour Docker.
 
**Couche (layer) Docker** — Chaque instruction du Dockerfile produit une couche mise en cache ; réordonner les instructions (dépendances avant code) évite de réinstaller inutilement.
 
**Volume monté (`docker run -v`)** — Pont temporaire entre un chemin local et un chemin dans le conteneur, actif uniquement pendant l'exécution — jamais copié dans l'image.
 
**Secret jamais copié dans l'image** — Principe de sécurité : un secret ne doit jamais apparaître dans une instruction `COPY` ou `ENV` contenant sa vraie valeur.
 
**`SecretsUsedInArgOrEnv`** — Avertissement Docker signalant qu'une variable au nom évocateur pourrait contenir un secret — à vérifier au cas par cas.
 
**Image autosuffisante** — Une image qui ne dépend d'aucune configuration externe à l'exécution, hormis les secrets injectés.
 
**Reproductibilité multi-environnement** — La preuve qu'un même pipeline produit un résultat identique sur plusieurs environnements totalement indépendants.
 
---
 
## Power BI & intégration BI
 
**ODBC (Open Database Connectivity)** — Protocole standard de connexion à une base de données ; passage obligé pour DuckDB.
 
**DSN (Data Source Name)** — Configuration nommée d'une connexion ODBC.
 
**`mart_decisions`** — Table plate réinjectant la classification du graphe, consommable sans SPARQL.
 
**Chargement en parallèle des tables** — Comportement par défaut de Power BI ouvrant plusieurs connexions simultanées ; à désactiver face à une base mono-écrivain.
 
**`.pbip` (Power BI Project)** — Format de sauvegarde éclatant le modèle en fichiers texte/JSON versionnables, contrairement au binaire opaque `.pbix`.
 
**Mesure DAX** — Calcul défini dans le modèle Power BI, traduction manuelle (ou désormais assistée par l'IA) d'une métrique du semantic layer.
 
**`DIVIDE()`** — Fonction DAX de division sécurisée, avec une valeur de repli explicite en cas de division par zéro.
 
---
 
## MCP Power BI officiel (Microsoft)
 
**Power BI Modeling MCP Server** — Serveur MCP officiel de Microsoft, distribué comme extension VS Code, connectant un agent IA à un modèle Power BI **ouvert localement** via le protocole XMLA — permet de lire et modifier tables, mesures, relations directement dans le fichier actif.
 
**Serveur MCP distant (remote) vs local** — Le serveur distant (`api.fabric.microsoft.com`) est en lecture seule et nécessite un tenant Fabric avec admin ; le serveur local (Modeling MCP) permet la création/modification mais exige Power BI Desktop ouvert avec le fichier chargé.
 
**Connexion XMLA locale** — Protocole utilisé par le serveur Modeling MCP pour dialoguer avec Power BI Desktop.
 
**Vérification croisée de cohérence** — Comparer un même résultat calculé indépendamment par deux systèmes distincts (SPARQL sur le graphe vs DAX sur Power BI) pour confirmer que la gouvernance tient, sans pour autant synchroniser leurs définitions.
 
---
 
## Restitution BI open source (Superset)
 
**`PYTHONPATH` vs `site-packages`** — Deux façons de rendre un paquet Python découvrable : l'installer dans le dossier standard (`site-packages`, risque de conflit avec l'existant) ou dans un dossier séparé ajouté explicitement au chemin de recherche (`PYTHONPATH`, jamais de conflit puisque jamais de partage d'espace).
 
**Namespace package cassé par réorganisation** — Quand un paquet tiers (ex. `protobuf`) réécrit la structure d'un dossier partagé (ex. `google/`) sans fusionner proprement avec son contenu existant, des sous-modules déjà installés (ex. `google.auth`) peuvent devenir invisibles sans avoir été supprimés physiquement.
 
**Conflit de casse sur un système de fichiers sensible à la casse** — Deux dossiers de métadonnées (`sqlalchemy-*.dist-info` et `SQLAlchemy-*.dist-info`) peuvent coexister sans jamais s'écraser mutuellement sur Linux, rendant une suppression incomplète invisible à l'œil nu.
 
**`--upgrade` avec `pip install --target`** — Sans ce flag, `pip` refuse silencieusement (simple avertissement, pas une erreur bloquante) d'écrire dans un dossier cible qui contient déjà des fichiers du même paquet.
 
**Séquence d'initialisation Superset** — `superset db upgrade` (métadonnées) → `superset fab create-admin` (compte admin) → `superset init` (rôles) → `superset run` (serveur) : jamais automatique au premier démarrage d'une image officielle.
 
---
 
## Architecture Docker Compose avancée (webserver/daemon séparés)
 
**Processus mal supervisé (`&` en shell)** — Combiner deux processus dans un seul `CMD` via `&` place le second en arrière-plan, sans la même garantie de supervision des signaux que le processus principal (PID 1) — peut se dégrader silencieusement après une longue durée d'activité, sans crash franc.
 
**Systèmes de fichiers indépendants entre conteneurs, même avec un volume partagé** — Un volume nommé partage un chemin précis entre conteneurs, mais chaque conteneur garde son propre système de fichiers pour tout le reste (y compris le code copié pendant le build) — un artefact généré (comme `manifest.json`) doit être régénéré indépendamment dans chaque conteneur qui en a besoin.
 
**Régression de fichier de configuration** — Un fichier édité au fil d'une longue session peut revenir à un état antérieur sans intention explicite — toujours vérifier le contenu réel avant de supposer qu'une correction déjà appliquée est toujours en place.
 
**Isolation de diagnostic inter-conteneurs** (`docker compose exec <service_A> ... http://service_B:port`) — Teste la connectivité réseau interne à Docker Compose, indépendamment de la couche réseau Windows/WSL2 — permet de distinguer un problème de conteneur d'un problème d'infrastructure hôte.
 
---
 
## Orchestration en production (Dagster dans Docker)
 
**`dagster dev` vs production** — `dagster dev` combine serveur web et exécution en un seul processus de développement ; son schedule ne se déclenche que si ce mode reste actif. La production sépare `dagster-daemon` (déclenchement réel des schedules) et `dagster-webserver` (supervision optionnelle).
 
**`dagster-daemon`** — Le processus qui vérifie en continu si un schedule doit se déclencher, indépendamment de toute interface web consultée ou non — le vrai moteur de l'automatisation, pas l'interface.
 
**`dagster.yaml`** — Fichier de configuration d'instance Dagster (distinct de `definitions.py`), déclarant notamment le `DagsterDaemonScheduler` et le `QueuedRunCoordinator` ; doit vivre à l'emplacement pointé par `DAGSTER_HOME`, pas dans le dossier du projet.
 
**Génération du manifest au runtime, pas au build** — `manifest.json` ne peut être généré qu'au lancement du conteneur (`docker run`), jamais pendant `docker build`, car les secrets (clé BigQuery) ne sont injectés qu'à l'exécution.
 
**Chemin portable (`os.environ.get` + `os.path.join`)** — Pattern permettant à un même script Python de fonctionner correctement en local (chemin Windows de repli) et dans un conteneur (variable `ENV` Docker), sans jamais casser l'un des deux environnements.
 
**Orchestration liée à la machine hôte** — Contrairement à une CI hébergée par un tiers (GitHub Actions), un conteneur Docker tourne physiquement sur la machine qui l'exécute : l'éteindre arrête l'orchestration. Une continuité 24/7 exige un hébergement cloud dédié (VPS, service managé, Cloud Scheduler).
 
---
 
## Data Vault (Hub / Link / Satellite)
 
**Hub** — Table contenant l'identité pure d'un concept métier ayant une existence indépendante (Client, Produit, Commande) : hash key, business key, `load_date`, `record_source` — jamais d'attribut descriptif.
 
**Test du "nom commun"** — Critère de choix d'un Hub : *"cette chose peut-elle exister et avoir un sens même si rien d'autre ne lui était jamais associé ?"* Si oui → Hub. Si l'existence dépend de la rencontre d'autres entités → Link.
 
**Link** — Table documentant une relation entre plusieurs Hubs (N-aire si plus de deux), au grain d'un événement ou d'une décision de rapprochement — jamais de mesure.
 
**Link same-as** — Type de Link documentant qu'une entité doit être rapprochée d'une autre, sans jamais fusionner les identités concernées — contrairement à une réconciliation Kimball classique.
 
**Satellite** — Table portant le contexte descriptif rattaché à un Hub ou un Link, avec un `hash_diff` permettant de détecter un changement entre deux chargements.
 
**`hash_diff`** — Hash calculé sur l'ensemble des attributs descriptifs d'un Satellite — sert à détecter efficacement si quelque chose a changé.
 
**`dbt_utils.generate_surrogate_key([...])`** — Macro du package `dbt-utils` calculant une hash key déterministe à partir d'une ou plusieurs colonnes.
 
**Data Vault part toujours du staging, jamais des marts** — Règle centrale : un mart Kimball contient déjà des décisions métier accumulées ; construire le Data Vault par-dessus reviendrait à en hériter silencieusement.
 
**`load_date` / `record_source`** — Métadonnées obligatoires sur chaque table Data Vault.
 
**Coexistence Kimball / Data Vault** — Les deux modélisations partagent le même staging mais restent indépendantes, répondant à des besoins différents (restitution rapide vs audit et traçabilité).
 
 