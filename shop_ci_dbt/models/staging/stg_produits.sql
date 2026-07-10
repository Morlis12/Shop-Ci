with source_data as (

    select * from {{ source('source_brut', 'produits') }}

),

cleaned_data as (

    select
        -- 1. conversion en texte pour les tests de missing
        cast(id_produit as varchar) as raw_id_produit,
        cast(nom_produit as varchar) as raw_nom_produit,
        cast(prix_unitaire as varchar) as raw_prix_unitaire,
        cast(cout_unitaire as varchar) as raw_cout_unitaire,
        cast(categorie as varchar) as raw_categorie,
        cast(statut as varchar) as raw_statut,

        -- 2. typage et nettoyage metier (securise avec cast as varchar)
        try_cast(id_produit as integer) as id_produit,
        trim(cast(nom_produit as varchar)) as nom_produit,
        nullif(trim(cast(categorie as varchar)), '') as categorie,
        try_cast(split_part(trim(cast(prix_unitaire as varchar)), ' ', 1) as integer) as prix_unitaire,
        try_cast(split_part(trim(cast(cout_unitaire as varchar)), ' ', 1) as integer) as cout_unitaire,
        lower(trim(cast(statut as varchar))) as statut

    from source_data

)

select
    id_produit,
    nom_produit,
    categorie,
    prix_unitaire,
    cout_unitaire,
    statut,

    -- =========================================================================
    -- section securisee des flags is_missing
    -- =========================================================================
    case 
        when raw_id_produit is null or trim(raw_id_produit) = '' or lower(trim(raw_id_produit)) = 'nan' then true
        else false
    end as is_missing_id_produit,

    case 
        when raw_nom_produit is null or trim(raw_nom_produit) = '' or lower(trim(raw_nom_produit)) = 'nan' then true
        else false
    end as is_missing_nom_produit,

    case 
        when raw_prix_unitaire is null or trim(raw_prix_unitaire) = '' or lower(trim(raw_prix_unitaire)) = 'nan' then true
        else false
    end as is_missing_prix_unitaire,

    case 
        when raw_cout_unitaire is null or trim(raw_cout_unitaire) = '' or lower(trim(raw_cout_unitaire)) = 'nan' then true
        else false
    end as is_missing_cout_unitaire,

    case 
        when raw_categorie is null or trim(raw_categorie) = '' or lower(trim(raw_categorie)) = 'nan' then true
        else false
    end as is_missing_categorie,

    case 
        when raw_statut is null or trim(raw_statut) = '' or lower(trim(raw_statut)) = 'nan' then true
        else false
    end as is_missing_statut

from cleaned_data
