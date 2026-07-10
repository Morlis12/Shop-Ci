-- TEST SINGULIER : règle métier de réconciliation du chiffre d'affaires.
-- Le CA des paiements valides doit égaler le CA des lignes de ventes
-- des commandes correspondantes. Un test dbt échoue s'il renvoie des lignes.
with ca_paiements as (

    select sum(montant) as ca
    from {{ ref('fait_paiements') }}
    where est_reussi = 1 and est_doublon = 0

),

ca_ventes as (

    select sum(v.montant_ligne) as ca
    from {{ ref('fait_ventes') }} v
    where v.id_commande in (
        select id_commande from {{ ref('fait_paiements') }}
        where est_reussi = 1 and est_doublon = 0
    )

)

select 
p.ca as ca_paiements,
v.ca as ca_ventes
from ca_paiements p, ca_ventes v
where p.ca != v.ca