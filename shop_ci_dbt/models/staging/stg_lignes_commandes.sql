with source_data as (

    select * from {{ source('source_brut', 'lignes_commande') }}

),

cleaned_data as (

    select
        -- force la conversion en texte (varchar) pour la compatibilité avec trim/lower dans les tests de missing
        cast(id_ligne as varchar) as raw_id_ligne,
        cast(id_commande as varchar) as raw_id_commande,
        cast(id_produit as varchar) as raw_id_produit,
        cast(quantite as varchar) as raw_quantite,

        -- typage, nettoyage et conversion sécurisée des données
        try_cast(id_ligne as integer) as id_ligne,
        try_cast(id_commande as integer) as id_commande,
        try_cast(id_produit as integer) as id_produit,
        try_cast(quantite as integer) as quantite

    from source_data

)

select
    id_ligne,
    id_commande,
    id_produit,
    quantite,

    -- =========================================================================
    -- section sécurisée des flags is_missing pour toutes les colonnes
    -- =========================================================================
    case 
        when raw_id_ligne is null or trim(raw_id_ligne) = '' or lower(trim(raw_id_ligne)) = 'nan' then true
        else false
    end as is_missing_id_ligne,

    case 
        when raw_id_commande is null or trim(raw_id_commande) = '' or lower(trim(raw_id_commande)) = 'nan' then true
        else false
    end as is_missing_id_commande,

    case 
        when raw_id_produit is null or trim(raw_id_produit) = '' or lower(trim(raw_id_produit)) = 'nan' then true
        else false
    end as is_missing_id_produit,

    case 
        when raw_quantite is null or trim(raw_quantite) = '' or lower(trim(raw_quantite)) = 'nan' then true
        else false
    end as is_missing_quantite

from cleaned_data
