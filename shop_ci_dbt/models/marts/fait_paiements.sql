{{
    config(
        materialized='incremental',
        unique_key='id_paiement',
        on_schema_change='fail'
    )
}}
-- Table de faits PAIEMENTS.
-- GRAIN DÉCLARÉ : une ligne = UN PAIEMENT (une commande entière).
-- Grain différent de fait_ventes -> table séparée (constellation).
with paiements as (

    select * from {{ ref('stg_paiements') }}

),

commandes as (

    select * from {{ ref('stg_commandes') }}

),

correspondance as (

    select * from {{ ref('int_correspondance_clients') }}

)

select
    p.id_paiement,
    p.id_commande,
    coalesce(corr.id_client_valide, -1) as id_client,
    c.jour_commande,
    c.canal,

    p.methode,
    p.statut_paiement,
    p.est_reussi,
    p.vrai_reussi,
    p.est_doublon,
    p.montant,
    c.date_commande                     as date_commande_chargement

from paiements p
inner join commandes c        on p.id_commande = c.id_commande
left join correspondance corr on c.id_client   = corr.id_client

{% if is_incremental() %}
-- En mode incrémental : On force le résultat du calcul en TIMESTAMP pour BigQuery
where c.date_commande > (
    select cast({{ dbt.dateadd(datepart='day', interval=-3, from_date_or_timestamp='max(date_commande_chargement)') }} as timestamp) from {{ this }}
)
{% endif %}