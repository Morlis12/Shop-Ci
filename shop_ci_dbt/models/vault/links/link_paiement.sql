{{
    config(
        materialized='table',
        tags=['data_vault', 'link']
    )
}}

-- LINK_PAIEMENT : relie chaque tentative de paiement (y compris les retries)
-- a sa commande. Un seul Hub concerne ici (hub_commande) -- un paiement
-- n'a de sens que par rapport a la commande qu'il regle. stg_paiements
-- est sur comme source : aucune ligne n'est supprimee, seulement flaggee.

with paiements as (

    select
        id_paiement,
        id_commande
    from {{ ref('stg_paiements') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['id_paiement']) }}       as link_paiement_hk,
    {{ dbt_utils.generate_surrogate_key(['id_commande']) }}       as hub_commande_hk,
    id_paiement,
    current_timestamp()                                            as load_date,
    'shop_ci_csv'                                                  as record_source

from paiements