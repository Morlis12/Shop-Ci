{{
    config(
        materialized='table',
        tags=['data_vault', 'hub']
    )
}}

-- HUB_COMMANDE : l'identite pure. Une ligne = un id_commande unique connu du systeme.

with source_commandes as (

    select distinct id_commande
    from {{ ref('stg_commandes') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['id_commande']) }} as hub_commande_hk,
    id_commande                                              as business_key_id_commande,
    current_timestamp()                                      as load_date,
    'shop_ci_csv'                                             as record_source

from source_commandes