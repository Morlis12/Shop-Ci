{{
    config(
        materialized='table',
        tags=['data_vault', 'link']
    )
}}

-- LINK_CLIENT_SAME_AS : documente explicitement qu'un id_client et son
-- id_client_valide desigent la MEME personne reelle. Contrairement a une
-- fusion silencieuse, cette relation reste tracable et reversible :
-- les deux identites d'origine restent visibles dans hub_client.

with correspondance as (

    select
        id_client,
        id_client_valide
    from {{ ref('int_correspondance_clients') }}
    where id_client != id_client_valide   -- seulement les vrais cas de doublon

)

select
    {{ dbt_utils.generate_surrogate_key(['id_client', 'id_client_valide']) }} as link_client_same_as_hk,
    {{ dbt_utils.generate_surrogate_key(['id_client']) }}                     as hub_client_hk,
    {{ dbt_utils.generate_surrogate_key(['id_client_valide']) }}              as hub_client_valide_hk,
    id_client,
    id_client_valide,
    current_timestamp()                                                       as load_date,
    'int_correspondance_clients'                                              as record_source

from correspondance