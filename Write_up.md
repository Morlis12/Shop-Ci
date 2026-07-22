# Shop_CI — Récit d'un projet d'analytics engineering, de la donnée sale à l'agent IA
 
> Ce document raconte *comment* et *pourquoi* les décisions ont été prises, pas seulement *quoi* a été construit. Il est pensé pour être lu comme un article : la trajectoire complète d'une reconversion vers l'analytics engineering, avec ses détours, ses erreurs corrigées, et ce qu'elles enseignent.
 
---
 
## Pourquoi ce projet
 
BoutiqueCI n'est pas un jeu de données Kaggle déjà propre. Les CSV sources ont été construits avec des pièges volontaires — trois formats de dates cohabitant dans la même colonne, des doublons de clients par email, des paiements en retry, des clés orphelines — précisément pour reproduire les problèmes qu'un analytics engineer rencontre réellement, et non les exercices d'école où tout fonctionne du premier coup.
 
L'objectif final n'était pas seulement de "faire tourner un pipeline dbt", mais de construire une chaîne complète et cohérente : de l'audit d'un fichier sale jusqu'à un agent IA capable de répondre, en langage naturel et avec des chiffres gouvernés, aux questions d'un client fictif — et jusqu'à une chaîne CI/CD qui protège ce travail contre la régression, et une restitution Power BI qui le rend consommable par un vrai outil de décision.
 
---
 
## Partie 1 — Le pipeline : discipline avant tout
 
### L'audit avant la transformation
 
Chaque chantier a commencé par la même question : *qu'est-ce que je vois vraiment dans les données, avant de décider quoi que ce soit ?* Les CSV ont été lus en texte brut (`all_varchar=true`) précisément pour ne rien masquer — un typage automatique aurait caché la coexistence de plusieurs formats de dates dans une même colonne, le vrai piège du projet.
 
### Une règle qui traverse tout le projet : ne jamais faire disparaître silencieusement une donnée
 
C'est devenu le fil rouge de toutes les décisions suivantes. Le staging ne supprime jamais de lignes sans raison analytique — les doublons de paiements sont *flaggés*, pas effacés. Et surtout : le membre client "inconnu" (`id = -1`) a été délibérément **conservé** dans le modèle en étoile, plutôt qu'exclu. Cette décision, en apparence mineure, s'est révélée structurante bien plus tard : elle a directement dicté la priorité des règles de classification dans le graphe de connaissances, et s'est retrouvée, sans qu'on l'ait planifié, jusque dans les écarts de comptage observés bien plus tard en Power BI (501 lignes dans `dim_clients`, 499 seulement classifiées — 2 clients existants mais n'ayant jamais acheté, donc jamais entrés dans le circuit de décision).
 
### Le semantic layer : une définition, pas une opinion
 
Le vrai déclic du projet a été le semantic layer MetricFlow. Avant lui, "le chiffre d'affaires" pouvait avoir plusieurs valeurs selon qui le calculait. La métrique `ca_officiel` a mis fin à cette ambiguïté en la codifiant une fois pour toutes. Ce principe s'est révélé si central qu'il a fini par se **répliquer** ailleurs dans le projet — d'abord en SPARQL sur le graphe (par nécessité, face au blocage MetricFlow), puis en DAX dans Power BI (par choix architectural, faute d'un Semantic Layer hébergé unique). Trois traductions d'une même définition, une vraie tension de gouvernance assumée plutôt que cachée : le jour où la règle change, il faudra la corriger aux trois endroits, un risque documenté plutôt qu'ignoré.
 
---
 
## Partie 2 — L'orchestration : capturer un code n'est pas le promouvoir en verdict
 
Le script `pipeline_quotidien.ps1` a introduit un principe simple : chaque commande rend son propre code de sortie, mais le *verdict global* du pipeline est une décision explicite, pas une moyenne automatique. La fraîcheur des sources est capturée et journalisée, mais volontairement exclue du verdict final — une exception commentée est une décision d'architecte ; la même exception muette serait un bug en devenir.
 
---
 
## Partie 3 — Le graphe de connaissances : donner un sens interrogeable aux données
 
### Pourquoi un graphe, et pas juste plus de SQL
 
Un modèle en étoile répond très bien aux questions qu'on a prévu de poser. Un graphe de connaissances répond aussi aux questions qu'on *n'a pas prévues* : "quels clients à haute valeur achètent des produits peu rentables ?" est une traversée à trois sauts, triviale en SPARQL grâce à une relation explicite posée entre les classes, laborieuse en SQL pur.
 
### Le patron en trois fichiers, devenu quatre
 
L'architecture — ontologie, export, classification — a fini par accueillir une quatrième pièce : `04_ecrire_labels_duckdb.py`, qui referme la boucle en réinjectant la classification dans DuckDB. Ce script n'était pas prévu dès le départ ; il est né d'une question simple posée à voix haute — "comment Power BI, qui ne parle pas SPARQL, va-t-il voir les labels du graphe ?" — et a révélé un principe plus large : chaque nouvelle destination de consommation (l'agent IA, puis Power BI) a exigé sa propre traduction du même savoir, jamais un accès direct au format natif du graphe.
 
---
 
## Partie 4 — Le serveur MCP : quand la théorie rencontre l'environnement réel
 
La chaîne d'incidents la plus longue et la plus instructive du projet — colonne manquante, doublon YAML silencieux, processus zombies, et finalement un sandboxing système bloquant tout sous-processus — a été résolue non par une intuition heureuse, mais par une discipline répétée : reproduire chaque symptôme à la main, mesurer plutôt que supposer, isoler une seule variable à la fois. La décision finale n'a pas été de "réparer" MetricFlow en sous-processus à tout prix, mais de contourner proprement, avec la garantie documentée que le contournement reproduit fidèlement le même périmètre que l'original.
 
---
 
## Partie 5 — CI/CD : la preuve par l'environnement neuf
 
### Le principe qui a tout changé
 
Jusqu'ici, "ça marche" signifiait "ça marche sur ma machine" — un état qui accumule, sans qu'on le remarque, des traces de tout ce qu'on a construit avant : une table déjà existante depuis un run précédent, un fichier généré une fois puis oublié. GitHub Actions a introduit une contrainte radicalement différente : une machine virtuelle vierge, sans aucune mémoire de ce qui précède, à chaque exécution.
 
### La découverte la plus révélatrice de tout le projet
 
La première tentative de CI a immédiatement échoué — pas sur le graphe, pas sur une nouveauté, mais sur un **test unitaire déjà écrit et considéré comme acquis** depuis des semaines : `ut_filtre_incremental_fenetre_glissante`. Le mock de `{{ this }}` fournissait une colonne (`jour_commande`) différente de celle réellement lue par le filtre SQL du modèle (`date_commande_chargement`) — un bug de test dormant, invisible en local car `fait_ventes` y existait déjà d'un précédent `dbt build`, donc le `MAX()` défaillant du mock n'était jamais mis à l'épreuve dans les mêmes conditions. Ce n'est qu'en environnement radicalement neuf que le décalage est devenu fatal, révélant une leçon simple mais rarement vécue aussi concrètement : *"ça marche chez moi" n'a jamais été une preuve de reproductibilité.*
 
### Une deuxième leçon, plus discrète mais tout aussi utile
 
`pywin32`, un paquet Windows-only, faisait échouer l'installation entière sur la machine Linux de la CI — non pas parce que le projet en avait besoin, mais parce qu'une dépendance transitive (`mcp`) le réclamait sur Windows. Aucun marqueur conditionnel n'a suffi à le contourner proprement ; la solution la plus robuste s'est révélée être la suppression pure et simple. Une vraie leçon de pragmatisme : parfois, la meilleure décision n'est pas de continuer à chercher la cause exacte d'un comportement capricieux, mais d'appliquer la correction la plus sûre et d'avancer.
 
### De l'indicateur au garde-fou
 
Une CI qui passe au vert reste, par défaut, un simple indicateur visuel — rien n'empêche techniquement de fusionner du code cassé malgré un échec affiché. La dernière étape du chantier a transformé cet indicateur en contrainte structurelle : une règle de protection de branche, rendant la fusion vers `main` **physiquement impossible** tant que la CI n'est pas verte. Le même principe déjà appliqué partout ailleurs dans le projet — transformer une bonne pratique en garantie automatisée plutôt qu'en discipline reposant sur la vigilance humaine.
 
---
 
## Partie 6 — Power BI : le dernier maillon, et ses propres surprises
 
### Un connecteur qui n'existe pas nativement
 
Brancher Power BI sur DuckDB n'a rien d'immédiat : aucun connecteur natif, un passage obligé par un pilote ODBC dont l'installation a elle-même généré une confusion révélatrice — confondre l'installateur du pilote (`odbc_install.exe`, à exécuter une seule fois) avec l'outil de configuration des sources de données (`odbcad32.exe`, à utiliser ensuite en continu). Une distinction évidente une fois comprise, mais qui a coûté plusieurs allers-retours avant d'être clarifiée.
 
### Le mono-écrivain, encore et toujours
 
Le vieux compagnon du projet — la contrainte mono-écrivain de DuckDB — est réapparu sous une forme nouvelle : Power BI, en chargeant plusieurs tables **en parallèle**, ouvrait simultanément plusieurs connexions au même fichier `.duckdb`, provoquant des échecs en cascade. La solution n'était pas un bug à corriger dans le code du projet, mais un comportement de l'outil consommateur à désactiver explicitement — élargissant la leçon du mono-écrivain à un principe plus général : une contrainte technique connue peut ressurgir sous une forme inattendue à chaque nouveau maillon ajouté à la chaîne.
 
### Un chevauchement d'identifiants presque invisible
 
La table `mart_decisions`, pensée comme une simple réinjection du graphe, cachait un piège de modélisation classique : un `id_client=7` et un `id_produit=7` coexistent naturellement, deux numérotations indépendantes qui se chevauchent sans le moindre rapport. Une relation directe et naïve aurait mélangé silencieusement des clients et des produits dans les mêmes jointures. La correction — scinder la table en deux requêtes filtrées, une par type d'entité — est un rappel que même une table minimaliste de trois colonnes peut receler une ambiguïté de modélisation qu'aucun test automatique n'aurait signalée sans une vérification manuelle attentive du schéma relationnel.
 
---
 
## Ce que ce projet démontre
 
Au-delà de l'empilement technique, ce projet est une démonstration de méthode : auditer avant de transformer, gouverner une définition avant de la multiplier, documenter une décision plutôt que la cacher — et, chapitre après chapitre, reconnaître qu'un même symptôme peut cacher des causes de nature radicalement différente : un bug de logique, une contrainte système, un comportement d'outil tiers, ou simplement une confusion de nommage entre deux exécutables qui se ressemblent. La CI, en particulier, a rappelé une vérité que le projet avait pourtant déjà frôlée plusieurs fois sans jamais la formuler aussi nettement : la meilleure preuve qu'un système fonctionne n'est jamais qu'il tourne chez son créateur, mais qu'il tourne identiquement ailleurs, sans lui.
 
---
 
*Ce document sera enrichi au fil des prochains chantiers : Data Vault, gouvernance/RGPD appliquée, orchestration du graphe dans le pipeline planifié.*