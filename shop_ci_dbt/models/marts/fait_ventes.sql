{{
    config(
        materialized='incremental',
        unique_key='id_ligne',
        on_schema_change='fail'
    )
}}

-- Table de faits VENTES.
-- GRAIN DÉCLARÉ : une ligne = UN PRODUIT dans UNE COMMANDE (ligne de commande).
with lignes as (

    select * from {{ ref('stg_lignes_commandes') }}

),

commandes as (

    select * from {{ ref('stg_commandes') }}

),

produits as (

    select * from {{ ref('stg_produits') }}

),

correspondance as (

    select * from {{ ref('int_correspondance_clients') }}

)

select
    -- Clé du grain
    l.id_ligne,

    -- Clés vers les dimensions
    l.id_commande,
    coalesce(corr.id_client_valide, -1)     as id_client,   -- orphelins -> membre inconnu
    l.id_produit,
    c.jour_commande,
    c.date_commande                         as date_commande_chargement,
    
    -- Dimensions dégénérées
    c.statut,
    c.canal,

    -- Mesures : toutes vraies au grain ligne
    l.quantite,
    l.quantite * p.prix_unitaire            as montant_ligne,
    l.quantite * p.cout_unitaire            as cout_ligne,
    l.quantite * (p.prix_unitaire - p.cout_unitaire) as marge_ligne

from lignes l
inner join commandes c        on l.id_commande = c.id_commande
inner join produits p         on l.id_produit  = p.id_produit
left join correspondance corr on c.id_client   = corr.id_client

{% if is_incremental() %}
-- En mode incrémental : On force le résultat du calcul en TIMESTAMP pour BigQuery
where c.date_commande > (
    select cast({{ dbt.dateadd(datepart='day', interval=-3, from_date_or_timestamp='max(date_commande_chargement)') }} as timestamp) from {{ this }}
)
{% endif %}