# Shop_CI — Récit d'un projet d'analytics engineering, de la donnée sale à l'agent IA
 
> Ce document raconte *comment* et *pourquoi* les décisions ont été prises, pas seulement *quoi* a été construit.
 
---
 
## Pourquoi ce projet
 
BoutiqueCI n'est pas un jeu de données déjà propre. Les CSV sources ont été construits avec des pièges volontaires pour reproduire les problèmes qu'un analytics engineer rencontre réellement. L'objectif : une chaîne complète, de l'audit d'un fichier sale jusqu'à un agent IA capable de répondre en langage naturel, avec une CI/CD, une restitution Power BI, une portabilité cloud, une orchestration moderne, et désormais une preuve de reproductibilité par conteneurisation.
 
---
 
## Parties 1 à 6 — résumé
 
Le pipeline applique une discipline stricte (staging, intermediate, marts Kimball, 63+ tests) autour d'un principe constant : ne jamais faire disparaître silencieusement une donnée — le membre "inconnu" conservé s'est révélé structurant jusque dans le graphe, Power BI, et les commandes orphelines retrouvées identiques après chaque migration. Le semantic layer a mis fin à un écart de 13% entre deux calculs du même chiffre d'affaires. Le graphe de connaissances répond aux questions relationnelles qu'un modèle en étoile gère mal. Le serveur MCP a traversé une chaîne d'incidents résolue par contournement documenté plutôt que par acharnement. La CI/CD a révélé, dès sa première exécution, un bug de test dormant invisible en local. Power BI a fait resurgir le mono-écrivain DuckDB sous une forme nouvelle.
 
## Partie 7 — BigQuery : porter le projet sur un vrai warehouse cloud
 
Une recherche du marché de l'analytics engineering a confirmé que DuckDB n'apparaît dans aucune offre comme outil de production recherché. La migration a exigé un mini-outil d'ingestion, les macros cross-database de dbt pour ne jamais dupliquer le code, et la découverte de plusieurs divergences de comportement entre moteurs SQL — jamais contournées à l'aveugle, toujours diagnostiquées avant correction.
 
## Partie 8 — Dagster : de la commande isolée à l'orchestration observable
 
La bascule conceptuelle centrale : penser en assets plutôt qu'en suite de commandes. La chaîne d'incidents rencontrée — fichiers jamais réellement sauvegardés, résolution de module dépendant du répertoire de travail externe, conflit de port, état non persistant sans `DAGSTER_HOME` — n'a jamais concerné la logique métier, seulement la façon dont l'outil s'articule avec son environnement. Une leçon plus généralisable que la syntaxe d'un outil précis.
 
---
 
## Partie 9 — Docker : la preuve ultime de reproductibilité
 
### Pourquoi cette étape ferme la boucle de tout ce qu'on a construit
 
Chaque chantier précédent a, d'une façon ou d'une autre, tourné autour d'une même question : *ce qui fonctionne ici fonctionnera-t-il ailleurs ?* La CI/CD y avait déjà répondu partiellement, en révélant un bug invisible en local sur une machine vierge. Docker pousse cette question à son terme logique : plutôt que de reconstruire un environnement à partir d'instructions (installer Python, créer une venv, poser les dépendances), on **empaquette l'environnement lui-même** — une image portable, identique sur n'importe quelle machine.
 
### Le principe de sécurité posé avant la première ligne de code
 
Avant d'écrire le moindre `Dockerfile`, une règle a été fixée : une image Docker peut être partagée, poussée sur un registre, inspectée par n'importe qui — y intégrer un secret serait pire que de le committer dans Git, où au moins l'historique reste privé par défaut. La clé de service BigQuery ne devait donc **jamais** apparaître dans une instruction `COPY`, uniquement injectée au moment de l'exécution via un volume monté (`docker run -v`), un pont temporaire entre le disque local et le conteneur, actif seulement pendant le run.
 
Cette règle posée en amont a directement structuré `.dockerignore` : secrets, environnement virtuel, caches Dagster et Python exclus explicitement, avant même d'écrire le `Dockerfile` lui-même.
 
### Une vérification, pas une supposition
 
Une fois l'image construite, l'affirmation "le secret n'y est jamais entré" n'a pas été acceptée sur la seule foi du `.dockerignore` — elle a été **vérifiée concrètement** : une recherche exhaustive à l'intérieur de l'image construite (`docker run ... find / -name "*.secrets*"`), ne renvoyant aucun résultat. Exactement la même discipline appliquée à chaque chantier précédent : vérifier plutôt que supposer, même quand la configuration semble correcte sur le papier.
 
### Un avertissement qui méritait d'être compris, pas ignoré
 
Docker a signalé `SecretsUsedInArgOrEnv` sur la ligne déclarant `GOOGLE_APPLICATION_CREDENTIALS`. Plutôt que d'ignorer ou de supprimer aveuglément cette ligne, la distinction a été clarifiée : cette variable ne contenait qu'un **chemin de fichier**, jamais le secret lui-même — l'outil de sécurité de Docker signale largement toute variable au nom évocateur, sans distinguer un chemin d'une vraie donnée sensible. Un faux positif compris vaut mieux qu'un avertissement supprimé sans le lire.
 
### Le seul vrai obstacle technique : où vit le profil de connexion
 
Le premier lancement du conteneur a échoué sur une erreur limpide : `Path '/root/.dbt' does not exist`. Le profil dbt vit normalement sur la machine locale, jamais copié dans une image par principe. Deux solutions existaient — monter le fichier local comme un second volume, ou générer directement dans l'image un `profiles.yml` autosuffisant (sans le vrai secret, celui-ci restant exclusivement dans le volume monté au lancement). La seconde a été retenue : elle rend le conteneur indépendant de toute configuration locale, cohérent avec l'esprit même de la conteneurisation — un artefact qui n'a besoin de rien d'autre que d'un secret pour fonctionner n'importe où.
 
### La preuve finale
 
Le pipeline complet, exécuté depuis un conteneur Linux isolé, a produit un résultat **rigoureusement identique** au run local et à la CI GitHub Actions — `PASS=79, WARN=1 (les 101 commandes orphelines, déjà connues depuis les tout premiers chapitres du projet), ERROR=0`. Trois environnements complètement indépendants, un seul et même résultat : la démonstration de reproductibilité la plus forte construite dans tout ce projet.
 
---
 
## Ce que ce projet démontre
 
Une méthode de diagnostic transférable, appliquée identiquement quel que soit l'outil. Une gouvernance pensée dès la conception, jamais rattrapée après coup. Une honnêteté architecturale assumée à chaque chantier. Et, avec Docker, la démonstration concrète — pas seulement affirmée — qu'un système correctement construit produit le même résultat, peu importe où il tourne.
 
---
 
*Ce document sera enrichi au fil des prochains chantiers : Data Vault, gouvernance/RGPD appliquée.*