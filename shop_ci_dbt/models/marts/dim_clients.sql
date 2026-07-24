with clients as (

    select
        id_client,
        nom_complet,
        ville,
        pays,
        date_inscription
    from {{ ref('stg_clients') }}

),

-- Membre "inconnu" (convention Kimball) : les faits orphelins pointeront
-- vers cette ligne au lieu de disparaître des jointures.
membre_inconnu as (

    select
        -- CORRECTION : Force le typage numérique de l'ID pour correspondre strictement au schéma BigQuery
        cast(-1 as {{ dbt.type_int() }}) as id_client,
        'Client inconnu' as nom_complet,
        -- CORRECTION : Remplacement de varchar par le type texte universel
        cast(null as {{ dbt.type_string() }}) as ville,
        cast(null as {{ dbt.type_string() }}) as pays,
        cast(null as date) as date_inscription

)

select * from clients
union all
select * from membre_inconnu
