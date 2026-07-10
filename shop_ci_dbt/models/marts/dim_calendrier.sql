-- Dimension calendrier : le QUAND du modèle en étoile.
-- Cette dimension n'existe dans AUCUNE source : on la GÉNÈRE, un jour par ligne.
-- C'est l'équivalent de ta table de dates Power BI (CALENDARAUTO).
with jours as (

    select cast(range as date) as jour
    from range(date '2023-01-01', date '2026-12-31', interval 1 day)

)

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
    strftime(jour, '%Y-%m')                     as annee_mois,
    isodow(jour)                                as numero_jour_semaine,
    case isodow(jour)
        when 1 then 'Lundi'    when 2 then 'Mardi'  when 3 then 'Mercredi'
        when 4 then 'Jeudi'    when 5 then 'Vendredi'
        when 6 then 'Samedi'   when 7 then 'Dimanche'
    end                                         as nom_jour,
    isodow(jour) in (6, 7)                      as est_weekend

from jours