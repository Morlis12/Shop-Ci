# Shop_CI — Récit d'un projet d'analytics engineering, de la donnée sale à l'agent IA
 
> Ce document raconte *comment* et *pourquoi* les décisions ont été prises, pas seulement *quoi* a été construit. Il est pensé pour être lu comme un article : la trajectoire complète d'une reconversion vers l'analytics engineering, avec ses détours, ses erreurs corrigées, et ce qu'elles enseignent.
 
---
 
## Pourquoi ce projet
 
BoutiqueCI n'est pas un jeu de données Kaggle déjà propre. Les CSV sources ont été construits avec des pièges volontaires — trois formats de dates cohabitant dans la même colonne, des doublons de clients par email, des paiements en retry, des clés orphelines — précisément pour reproduire les problèmes qu'un analytics engineer rencontre réellement, et non les exercices d'école où tout fonctionne du premier coup.
 
L'objectif final n'était pas seulement de "faire tourner un pipeline dbt", mais de construire une chaîne complète et cohérente : de l'audit d'un fichier sale jusqu'à un agent IA capable de répondre, en langage naturel et avec des chiffres gouvernés, aux questions d'un client fictif — jusqu'à une chaîne CI/CD qui protège ce travail, une restitution Power BI pilotée en partie par l'IA elle-même, une portabilité cloud démontrée, une orchestration à la hauteur des standards du marché, une preuve de reproductibilité par conteneurisation, et deux modélisations coexistantes du même socle de données.
 
---
 
## Partie 1 — Le pipeline : discipline avant tout
 
### L'audit avant la transformation
 
Chaque chantier a commencé par la même question : *qu'est-ce que je vois vraiment dans les données, avant de décider quoi que ce soit ?* Les CSV ont été lus en texte brut (`all_varchar=true`) précisément pour ne rien masquer — un typage automatique aurait caché la coexistence de plusieurs formats de dates dans une même colonne, le vrai piège du projet.
 
### Une règle qui traverse tout le projet : ne jamais faire disparaître silencieusement une donnée
 
C'est devenu le fil rouge de toutes les décisions suivantes. Le staging ne supprime jamais de lignes sans raison analytique — les doublons de paiements sont *flaggés*, pas effacés. Et surtout : le membre client "inconnu" (`id = -1`) a été délibérément **conservé** dans le modèle en étoile, plutôt qu'exclu. Cette décision, en apparence mineure, s'est révélée structurante bien plus tard : elle a directement dicté la priorité des règles de classification dans le graphe de connaissances, s'est retrouvée jusque dans les écarts de comptage observés en Power BI, a resurgi lors de la migration BigQuery (101 commandes orphelines retrouvées identiques), et a été reprise une dernière fois — sous une forme plus précise encore — par le Data Vault (91 vraies commandes orphelines, distinctes des doublons éliminés).
 
### Le semantic layer : une définition, pas une opinion
 
Le vrai déclic du projet a été le semantic layer MetricFlow. Avant lui, "le chiffre d'affaires" pouvait avoir plusieurs valeurs selon qui le calculait — un écart de 13% observé concrètement entre deux calculs indépendants. La métrique `ca_officiel` a mis fin à cette ambiguïté en la codifiant une fois pour toutes. Ce principe s'est révélé si central qu'il a fini par se **répliquer** ailleurs dans le projet — d'abord en SPARQL sur le graphe, puis en DAX dans Power BI, et la tension qui en découle (trois traductions d'une même définition, jamais une seule source hébergée) est restée un fil de discussion jusqu'au chantier MCP Power BI, bien plus tard.
 
---
 
## Partie 2 — L'orchestration : capturer un code n'est pas le promouvoir en verdict
 
Le script `pipeline_quotidien.ps1` a introduit un principe simple : chaque commande rend son propre code de sortie, mais le *verdict global* du pipeline est une décision explicite, pas une moyenne automatique. La fraîcheur des sources est capturée et journalisée, mais volontairement exclue du verdict final — une exception commentée est une décision d'architecte ; la même exception muette serait un bug en devenir.
 
---
 
## Partie 3 — Le graphe de connaissances : donner un sens interrogeable aux données
 
### Pourquoi un graphe, et pas juste plus de SQL
 
Un modèle en étoile répond très bien aux questions qu'on a prévu de poser. Un graphe de connaissances répond aussi aux questions qu'on *n'a pas prévues* : "quels clients à haute valeur achètent des produits peu rentables ?" est une traversée à trois sauts, triviale en SPARQL grâce à une relation explicite posée entre les classes, laborieuse en SQL pur.
 
### Le patron en trois fichiers, devenu quatre
 
L'architecture — ontologie, export, classification — a fini par accueillir une quatrième pièce : la réinjection des labels vers un consommateur BI qui ne parle pas SPARQL. Chaque nouvelle destination de consommation (l'agent IA, puis Power BI) a exigé sa propre traduction du même savoir, jamais un accès direct au format natif du graphe.
 
---
 
## Partie 4 — Le serveur MCP : quand la théorie rencontre l'environnement réel
 
La chaîne d'incidents la plus longue et la plus instructive du projet — colonne manquante, doublon YAML silencieux, processus zombies, et finalement un sandboxing système bloquant tout sous-processus — a été résolue non par une intuition heureuse, mais par une discipline répétée : reproduire chaque symptôme à la main, mesurer plutôt que supposer, isoler une seule variable à la fois. La décision finale n'a pas été de "réparer" MetricFlow en sous-processus à tout prix, mais de contourner proprement, avec la garantie documentée que le contournement reproduit fidèlement le même périmètre que l'original — une garantie qui a directement servi, bien plus tard, à justifier la vérification croisée du chantier MCP Power BI.
 
---
 
## Partie 5 — CI/CD : la preuve par l'environnement neuf
 
### Le principe qui a tout changé
 
Jusqu'ici, "ça marche" signifiait "ça marche sur ma machine" — un état qui accumule, sans qu'on le remarque, des traces de tout ce qu'on a construit avant. GitHub Actions a introduit une contrainte radicalement différente : une machine virtuelle vierge, sans aucune mémoire de ce qui précède, à chaque exécution.
 
### La découverte la plus révélatrice de tout le projet
 
La première tentative de CI a immédiatement échoué — pas sur le graphe, pas sur une nouveauté, mais sur un test unitaire déjà écrit et considéré comme acquis depuis des semaines : `ut_filtre_incremental_fenetre_glissante`. Le mock de `{{ this }}` fournissait une colonne (`jour_commande`) différente de celle réellement lue par le filtre SQL du modèle (`date_commande_chargement`) — un bug de test dormant, invisible en local car `fait_ventes` y existait déjà d'un précédent `dbt build`. Ce n'est qu'en environnement radicalement neuf que le décalage est devenu fatal, révélant une leçon simple mais rarement vécue aussi concrètement : *"ça marche chez moi" n'a jamais été une preuve de reproductibilité.*
 
### Une deuxième leçon, plus discrète mais tout aussi utile
 
`pywin32`, un paquet Windows-only, faisait échouer l'installation entière sur la machine Linux de la CI — non pas parce que le projet en avait besoin, mais parce qu'une dépendance transitive (`mcp`) le réclamait sur Windows. Un marqueur PEP 508 n'a pas suffi à le contourner proprement ; la solution la plus robuste s'est révélée être la suppression pure et simple.
 
### De l'indicateur au garde-fou
 
Une CI qui passe au vert reste, par défaut, un simple indicateur visuel. La dernière étape du chantier a transformé cet indicateur en contrainte structurelle : une règle de protection de branche, rendant la fusion vers `main` **physiquement impossible** tant que la CI n'est pas verte.
 
---
 
## Partie 6 — Power BI : le dernier maillon, et ses propres surprises (première visite)
 
### Un connecteur qui n'existe pas nativement
 
Brancher Power BI sur DuckDB n'a rien d'immédiat : aucun connecteur natif, un passage obligé par un pilote ODBC dont l'installation a elle-même généré une confusion révélatrice — confondre l'installateur du pilote avec l'outil de configuration des sources de données.
 
### Le mono-écrivain, encore et toujours
 
La contrainte mono-écrivain de DuckDB est réapparue sous une forme nouvelle : Power BI, en chargeant plusieurs tables **en parallèle**, ouvrait simultanément plusieurs connexions au même fichier `.duckdb`, provoquant des échecs en cascade — résolu en désactivant explicitement le chargement parallèle.
 
### Un chevauchement d'identifiants presque invisible
 
La table `mart_decisions` cachait un piège de modélisation classique : un `id_client=7` et un `id_produit=7` coexistent naturellement. La correction — scinder la table en deux requêtes filtrées, une par type d'entité — est un rappel que même une table minimaliste peut receler une ambiguïté qu'aucun test automatique n'aurait signalée sans vérification manuelle du schéma relationnel.
 
---
 
## Partie 7 — BigQuery : porter le même projet sur un vrai warehouse cloud
 
### Pourquoi cette étape, maintenant
 
Après la recherche du marché de l'analytics engineering, un constat s'est imposé : DuckDB n'apparaît dans aucune source consultée comme un outil de production recherché — le trio Snowflake/BigQuery/Databricks domine les offres réelles.
 
### Le premier obstacle : il n'y a pas de "fichier local" dans le cloud
 
`read_csv_auto()` n'a aucun équivalent sur BigQuery. Il a fallu construire `charger_csv_bigquery.py`, un mini-outil d'ingestion dans l'esprit d'un Fivetran fait maison.
 
### Le deuxième obstacle : deux dialectes SQL, un seul code source voulu
 
Les macros cross-database de dbt ont permis de garder un seul fichier `.sql` vrai sur les deux moteurs. Pour les cas sans équivalent générique (la génération de `dim_calendrier`), un routage conditionnel Jinja a permis de garder deux implémentations natives dans le même fichier.
 
### Une leçon sur les limites du parsing dbt
 
Une tentative d'utiliser une macro cross-database directement dans un fichier de contrat (`schema.yml`) a révélé une limite précise : l'objet Jinja `dbt` n'existe qu'au moment de la compilation SQL, pas au moment du parsing des fichiers YAML.
 
### Une divergence de comportement SQL, pas de syntaxe
 
Le modèle `fait_ventes` filtrait sur un alias défini dans son propre `SELECT` — toléré par DuckDB, refusé par BigQuery en raison d'un ordre d'exécution SQL plus strict.
 
### L'incident `_sources.yml` : deux tentatives ratées avant la simplification
 
Une première tentative de routage conditionnel directement dans le YAML (`{% if target.type == 'bigquery' %}`) a échoué : contrairement aux fichiers `.sql`, le YAML n'a pas un support Jinja structurel complet — on peut y substituer une valeur, pas y ajouter ou retirer des clés entières selon une condition. L'erreur (`found character that cannot start any token`) a confirmé que le fichier avait été lu comme du YAML brut, jamais évalué par Jinja avant le parsing.
 
Une deuxième tentative — deux sources nommées distinctement, choisies via une macro `source_brut()` — a échoué à son tour, d'une façon plus subtile : sur DuckDB, une source avec `external_location` déclenche un mécanisme spécial de l'adaptateur (remplacement de l'appel par un texte SQL complet `read_csv_auto(...)`) qui ne s'est pas correctement déclenché en passant par une macro intermédiaire, produisant un texte dupliqué (`select * select * from read_csv_auto(...)`).
 
Face à ces deux échecs, la décision finale a été d'**abandonner complètement la double compatibilité** : puisque la cible réelle de production est BigQuery, maintenir deux chemins ajoutait de la complexité sans bénéfice réel — un retour à la simplicité maximale, cohérent avec un principe déjà appliqué ailleurs dans le projet (éviter la sur-ingénierie pour un besoin qu'on n'a pas vraiment).
 
### Pourquoi deux environnements, un seul moteur
 
La tentation "DuckDB pour le développement, BigQuery pour la production" a été explicitement écartée. Deux moteurs SQL différents entre dev et prod auraient recréé exactement le piège que la CI avait déjà révélé une fois : une validation locale qui ne prouve rien de fiable sur l'environnement réel.
 
---
 
## Partie 8 — Dagster : de la commande isolée à l'orchestration observable
 
### Le principe qui change tout : penser en assets, pas en commandes
 
`pipeline_quotidien.ps1` exécute une **suite de commandes** ; Dagster raisonne en **assets**, chaque table produite devenant un objet que l'outil sait construire, surveiller, et relier à ses dépendances. `dagster-dbt` lit directement le `manifest.json` déjà généré par dbt et transforme automatiquement chaque modèle en asset — le vrai projet dbt reste la seule source de vérité, jamais dupliqué.
 
### Une chaîne d'incidents entièrement liée à la structure de fichiers, pas à la logique
 
Le premier échec (`FileNotFoundError`) provenait d'un chemin doublé, la commande étant relancée depuis un répertoire de travail incohérent avec le chemin relatif fourni. Le deuxième échec, plus révélateur, était un `ModuleNotFoundError: No module named 'assets'` — la découverte que les fichiers `assets.py` et `definitions.py` donnés à copier-coller n'avaient en réalité **jamais été sauvegardés**, seul `__init__.py` (vide, 0 octet) ayant été créé. Une vérification systématique de la taille réelle de chaque fichier a confirmé le problème avant toute nouvelle tentative.
 
Une fois les fichiers réellement présents, un troisième obstacle est apparu : un import absolu (`from assets import ...`) échouait parce que Dagster résout les modules locaux depuis le répertoire de travail **externe**, pas depuis le sous-dossier interne où vivait réellement le fichier. La correction — un import qualifié (`from dagster_shop_ci.assets import ...`) — a nécessité de comprendre précisément depuis quel point Dagster construit son espace de noms.
 
### Le port qui refusait de se libérer, et la persistance de l'état
 
Une dernière anicroche, familière dans son mécanisme sinon dans sa forme : un ancien serveur Dagster, jamais arrêté proprement (fenêtre fermée plutôt que Ctrl+C), continuait d'occuper le port 3000 — le même principe que les processus Python "zombies" rencontrés avec DuckDB. Enfin, sans `DAGSTER_HOME` fixé explicitement, l'historique des runs et l'état du schedule s'effaçaient à chaque fermeture du serveur — un dernier détail transformant un outil qui "oublie tout" en système véritablement persistant.
 
---
 
## Partie 9 — Docker : la preuve ultime de reproductibilité
 
### Le principe de sécurité posé avant la première ligne de code
 
Avant d'écrire le moindre `Dockerfile`, une règle a été fixée : une image Docker peut être partagée, inspectée par n'importe qui — y intégrer un secret serait pire que de le committer dans Git. La clé de service BigQuery ne devait jamais apparaître dans une instruction `COPY`, uniquement injectée au moment de l'exécution via un volume monté.
 
### Une vérification, pas une supposition
 
Une fois l'image construite, l'affirmation "le secret n'y est jamais entré" n'a pas été acceptée sur la seule foi du `.dockerignore` — elle a été vérifiée concrètement, une recherche exhaustive à l'intérieur de l'image ne renvoyant aucun résultat.
 
### Un avertissement qui méritait d'être compris, pas ignoré
 
Docker a signalé `SecretsUsedInArgOrEnv` sur la variable `GOOGLE_APPLICATION_CREDENTIALS`. La distinction a été clarifiée plutôt qu'ignorée : cette variable ne contenait qu'un chemin de fichier, jamais le secret lui-même.
 
### Le seul vrai obstacle technique : où vit le profil de connexion
 
Le premier lancement du conteneur a échoué sur `Path '/root/.dbt' does not exist`. La décision retenue — générer un `profiles.yml` autosuffisant directement dans l'image, sans le vrai secret — rend le conteneur indépendant de toute configuration locale.
 
### La preuve finale
 
Le pipeline complet, exécuté depuis un conteneur Linux isolé, a produit un résultat rigoureusement identique au run local et à la CI GitHub Actions — trois environnements complètement indépendants, un seul et même résultat.
 
---
 
## Partie 10 — Data Vault : deux modélisations, une même vérité brute
 
### La question qui a structuré tout le chantier
 
Une question posée à voix haute — *"le Data Vault ne peut pas exister de lui-même, il y a toujours un staging au départ ?"* — a mené à une clarification centrale : le Data Vault doit partir du **staging**, jamais des **marts**, pour ne jamais hériter silencieusement d'une décision métier déjà prise par Kimball.
 
Cette clarification a eu une conséquence concrète immédiate : `hub_client`, construit initialement depuis `stg_clients` (qui élimine déjà 10 doublons), s'est révélé lui aussi hériter d'une décision de périmètre. La correction — reconstruire `hub_client` depuis la source brute pour couvrir les 510 identités, pas seulement les 500 survivants — a été la première vraie leçon pratique de ce chantier.
 
### Le test du "nom commun" pour choisir un Hub
 
Trois candidats ont été retenus — Client, Produit, Commande — selon un critère précis : *"cette chose peut-elle exister et avoir un sens, même si rien d'autre ne lui était jamais associé ?"* Ce même test, appliqué a posteriori, a révélé un oubli : deux tables de faits existaient côté Kimball (`fait_ventes`, `fait_paiements`), mais un seul Link avait été construit initialement — `link_paiement` a suivi.
 
### Le Link `same-as` : documenter une décision, sans jamais l'appliquer
 
`link_client_same_as` a demandé plusieurs clarifications avant de se comprendre pleinement : ce n'est pas une table qui *fait* quelque chose — contrairement à `int_correspondance_clients`, qui fusionne activement les doublons dans les marts finaux, le Link se contente d'enregistrer un fait, sans jamais l'appliquer lui-même. La vraie différence avec une simple table de correspondance n'est pas le contenu informatif, mais la forme : des hash keys standardisées, dont la valeur n'apparaît clairement qu'à grande échelle — construite ici pour la démontrer et savoir l'expliquer, pas parce qu'elle change concrètement quelque chose sur un projet de cette taille.
 
### Une découverte plus précise que ce que Kimball avait révélé
 
Un test d'intégrité systématique a révélé 91 commandes orphelines, pas 101 — non pas une erreur, mais une distinction plus fine que Kimball avait masquée. Sur les 101 déjà connues, une partie référençait des `id_client` qui existaient bien en brut, simplement éliminés par le dédoublonnage. Restent 91 vrais orphelins absolus. Le Data Vault n'a pas corrigé une erreur — il a posé une question plus précise à la même donnée.
 
### Une correction méthodologique en cours de route, sur le test lui-même
 
Une première tentative de test d'intégrité (`relationships` déclaré directement au niveau du modèle) a échoué uniformément sur les 9 tests avec un message cryptique (`SELECT list must not be empty`) — une erreur de structure YAML, pas de données. La correction (imbriquer chaque test sous `columns: → name:`) a rappelé une règle dbt déjà croisée ailleurs : un test générique doit toujours être rattaché à une colonne précise.
 
---
 
## Partie 11 — MCP Power BI : deux serveurs, un seul agent, une vérification croisée
 
### Pourquoi ce chantier, et ce qu'il ne fallait pas promettre à tort
 
La tentation naturelle, en formulant l'objectif, était de viser une "synchronisation automatique" entre MetricFlow et les mesures DAX de Power BI — mais une vérification rapide, avant de lancer la première vraie commande, a rappelé une limite déjà documentée depuis le chapitre serveur MCP : le serveur maison ne lit jamais directement MetricFlow, à cause du blocage de sous-processus. Cette vérification, faite avant plutôt qu'après, a changé la nature de la démonstration : plutôt qu'une synchronisation de définitions (impossible avec l'architecture actuelle), l'objectif est devenu une **vérification croisée de cohérence** entre deux systèmes indépendants.
 
### L'installation, plus simple que prévu — une vraie rareté dans ce projet
 
Contrairement à la plupart des chantiers précédents, l'installation du serveur MCP Power BI officiel s'est déroulée sans incident notable : une extension VS Code, un exécutable généré à un chemin prévisible, une déclaration dans `claude_desktop_config.json` à côté du serveur déjà existant.
 
### La première vraie preuve : lecture, avant toute écriture
 
Une simple demande de lister les tables et les mesures existantes a confirmé que la connexion XMLA locale fonctionnait correctement : 14 tables et 6 mesures DAX retrouvées, identiques à ce qui avait été construit au chapitre Power BI, plusieurs semaines auparavant.
 
### Un premier essai qui n'a pas fait ce qu'on croyait — et pourquoi ce n'était pas un échec
 
La première tentative de démonstration a comparé deux valeurs déjà existantes, confirmant leur identité — un résultat juste, mais qui n'a rien prouvé de nouveau sur la capacité **d'écriture** du serveur. Une remarque directe a permis de corriger le tir avant de conclure trop vite.
 
### La preuve finale, vérifiée à l'endroit qui compte vraiment
 
La création de `ca_clients_vip`, combinant `ca_officiel` et la classification du graphe, a été vérifiée non pas sur l'affirmation de l'agent, mais par un contrôle indépendant : ouvrir Power BI Desktop directement et constater la présence de la nouvelle mesure — exactement la même discipline appliquée au chapitre Docker.
 
---
 
## Ce que ce projet démontre
 
Au-delà de l'empilement technique, ce projet est une démonstration de méthode : auditer avant de transformer, gouverner une définition avant de la multiplier, documenter une décision plutôt que la cacher — et, chapitre après chapitre, reconnaître qu'un même symptôme peut cacher des causes de nature radicalement différente. La CI a rappelé qu'un système qui tourne chez son créateur ne prouve rien tant qu'il ne tourne pas identiquement ailleurs. Docker a poussé cette preuve à son terme. Le Data Vault a montré qu'une règle qu'on vient de poser mérite d'être vérifiée sur son premier cas concret, pas simplement appliquée de mémoire. Le chantier MCP Power BI, en clôture, a rappelé la discipline la plus simple et la plus souvent négligée : savoir reconnaître, avant de démontrer quoi que ce soit, la différence entre ce qu'on souhaiterait prouver et ce que l'architecture réelle permet honnêtement de prouver.
 
---
 
*Ce document sera enrichi au fil des prochains chantiers : Superset, OpenClaw, gouvernance/RGPD, second projet dédié aux packages dbt de certification.*