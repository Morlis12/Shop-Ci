{% macro nettoyer_date(colonne) %}
    coalesce(
        -- Famille ISO : AAAA-MM-JJ, avec ou sans heure (non ambigu)
        try_cast({{ colonne }} as timestamp),
        -- Famille française à slashs : JJ/MM/AAAA, du plus précis au moins précis
        try_strptime({{ colonne }}, '%d/%m/%Y %H:%M:%S'),
        try_strptime({{ colonne }}, '%d/%m/%Y %H:%M'),
        try_strptime({{ colonne }}, '%d/%m/%Y'),
        -- Famille US à tirets : MM-JJ-AAAA (convention établie par l'audit)
        try_strptime({{ colonne }}, '%m-%d-%Y %H:%M:%S'),
        try_strptime({{ colonne }}, '%m-%d-%Y %H:%M'),
        try_strptime({{ colonne }}, '%m-%d-%Y')
    )
{% endmacro %}