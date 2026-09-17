CREATE SCHEMA IF NOT EXISTS infra;
CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS infra.schema_migrations (
  migration_name text PRIMARY KEY,
  checksum_sha256 text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS infra.environment_guard (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  environment_name text NOT NULL CHECK (environment_name IN ('development', 'verification', 'production')),
  created_at timestamptz NOT NULL DEFAULT now()
);

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA app TO forest_arena_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO forest_arena_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO forest_arena_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT USAGE, SELECT ON SEQUENCES TO forest_arena_app;
