
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
        -1 as id_client,
        'Client inconnu' as nom_complet,
        cast(null as varchar) as ville,
        cast(null as varchar) as pays,
        cast(null as date) as date_inscription

)

select * from clients
union all
select * from membre_inconnu