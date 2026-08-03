{{
    config(
        materialized='table',
        tags=['data_vault', 'link']
    )
}}

-- LINK_VENTE : relie Client, Produit et Commande pour chaque ligne de vente.
-- Construit depuis le STAGING brut, jamais depuis fait_ventes -- pour ne pas
-- heriter silencieusement des decisions deja prises par le mart Kimball
-- (re-routage vers le membre inconnu, notamment).
-- stg_commandes est ici sur, car il ne fait que du typage (safe_cast),
-- aucune decision de re-routage ou de fusion.

with lignes as (

    select
        id_ligne,
        id_commande,
        id_produit
    from {{ ref('stg_lignes_commandes') }}

),

commandes as (

    select
        id_commande,
        id_client
    from {{ ref('stg_commandes') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['l.id_ligne']) }}        as link_vente_hk,
    {{ dbt_utils.generate_surrogate_key(['c.id_client']) }}       as hub_client_hk,
    {{ dbt_utils.generate_surrogate_key(['l.id_produit']) }}      as hub_produit_hk,
    {{ dbt_utils.generate_surrogate_key(['l.id_commande']) }}     as hub_commande_hk,
    l.id_ligne,
    current_timestamp()                                            as load_date,
    'shop_ci_csv'                                                  as record_source

from lignes l
inner join commandes c on l.id_commande = c.id_commande