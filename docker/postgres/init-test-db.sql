-- Creates the test database alongside the primary `squadup` database.
-- Runs once when Postgres initialises a fresh data directory (i.e. on
-- first `docker compose up`). Existing volumes don't re-run init scripts;
-- see README for the one-line fix if you already had a volume.
--
-- Idempotent via the `SELECT ... \gexec` pattern — does nothing if the
-- database already exists.

SELECT 'CREATE DATABASE squadup_test OWNER squadup'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'squadup_test'
)\gexec
