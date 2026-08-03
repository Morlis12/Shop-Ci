{{
    config(
        materialized='table',
        tags=['data_vault', 'hub']
    )
}}

-- HUB_CLIENT : l'identite pure, TOUS les id_client bruts rencontres --
-- y compris ceux que stg_clients elimine ensuite par dedoublonnage.
-- C'est le role d'audit du Data Vault : ne jamais faire disparaitre
-- une identite brute, meme une identite qui s'avere etre un doublon.

with source_clients_bruts as (

    select distinct {{ dbt.safe_cast("id_client", dbt.type_int()) }} as id_client
    from {{ source('source_brut', 'clients') }}
    where id_client is not null

)

select
    {{ dbt_utils.generate_surrogate_key(['id_client']) }} as hub_client_hk,
    id_client                                              as business_key_id_client,
    current_timestamp()                                    as load_date,
    'shop_ci_csv'                                           as record_source

from source_clients_bruts