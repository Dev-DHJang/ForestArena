#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

fail() {
  echo "verify-database: FAIL: $*" >&2
  exit 1
}

for path in \
  database/.env.development.example \
  database/compose.development.yml \
  database/init/010_create_app_role.sh \
  database/migrations/0001_development_foundation.sql \
  scripts/db-dev.sh \
  scripts/verify-database-runtime.sh \
  docs/engineering/database.md \
  _workspace/development-database/00_request.md \
  _workspace/development-database/01_contract.md
do
  [ -f "$path" ] || fail "필수 파일 없음: $path"
done

grep -qF 'postgres:18.6-alpine3.23' database/compose.development.yml || fail "PostgreSQL 이미지 버전 없음"
grep -qF '127.0.0.1:${FOREST_ARENA_DB_PORT}:5432' database/compose.development.yml || fail "로컬 전용 포트 없음"
grep -qF 'pg_isready' database/compose.development.yml || fail "준비 상태 검사 없음"
grep -qF 'database/.env.development' .gitignore || fail "개발 비밀번호 제외 규칙 없음"
grep -qF 'database/backups/' .gitignore || fail "개발 백업 제외 규칙 없음"
grep -qF 'schema_migrations' database/migrations/0001_development_foundation.sql || fail "마이그레이션 기록 없음"
grep -qF 'environment_guard' database/migrations/0001_development_foundation.sql || fail "환경 표식 없음"
grep -qF -- '--confirm-development' scripts/db-dev.sh || fail "삭제 확인 규칙 없음"
grep -qF 'checksum_sha256' scripts/db-dev.sh || fail "마이그레이션 해시 확인 없음"

sh -n database/init/010_create_app_role.sh
sh -n scripts/db-dev.sh
sh -n scripts/verify-database.sh
sh -n scripts/verify-database-runtime.sh

echo "verify-database: PASS"
echo "- 개발계 PostgreSQL 구성, 비밀번호 제외, 마이그레이션 및 삭제 보호 규칙 확인"
