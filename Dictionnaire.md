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
 
**Mock (simulacre)** — Donnée factice fabriquée pour remplacer une vraie source le temps d'un test, contenant uniquement les colonnes réellement lues par le code testé — ni plus, ni moins.
 
**Contrat de modèle (`contract: enforced`)** — Verrouillage du nom, du type et du nombre de colonnes d'un modèle avant sa matérialisation.
 
**Snapshot** — Objet dbt à mémoire, historisant les changements d'une table source selon le pattern SCD Type 2, insert-only.
 
**Modèle incrémental** — Matérialisation qui ne retraite que les nouvelles lignes à chaque exécution, avec une clé unique pour gérer les mises à jour (upsert).
 
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
 
**SPARQL SELECT / CONSTRUCT** — SELECT interroge et affiche ; CONSTRUCT fabrique de nouveaux triplets à partir d'un motif trouvé — le mécanisme d'inférence utilisé pour la classification.
 
**FILTER NOT EXISTS** — Exclut les résultats pour lesquels un motif secondaire existe déjà — utilisé pour la cascade de priorité des règles de classification (équivalent d'un `CASE WHEN`).
 
**Chemin de propriété (`+`, `*`, `/`, `|`)** — Rendent une relation transitive, chaînée, ou alternative sans réécrire plusieurs triplets.
 
**Membre inconnu (graphe)** — Équivalent Kimball transposé au graphe : la classe `ClientNonIdentifie`, priorité absolue dans les règles de classification.
 
---
 
## Serveur MCP (Model Context Protocol)
 
**MCP** — Protocole standard permettant à un agent IA d'appeler des outils externes exposés par un serveur local ou distant — conçu pour un raisonnement conversationnel, pas comme une API REST générique.
 
**Outil (`@mcp.tool()`)** — Fonction Python transformée en capacité appelable par l'agent IA ; sa docstring sert de description à l'IA pour savoir quand l'utiliser.
 
**Rechargement à la demande** — Pattern consistant à relire une source de données à chaque appel d'outil plutôt qu'une seule fois au démarrage.
 
**Sandboxing / AppContainer** — Mécanisme d'isolation Windows restreignant certaines opérations système (création de processus enfants) pour des raisons de sécurité.
 
---
 
## Méthodologie de diagnostic
 
**Doute méthodique** — Ne jamais supposer la cause d'un problème, mais la vérifier systématiquement par un test isolé et reproductible.
 
**Reproduire avant de blâmer** — Reproduire manuellement le comportement d'un outil externe complexe avant de l'accuser d'un dysfonctionnement.
 
**Environnement neuf comme révélateur** — Une machine vierge (CI, nouvel utilisateur) expose des dépendances cachées à un état local qu'on ne remarque jamais en travaillant toujours sur la même machine.
 
---
 
## CI/CD (GitHub Actions)
 
**Workflow** — Fichier YAML (`.github/workflows/`) décrivant quand et comment exécuter des tâches automatisées ; doit impérativement être à la racine du dépôt.
 
**Runner** — Machine virtuelle entièrement vierge prêtée par GitHub pour exécuter le workflow, détruite après chaque run — sans aucune trace des runs précédents ni de la machine locale du développeur.
 
**`on: pull_request`** — Déclencheur qui lance le workflow à chaque ouverture ou mise à jour d'une Pull Request, avant toute fusion vers `main`.
 
**`working-directory`** — Précise depuis quel sous-dossier une étape s'exécute, indépendamment de la racine du repo.
 
**Dépendance transitive** — Un paquet requis non pas directement par le code, mais par un autre paquet dont on dépend (ex. : `pywin32`, requis par `mcp` sur Windows uniquement).
 
**Marqueur PEP 508** — Syntaxe conditionnelle dans `requirements.txt` pour installer un paquet selon la plateforme (`; sys_platform == "win32"`) — pas toujours suffisante en pratique ; la suppression pure reste parfois la solution la plus robuste.
 
**Chemin relatif vs absolu — le vrai critère** — Absolu si le processus est démarré par un tiers sans contrôle du dossier de départ (Planificateur, Claude Desktop). Relatif si le script est lancé manuellement depuis un dossier connu (rend le code portable entre machines, y compris vers la CI).
 
**Status check** — Le résultat (✅/❌) d'un job CI affiché sur une Pull Request. Sans règle de protection, un simple indicateur ignorable, pas un blocage réel.
 
**Règle de protection de branche** — Configuration GitHub rendant un status check obligatoire avant fusion — grise physiquement le bouton de fusion tant que la CI n'est pas verte.
 
---
 
## Power BI & intégration BI
 
**ODBC (Open Database Connectivity)** — Protocole standard de connexion à une base de données ; passage obligé pour connecter Power BI à DuckDB, faute de connecteur natif.
 
**DSN (Data Source Name)** — Configuration nommée d'une connexion ODBC (nom, chemin du fichier base), enregistrée via l'outil "Sources de données ODBC" (`odbcad32.exe`) — à ne pas confondre avec l'installateur du pilote lui-même.
 
**`mart_decisions`** — Table plate réinjectant la classification du graphe dans DuckDB (`entity_type`, `entity_id`, `label`), consommable par tout outil SQL/BI sans jamais avoir besoin de parler SPARQL.
 
**Chargement en parallèle des tables** — Comportement par défaut de Power BI ouvrant plusieurs connexions simultanées à la source lors du chargement ; à désactiver explicitement face à une base mono-écrivain comme DuckDB.
 
**`.pbip` (Power BI Project)** — Format de sauvegarde éclatant le modèle en fichiers texte/JSON versionnables et diff-ables dans Git, contrairement au binaire opaque `.pbix`.
 
**Mesure DAX** — Calcul défini dans le modèle Power BI (ex. : `CALCULATE(SUM(...), condition)`), traduction manuelle d'une métrique du semantic layer dbt dans le langage de Power BI.
 
**`DIVIDE()`** — Fonction DAX de division sécurisée, avec une valeur de repli explicite en cas de division par zéro — équivalent du `COALESCE`/`NULLIF` combinés en SQL.