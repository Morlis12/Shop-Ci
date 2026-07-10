
{{
    config(
        materialized='incremental',
        unique_key='id_ligne',
        on_schema_change='fail'
    )
}}

-- Table de faits VENTES.
-- GRAIN DÉCLARÉ : une ligne = UN PRODUIT dans UNE COMMANDE (ligne de commande).
-- Toute mesure de cette table est vraie à ce grain (pas de montant de paiement
-- ici : grain commande != grain ligne -> il vit dans fait_paiements).
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
    -- Dimensions dégénérées (attributs de l'événement, sans table dédiée)
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
-- En mode incrémental : ne traiter que les commandes plus récentes que
-- le maximum déjà chargé, avec 3 jours de marge pour les retardataires.
where date_commande_chargement > (
    select max(date_commande_chargement) - interval 3 day from {{ this }}
)
{% endif %}