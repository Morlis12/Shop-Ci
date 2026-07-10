-- Dimension produits : le QUOI du modèle en étoile.
select
    id_produit,
    nom_produit,
    coalesce(categorie, 'Non catégorisé') as categorie,
    prix_unitaire,
    cout_unitaire,
    statut
from {{ ref('stg_produits') }}