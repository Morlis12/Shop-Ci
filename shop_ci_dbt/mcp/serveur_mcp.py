"""
mcp/serveur_mcp.py — SERVEUR MCP SHOP_CI
Ce serveur n'est JAMAIS lancé à la main : c'est le client IA (Claude
Desktop) qui le démarre, via le chemin absolu de sa configuration.
"""
import subprocess
from rdflib import Graph, Namespace
from mcp.server.fastmcp import FastMCP

# =====================================================================
# CONFIGURATION DES CHEMINS ET DE L'ENVIRONNEMENT
# =====================================================================

# RÈGLE D'OR : Utilisation impérative de chemins absolus (complets).
# Le processus parent (l'IA) qui démarre ce script n'a aucune notion de
# notre dossier de travail actuel. Sans chemin complet, les fichiers restent introuvables.
RACINE = r"C:\Users\Laptop Studio\Documents\Shop Ci"

# Emplacement du graphe de connaissances sémantiques généré précédemment (.ttl)
GRAPHE_TTL = RACINE + r"\shop_ci_dbt\owl\shop_ci_classified.ttl"

# Emplacement du projet dbt contenant toute la logique des modèles et de MetricFlow
DOSSIER_DBT = RACINE + r"\shop_ci_dbt"

# Définition de l'espace de noms (URI) officiel pour identifier nos concepts métiers
SHOP = Namespace("http://shop-ci.ci/ontologie#")

# Initialisation du serveur de communication avec l'IA sous le nom "shop-ci"
mcp = FastMCP("shop-ci")

# Chargement en mémoire du graphe de connaissances au format Turtle (.ttl)
# C'est ce dictionnaire géant que l'IA va pouvoir interroger à la volée.
_graphe = Graph()
_graphe.parse(GRAPHE_TTL, format="turtle")


# =====================================================================
# OUTILS EXPOSÉS À L'INTELLIGENCE ARTIFICIELLE (TOOLS)
# =====================================================================

@mcp.tool()
def interroger_graphe(sparql: str) -> str:
    """SPARQL libre sur le graphe de décision (Client, Produit, Vente,
    labels ClientVIP, ProduitStar...). Pour les questions croisées."""
    # Cet outil permet à l'IA d'écrire et d'exécuter son propre langage de requête (SPARQL)
    # pour naviguer librement dans les relations complexes du graphe sémantique.
    try:
        # Exécute la requête sur le graphe, assemble les colonnes de chaque ligne avec un séparateur " | "
        res = [" | ".join(str(x) for x in row) for row in _graphe.query(sparql)]
        return "\n".join(res) if res else "(aucun resultat)"
    except Exception as e:
        return f"Erreur SPARQL : {e}"


@mcp.tool()
def lister_categorie(categorie: str) -> str:
    """Liste les individus d'un label métier (ClientVIP, ProduitStar...)."""
    # Cet outil permet à l'IA d'obtenir rapidement la liste brute des entités
    # (ex: les codes de tous nos clients classés comme "ClientVIP").
    q = f"""PREFIX shop: <http://shop-ci.ci/ontologie#>
        SELECT ?e WHERE {{ ?e a shop:{categorie} . }} ORDER BY ?e"""
    try:
        # Exécute la requête et nettoie l'URL technique pour ne garder que l'identifiant lisible (ex: "client_45")
        lignes = [str(r[0]).split("/")[-1] for r in _graphe.query(q)]
        return f"{len(lignes)} individu(s) :\n" + "\n".join(lignes) if lignes else "Aucun (vérifie l'orthographe)."
    except Exception as e:
        return f"Erreur : {e}"


@mcp.tool()
def expliquer_categorie(categorie: str) -> str:
    """Définition officielle d'une catégorie, telle qu'écrite dans l'ontologie."""
    # Cet outil donne à l'IA un accès direct au dictionnaire de l'entreprise :
    # elle peut lire la description textuelle d'un indicateur écrite par les architectes.
    q = f"""PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        SELECT ?label ?comment WHERE {{
            shop:{categorie} rdfs:label ?label ; rdfs:comment ?comment . }}"""
    try:
        res = list(_graphe.query(q))
        # Renvoie le nom officiel de la catégorie suivi de sa définition métier claire
        return f"{res[0][0]} : {res[0][1]}" if res else f"'{categorie}' introuvable."
    except Exception as e:
        return f"Erreur : {e}"


@mcp.tool()
def calculer_metrique(metriques: str, group_by: str = "") -> str:
    """Métriques GOUVERNÉES via MetricFlow (ex 'ca_officiel,taux_marge')."""
    # C'est l'outil central de l'architecture (le Semantic Layer local).
    # L'IA n'écrit pas de SQL. Elle demande un indicateur et des dimensions d'analyse.
    # Le script réveille la CLI MetricFlow en arrière-plan pour générer le calcul parfait.
    
    # Construction de la commande à envoyer au terminal de la machine
    cmd = ["mf", "query", "--metrics", metriques]
    if group_by: 
        cmd += ["--group-by", group_by]
    
    # Exécution de la commande dbt/MetricFlow dans le dossier du projet dbt
    # capture_output=True intercepte la réponse texte, timeout=60 évite les blocages infinis
    out = subprocess.run(cmd, cwd=DOSSIER_DBT, capture_output=True,
                          text=True, timeout=60, shell=True)
    
    # Renvoie le tableau de résultats généré par MetricFlow (ou l'erreur technique si le calcul échoue)
    return out.stdout or out.stderr


# =====================================================================
# POINT D'ENTRÉE DU SCRIPT
# =====================================================================
if __name__ == "__main__":
    # Démarre le protocole d'écoute du serveur. 
    # À partir de cet instant, le serveur attend les instructions standardisées de l'IA parent.
    mcp.run()
