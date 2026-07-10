-- PROBLÈME RÉSOLU ICI : en dédoublonnant les clients (stg_clients),
-- on a supprimé 10 id_client. Les commandes qui pointaient vers ces ids
-- sont devenues orphelines. Ce modèle fournit la table de re-routage :
-- chaque id_client BRUT -> l'id_client SURVIVANT (celui gardé par stg_clients).
with clients_bruts as (

    select
        cast(id_client as integer) as id_client,
        trim(lower(email)) as email
    from {{ source('source_brut', 'clients') }}

),

survivants as (

    select id_client as id_client_valide, email
    from {{ ref('stg_clients') }}

)

select
    b.id_client,
    s.id_client_valide

from clients_bruts b
inner join survivants s on b.email = s.email