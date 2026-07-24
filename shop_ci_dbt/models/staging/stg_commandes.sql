with source_data as (

    select * from {{ source('source_brut', 'commandes') }}

),

cleaned_data as (

    select
        -- 1. conservation des valeurs brutes en texte pour les tests de missing
        cast(id_commande as {{ dbt.type_string() }}) as raw_id_commande,
        cast(id_client as {{ dbt.type_string() }}) as raw_id_client,
        cast(date_commande as {{ dbt.type_string() }}) as raw_date_commande,
        cast(statut as {{ dbt.type_string() }}) as raw_statut,
        cast(canal as {{ dbt.type_string() }}) as raw_canal,

        -- 2. conservation et typage des identifiants pour la selection finale
        {{ dbt.safe_cast("id_commande", dbt.type_int()) }} as id_commande,
        {{ dbt.safe_cast("id_client", dbt.type_int()) }} as id_client,

        -- 3. typage et normalisation de la date en timestamp via macro
        {{ nettoyer_date('date_commande') }} as date_commande,

        -- 4. normalisation des statuts et canaux
        lower(trim(cast(statut as {{ dbt.type_string() }}))) as statut,
        lower(trim(cast(canal as {{ dbt.type_string() }}))) as canal

    from source_data

)

select
    id_commande,
    id_client,
    date_commande,
    cast(date_commande as date) as jour_commande,
    statut,
    canal,

    -- =========================================================================
    -- section des flags de valeurs manquantes (missing) pour toutes les colonnes
    -- =========================================================================
    case 
        when raw_id_commande is null or trim(raw_id_commande) = '' or lower(trim(raw_id_commande)) = 'nan' then true
        else false
    end as is_missing_id_commande,

    case 
        when raw_id_client is null or trim(raw_id_client) = '' or lower(trim(raw_id_client)) = 'nan' then true
        else false
    end as is_missing_id_client,

    case 
        when raw_date_commande is null or trim(raw_date_commande) = '' or lower(trim(raw_date_commande)) = 'nan' then true
        else false
    end as is_missing_date_commande,

    case 
        when raw_statut is null or trim(raw_statut) = '' or lower(trim(raw_statut)) = 'nan' then true
        else false
    end as is_missing_statut,

    case 
        when raw_canal is null or trim(raw_canal) = '' or lower(trim(raw_canal)) = 'nan' then true
        else false
    end as is_missing_canal

from cleaned_data