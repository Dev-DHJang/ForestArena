#!/usr/bin/env python3
"""Create a separate admin integration database without touching development rows."""
import json, os, pathlib, secrets, subprocess
root = pathlib.Path(__file__).resolve().parents[1]
container = 'forest-arena-development-db-1'
info = json.loads(subprocess.check_output(['docker','inspect',container]))[0]
values = dict(v.split('=',1) for v in info['Config']['Env'] if '=' in v)
owner = values['POSTGRES_USER']
password = values['POSTGRES_PASSWORD']
db = 'forest_arena_admin_test_dev'
def sql(database, text):
    subprocess.run(['docker','exec','-i',container,'psql','-Xq','-v','ON_ERROR_STOP=1','-U',owner,'-d',database],input=text,text=True,check=True,stdout=subprocess.DEVNULL)
exists = subprocess.check_output(['docker','exec',container,'psql','-XAt','-U',owner,'-d',values['POSTGRES_DB'],'-c',f"SELECT 1 FROM pg_database WHERE datname='{db}'"],text=True).strip()
if not exists:
    sql(values['POSTGRES_DB'],f'CREATE DATABASE {db};')
    for migration in sorted((root/'database/migrations').glob('*.sql')):
        sql(db,migration.read_text())
    sql(db,"INSERT INTO infra.environment_guard(environment_name) VALUES('verification');")
test_owner = 'forest_arena_admin_test_owner'
test_password = secrets.token_hex(32)
sql(db, f"DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='{test_owner}') THEN CREATE ROLE {test_owner} LOGIN; END IF; END $$; ALTER ROLE {test_owner} PASSWORD '{test_password}';")
sql(db, f"ALTER DATABASE {db} OWNER TO {test_owner};")
sql(db, """DO $$ DECLARE x record; BEGIN
FOR x IN SELECT nspname FROM pg_namespace WHERE nspname IN ('app','admin','infra') LOOP
EXECUTE format('ALTER SCHEMA %I OWNER TO forest_arena_admin_test_owner',x.nspname); END LOOP;
FOR x IN SELECT schemaname,tablename FROM pg_tables WHERE schemaname IN ('app','admin','infra') LOOP
EXECUTE format('ALTER TABLE %I.%I OWNER TO forest_arena_admin_test_owner',x.schemaname,x.tablename); END LOOP;
END $$;""")
owner = test_owner
password = test_password
state = pathlib.Path.home()/'Library/Application Support/ForestArena/admin'
state.mkdir(parents=True, exist_ok=True)
path = state/'test.env'
os.umask(0o077)
# SQL owner password comes from the already-running local container; never print it.
import shlex
with path.open('w') as out:
    for k,v in {
        'ADMIN_TEST_DATABASE_URL':f'jdbc:postgresql://127.0.0.1:55432/{db}',
        'ADMIN_TEST_DATABASE_USER':owner,
        'ADMIN_TEST_DATABASE_PASSWORD':password,
        'ADMIN_DB_URL':f'jdbc:postgresql://127.0.0.1:55432/{db}',
        'ADMIN_DB_USER':'forest_arena_admin_web',
        'ADMIN_KEY_FILE':str(state/'test-keys.json')
    }.items(): out.write(f'{k}={shlex.quote(v)}\n')
# Use the provisioned admin-web role password, which setup already synchronized.
for line in (state/'db.env').read_text().splitlines():
    if line.startswith('ADMIN_DB_PASSWORD='):
        with path.open('a') as out: out.write(line+'\n')
path.chmod(0o600)
print('prepare-admin-test-db: isolated verification DB ready; external test.env saved')
