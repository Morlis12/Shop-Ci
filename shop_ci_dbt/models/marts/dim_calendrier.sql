-- Dimension calendrier : le QUAND du modèle en étoile.
-- Cette dimension n'existe dans AUCUNE source : on la GÉNÈRE, un jour par ligne.
-- C'est l'équivalent de ta table de dates Power BI (CALENDARAUTO).
with jours as (

    {% if target.type == 'bigquery' %}
    -- Syntaxe pour générer des lignes de dates sur BigQuery
    select jour
    from unnest(generate_date_array(date '2023-01-01', date '2026-12-31', interval 1 day)) as jour
    {% else %}
    -- Syntaxe d'origine pour DuckDB local
    select cast(range as date) as jour
    from range(date '2023-01-01', date '2026-12-31', interval 1 day)
    {% endif %}

),

calcul_base as (

    select
        jour,
        extract(year from jour)                     as annee,
        extract(month from jour)                    as numero_mois,
        case extract(month from jour)
            when 1 then 'Janvier'   when 2 then 'Février'   when 3 then 'Mars'
            when 4 then 'Avril'     when 5 then 'Mai'       when 6 then 'Juin'
            when 7 then 'Juillet'   when 8 then 'Août'      when 9 then 'Septembre'
            when 10 then 'Octobre'  when 11 then 'Novembre' when 12 then 'Décembre'
        end                                         as nom_mois,
        
        -- Routage des fonctions de formatage et d'extraction selon la cible
        {% if target.type == 'bigquery' %}
        format_date('%Y-%m', jour)                  as annee_mois,
        -- BigQuery extrait de 1 (Dimanche) à 7 (Samedi). On décale pour retrouver l'ISO (1=Lundi, 7=Dimanche)
        case extract(dayofweek from jour)
            when 1 then 7
            else extract(dayofweek from jour) - 1
        end                                         as numero_jour_semaine
        {% else %}
        strftime(jour, '%Y-%m')                     as annee_mois,
        isodow(jour)                                as numero_jour_semaine
        {% endif %}

    from jours

)

select
    jour,
    annee,
    numero_mois,
    nom_mois,
    annee_mois,
    numero_jour_semaine,
    case numero_jour_semaine
        when 1 then 'Lundi'    when 2 then 'Mardi'  when 3 then 'Mercredi'
        when 4 then 'Jeudi'    when 5 then 'Vendredi'
        when 6 then 'Samedi'   when 7 then 'Dimanche'
    end                                         as nom_jour,
    -- Création d'un booléen strict et standardisé pour le week-end
    case when numero_jour_semaine in (6, 7) then true else false end as est_weekend

from calcul_base
