with source_data as (

    select * from {{ source('source_brut', 'lignes_commande') }}

),

cleaned_data as (

    select
        -- force la conversion en texte de manière portable (STRING/VARCHAR)
        cast(id_ligne as {{ dbt.type_string() }}) as raw_id_ligne,
        cast(id_commande as {{ dbt.type_string() }}) as raw_id_commande,
        cast(id_produit as {{ dbt.type_string() }}) as raw_id_produit,
        cast(quantite as {{ dbt.type_string() }}) as raw_quantite,

        -- typage et conversion sécurisée universelle (SAFE_CAST/TRY_CAST)
        {{ dbt.safe_cast("id_ligne", dbt.type_int()) }} as id_ligne,
        {{ dbt.safe_cast("id_commande", dbt.type_int()) }} as id_commande,
        {{ dbt.safe_cast("id_produit", dbt.type_int()) }} as id_produit,
        {{ dbt.safe_cast("quantite", dbt.type_int()) }} as quantite

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
