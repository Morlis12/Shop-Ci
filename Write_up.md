# Shop_CI — Récit d'un projet d'analytics engineering, de la donnée sale à l'agent IA
 
> Ce document raconte *comment* et *pourquoi* les décisions ont été prises, pas seulement *quoi* a été construit. Il est pensé pour être lu comme un article : la trajectoire complète d'une reconversion vers l'analytics engineering, avec ses détours, ses erreurs corrigées, et ce qu'elles enseignent.
 
---
 
## Pourquoi ce projet
 
BoutiqueCI n'est pas un jeu de données Kaggle déjà propre. Les CSV sources ont été construits avec des pièges volontaires — trois formats de dates cohabitant dans la même colonne, des doublons de clients par email, des paiements en retry, des clés orphelines — précisément pour reproduire les problèmes qu'un analytics engineer rencontre réellement, et non les exercices d'école où tout fonctionne du premier coup.
 
L'objectif final n'était pas seulement de "faire tourner un pipeline dbt", mais de construire une chaîne complète et cohérente : de l'audit d'un fichier sale jusqu'à un agent IA capable de répondre, en langage naturel et avec des chiffres gouvernés, aux questions d'un client fictif.
 
---
 
## Partie 1 — Le pipeline : discipline avant tout
 
### L'audit avant la transformation
 
Chaque chantier a commencé par la même question : *qu'est-ce que je vois vraiment dans les données, avant de décider quoi que ce soit ?* Les CSV ont été lus en texte brut (`all_varchar=true`) précisément pour ne rien masquer — un typage automatique aurait caché la coexistence de plusieurs formats de dates dans une même colonne, le vrai piège du projet.
 
### Une règle qui traverse tout le projet : ne jamais faire disparaître silencieusement une donnée
 
C'est devenu le fil rouge de toutes les décisions suivantes. Le staging ne supprime jamais de lignes sans raison analytique — les doublons de paiements sont *flaggés*, pas effacés, car un retry raté est en soi une information sur la fiabilité du système de paiement. Et surtout : le membre client "inconnu" (`id = -1`) — les commandes dont l'identité du client n'a jamais pu être établie — a été délibérément **conservé** dans le modèle en étoile, plutôt qu'exclu. Cette décision, en apparence mineure, s'est révélée structurante bien plus tard : elle a directement dicté la priorité des règles de classification dans le graphe de connaissances (voir Partie 3), où `ClientNonIdentifie` a été positionné en priorité absolue, avant même `ClientVIP`.
 
### Le semantic layer : une définition, pas une opinion
 
Le vrai déclic du projet a été le semantic layer MetricFlow. Avant lui, "le chiffre d'affaires" pouvait avoir plusieurs valeurs selon qui le calculait — avec ou sans les commandes annulées, avec ou sans les retours. La métrique `ca_officiel` a mis fin à cette ambiguïté en la codifiant une fois pour toutes : filtre unique, définition unique, tous les consommateurs (SQL, Power BI, et plus tard l'agent IA) obtiennent le même chiffre. L'écart observé entre `ca_brut` et `ca_officiel` — environ 13 % — a illustré concrètement pourquoi cette gouvernance compte : sans elle, deux analystes auraient pu arriver en réunion avec deux chiffres différents, tous deux "corrects" selon leur propre définition non écrite.
 
---
 
## Partie 2 — L'orchestration : capturer un code n'est pas le promouvoir en verdict
 
Le script `pipeline_quotidien.ps1` a introduit un principe simple mais souvent mal compris : chaque commande rend son propre code de sortie, mais le *verdict global* du pipeline est une décision explicite, pas une moyenne automatique. La fraîcheur des sources, structurellement toujours en échec sur des données fictives figées en 2025, est capturée et journalisée — mais volontairement exclue du `if` final qui décide du succès ou de l'échec. Le commentaire dans le script documente ce choix : une exception commentée est une décision d'architecte ; la même exception muette serait un bug en devenir.
 
---
 
## Partie 3 — Le graphe de connaissances : donner un sens interrogeable aux données
 
### Pourquoi un graphe, et pas juste plus de SQL
 
Un modèle en étoile répond très bien aux questions qu'on a prévu de poser. Un graphe de connaissances répond aussi aux questions qu'on *n'a pas prévues* : "quels clients à haute valeur achètent des produits peu rentables ?" est une traversée à trois sauts (Client → Vente → Produit) qui serait laborieuse en SQL pur, mais triviale en SPARQL grâce à une relation explicite (`ObjectProperty`) posée entre les classes.
 
### Le patron en trois fichiers
 
L'architecture — ontologie, export, classification — sépare strictement trois responsabilités : la *grammaire* du domaine (quelles classes, quelles règles existent), le *peuplement* par les données réelles (lecture seule sur DuckDB), et l'*inférence* (les règles SPARQL `CONSTRUCT` qui déduisent les labels métier). Cette séparation, reprise d'un projet antérieur sur le secteur aérien, s'est révélée directement transposable : le vocabulaire change (`Client`, `Produit`), mais la structure — classe mère, sous-classes de décision documentées, règles ordonnées par priorité, contrôle de cohérence automatisé — reste identique.
 
### Calibrer sur le réel, pas sur l'intuition
 
Les seuils de classification (`ClientVIP` : CA ≥ 500 000 et ≥ 8 commandes) n'ont pas été choisis arbitrairement — ils ont émergé d'un audit préalable des distributions réelles. Une première intuition sur les produits ("il doit bien y avoir des produits à perte") s'est révélée fausse : tous les produits du jeu de données affichaient un volume et une marge confortables. Plutôt que d'inventer artificiellement une catégorie vide, les seuils ont été recalibrés sur ce que les données montraient vraiment.
 
---
 
## Partie 4 — Le serveur MCP : quand la théorie rencontre l'environnement réel
 
C'est la partie la plus longue à raconter, et la plus instructive.
 
### La chaîne d'incidents
 
Brancher un serveur MCP à Claude Desktop a semblé, sur le papier, être la dernière étape simple d'un projet déjà solide. En pratique, elle a révélé une chaîne de six couches de causalité différentes : une colonne manquante dans une requête SQL, un doublon silencieux dans un fichier YAML qui dormait sans symptôme visible, des processus Python "zombies" gardant un fichier verrouillé, un dossier jamais créé, et finalement — la découverte la plus structurelle — un sandboxing système qui bloquait discrètement toute tentative d'invoquer un sous-processus externe depuis le serveur.
 
### La méthode plutôt que la chance
 
Ce qui a permis de progresser n'a jamais été une intuition heureuse, mais une discipline répétée : reproduire chaque symptôme à la main avant d'accuser un outil ; mesurer un temps d'exécution plutôt que de le supposer ; isoler une seule variable à la fois ; et, décisif, injecter une preuve sans ambiguïté (`return "VERSION_TEST_12345"`) pour trancher définitivement une hypothèse binaire plutôt que de deviner. Trois architectures différentes ont été tentées pour contourner le blocage du sous-processus — bloquante, en thread séparé, asynchrone native — et les trois ont échoué de façon similaire en conditions réelles tout en fonctionnant parfaitement en test manuel isolé. Ce motif répété a fini par pointer vers la bonne explication : la cause n'était pas dans le code, mais dans le contexte d'exécution imposé par l'environnement sandboxé de l'application cliente.
 
### Savoir s'arrêter et documenter, plutôt que s'acharner
 
La décision finale n'a pas été de "réparer" MetricFlow en sous-processus à tout prix, mais de reconnaître la contrainte comme structurelle et de la contourner proprement : la métrique `ca_officiel` est recalculée directement sur le graphe de connaissances, avec la garantie que ce calcul reproduit exactement le même périmètre que le semantic layer, puisque le même filtre est appliqué dès l'export du graphe. Cette limitation est documentée explicitement dans le code et dans ce projet, plutôt que dissimulée — une décision d'architecte assumée, pas un aveu d'échec.
 
---
 
## Ce que ce projet démontre
 
Au-delà de l'empilement technique (dbt, DuckDB, MetricFlow, RDF/OWL/SPARQL, MCP), ce projet est avant tout une démonstration de méthode : auditer avant de transformer, gouverner une définition avant de la multiplier, documenter une décision plutôt que la cacher, et surtout — reconnaître qu'un même symptôme peut cacher des causes de nature radicalement différente, du bug de logique à la contrainte système, en passant par le comportement de raisonnement d'un agent IA lui-même.
 
---
 
*Ce document sera enrichi au fil des prochains chantiers : le livrable interactif client, Power BI, le Data Vault.*