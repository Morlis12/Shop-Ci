with source_data as (

    select * from {{ source('source_brut', 'clients') }}

),

cleaned_data as (

    select
        cast(id_client as {{ dbt.type_string() }}) as raw_id_client,
        cast(email as {{ dbt.type_string() }}) as raw_email,
        cast(prenom as {{ dbt.type_string() }}) as raw_prenom,
        cast(nom as {{ dbt.type_string() }}) as raw_nom,
        cast(ville as {{ dbt.type_string() }}) as raw_ville,
        cast(pays as {{ dbt.type_string() }}) as raw_pays,
        cast(date_inscription as {{ dbt.type_string() }}) as raw_date_inscription,
        cast(telephone as {{ dbt.type_string() }}) as raw_telephone,

        {{ dbt.safe_cast("id_client", dbt.type_int()) }} as id_client,
        trim(lower(cast(email as {{ dbt.type_string() }}))) as email,
        
        concat(upper(substr(trim(cast(prenom as {{ dbt.type_string() }})), 1, 1)), lower(substr(trim(cast(prenom as {{ dbt.type_string() }})), 2))) as prenom,
        
        upper(trim(cast(nom as {{ dbt.type_string() }}))) as nom,
        lower(trim(cast(ville as {{ dbt.type_string() }}))) as ville,

        -- Utilisation des guillemets doubles pour sécuriser les apostrophes
        case
            when lower(trim(cast(pays as {{ dbt.type_string() }}))) in ("ci", "cote d'ivoire", "côte d'ivoire") then "Côte d'Ivoire"
            when lower(trim(cast(pays as {{ dbt.type_string() }}))) in ("sn", "senegal", "sénégal") then "Sénégal"
            when lower(trim(cast(pays as {{ dbt.type_string() }}))) in ("fr", "france") then "France"
            when lower(trim(cast(pays as {{ dbt.type_string() }}))) in ("ml", "mali") then "Mali"
            else trim(cast(pays as {{ dbt.type_string() }}))
        end as pays,

        cast({{ nettoyer_date('date_inscription') }} as date) as date_inscription,

        nullif(trim(cast(telephone as {{ dbt.type_string() }})), '') as telephone

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
    concat(prenom, ' ', nom) as nom_complet,
    ville,
    pays,
    date_inscription,
    telephone,

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
