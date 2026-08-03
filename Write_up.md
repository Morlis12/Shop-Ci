# Shop_CI — Récit d'un projet d'analytics engineering, de la donnée sale à l'agent IA
 
> Ce document raconte *comment* et *pourquoi* les décisions ont été prises, pas seulement *quoi* a été construit.
 
---
 
## Pourquoi ce projet
 
BoutiqueCI n'est pas un jeu de données déjà propre. Les CSV sources ont été construits avec des pièges volontaires pour reproduire les problèmes qu'un analytics engineer rencontre réellement. L'objectif : une chaîne complète, de l'audit d'un fichier sale jusqu'à un agent IA capable de répondre en langage naturel, avec une CI/CD, une restitution Power BI, une portabilité cloud, une orchestration moderne, une preuve de reproductibilité par conteneurisation, et désormais deux modélisations coexistantes du même socle de données.
 
---
 
## Parties 1 à 9 — résumé
 
Le pipeline applique une discipline stricte autour d'un principe constant : ne jamais faire disparaître silencieusement une donnée. Le semantic layer a mis fin à un écart de 13% entre deux calculs du même chiffre d'affaires. Le graphe de connaissances répond aux questions relationnelles qu'un modèle en étoile gère mal. Le serveur MCP, la CI/CD, Power BI, la migration BigQuery, Dagster et Docker ont chacun révélé leur propre chaîne d'incidents instructifs — jamais des bugs isolés, toujours des leçons sur la façon dont un outil s'articule avec son environnement.
 
---
 
## Partie 10 — Data Vault : deux modélisations, une même vérité brute
 
### Pourquoi construire une deuxième modélisation plutôt que de remplacer la première
 
Le Data Vault n'a jamais eu vocation à remplacer Kimball dans ce projet — les deux coexistent, chacun répondant à un besoin différent : Kimball pour la restitution rapide et intuitive (ce que Power BI et l'agent IA consomment déjà), Data Vault pour l'audit et la traçabilité. La vraie valeur pédagogique de ce chantier n'était pas de construire un Hub ou un Link — c'était de comprendre **où**, précisément, le Data Vault doit puiser ses données, une question qui a occupé une bonne partie de la construction.
 
### La question qui a structuré tout le chantier : d'où le Data Vault doit-il partir
 
Une question posée à voix haute — *"le Data Vault ne peut pas exister de lui-même, il y a toujours un staging au départ ?"* — a mené à une clarification centrale : le Data Vault doit partir du **staging**, jamais des **marts**. La raison n'est pas stylistique : un mart Kimball comme `fait_ventes` contient déjà des décisions métier accumulées (le re-routage vers le membre inconnu, l'exclusion des commandes annulées) ; construire le Data Vault par-dessus en hériterait silencieusement, le réduisant à une copie déguisée plutôt qu'une vraie couche d'audit indépendante.
 
Cette clarification, en apparence simple, a eu une conséquence concrète immédiate et non anticipée : `hub_client`, construit initialement depuis `stg_clients` (qui élimine déjà 10 doublons par dédoublonnage), s'est révélé **lui aussi** hériter d'une décision de périmètre. La correction — reconstruire `hub_client` depuis la source brute pour couvrir les 510 identités, pas seulement les 500 survivants — a été la première vraie leçon pratique de ce chantier : même une règle qu'on vient de poser soi-même mérite d'être vérifiée sur le premier cas construit, pas simplement appliquée de mémoire.
 
### Le test du "nom commun" pour choisir un Hub
 
Trois candidats Hub ont été retenus — Client, Produit, Commande — selon un critère précis : *"cette chose peut-elle exister et avoir un sens, même si rien d'autre ne lui était jamais associé ?"* Une ligne de vente a été explicitement écartée de ce statut : elle n'existe que parce qu'un Client, un Produit et une Commande se rencontrent — la définition même d'une relation, pas d'une identité. Ce même test, appliqué a posteriori à Paiement, a révélé un oubli : deux tables de faits existaient côté Kimball (`fait_ventes`, `fait_paiements`), mais un seul Link avait été construit initialement. La correction a suivi la même logique déjà établie — `link_paiement`, rattaché au seul `hub_commande`, sans Client ni Produit directement impliqués.
 
### Le Link `same-as` : documenter une décision, sans jamais l'appliquer
 
La partie la plus longue à faire comprendre a été `link_client_same_as`. Sa nature a été mal comprise plusieurs fois avant de se clarifier : ce n'est pas une table qui *fait* quelque chose — contrairement à `int_correspondance_clients` côté Kimball, qui fusionne activement les doublons dans les marts finaux, le Link se contente d'**enregistrer un fait** ("ces deux identités désignent la même personne"), sans jamais l'appliquer lui-même. La vraie différence avec une simple table de correspondance n'est pas le contenu informatif — les deux portent la même information — mais la forme : des hash keys standardisées, dans le même format que n'importe quel autre Link du même Data Vault, plutôt que des colonnes "maison" propres à ce cas précis. Une différence dont la valeur n'apparaît clairement qu'à grande échelle, honnêtement peu perceptible sur un projet de cette taille — construite ici pour la démontrer et savoir l'expliquer, pas parce qu'elle change concrètement quelque chose aujourd'hui.
 
### Une découverte plus précise que ce que Kimball avait révélé
 
Un test d'intégrité systématique (`relationships` sur chaque hash key, vérifiant que chaque Link/Satellite pointe bien vers une ligne réellement présente dans son Hub) a révélé un chiffre inattendu : 91 commandes orphelines, pas 101. La différence ne signalait pas une erreur, mais une **distinction plus fine** que Kimball avait masquée : sur les 101 commandes déjà connues comme orphelines par rapport aux 500 survivants de `stg_clients`, une partie référençait en réalité des `id_client` qui existaient bien dans les données brutes, simplement éliminés par le dédoublonnage — ces cas-là, résolus par le Hub élargi aux 510 identités, ont disparu du décompte. Restent 91 vrais orphelins absolus, des commandes référençant un `id_client` qui n'a jamais existé nulle part, même en brut. Le Data Vault n'a pas corrigé une erreur de Kimball — il a simplement posé une question plus précise à la même donnée, et obtenu une réponse plus fine.
 
### Une correction méthodologique en cours de route, sur le test lui-même
 
Une première tentative de test d'intégrité (`relationships` déclaré directement au niveau du modèle, sans colonne précisée) a échoué uniformément sur les 9 tests avec un message cryptique (`SELECT list must not be empty`) — une erreur de structure YAML, pas de données. La correction (imbriquer chaque test sous `columns: → name:`) a rappelé une règle dbt déjà croisée ailleurs dans le projet mais jamais formulée aussi clairement : un test générique doit toujours être rattaché à une colonne précise, jamais posé en vrac au niveau du modèle.
 
---
 
## Ce que ce projet démontre
 
Une méthode de diagnostic transférable, appliquée identiquement quel que soit l'outil ou la méthodologie de modélisation. Le chantier Data Vault ajoute sa propre nuance à cette leçon répétée : parfois, la meilleure preuve qu'une règle qu'on vient de poser est correcte n'est pas de l'énoncer clairement, mais de l'appliquer au premier cas concret et de vérifier qu'elle tient — exactement ce qui a révélé, dès `hub_client`, que la théorie fraîchement posée avait une conséquence pratique non anticipée.
 
---
 
*Ce document sera enrichi au fil des prochains chantiers : MCP Power BI, Superset, OpenClaw, gouvernance/RGPD.*