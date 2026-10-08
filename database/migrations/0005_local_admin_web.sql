-- Local-only administration; passwords are provisioned outside migrations.
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'forest_arena_admin_web') THEN
    CREATE ROLE forest_arena_admin_web LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
  END IF;
END $$;
CREATE SCHEMA admin;
REVOKE ALL ON SCHEMA admin FROM PUBLIC, forest_arena_app;
CREATE TABLE admin.accounts (
  id uuid PRIMARY KEY,
  login_id text NOT NULL UNIQUE CHECK (login_id ~ '^[A-Za-z0-9_.-]{3,80}$'),
  password_hash text NOT NULL,
  display_name_encrypted text NOT NULL,
  email_encrypted text,
  role text NOT NULL CHECK (role IN ('SUPER_ADMIN','OPERATOR','VIEWER')),
  active boolean NOT NULL DEFAULT true,
  must_change_password boolean NOT NULL DEFAULT true,
  session_version bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE admin.sessions (
  id text PRIMARY KEY CHECK (length(id)=64),
  account_id uuid NOT NULL REFERENCES admin.accounts(id),
  session_version bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON admin.sessions(account_id);
CREATE TABLE admin.login_limits (
  scope text NOT NULL CHECK (scope IN ('account','ip')),
  key_hash text NOT NULL,
  failures integer NOT NULL DEFAULT 0,
  locked_until timestamptz,
  window_started_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(scope,key_hash)
);
CREATE TABLE admin.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id uuid,
  action text NOT NULL,
  target_id text NOT NULL,
  reason_encrypted text NOT NULL,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON admin.audit_log(created_at DESC);
CREATE TABLE admin.requests (
  actor_id uuid NOT NULL,
  player_id uuid NOT NULL REFERENCES app.player_profiles(player_id),
  request_id uuid NOT NULL,
  request_hash text NOT NULL,
  response jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(actor_id,player_id,request_id)
);
GRANT USAGE ON SCHEMA app,admin TO forest_arena_admin_web;
GRANT SELECT ON app.players,app.player_profiles,app.matches,app.match_participants TO forest_arena_admin_web;
GRANT UPDATE(profile,revision,updated_at) ON app.player_profiles TO forest_arena_admin_web;
GRANT SELECT,INSERT,UPDATE,DELETE ON admin.accounts,admin.sessions,admin.login_limits TO forest_arena_admin_web;
GRANT SELECT,INSERT ON admin.audit_log,admin.requests TO forest_arena_admin_web;
GRANT USAGE,SELECT ON SEQUENCE admin.audit_log_id_seq TO forest_arena_admin_web;
