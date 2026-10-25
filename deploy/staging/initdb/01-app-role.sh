#!/bin/sh
set -eu
# psql reads the secret from the environment, never a shell-expanded SQL string
# or process argument. Executed only when initializing a fresh PostgreSQL volume.
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set=ON_ERROR_STOP=1 <<'SQL'
\getenv app_password APP_DATABASE_PASSWORD
CREATE ROLE acessoja_app LOGIN;
ALTER ROLE acessoja_app PASSWORD :'app_password';
GRANT CONNECT ON DATABASE acessoja_staging TO acessoja_app;
GRANT USAGE, CREATE ON SCHEMA public TO acessoja_app;
SQL
