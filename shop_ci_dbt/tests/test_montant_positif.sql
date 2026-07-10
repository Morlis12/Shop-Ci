-- ce test isole toutes les lignes ou le montant est strictement inferieur a 0
-- si ce select renvoie des lignes, le test dbt echouera
select
    id_paiement,
    id_commande,
    montant
from {{ ref('stg_paiements') }}
where montant < 0
