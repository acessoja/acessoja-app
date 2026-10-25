FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY backend/requirements.txt backend/requirements-geographic.txt /app/backend/
RUN pip install -r backend/requirements-geographic.txt && useradd --uid 10001 --create-home app
COPY . /app
RUN mkdir -p /var/lib/acessoja/media /var/lib/acessoja/deletions /var/log/acessoja /app/staticfiles && chmod 0700 /var/lib/acessoja/media /var/lib/acessoja/deletions /var/log/acessoja && chown -R app:app /app /var/lib/acessoja /var/log/acessoja
USER 10001:10001
CMD ["gunicorn", "acessoja.wsgi:application", "--config", "deploy/staging/gunicorn.conf.py"]
