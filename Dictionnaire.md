# Dictionnaire — Shop_CI
 
Glossaire des termes techniques employés dans le projet, organisé par domaine. Document vivant, complété au fil des chantiers.
 
---
 
## dbt & modélisation
 
**Modèle** — Une table ou vue produite par dbt (staging, intermediate, mart).
 
**Staging** — Couche de nettoyage 1-pour-1 : une source = un modèle staging. Typage, normalisation, flags de qualité. Ne croise jamais deux sources.
 
**Intermediate** — Couche de logique inter-tables, réutilisable par plusieurs marts. Exemple : `int_correspondance_clients`, qui re-route les commandes des clients dédoublonnés.
 
**Mart** — Interface publique consommée par le BI, le semantic layer, ou l'IA. Seule couche exposée aux consommateurs finaux.
 
**Grain** — La définition précise de ce que représente une ligne d'une table de faits (ex. : une ligne = un produit dans une commande). Première décision à prendre en modélisation Kimball.
 
**Membre inconnu (Unknown Member)** — Convention Kimball : une ligne spéciale dans une dimension (id = -1) qui accueille les faits dont la clé étrangère est orpheline, pour éviter que ces faits disparaissent silencieusement des jointures.
 
**Dimension dégénérée** — Un attribut de dimension stocké directement dans la table de faits (ex. : `canal`), sans table de dimension dédiée.
 
**Fan-out** — Multiplication artificielle des lignes (et donc des mesures) causée par une jointure entre deux tables de grains différents.
 
**Constellation** — Modèle avec plusieurs tables de faits de grains différents, partageant certaines dimensions communes.
 
**Contrat de modèle (`contract: enforced`)** — Verrouillage du nom, du type et du nombre de colonnes d'un modèle avant sa matérialisation.
 
**Snapshot** — Objet dbt à mémoire, historisant les changements d'une table source selon le pattern SCD Type 2 (`dbt_valid_from`/`dbt_valid_to`). Insert-only, jamais reconstruit.
 
**Modèle incrémental** — Matérialisation qui ne retraite que les nouvelles lignes à chaque exécution, avec une clé unique pour gérer les mises à jour (upsert).
 
**Test unitaire (`unit_tests`)** — Test dbt qui vérifie la logique d'un modèle sur des données fictives contrôlées (`given`/`expect`), indépendamment de la base réelle.
 
**Fraîcheur des sources (`source freshness`)** — Vérification que les données d'une source ne dépassent pas un délai maximal depuis leur dernier chargement (seuils `warn`/`error`).
 
---
 
## Semantic Layer (MetricFlow)
 
**Modèle sémantique (`semantic_model`)** — Déclaration des entités, dimensions et mesures disponibles sur un modèle dbt, base des métriques.
 
**Métrique gouvernée** — Définition unique et centralisée d'un indicateur métier (ex. : `ca_officiel`), garantissant que tous les consommateurs obtiennent le même chiffre.
 
**Métrique simple / ratio / dérivée** — Trois types de métriques MetricFlow : une mesure filtrée, un rapport entre deux métriques, une expression combinant plusieurs métriques.
 
**Time spine** — Table calendrier déclarée comme référence temporelle pour les agrégations MetricFlow.
 
---
 
## Orchestration
 
**Code de sortie (exit code)** — Convention universelle : 0 = succès, tout autre nombre = échec. Langage commun entre dbt, PowerShell, GitHub Actions, etc.
 
**Chemin absolu vs relatif** — Un chemin relatif dépend du répertoire d'où l'on exécute une commande ; un chemin absolu pointe toujours au même endroit. Les processus externes (Planificateur de tâches, Claude Desktop) exigent des chemins absolus.
 
**Environnement nu** — Contexte d'exécution d'un processus démarré par un tiers, qui n'hérite ni de la venv activée manuellement, ni du répertoire de travail habituel.
 
**Mono-écrivain (DuckDB)** — Limitation de DuckDB : un seul processus peut ouvrir le fichier `.duckdb` en écriture (ou en lecture exclusive) à la fois.
 
---
 
## Graphe de connaissances (RDF / OWL / SPARQL)
 
**Triplet** — Un fait atomique de la forme *sujet → relation → objet* ; la brique de base d'un graphe RDF.
 
**RDF / Turtle (`.ttl`)** — Modèle standard de représentation de triplets ; Turtle en est la syntaxe lisible.
 
**Ontologie** — Déclaration des classes et relations autorisées dans un graphe, écrite avant tout peuplement de données (l'équivalent d'un schéma ou d'un contrat).
 
**Classe / Instance (individu)** — Une classe est un type (ex. : `Client`) ; une instance est un exemplaire concret de ce type (ex. : `client_305`).
 
**Sous-classe (`subClassOf`)** — Une classe qui hérite d'une classe mère ; sert à construire une hiérarchie de décision métier.
 
**DatatypeProperty** — Relation qui relie un individu à une valeur simple (nombre, texte, date).
 
**ObjectProperty** — Relation qui relie un individu à un autre individu du graphe, permettant les traversées à plusieurs sauts.
 
**`disjointWith`** — Déclare que deux classes sont mutuellement exclusives.
 
**SPARQL** — Langage de requête des graphes RDF, équivalent du SQL pour les données relationnelles.
 
**`SELECT`** — Requête SPARQL qui interroge et affiche des résultats.
 
**`CONSTRUCT`** — Requête SPARQL qui fabrique de nouveaux triplets à partir d'un motif trouvé ; mécanisme utilisé pour la classification/inférence.
 
**`FILTER` / `FILTER NOT EXISTS`** — Condition sur les résultats ; `NOT EXISTS` exclut les cas où un motif existe déjà, utilisé pour empêcher le double classement dans une cascade de règles priorisées.
 
**Chemin de propriété (`+`)** — Rend une relation transitive (ex. : `dependDe+` remonte tout l'amont d'un modèle, direct ou indirect).
 
**Membre inconnu (graphe)** — Équivalent Kimball transposé au graphe : la classe `ClientNonIdentifie` (individu `id = -1`), positionnée en priorité absolue dans les règles de classification pour ne jamais être masquée.
 
---
 
## Serveur MCP (Model Context Protocol)
 
**MCP** — Protocole standard permettant à un agent IA d'appeler des outils externes (fonctions) exposés par un serveur local ou distant.
 
**Outil (`@mcp.tool()`)** — Fonction Python transformée en capacité appelable par l'agent IA ; sa docstring sert de description à l'IA pour savoir quand l'utiliser.
 
**Rechargement à la demande** — Pattern consistant à relire une source de données (ici, le fichier `.ttl`) à chaque appel d'outil plutôt qu'une seule fois au démarrage, garantissant la fraîcheur sans redémarrage du serveur.
 
**Sandboxing / AppContainer** — Mécanisme d'isolation appliqué par Windows aux applications du Store, restreignant certaines opérations système (création de processus enfants, gestion de signaux) pour des raisons de sécurité.
 
**Processus zombie** — Processus qui continue de tourner en arrière-plan après un arrêt apparent, retenant des ressources (fichiers, mémoire) verrouillées.
 
**Boucle asynchrone bloquée** — Situation où du code synchrone et lent, exécuté directement dans une boucle événementielle (`asyncio`/`anyio`), gèle toute la boucle et empêche le protocole de répondre à temps.
 
---
 
## Méthodologie de diagnostic
 
**Doute méthodique** — Principe consistant à ne jamais supposer la cause d'un problème, mais à la vérifier systématiquement par un test isolé et reproductible.
 
**Isoler la variable** — Changer un seul élément à la fois avant de retester, pour savoir précisément lequel a un effet réel.
 
**Reproduire avant de blâmer** — Reproduire manuellement le comportement d'un outil externe complexe, dans un contexte simple et contrôlé, avant de l'accuser d'un dysfonctionnement.
 
**Contournement (workaround) architectural** — Choix délibéré d'une voie alternative qui évite une contrainte bloquante, plutôt que de continuer à tenter de la lever directement.
 
**Honnêteté architecturale** — Documenter explicitement une limitation connue et le raisonnement de la décision prise, plutôt que de la dissimuler.
 
---
 
*Ce dictionnaire s'enrichira des termes propres aux prochains chantiers : Power BI, Data Vault, GitHub Actions.*