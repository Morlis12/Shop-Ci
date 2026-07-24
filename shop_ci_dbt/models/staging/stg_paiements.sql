with source_data as (

    select *from {{ source('source_brut', 'paiements') }}

),

cleaned_data as (

    select
        -- 1. Conversion portable en texte (STRING sur BigQuery / VARCHAR sur DuckDB)
        cast(id_paiement as {{ dbt.type_string() }}) as raw_id_paiement,
        cast(id_commande as {{ dbt.type_string() }}) as raw_id_commande,
        cast(montant as {{ dbt.type_string() }}) as raw_montant,
        cast(methode as {{ dbt.type_string() }}) as raw_methode,
        cast(statut_paiement as {{ dbt.type_string() }}) as raw_statut_paiement,

        -- 2. Typage numérique portable sécurisé (Remplace try_cast)
        {{ dbt.safe_cast("id_paiement", dbt.type_int()) }} as id_paiement,
        {{ dbt.safe_cast("id_commande", dbt.type_int()) }} as id_commande,
        {{ dbt.safe_cast("montant", dbt.type_int()) }} as montant,
        
        -- 3. Nettoyage et normalisation du texte
        replace(lower(trim(cast(methode as {{ dbt.type_string() }}))), ' ', '_') as methode,
        lower(trim(cast(statut_paiement as {{ dbt.type_string() }}))) as statut_paiement

    from source_data

),

avec_rangs as (

    select
        *,
        row_number() over (
            partition by id_commande, statut_paiement
            order by id_paiement asc
        ) as rang_dans_statut
    from cleaned_data

)

select
    id_paiement,
    id_commande,
    montant,
    methode,
    statut_paiement,

    -- Flags métiers préexistants
    case when statut_paiement = 'reussi' then 1 else 0 end as est_reussi,
    case when statut_paiement = 'reussi' and rang_dans_statut = 1 then 1 else 0 end as vrai_reussi,
    case when statut_paiement = 'reussi' and rang_dans_statut > 1 then 1 else 0 end as est_doublon,

    -- =========================================================================
    -- Section sécurisée des flags is_missing pour toutes les colonnes
    -- =========================================================================
    case 
        when raw_id_paiement is null or trim(raw_id_paiement) = '' or lower(trim(raw_id_paiement)) = 'nan' then true
        else false
    end as is_missing_id_paiement,

    case 
        when raw_id_commande is null or trim(raw_id_commande) = '' or lower(trim(raw_id_commande)) = 'nan' then true
        else false
    end as is_missing_id_commande,

    case 
        when raw_montant is null or trim(raw_montant) = '' or lower(trim(raw_montant)) = 'nan' then true
        else false
    end as is_missing_montant,

    case 
        when raw_methode is null or trim(raw_methode) = '' or lower(trim(raw_methode)) = 'nan' then true
        else false
    end as is_missing_methode,

    case 
        when raw_statut_paiement is null or trim(raw_statut_paiement) = '' or lower(trim(raw_statut_paiement)) = 'nan' then true
        else false
    end as is_missing_statut_paiement

from avec_rangs
where id_paiement is not null
