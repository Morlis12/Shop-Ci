# Shop_CI — Récit d'un projet d'analytics engineering, de la donnée sale à l'agent IA
 
> Ce document raconte *comment* et *pourquoi* les décisions ont été prises, pas seulement *quoi* a été construit. Il est pensé pour être lu comme un article : la trajectoire complète d'une reconversion vers l'analytics engineering, avec ses détours, ses erreurs corrigées, et ce qu'elles enseignent.
 
---
 
## Pourquoi ce projet
 
BoutiqueCI n'est pas un jeu de données Kaggle déjà propre. Les CSV sources ont été construits avec des pièges volontaires — trois formats de dates cohabitant dans la même colonne, des doublons de clients par email, des paiements en retry, des clés orphelines — précisément pour reproduire les problèmes qu'un analytics engineer rencontre réellement, et non les exercices d'école où tout fonctionne du premier coup.
 
L'objectif final n'était pas seulement de "faire tourner un pipeline dbt", mais de construire une chaîne complète et cohérente : de l'audit d'un fichier sale jusqu'à un agent IA capable de répondre, en langage naturel et avec des chiffres gouvernés, aux questions d'un client fictif — jusqu'à une chaîne CI/CD qui protège ce travail contre la régression, une restitution Power BI qui le rend consommable, et une portabilité vers un vrai entrepôt cloud qui prouve que ces compétences ne restent pas enfermées dans un fichier local.
 
---
 
## Partie 1 — Le pipeline : discipline avant tout
 
### L'audit avant la transformation
 
Chaque chantier a commencé par la même question : *qu'est-ce que je vois vraiment dans les données, avant de décider quoi que ce soit ?* Les CSV ont été lus en texte brut (`all_varchar=true`) précisément pour ne rien masquer — un typage automatique aurait caché la coexistence de plusieurs formats de dates dans une même colonne, le vrai piège du projet.
 
### Une règle qui traverse tout le projet : ne jamais faire disparaître silencieusement une donnée
 
C'est devenu le fil rouge de toutes les décisions suivantes. Le staging ne supprime jamais de lignes sans raison analytique — les doublons de paiements sont *flaggés*, pas effacés. Et surtout : le membre client "inconnu" (`id = -1`) a été délibérément **conservé** dans le modèle en étoile, plutôt qu'exclu. Cette décision, en apparence mineure, s'est révélée structurante bien plus tard : elle a directement dicté la priorité des règles de classification dans le graphe de connaissances, s'est retrouvée jusque dans les écarts de comptage observés en Power BI, et a resurgi une dernière fois lors de la migration BigQuery — où dbt a intercepté les 101 commandes orphelines connues, confirmant que le membre inconnu continuait de jouer son rôle protecteur sur un tout nouveau moteur.
 
### Le semantic layer : une définition, pas une opinion
 
Le vrai déclic du projet a été le semantic layer MetricFlow. Avant lui, "le chiffre d'affaires" pouvait avoir plusieurs valeurs selon qui le calculait. La métrique `ca_officiel` a mis fin à cette ambiguïté en la codifiant une fois pour toutes. Ce principe s'est révélé si central qu'il a fini par se **répliquer** ailleurs dans le projet — d'abord en SPARQL sur le graphe, puis en DAX dans Power BI. Trois traductions d'une même définition, une vraie tension de gouvernance assumée plutôt que cachée.
 
---
 
## Partie 2 — L'orchestration : capturer un code n'est pas le promouvoir en verdict
 
Le script `pipeline_quotidien.ps1` a introduit un principe simple : chaque commande rend son propre code de sortie, mais le *verdict global* du pipeline est une décision explicite, pas une moyenne automatique. La fraîcheur des sources est capturée et journalisée, mais volontairement exclue du verdict final.
 
---
 
## Partie 3 — Le graphe de connaissances : donner un sens interrogeable aux données
 
### Pourquoi un graphe, et pas juste plus de SQL
 
Un modèle en étoile répond très bien aux questions qu'on a prévu de poser. Un graphe de connaissances répond aussi aux questions qu'on *n'a pas prévues* : "quels clients à haute valeur achètent des produits peu rentables ?" est une traversée à trois sauts, triviale en SPARQL, laborieuse en SQL pur.
 
### Le patron en trois fichiers, devenu quatre
 
L'architecture — ontologie, export, classification — a fini par accueillir une quatrième pièce : `04_ecrire_labels_duckdb.py`, qui referme la boucle en réinjectant la classification dans DuckDB pour Power BI.
 
---
 
## Partie 4 — Le serveur MCP : quand la théorie rencontre l'environnement réel
 
La chaîne d'incidents la plus longue et la plus instructive du projet a été résolue non par une intuition heureuse, mais par une discipline répétée : reproduire chaque symptôme à la main, mesurer plutôt que supposer, isoler une seule variable à la fois.
 
---
 
## Partie 5 — CI/CD : la preuve par l'environnement neuf
 
### La découverte la plus révélatrice de tout le projet
 
La première tentative de CI a immédiatement échoué sur un **test unitaire déjà écrit et considéré comme acquis** : `ut_filtre_incremental_fenetre_glissante`. Le mock de `{{ this }}` fournissait une colonne différente de celle réellement lue par le filtre SQL du modèle — un bug de test dormant, invisible en local car `fait_ventes` y existait déjà d'un précédent `dbt build`. Ce n'est qu'en environnement radicalement neuf que le décalage est devenu fatal.
 
### De l'indicateur au garde-fou
 
Une règle de protection de branche a transformé le statut CI d'un simple indicateur visuel en contrainte structurelle, rendant la fusion vers `main` physiquement impossible tant que la CI n'est pas verte.
 
---
 
## Partie 6 — Power BI : le dernier maillon, et ses propres surprises
 
### Le mono-écrivain, encore et toujours
 
Power BI, en chargeant plusieurs tables en parallèle, ouvrait simultanément plusieurs connexions au même fichier `.duckdb`, provoquant des échecs en cascade — la même contrainte mono-écrivain rencontrée ailleurs dans le projet, sous une forme nouvelle.
 
### Un chevauchement d'identifiants presque invisible
 
La table `mart_decisions` cachait un piège de modélisation classique : un `id_client=7` et un `id_produit=7` coexistent naturellement. La correction — scinder la table en deux requêtes filtrées — rappelle que même une table minimaliste peut receler une ambiguïté qu'aucun test automatique n'aurait signalée.
 
---
 
## Partie 7 — BigQuery : porter le même projet sur un vrai warehouse cloud
 
### Pourquoi cette étape, maintenant
 
Après la recherche du marché de l'analytics engineering en 2026, un constat s'est imposé : DuckDB, excellent pour apprendre et prototyper, n'apparaît dans aucune source consultée comme un outil de production recherché — le trio Snowflake/BigQuery/Databricks domine les offres réelles. La vraie question qu'un recruteur poserait après avoir vu le reste du projet était prévisible : *"c'est bien en local, mais sais-tu faire pareil sur un vrai stack d'entreprise ?"* Cette partie répond directement à cette question.
 
### Le premier obstacle : il n'y a pas de "fichier local" dans le cloud
 
`read_csv_auto()`, la fonction DuckDB qui interrogeait directement les CSV sur disque, n'a aucun équivalent sur BigQuery — un entrepôt cloud n'a pas de notion de "dossier local". Il a fallu construire `charger_csv_bigquery.py`, un mini-outil d'ingestion dans l'esprit d'un Fivetran fait maison : lire chaque CSV, forcer toutes les colonnes en texte brut (préservant le principe d'audit-avant-transformation même hors DuckDB), et pousser physiquement les données comme de vraies tables dans le dataset source cloud.
 
### Le deuxième obstacle : deux dialectes SQL, un seul code source voulu
 
Migrer aurait pu signifier réécrire deux fois chaque modèle — une version DuckDB, une version BigQuery. La solution retenue a été plus disciplinée : utiliser systématiquement les **macros cross-database** que dbt fournit précisément pour ce cas (`dbt.type_string()`, `dbt.safe_cast()`, `dbt.split_part()`, `dbt.dateadd()`), qui se traduisent automatiquement dans le bon dialecte selon la cible active. Le gain n'est pas seulement esthétique : un seul fichier `.sql` reste vrai sur les deux moteurs, éliminant le risque qu'une correction faite d'un côté soit oubliée de l'autre.
 
Pour les cas où aucune macro générique n'existait — la génération de `dim_calendrier`, qui reposait sur des fonctions DuckDB (`range`, `strftime`, `isodow`) sans équivalent direct côté cloud — un routage conditionnel Jinja (`{% if target.type == 'bigquery' %}`) a permis de garder deux implémentations natives dans le même fichier, chacune optimale sur son moteur, plutôt que de forcer un compromis dégradé des deux côtés.
 
### Une leçon sur les limites du parsing dbt
 
Une tentative d'utiliser `{{ dbt.type_int() }}` directement dans un fichier de contrat (`schema.yml`) a révélé une limite technique précise : l'objet Jinja `dbt` n'existe qu'au moment de la **compilation SQL**, pas au moment du **parsing des fichiers YAML** — deux étapes distinctes du cycle de vie dbt, avec des capacités différentes. La solution est revenue à des types SQL standards universels (`int64`, `string`), compris nativement par les deux moteurs sans macro nécessaire — un rappel que la portabilité cross-database ne s'obtient pas de la même façon partout dans un projet dbt.
 
### Une divergence de comportement SQL, pas de syntaxe
 
Le modèle `fait_ventes` filtrait sur un alias défini dans son propre `SELECT` — un raccourci que DuckDB tolère, mais que BigQuery refuse, en raison d'un ordre d'exécution SQL plus strict côté cloud. La correction n'était pas cosmétique : elle a exigé de revenir filtrer sur la colonne source réelle, révélant que certains raccourcis qui "marchent" sur un moteur reposent parfois sur une tolérance non garantie ailleurs.
 
### La contrainte du bac à sable gratuit
 
Le palier BigQuery sans carte bancaire interdit les requêtes de modification de données (DML/MERGE) — bloquant nativement tout modèle incrémental et tout snapshot. Plutôt que de contourner artificiellement cette limite dans le code du projet, la décision a été de la documenter comme une contrainte d'environnement temporaire (`--full-refresh`, exclusion des snapshots), résolue par l'activation de la facturation plutôt que par un bricolage permanent du pipeline lui-même — la même discipline déjà appliquée à chaque contrainte technique rencontrée dans ce projet : comprendre la vraie cause avant de choisir entre contourner et corriger.
 
### Pourquoi deux environnements, un seul moteur
 
La tentation initiale — DuckDB pour le développement, BigQuery pour la production — a été explicitement écartée. Deux moteurs SQL différents entre dev et prod recréeraient exactement le piège que la CI avait déjà révélé une fois : une validation locale qui ne prouve rien de fiable sur l'environnement réel. La bonne architecture retenue place dev et prod sur le **même moteur** (BigQuery), séparés seulement par le schéma cible, une macro `generate_schema_name` personnalisée garantissant qu'un run de développement ne puisse jamais écrire accidentellement dans la production.
 
---
 
## Ce que ce projet démontre
 
Au-delà de l'empilement technique, ce projet est une démonstration de méthode : auditer avant de transformer, gouverner une définition avant de la multiplier, documenter une décision plutôt que la cacher — et, chapitre après chapitre, reconnaître qu'un même symptôme peut cacher des causes de nature radicalement différente. La migration BigQuery a ajouté sa propre version de cette leçon : un code qui fonctionne sur un moteur SQL n'est pas automatiquement portable sur un autre, et la vraie compétence n'est pas de connaître un dialecte par cœur, mais de savoir où chercher — et quels outils (les macros cross-database de dbt, en l'occurrence) existent précisément pour éviter d'avoir à choisir entre portabilité et duplication.
 
---
 
*Ce document sera enrichi au fil des prochains chantiers : Docker, Dagster, Data Vault, gouvernance/RGPD appliquée.*
 