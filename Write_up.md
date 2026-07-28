# Shop_CI — Récit d'un projet d'analytics engineering, de la donnée sale à l'agent IA
 
> Ce document raconte *comment* et *pourquoi* les décisions ont été prises, pas seulement *quoi* a été construit.
 
---
 
## Pourquoi ce projet
 
BoutiqueCI n'est pas un jeu de données Kaggle déjà propre. Les CSV sources ont été construits avec des pièges volontaires — trois formats de dates, doublons de clients, paiements en retry, clés orphelines — pour reproduire les problèmes qu'un analytics engineer rencontre réellement.
 
L'objectif n'était pas seulement de "faire tourner un pipeline dbt", mais de construire une chaîne complète : de l'audit d'un fichier sale jusqu'à un agent IA capable de répondre en langage naturel, jusqu'à une chaîne CI/CD, une restitution Power BI, une portabilité cloud démontrée, et une orchestration à la hauteur des standards du marché.
 
---
 
## Partie 1 — Le pipeline : discipline avant tout
 
Chaque chantier a commencé par la même question : *qu'est-ce que je vois vraiment, avant de décider quoi que ce soit ?* Un principe traverse tout le projet : ne jamais faire disparaître silencieusement une donnée. Le membre client "inconnu" (`id = -1`), conservé plutôt qu'exclu, s'est révélé structurant bien au-delà de sa portée initiale — jusque dans la logique de classification du graphe, puis dans les comptages observés en Power BI, puis dans les 101 commandes orphelines retrouvées identiques après la migration BigQuery.
 
## Partie 2 — Le semantic layer : une définition, pas une opinion
 
La métrique `ca_officiel` a mis fin à l'ambiguïté d'un chiffre d'affaires calculable de plusieurs façons différentes — un écart de 13% observé avant sa mise en place. Ce principe s'est répliqué ailleurs : en SPARQL sur le graphe, puis en DAX dans Power BI. Trois traductions d'une même définition, une tension de gouvernance assumée plutôt que cachée.
 
## Partie 3 — Le graphe de connaissances
 
Un modèle en étoile répond aux questions prévues. Un graphe répond aussi aux questions imprévues : une traversée à trois sauts, triviale en SPARQL, laborieuse en SQL pur. Le patron en trois fichiers (ontologie, export, classification) a fini par accueillir une quatrième pièce, réinjectant la classification vers un consommateur BI qui ne parle pas SPARQL.
 
## Partie 4 — Le serveur MCP
 
La chaîne d'incidents la plus longue du projet a été résolue par une discipline répétée : reproduire, mesurer, isoler une variable à la fois. La décision finale a été de contourner proprement un blocage système, avec la garantie documentée que le contournement reproduit fidèlement l'original.
 
## Partie 5 — CI/CD : la preuve par l'environnement neuf
 
La première tentative de CI a immédiatement révélé un bug dormant dans un test unitaire considéré comme acquis — invisible en local, fatal sur une machine vierge. Une règle de protection de branche a transformé le statut CI d'un indicateur visuel en contrainte structurelle.
 
## Partie 6 — Power BI : le dernier maillon, et ses propres surprises
 
Le mono-écrivain DuckDB est réapparu sous une forme nouvelle : Power BI chargeant plusieurs tables en parallèle. La table `mart_decisions` cachait un piège de modélisation classique — un chevauchement d'identifiants entre clients et produits, résolu par deux requêtes filtrées distinctes.
 
## Partie 7 — BigQuery : porter le même projet sur un vrai warehouse cloud
 
Après une recherche du marché de l'analytics engineering, un constat s'est imposé : DuckDB n'apparaît dans aucune offre comme un outil de production recherché. La migration a exigé un mini-outil d'ingestion (`charger_csv_bigquery.py`), les macros cross-database de dbt pour éviter de dupliquer le code, un routage conditionnel Jinja pour `dim_calendrier`, et la découverte qu'un filtre sur alias toléré par DuckDB est refusé par BigQuery en raison d'un ordre d'exécution SQL plus strict. La tentation "DuckDB en dev, BigQuery en prod" a été explicitement écartée : deux moteurs différents entre ces deux environnements auraient recréé le piège que la CI avait déjà révélé une fois.
 
---
 
## Partie 8 — Dagster : de la commande isolée à l'orchestration observable
 
### Pourquoi cette étape, après BigQuery
 
Une fois le pipeline portable et testé sur le cloud, la question suivante devenait inévitable : comment le faire tourner de façon fiable, observable, et reproductible — pas juste "je tape une commande dans un terminal quand j'y pense" ? `pipeline_quotidien.ps1` répondait à cette question au Niveau 1 (planification locale). Dagster répond à la même question au Niveau 3 : un orchestrateur dédié, avec une interface de suivi que ni PowerShell ni un simple cron ne fournissent nativement.
 
### Le principe qui change tout : penser en assets, pas en commandes
 
La bascule mentale la plus importante de ce chantier n'était pas technique mais conceptuelle : `pipeline_quotidien.ps1` exécute une **suite de commandes** ; Dagster raisonne en **assets**, chaque table produite devenant un objet que l'outil sait construire, surveiller, et relier à ses dépendances. `dagster-dbt` lit directement le `manifest.json` déjà généré par dbt et transforme automatiquement chaque modèle en asset — aucune redéclaration manuelle, le vrai projet dbt reste la seule source de vérité, jamais dupliqué.
 
### Une chaîne d'incidents entièrement liée à la structure de fichiers, pas à la logique
 
Contrairement aux chantiers précédents, aucun des obstacles rencontrés ici ne concernait la logique métier — tous provenaient de la façon dont Python et Dagster résolvent les chemins et les imports, un terrain nouveau pour ce projet.
 
Le premier échec (`FileNotFoundError`) provenait d'un chemin doublé : la commande `dagster dev -f dagster_shop_ci\definitions.py` avait été relancée depuis un répertoire de travail qui rendait ce chemin relatif incohérent. Le deuxième échec, plus révélateur, était un `ModuleNotFoundError: No module named 'assets'` — la découverte que les fichiers `assets.py` et `definitions.py` donnés à copier-coller n'avaient en réalité jamais été sauvegardés, seul `__init__.py` (vide) ayant été créé. Une vérification systématique de la taille réelle de chaque fichier, avant toute nouvelle tentative, a confirmé le problème avant de corriger à l'aveugle.
 
Une fois les fichiers réellement présents, un troisième obstacle est apparu, plus subtil : un import absolu (`from assets import ...`) échouait parce que Dagster résout les modules locaux depuis le répertoire de travail **externe**, pas depuis le sous-dossier interne où vivait réellement le fichier. La correction — un import qualifié (`from dagster_shop_ci.assets import ...`) — a nécessité de comprendre précisément depuis quel point Dagster construit son espace de noms, une leçon qui dépasse largement ce seul projet.
 
### Le port qui refusait de se libérer
 
Une dernière anicroche, familière dans son mécanisme sinon dans sa forme : `[Errno 10048] only one usage of each socket address` — un ancien serveur Dagster, jamais arrêté proprement (fenêtre fermée plutôt que Ctrl+C), continuait d'occuper le port 3000. Le même principe que les processus Python "zombies" rencontrés avec DuckDB à plusieurs reprises dans ce projet : un arrêt propre (Ctrl+C, pas une fermeture brutale de fenêtre) évite systématiquement ce genre d'incident.
 
### La persistance de l'état comme détail non négligeable
 
Un dernier point, facile à manquer : sans variable d'environnement `DAGSTER_HOME` fixée explicitement, Dagster utilise un dossier temporaire, effacé à chaque fermeture du serveur — y compris l'historique des runs et l'état d'activation du schedule. Fixer cette variable de façon permanente a transformé un outil qui "oublie tout" entre deux sessions en un vrai système persistant, cohérent avec l'exigence de continuité qu'on attend d'un orchestrateur de production.
 
---
 
## Ce que ce projet démontre
 
Une méthode de diagnostic transférable, appliquée identiquement quel que soit l'outil : lire le message d'erreur en entier, reproduire avant d'accuser, isoler une seule variable à la fois, vérifier plutôt que supposer. Le chantier Dagster confirme une vérité déjà entrevue plusieurs fois : la majorité des incidents rencontrés dans un nouvel outil ne viennent pas de sa logique propre, mais de la façon dont il s'articule avec l'environnement qui l'entoure — chemins, imports, processus, état persistant. Une compétence bien plus rare, et bien plus utile à long terme, que la mémorisation de la syntaxe d'un outil précis.
 
---
 
*Ce document sera enrichi au fil des prochains chantiers : Docker, Data Vault, gouvernance/RGPD appliquée.*