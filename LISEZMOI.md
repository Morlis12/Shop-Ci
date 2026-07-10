# 🛍️ Projet BoutiqueCI — Devenir Analytics Engineer, pas à pas

Bienvenue dans ton projet d'apprentissage ! Tu viens du monde Power BI / data analyst : tu sais déjà **consommer** et **visualiser** des données. L'analytics engineer, lui, travaille **en amont** : il transforme les données brutes et sales en tables propres, testées et documentées... celles-là mêmes que le data analyst branche ensuite sur Power BI.

> **En une phrase :** le data analyst répond aux questions métier, l'analytics engineer construit les fondations fiables qui permettent d'y répondre.

## 📦 Le contexte métier

BoutiqueCI est un e-commerce basé à Abidjan qui vend des produits artisanaux (textile, cosmétique, épicerie...) en Afrique de l'Ouest et en Europe. La direction veut suivre : le chiffre d'affaires, les meilleurs clients, la performance par canal de vente (site web, appli, WhatsApp) et par catégorie de produits.

Problème : les données exportées des systèmes sources sont **sales** (comme partout). C'est ton travail de les fiabiliser.

## 🗂️ Les 5 fichiers de données brutes (`data_brute/`)

| Fichier | Contenu | Lignes |
|---|---|---|
| `clients.csv` | Les clients inscrits | 510 |
| `produits.csv` | Le catalogue produits | 20 |
| `commandes.csv` | Les commandes passées | 3 000 |
| `lignes_commande.csv` | Le détail produit par produit de chaque commande | ~7 400 |
| `paiements.csv` | Les paiements associés aux commandes | ~2 900 |

## ⚠️ Les pièges volontairement cachés dedans

Je les liste ici pour que tu saches ce que tu cherches — en entreprise, personne ne te donnera cette liste !

1. **Dates en formats mixtes** : `2024-01-25`, `22/03/2023` et même du format américain `04-18-2024`.
2. **Doublons de clients** : mêmes personnes, ids différents (détectables par l'email).
3. **Casse incohérente** : emails en MAJUSCULES, statuts `livree` vs `LIVREE`, pays `France` vs `france` vs `FR`.
4. **Prix stockés en texte** : `12500 XOF` au lieu de `12500`.
5. **Clés orphelines** : des commandes qui pointent vers des clients inexistants.
6. **Doublons de paiement** : des retries qui gonflent artificiellement le CA si on ne les traite pas.
7. **Valeurs manquantes** : téléphones vides, catégories vides.

## 🗺️ La feuille de route (notre programme)

### Étape 1 — Explorer et auditer les données (le "data profiling")
Avant de transformer quoi que ce soit, un analytics engineer **audite**. On utilisera SQL avec **DuckDB** (une base de données ultra-simple, qui tourne sur ton PC sans rien installer de lourd).

### Étape 2 — L'architecture en couches (le modèle "médaillon")
- **raw/sources** : les données brutes, jamais modifiées
- **staging** : nettoyage 1-pour-1 (types, casse, dates, renommage) — une table staging par table source
- **intermediate** : logique métier réutilisable (ex : dédoublonnage des paiements)
- **marts** : les tables finales pour le métier (`fait_ventes`, `dim_clients`...) — celles que tu brancherais sur Power BI

### Étape 3 — dbt, l'outil central du métier
On installera **dbt** (data build tool) : le standard de l'industrie. Tu y écriras tes transformations en SQL, avec du versionning, des dépendances automatiques et de la documentation générée.

### Étape 4 — Les tests de qualité de données
`unique`, `not_null`, `relationships`... on apprendra à écrire des tests qui empêchent les données pourries d'arriver jusqu'au dashboard.

### Étape 5 — Modélisation dimensionnelle (Kimball)
Tables de faits et dimensions — tu connais déjà le concept via Power BI (schéma en étoile !), on apprendra à les **construire** au lieu de les consommer.

### Étape 6 — Documentation, bonnes pratiques Git et industrialisation

## 🚀 Pour démarrer (Étape 1)

Sur ton PC, installe Python puis :
```bash
pip install duckdb
```
Place les 5 CSV dans un dossier `data_brute/` et dis-moi quand tu es prêt : on écrira ensemble tes premières requêtes d'audit.

Audit
All stg => Final CTE not nul Id (Flag)
Tester doublons de ligne 

Clients : 
-Email: ya 10 dublons, penser au trim lower 
-Pays : il ya les valeurs CI ,SN creer la correspondance au vrai pays,penser au trim lower ,Lister tous les elements distinct de pays pour visualiser
 test pour lister les pays pour pointer la liste de correspondance
-Date dinscription : creer la transformation e formatage complet 
-Nom et prenom : Colonne calculée 
-Ville lower .....
