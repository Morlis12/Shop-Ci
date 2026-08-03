{{
    config(
        materialized='table',
        tags=['data_vault', 'hub']
    )
}}

-- HUB_PRODUIT : l'identite pure. Une ligne = un id_produit unique connu du systeme.

with source_produits as (

    select distinct id_produit
    from {{ ref('stg_produits') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['id_produit']) }} as hub_produit_hk,
    id_produit                                              as business_key_id_produit,
    current_timestamp()                                     as load_date,
    'shop_ci_csv'                                            as record_source

from source_produits