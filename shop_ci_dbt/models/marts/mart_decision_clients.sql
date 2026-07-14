with ventes_client as (
    select
        v.id_client,
        count(distinct v.id_commande)  as nb_commandes,
        sum(v.montant_ligne)           as ca_total,
        max(c.jour_commande)           as derniere_commande
    from {{ ref('fait_ventes') }} v
    inner join {{ ref('stg_commandes') }} c on v.id_commande = c.id_commande
    where v.statut not in ('annulee', 'retournee')
    -- NOTE : on GARDE le membre -1. C'est une masse de ~2M XOF de CA
    -- (31 commandes non identifiees). Il sera classe ClientNonIdentifie
    -- dans le graphe : une decision metier ("identifier ces commandes"),
    -- pas une exclusion silencieuse.
    group by 1
),
reference as (
    select max(derniere_commande) as date_ref from ventes_client
)
select
    vc.id_client,
    dc.nom_complet,
    dc.pays,
    dc.date_inscription,
    vc.nb_commandes,
    vc.ca_total,
    vc.derniere_commande,
    date_diff('day', vc.derniere_commande, r.date_ref)  as jours_inactivite,
    date_diff('day', dc.date_inscription, r.date_ref)   as anciennete_jours
from ventes_client vc
cross join reference r
inner join {{ ref('dim_clients') }} dc on vc.id_client = dc.id_client