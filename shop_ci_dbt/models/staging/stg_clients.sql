with source_data as (

    select * from {{ source('source_brut', 'clients') }}

),

cleaned_data as (

    select
        -- 1. force la conversion en texte (varchar) pour la compatibilité avec trim/lower dans les tests de missing
        cast(id_client as varchar) as raw_id_client,
        cast(email as varchar) as raw_email,
        cast(prenom as varchar) as raw_prenom,
        cast(nom as varchar) as raw_nom,
        cast(ville as varchar) as raw_ville,
        cast(pays as varchar) as raw_pays,
        cast(date_inscription as varchar) as raw_date_inscription,
        cast(telephone as varchar) as raw_telephone,

        -- 2. typage, conversion et nettoyage sécurisé des données
        try_cast(id_client as integer) as id_client,
        trim(lower(cast(email as varchar))) as email,
        upper(substr(trim(cast(prenom as varchar)), 1, 1)) || lower(substr(trim(cast(prenom as varchar)), 2)) as prenom,
        upper(trim(cast(nom as varchar))) as nom,
        lower(trim(cast(ville as varchar))) as ville,

        -- 3. normalisation des pays sécurisée
        case
            when lower(trim(cast(pays as varchar))) in ('ci', 'cote d''ivoire', 'côte d''ivoire') then 'Côte d''Ivoire'
            when lower(trim(cast(pays  as varchar))) in ('sn', 'senegal', 'sénégal') then 'Sénégal'
            when lower(trim(cast(pays as varchar))) in ('fr', 'france') then 'France'
            when lower(trim(cast(pays as varchar))) in ('ml', 'mali') then 'Mali'
            else trim(cast(pays as varchar))
        end as pays,

        -- 4. standardisation de la date d'inscription
cast({{ nettoyer_date('date_inscription') }} as date) as date_inscription,

        nullif(trim(cast(telephone as varchar)), '') as telephone

    from source_data

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by email
            order by date_inscription asc, id_client asc
        ) as rang
    from cleaned_data

)

select
    id_client,
    email,
    prenom,
    nom,
    prenom || ' ' || nom as nom_complet,
    ville,
    pays,
    date_inscription,
    telephone,

    -- =========================================================================
    -- section sécurisée des flags is_missing pour toutes les colonnes
    -- =========================================================================
    case 
        when raw_id_client is null or trim(raw_id_client) = '' or lower(trim(raw_id_client)) = 'nan' then true
        else false
    end as is_missing_id_client,

    case 
        when raw_email is null or trim(raw_email) = '' or lower(trim(raw_email)) = 'nan' then true
        else false
    end as is_missing_email,

    case 
        when raw_prenom is null or trim(raw_prenom) = '' or lower(trim(raw_prenom)) = 'nan' then true
        else false
    end as is_missing_prenom,

    case 
        when raw_nom is null or trim(raw_nom) = '' or lower(trim(raw_nom)) = 'nan' then true
        else false
    end as is_missing_nom,

    case 
        when raw_ville is null or trim(raw_ville) = '' or lower(trim(raw_ville)) = 'nan' then true
        else false
    end as is_missing_ville,

    case 
        when raw_pays is null or trim(raw_pays) = '' or lower(trim(raw_pays)) = 'nan' then true
        else false
    end as is_missing_pays,

    case 
        when raw_date_inscription is null or trim(raw_date_inscription) = '' or lower(trim(raw_date_inscription)) = 'nan' then true
        else false
    end as is_missing_date_inscription,

    case 
        when raw_telephone is null or trim(raw_telephone) = '' or lower(trim(raw_telephone)) = 'nan' then true
        else false
    end as is_missing_telephone

from deduplicated
where rang = 1

