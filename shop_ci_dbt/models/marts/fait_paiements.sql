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
where date_commande_chargement > (
    select max(date_commande_chargement) - interval 3 day from {{ this }}
)
{% endif %}