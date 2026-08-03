{{
    config(
        materialized='table',
        tags=['data_vault', 'satellite']
    )
}}

-- SAT_PAIEMENT : contexte de chaque tentative de paiement, y compris
-- les retries -- stg_paiements ne supprime jamais de ligne, seulement
-- des flags ajoutes par-dessus.

with paiements as (

    select
        id_paiement,
        montant,
        methode,
        statut_paiement,
        est_reussi,
        vrai_reussi,
        est_doublon
    from {{ ref('stg_paiements') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['id_paiement']) }}         as link_paiement_hk,
    montant,
    methode,
    statut_paiement,
    est_reussi,
    vrai_reussi,
    est_doublon,
    {{ dbt_utils.generate_surrogate_key(['montant', 'methode', 'statut_paiement', 'est_reussi', 'vrai_reussi', 'est_doublon']) }} as hash_diff,
    current_timestamp()                                              as load_date,
    'shop_ci_csv'                                                    as record_source

from paiements