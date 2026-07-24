{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if target.name == 'bigquery_prod' -%}
        {{ default_schema }}

    {%- elif custom_schema_name is not none -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}

    {%- else -%}
        {{ default_schema }}

    {%- endif -%}

{%- endmacro %}