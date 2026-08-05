FROM apache/superset:latest

USER root
RUN /usr/local/bin/python -m pip install --no-cache-dir --no-deps --target=/app/.venv/lib/python3.10/site-packages \
    sqlalchemy-bigquery \
    google-cloud-bigquery \
    google-cloud-core \
    google-api-core \
    google-resumable-media \
    google-crc32c \
    proto-plus \
    googleapis-common-protos \
    grpcio \
    grpcio-status

RUN rm -rf /app/.venv/lib/python3.10/site-packages/sqlalchemy \
           /app/.venv/lib/python3.10/site-packages/sqlalchemy-*.dist-info \
           /app/.venv/lib/python3.10/site-packages/SQLAlchemy-*.dist-info \
           /app/.venv/lib/python3.10/site-packages/SQLAlchemy.libs && \
    /usr/local/bin/python -m pip install --no-cache-dir --no-deps --target=/app/.venv/lib/python3.10/site-packages "sqlalchemy==1.4.54"


COPY superset_config.py /app/pythonpath/superset_config.py

USER superset

CMD superset db upgrade && \
    (superset fab create-admin --username admin --firstname Admin --lastname User --email admin@shopci.local --password admin || true) && \
    superset init && \
    superset run -h 0.0.0.0 -p 8088