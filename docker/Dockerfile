FROM python:3.12-slim

WORKDIR /app

COPY app/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app/app.py .
COPY app/test_app.py .
COPY app/gunicorn.conf.py .

RUN useradd --create-home --shell /usr/sbin/nologin appuser \
    && mkdir -p /tmp/prometheus_multiproc \
    && chown -R appuser:appuser /app /tmp/prometheus_multiproc

ENV PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus_multiproc

USER appuser

EXPOSE 5000

CMD ["gunicorn", \
     "--config", "gunicorn.conf.py", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--timeout", "30", \
     "app:app"]
