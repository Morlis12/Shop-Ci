{{
    config(
        materialized='table',
        tags=['data_vault', 'satellite']
    )
}}

-- SAT_PRODUIT : le contexte descriptif de chaque produit.
-- Le nettoyage du prix (suffixe XOF, split_part) est un nettoyage TECHNIQUE
-- pur -- pas une decision de perimetre -- reproduit ici depuis la source brute.

with source_produits as (

    select
        {{ dbt.safe_cast("id_produit", dbt.type_int()) }}                                              as id_produit,
        trim(cast(nom_produit as {{ dbt.type_string() }}))                                              as nom_produit,
        nullif(trim(cast(categorie as {{ dbt.type_string() }})), '')                                    as categorie,
        {{ dbt.safe_cast(dbt.split_part("trim(cast(prix_unitaire as " ~ dbt.type_string() ~ "))", "' '", 1), dbt.type_int()) }} as prix_unitaire,
        {{ dbt.safe_cast(dbt.split_part("trim(cast(cout_unitaire as " ~ dbt.type_string() ~ "))", "' '", 1), dbt.type_int()) }} as cout_unitaire,
        lower(trim(cast(statut as {{ dbt.type_string() }})))                                            as statut
    from {{ source('source_brut', 'produits') }}
    where id_produit is not null

)

select
    {{ dbt_utils.generate_surrogate_key(['id_produit']) }}         as hub_produit_hk,
    nom_produit,
    categorie,
    prix_unitaire,
    cout_unitaire,
    statut,
    {{ dbt_utils.generate_surrogate_key(['nom_produit', 'categorie', 'prix_unitaire', 'cout_unitaire', 'statut']) }} as hash_diff,
    current_timestamp()                                              as load_date,
    'shop_ci_csv'                                                    as record_source

from source_produits