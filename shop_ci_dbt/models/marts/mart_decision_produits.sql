-- =========================================================================
-- MART DE DECISION : PRODUITS
-- Attributs de decision par produit (volume, marge, statut). Le label metier
-- (ProduitStar, ProduitMargeFaible...) sera DEDUIT dans le graphe.
-- =========================================================================
with ventes_produit as (

    select
        v.id_produit,
        sum(v.quantite)                                    as quantite_vendue,
        count(distinct v.id_commande)                      as nb_commandes,
        sum(v.montant_ligne)                               as ca_total,
        sum(v.marge_ligne)                                 as marge_total,
        case when sum(v.montant_ligne) > 0
             then round(100.0 * sum(v.marge_ligne) / sum(v.montant_ligne), 1)
             else 0 end                                    as taux_marge_pct
    from {{ ref('fait_ventes') }} v
    where v.statut not in ('annulee', 'retournee')   -- coherent avec ca_officiel
    group by 1

)

select
    dp.id_produit,
    dp.nom_produit as nom_produit,
    dp.categorie,
    dp.statut,
    coalesce(vp.quantite_vendue, 0)  as quantite_vendue,
    coalesce(vp.nb_commandes, 0)     as nb_commandes,
    coalesce(vp.ca_total, 0)         as ca_total,
    coalesce(vp.marge_total, 0)      as marge_total,
    coalesce(vp.taux_marge_pct, 0)   as taux_marge_pct

from {{ ref('dim_produits') }} dp
left join ventes_produit vp on dp.id_produit = vp.id_produit