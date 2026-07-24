{% macro nettoyer_date(colonne) %}
    
    {% if target.type == 'bigquery' %}
    -- =========================================================================
    -- VERSION BIGQUERY (CLOUD)
    -- =========================================================================
    coalesce(
        -- Famille ISO : AAAA-MM-JJ, avec ou sans heure
        safe.parse_timestamp('%Y-%m-%d %H:%M:%S', {{ colonne }}),
        safe.parse_timestamp('%Y-%m-%d', {{ colonne }}),
        
        -- Famille française à slashs : JJ/MM/AAAA
        safe.parse_timestamp('%d/%m/%Y %H:%M:%S', {{ colonne }}),
        safe.parse_timestamp('%d/%m/%Y %H:%M', {{ colonne }}),
        safe.parse_timestamp('%d/%m/%Y', {{ colonne }}),
        
        -- Famille US à tirets : MM-JJ-AAAA
        safe.parse_timestamp('%m-%d-%Y %H:%M:%S', {{ colonne }}),
        safe.parse_timestamp('%m-%d-%Y %H:%M', {{ colonne }}),
        safe.parse_timestamp('%m-%d-%Y', {{ colonne }})
    )

    {% else %}
    -- =========================================================================
    -- VERSION DUCKDB (LOCAL)
    -- =========================================================================
    coalesce(
        -- Famille ISO : AAAA-MM-JJ, avec ou sans heure
        try_cast({{ colonne }} as timestamp),
        
        -- Famille française à slashs : JJ/MM/AAAA
        try_strptime({{ colonne }}, '%d/%m/%Y %H:%M:%S'),
        try_strptime({{ colonne }}, '%d/%m/%Y %H:%M'),
        try_strptime({{ colonne }}, '%d/%m/%Y'),
        
        -- Famille US à tirets : MM-JJ-AAAA
        try_strptime({{ colonne }}, '%m-%d-%Y %H:%M:%S'),
        try_strptime({{ colonne }}, '%m-%d-%Y %H:%M'),
        try_strptime({{ colonne }}, '%m-%d-%Y')
    )
    {% endif %}

{% endmacro %}
