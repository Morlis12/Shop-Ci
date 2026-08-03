{{
    config(
        materialized='table',
        tags=['data_vault', 'satellite']
    )
}}

-- SAT_CLIENT : le contexte descriptif de chaque identite brute du hub_client.
-- Une ligne par id_client BRUT (510 lignes attendues, comme hub_client) --
-- le detail (nom, pays...) reste rattache a l'identite d'origine, jamais
-- fusionne avec le survivant (c'est le role de link_client_same_as).

with source_clients as (

    select
        {{ dbt.safe_cast("id_client", dbt.type_int()) }}                          as id_client,
        trim(concat(
            cast(prenom as {{ dbt.type_string() }}), 
            ' ', 
            cast(nom as {{ dbt.type_string() }})
        ))                                                                          as nom_complet,
        trim(cast(pays as {{ dbt.type_string() }}))                                 as pays,
        trim(cast(ville as {{ dbt.type_string() }}))                                as ville,
        {{ nettoyer_date('date_inscription') }}                                     as date_inscription
    from {{ source('source_brut', 'clients') }}
    where id_client is not null

)

select
    {{ dbt_utils.generate_surrogate_key(['id_client']) }}          as hub_client_hk,
    nom_complet,
    pays,
    ville,
    date_inscription,
    {{ dbt_utils.generate_surrogate_key(['nom_complet', 'pays', 'ville', 'date_inscription']) }} as hash_diff,
    current_timestamp()                                             as load_date,
    'shop_ci_csv'                                                   as record_source

from source_clients