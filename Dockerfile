FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY shop_ci_dbt/ ./shop_ci_dbt/
COPY data_brute/ ./data_brute/
COPY charger_csv_bigquery.py .
COPY dagster_shop_ci/ ./dagster_shop_ci/

ENV GOOGLE_APPLICATION_CREDENTIALS=/app/.secrets.json
ENV DBT_PROJECT_DIR=/app/shop_ci_dbt
ENV DAGSTER_HOME=/app/dagster_home

RUN mkdir -p /app/dagster_home && \
    mkdir -p /root/.dbt && \
    printf 'shop_ci_dbt:\n  target: bigquery_dev\n  outputs:\n    bigquery_dev:\n      type: bigquery\n      method: service-account\n      project: shop-503309\n      dataset: shop_ci_dev\n      threads: 4\n      keyfile: /app/.secrets.json\n      location: US\n' > /root/.dbt/profiles.yml

COPY dagster_shop_ci/dagster.yaml /app/dagster_home/dagster.yaml

WORKDIR /app/dagster_shop_ci

EXPOSE 3000

CMD sh -c "cd /app/shop_ci_dbt && dbt deps && dbt parse --target bigquery_dev && cd /app/dagster_shop_ci && dagster-webserver -h 0.0.0.0 -p 3000 -f dagster_shop_ci/definitions.py & dagster-daemon run -f dagster_shop_ci/definitions.py"