{{
    config(
        materialized='table',
        tags=['data_vault', 'satellite']
    )
}}

-- SAT_VENTE : les mesures de chaque ligne de vente. Contrairement a
-- fait_ventes, AUCUN filtre annulee/retournee ici -- le Data Vault garde
-- tout, ce tri est une decision de restitution, jamais de l'audit.

with lignes as (

    select
        id_ligne,
        id_produit,
        quantite
    from {{ ref('stg_lignes_commandes') }}

),

produits as (

    select
        id_produit,
        prix_unitaire,
        cout_unitaire
    from {{ ref('stg_produits') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['l.id_ligne']) }}          as link_vente_hk,
    l.quantite,
    l.quantite * p.prix_unitaire                                      as montant_ligne,
    l.quantite * (p.prix_unitaire - p.cout_unitaire)                  as marge_ligne,
    {{ dbt_utils.generate_surrogate_key(['l.quantite', 'p.prix_unitaire', 'p.cout_unitaire']) }} as hash_diff,
    current_timestamp()                                                as load_date,
    'shop_ci_csv'                                                      as record_source

from lignes l
inner join produits p on l.id_produit = p.id_produit