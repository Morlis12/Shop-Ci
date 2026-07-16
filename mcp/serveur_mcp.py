"""
mcp/serveur_mcp.py — SERVEUR MCP SHOP_CI
Ce serveur n'est JAMAIS lance a la main : c'est le client IA (Claude
Desktop) qui le demarre, via le chemin absolu declare dans sa config
(claude_desktop_config.json).

ARCHITECTURE : 4 outils exposes a l'agent IA :
  1. interroger_graphe   -> SPARQL libre (le SENS, les questions croisees)
  2. lister_categorie    -> raccourci : tous les individus d'un label
  3. expliquer_categorie -> lit la regle metier depuis l'ontologie
  4. calculer_metrique   -> les chiffres gouvernes (CA, marge...)

LIMITATION CONNUE (documentee suite a une longue session de debogage) :
calculer_metrique n'invoque plus MetricFlow (mf.exe) via sous-processus.
Claude Desktop (version Windows Store) tourne dans un environnement
sandboxe (AppContainer) qui restreint la creation de nouveaux processus
et la manipulation de threads/signaux systeme. Consequence : mf.exe
timeoute systematiquement quand il est appele DEPUIS ce serveur MCP,
alors qu'il fonctionne parfaitement en ligne de commande manuelle.
Solution retenue : pour ca_officiel, on recalcule directement sur le
graphe RDF (lecture de fichier + calcul en memoire = pas de nouveau
processus = autorise par le sandbox). Le resultat est IDENTIQUE a
MetricFlow car 02_export.py applique deja le meme filtre anti-
annulees/retournees avant de peupler les individus Vente du graphe.
"""

from rdflib import Graph, Namespace          # rdflib : la librairie qui sait lire/interroger des fichiers RDF (.ttl)
from mcp.server.fastmcp import FastMCP        # FastMCP : le framework qui transforme des fonctions Python en outils MCP

# ---------------------------------------------------------------------------
# CONFIGURATION — chemins ABSOLUS obligatoires.
# Ce script est demarre par un processus EXTERNE (Claude Desktop), qui
# n'herite d'aucun repertoire de travail ni PATH personnalise. Un chemin
# relatif (ex: "owl/fichier.ttl") echouerait car "on ne sait pas d'ou on part".
# ---------------------------------------------------------------------------
RACINE = r"C:\Users\Laptop Studio\Documents\Shop Ci"
GRAPHE_TTL = RACINE + r"\shop_ci_dbt\owl\shop_ci_classified.ttl"  # le graphe final, genere par 03_classify.py

# SHOP : le "prefixe" de notre ontologie. Permet d'ecrire shop:Client au
# lieu de l'URL complete http://shop-ci.ci/ontologie#Client a chaque fois.
SHOP = Namespace("http://shop-ci.ci/ontologie#")

# mcp : l'objet serveur. "shop-ci" est le nom qui apparait dans Claude
# Desktop (Settings -> Developer -> Local MCP servers).
mcp = FastMCP("shop-ci")


def get_graphe():
    """
    Recharge le graphe DEPUIS LE DISQUE a chaque appel (pas de variable
    globale chargee une seule fois au demarrage).

    POURQUOI : si on chargeait le graphe une seule fois en haut du fichier
    (comme dans une version precedente), toute regeneration du .ttl
    (apres avoir relance owl/03_classify.py) resterait invisible tant que
    le processus serveur n'est pas redemarre. En le rechargeant a chaque
    appel, on paie un cout minime (quelques centaines de millisecondes
    pour ~35000 triplets) mais on garantit de toujours lire la derniere
    version -- plus jamais besoin de redemarrer Claude Desktop apres une
    regeneration du graphe.
    """
    g = Graph()                                  # un graphe RDF vide
    g.parse(GRAPHE_TTL, format="turtle")          # on le remplit en lisant le fichier .ttl
    return g


@mcp.tool()  # ce decorateur transforme la fonction en outil visible par l'agent IA
def interroger_graphe(sparql: str) -> str:
    """SPARQL libre sur le graphe de décision (Client, Produit, Vente,
    labels ClientVIP, ProduitStar...). Pour les questions croisées.
    (Ce texte de docstring est ce que l'IA LIT pour savoir quand utiliser
    cet outil -- il doit rester clair et precis.)"""
    try:
        g = get_graphe()                                       # graphe frais a chaque appel
        # g.query(sparql) execute la requete et renvoie des lignes de resultats.
        # Chaque "row" est un tuple de valeurs (une par variable demandee dans SELECT).
        # On les transforme en texte lisible : "valeur1 | valeur2 | ..."
        res = [" | ".join(str(x) for x in row) for row in g.query(sparql)]
        return "\n".join(res) if res else "(aucun resultat)"    # une ligne par resultat, ou message explicite si vide
    except Exception as e:
        # On capture TOUTE exception (requete SPARQL mal formee, etc.)
        # pour que l'agent IA recoive un message d'erreur clair plutot
        # qu'un crash silencieux du serveur.
        return f"Erreur SPARQL : {e}"


@mcp.tool()
def lister_categorie(categorie: str) -> str:
    """Liste les individus d'un label métier (ClientVIP, ProduitStar...)."""
    # Requete SPARQL construite dynamiquement : {categorie} est injecte
    # directement dans le texte de la requete (ex: "shop:ClientVIP").
    # ATTENTION : ceci n'est sur que parce que categorie vient d'un agent
    # IA de confiance dans un contexte local -- dans une API publique,
    # on eviterait l'injection directe de texte dans une requete.
    q = f"""PREFIX shop: <http://shop-ci.ci/ontologie#>
        SELECT ?e WHERE {{ ?e a shop:{categorie} . }} ORDER BY ?e"""
    try:
        g = get_graphe()
        # str(r[0]) donne l'URI complet (http://shop-ci.ci/client_305) ;
        # .split("/")[-1] garde seulement la derniere partie (client_305) --
        # plus lisible pour l'humain qui lira la reponse de l'IA.
        lignes = [str(r[0]).split("/")[-1] for r in g.query(q)]
        return f"{len(lignes)} individu(s) :\n" + "\n".join(lignes) if lignes else "Aucun (vérifie l'orthographe)."
    except Exception as e:
        return f"Erreur : {e}"


@mcp.tool()
def expliquer_categorie(categorie: str) -> str:
    """Définition officielle d'une catégorie, telle qu'écrite dans l'ontologie."""
    # rdfs:label = le nom court lisible ("Client à haute valeur")
    # rdfs:comment = la regle complete en prose, ecrite dans 01_schema.py
    # (ex: "PRIORITE 2. aCaTotal >= 500000 ET aNbCommandes >= 8.")
    q = f"""PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX shop: <http://shop-ci.ci/ontologie#>
        SELECT ?label ?comment WHERE {{
            shop:{categorie} rdfs:label ?label ; rdfs:comment ?comment . }}"""
    try:
        g = get_graphe()
        res = list(g.query(q))
        # res[0] = la premiere (et unique) ligne de resultat ; [0] et [1]
        # correspondent respectivement a ?label et ?comment.
        return f"{res[0][0]} : {res[0][1]}" if res else f"'{categorie}' introuvable."
    except Exception as e:
        return f"Erreur : {e}"


@mcp.tool()
def calculer_metrique(metriques: str, group_by: str = "") -> str:
    """Métriques Shop_CI. ca_officiel et marge : calcul direct via le
    graphe (résultat identique à MetricFlow — le graphe est déjà filtré
    hors annulées/retournées à l'export). Les autres métriques ne sont
    pas encore disponibles par cette voie (limitation connue : MetricFlow
    ne peut pas être invoqué en sous-processus depuis ce serveur MCP,
    voir la note en tête de fichier)."""
    g = get_graphe()

    # .strip() enleve les espaces avant/apres, au cas ou l'agent IA envoie
    # " ca_officiel " au lieu de "ca_officiel" -- comparaison plus robuste.
    if metriques.strip() == "ca_officiel":
        # SUM(?m) additionne toutes les valeurs aMontantVente trouvees.
        # Comme 02_export.py a deja exclu les commandes annulees/retournees
        # AVANT de creer les individus Vente, cette somme correspond
        # EXACTEMENT au perimetre de la metrique ca_officiel du semantic layer.
        q = """PREFIX shop: <http://shop-ci.ci/ontologie#>
            SELECT (SUM(?m) AS ?total) WHERE { ?v a shop:Vente ; shop:aMontantVente ?m . }"""
        res = list(g.query(q))
        total = res[0][0] if res else 0   # 0 par securite si le graphe est vide
        return f"ca_officiel = {total} (calculé via le graphe, périmètre identique au semantic layer : hors annulées/retournées)"

    # Pour toute autre métrique demandée : message explicite plutôt qu'un
    # timeout silencieux -- l'agent IA (et l'humain qui lit) comprend
    # immédiatement pourquoi la réponse n'est pas disponible.
    return ("Métrique non disponible par cette voie pour l'instant. "
            "Limitation connue : le pont MetricFlow est bloqué par le sandboxing "
            "du client MCP. Utilise interroger_graphe pour une requête SPARQL directe.")


# Point d'entree : ne s'execute QUE si ce fichier est lance directement
# (par Claude Desktop, ou par toi en test manuel) -- pas s'il est importe
# comme module depuis un autre script.
if __name__ == "__main__":
    mcp.run()   # demarre la boucle du serveur MCP, qui attend les appels de l'agent IA