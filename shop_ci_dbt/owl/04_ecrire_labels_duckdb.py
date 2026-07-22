"""
04_ecrire_labels_duckdb.py
Réinjecte la classification du graphe (shop_ci_classified.ttl) dans DuckDB,
sous forme de table plate 'mart_decisions' — consommable par Power BI
sans avoir besoin de comprendre SPARQL.

ATTENTION : ce script ÉCRIT dans dev.duckdb (contrairement à 02_export.py
qui ne fait que lire). Ferme VS Code, tout processus dbt/python en arrière-plan,
et Power BI si déjà ouvert sur ce fichier, avant de lancer ce script.
"""

# Importation des modules nécessaires
import duckdb  # Pour interagir avec la base de données DuckDB
from rdflib import Graph, Namespace  # Pour manipuler le graphe de données RDF (ontologie)

# Définition de l'espace de noms (Namespace) propre à l'ontologie du projet
SHOP = Namespace("http://shop-ci.ci/ontologie#")
# Définition du chemin d'accès au fichier de la base de données DuckDB
DB_PATH = "../dev.duckdb"  # chemin relatif, lancé depuis le dossier owl/

# --- 1. Charger le graphe déjà classifié ---
# Initialisation d'un graphe RDF vide
g = Graph()
# Chargement et analyse du fichier Turtle (.ttl) contenant les données classifiées
g.parse("shop_ci_classified.ttl", format="turtle")


def extraire_labels(classe_racine: str) -> list[tuple]:
    """
    Pour une classe racine donnée (Client ou Produit), extrait chaque
    individu et son label de décision (ex: ClientVIP), en excluant
    la classe racine elle-même du résultat.
    """
    # Construction de la requête SPARQL dynamique en injectant la classe racine (Client ou Produit)
    requete = f"""
    PREFIX shop: <http://shop-ci.ci/ontologie#>
    SELECT ?entite ?label WHERE {{
        ?entite a ?label .
        ?entite a shop:{classe_racine} .
        FILTER(?label != shop:{classe_racine})
    }}
    """
    lignes = []
    # Exécution de la requête sur le graphe RDF chargé
    for row in g.query(requete):
        # row.entite ressemble à : "http://shop-ci.ci/ontologie#client_305"
        # On découpe la chaîne au niveau du '#' et on garde la dernière partie : "client_305"
        entite_id_texte = str(row.entite).split("#")[-1]      
        
        # On extrait uniquement le numéro en découpant au niveau du '_' : "305", puis conversion en entier (int)
        entite_id_numerique = int(entite_id_texte.split("_")[-1])  
        
        # row.label ressemble à : "http://shop-ci.ci"
        # On récupère uniquement le nom de la classe de classification : "ClientVIP"
        label = str(row.label).split("#")[-1]                  
        
        # On ajoute le tuple formaté (Type, ID numérique, Classification) à notre liste
        lignes.append((classe_racine, entite_id_numerique, label))
        
    return lignes


# --- 2. Extraire pour les deux classes ---
# Extraction des classifications pour les clients
lignes_clients = extraire_labels("Client")
# Extraction des classifications pour les produits
lignes_produits = extraire_labels("Produit")
# Fusion des deux listes de tuples dans une seule variable globale
toutes_lignes = lignes_clients + lignes_produits

# Affichage d'un résumé textuel dans la console
print(f"{len(lignes_clients)} clients classifiés, {len(lignes_produits)} produits classifiés.")

# --- 3. Écrire dans DuckDB (read_only=False, cette fois) ---
# À ce stade, le script s'arrête. Il vous reste à ajouter le code de connexion à DuckDB 
# pour insérer la variable `toutes_lignes` dans la table 'mart_decisions'.
con = duckdb.connect(DB_PATH, read_only=False)

con.execute("""
    CREATE OR REPLACE TABLE mart_decisions (
        entity_type VARCHAR,   -- 'Client' ou 'Produit'
        entity_id   INTEGER,   -- id_client ou id_produit, pour la jointure
        label       VARCHAR    -- ex: 'ClientVIP', 'ProduitStar'
    )
""")

con.executemany(
    "INSERT INTO mart_decisions VALUES (?, ?, ?)",
    toutes_lignes
)

resultat = con.execute("SELECT COUNT(*) FROM mart_decisions").fetchone()
print(f"mart_decisions créée : {resultat[0]} lignes écrites.")

con.close()