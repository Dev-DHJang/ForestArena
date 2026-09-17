#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DATABASE_DIR="$ROOT/database"
ENV_FILE="$DATABASE_DIR/.env.development"
ENV_EXAMPLE="$DATABASE_DIR/.env.development.example"
COMPOSE_FILE="$DATABASE_DIR/compose.development.yml"
MIGRATIONS_DIR="$DATABASE_DIR/migrations"
BACKUP_DIR="$DATABASE_DIR/backups"

fail() {
  echo "db-dev: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
사용법: ./scripts/db-dev.sh <명령> [인자]

명령:
  install                       macOS 개발 도구를 설치한다.
  doctor                        필요한 도구와 Docker 연결을 확인한다.
  up                            개발 DB를 시작하고 마이그레이션을 적용한다.
  down                          DB를 멈춘다. 데이터 볼륨은 유지한다.
  status                        컨테이너 상태를 표시한다.
  logs                          DB 로그를 계속 표시한다.
  psql                          관리자 psql을 연다.
  migrate                       새 마이그레이션을 적용한다.
  backup                        database/backups에 백업을 만든다.
  restore <파일> --confirm-development
                                개발계 백업을 복원한다.
  reset --confirm-development   개발계 DB와 볼륨을 지우고 새로 만든다.
USAGE
}

load_env() {
  [ -f "$ENV_FILE" ] || fail "환경 파일이 없습니다. 먼저 up을 실행하세요: $ENV_FILE"
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
}

create_env_if_missing() {
  [ -f "$ENV_FILE" ] && return
  command -v openssl >/dev/null 2>&1 || fail "openssl이 없어 개발용 비밀번호를 만들 수 없습니다."
  admin_password=$(openssl rand -hex 24)
  app_password=$(openssl rand -hex 24)
  umask 077
  {
    printf '%s\n' "FOREST_ARENA_DB_PORT=55432"
    printf '%s\n' "FOREST_ARENA_DB_NAME=forest_arena_dev"
    printf '%s\n' "FOREST_ARENA_DB_ADMIN_USER=forest_arena_admin"
    printf '%s\n' "FOREST_ARENA_DB_ADMIN_PASSWORD=$admin_password"
    printf '%s\n' "FOREST_ARENA_DB_APP_USER=forest_arena_app"
    printf '%s\n' "FOREST_ARENA_DB_APP_PASSWORD=$app_password"
    printf '%s\n' "FOREST_ARENA_DB_ENVIRONMENT=development"
  } > "$ENV_FILE"
  echo "db-dev: 개발계 환경 파일을 만들었습니다: $ENV_FILE"
}

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

require_docker() {
  command -v docker >/dev/null 2>&1 || fail "docker가 없습니다. ./scripts/db-dev.sh install을 실행하세요."
  docker version >/dev/null 2>&1 || fail "Docker 엔진에 연결할 수 없습니다. Colima를 시작한 뒤 다시 실행하세요."
}

start_colima_if_needed() {
  command -v colima >/dev/null 2>&1 || fail "colima가 없습니다. ./scripts/db-dev.sh install을 실행하세요."
  colima status >/dev/null 2>&1 || colima start --runtime docker --cpu 2 --memory 2 --disk 20
}

db_psql() {
  compose exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_ADMIN_PASSWORD" db \
    psql --username "$FOREST_ARENA_DB_ADMIN_USER" --dbname "$FOREST_ARENA_DB_NAME" "$@"
}

require_development_guard() {
  [ "$FOREST_ARENA_DB_ENVIRONMENT" = "development" ] || fail "개발계 환경 파일만 사용할 수 있습니다."
  case "$FOREST_ARENA_DB_NAME" in
    *_dev) ;;
    *) fail "개발계 DB 이름은 _dev로 끝나야 합니다." ;;
  esac
  guard=$(db_psql -Atqc "SELECT environment_name FROM infra.environment_guard WHERE singleton" || true)
  [ "$guard" = "development" ] || fail "DB 개발계 표식이 맞지 않습니다: ${guard:-없음}"
}

set_development_guard() {
  guard=$(db_psql -Atqc "SELECT environment_name FROM infra.environment_guard WHERE singleton" || true)
  if [ -z "$guard" ]; then
    db_psql --set ON_ERROR_STOP=1 --set environment_name=development <<'SQL'
INSERT INTO infra.environment_guard (singleton, environment_name)
VALUES (true, :'environment_name');
SQL
  elif [ "$guard" != "development" ]; then
    fail "이미 다른 환경 표식이 있습니다: $guard"
  fi
}

apply_migrations() {
  for migration_path in "$MIGRATIONS_DIR"/*.sql
  do
    [ -f "$migration_path" ] || continue
    migration_name=$(basename "$migration_path")
    checksum=$(shasum -a 256 "$migration_path" | awk '{print $1}')
    ledger_exists=$(db_psql -Atqc "SELECT to_regclass('infra.schema_migrations') IS NOT NULL")
    if [ "$ledger_exists" = "t" ]; then
      applied_checksum=$(db_psql -Atqc \
        "SELECT checksum_sha256 FROM infra.schema_migrations WHERE migration_name = '$migration_name'")
    else
      applied_checksum=''
    fi

    if [ -n "$applied_checksum" ]; then
      [ "$applied_checksum" = "$checksum" ] || fail "적용된 마이그레이션이 바뀌었습니다: $migration_name"
      continue
    fi

    echo "db-dev: 적용 $migration_name"
    compose exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_ADMIN_PASSWORD" db \
      psql --username "$FOREST_ARENA_DB_ADMIN_USER" --dbname "$FOREST_ARENA_DB_NAME" \
        --set ON_ERROR_STOP=1 \
        --set migration_name="$migration_name" \
        --set migration_checksum="$checksum" <<SQL
BEGIN;
\\i /migrations/$migration_name
INSERT INTO infra.schema_migrations (migration_name, checksum_sha256)
VALUES (:'migration_name', :'migration_checksum');
COMMIT;
SQL
  done
  set_development_guard
  require_development_guard
}

install_tools() {
  command -v brew >/dev/null 2>&1 || fail "Homebrew가 필요합니다: https://brew.sh"
  brew install colima docker docker-compose
  plugin_source="$(brew --prefix)/lib/docker/cli-plugins/docker-compose"
  plugin_target="$HOME/.docker/cli-plugins/docker-compose"
  [ -x "$plugin_source" ] || fail "docker-compose 플러그인을 찾지 못했습니다: $plugin_source"
  mkdir -p "$(dirname "$plugin_target")"
  if [ ! -e "$plugin_target" ]; then
    ln -s "$plugin_source" "$plugin_target"
  fi
  echo "db-dev: 설치가 끝났습니다. ./scripts/db-dev.sh up을 실행하세요."
}

backup_database() {
  require_development_guard
  mkdir -p "$BACKUP_DIR"
  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  backup_path="$BACKUP_DIR/forest_arena_dev_$timestamp.dump"
  backup_temp="$backup_path.partial"
  umask 077
  if ! compose exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_ADMIN_PASSWORD" db \
    pg_dump --format=custom --username "$FOREST_ARENA_DB_ADMIN_USER" \
      --dbname "$FOREST_ARENA_DB_NAME" > "$backup_temp"
  then
    rm -f "$backup_temp"
    fail "백업을 만들지 못했습니다."
  fi
  mv "$backup_temp" "$backup_path"
  chmod 600 "$backup_path"
  echo "db-dev: 백업 생성: $backup_path"
}

restore_database() {
  backup_path=${1:-}
  confirmation=${2:-}
  [ -n "$backup_path" ] || fail "복원할 백업 파일이 필요합니다."
  [ -f "$backup_path" ] || fail "백업 파일이 없습니다: $backup_path"
  [ "$confirmation" = "--confirm-development" ] || fail "복원하려면 --confirm-development를 함께 입력하세요."
  require_development_guard
  compose exec -T -e "PGPASSWORD=$FOREST_ARENA_DB_ADMIN_PASSWORD" db \
    pg_restore --clean --if-exists --no-owner --username "$FOREST_ARENA_DB_ADMIN_USER" \
      --dbname "$FOREST_ARENA_DB_NAME" < "$backup_path"
  require_development_guard
}

case ${1:-} in
  install)
    install_tools
    ;;
  doctor)
    command -v colima >/dev/null 2>&1 || fail "colima가 없습니다."
    command -v docker >/dev/null 2>&1 || fail "docker가 없습니다."
    docker compose version >/dev/null 2>&1 || fail "docker compose가 없습니다."
    docker version >/dev/null 2>&1 || fail "Docker 엔진에 연결할 수 없습니다."
    echo "db-dev: 개발계 도구와 Docker 연결을 확인했습니다."
    ;;
  up)
    create_env_if_missing
    load_env
    start_colima_if_needed
    require_docker
    compose up --detach --wait db
    apply_migrations
    echo "db-dev: 개발계 DB가 준비되었습니다: 127.0.0.1:$FOREST_ARENA_DB_PORT/$FOREST_ARENA_DB_NAME"
    ;;
  down)
    load_env
    require_docker
    compose down
    ;;
  status)
    load_env
    require_docker
    compose ps
    ;;
  logs)
    load_env
    require_docker
    compose logs --follow db
    ;;
  psql)
    load_env
    require_docker
    db_psql
    ;;
  migrate)
    load_env
    require_docker
    apply_migrations
    ;;
  backup)
    load_env
    require_docker
    backup_database
    ;;
  restore)
    load_env
    require_docker
    restore_database "${2:-}" "${3:-}"
    ;;
  reset)
    [ "${2:-}" = "--confirm-development" ] || fail "초기화하려면 --confirm-development를 함께 입력하세요."
    load_env
    require_docker
    require_development_guard
    compose down --volumes
    rm -f "$ENV_FILE"
    echo "db-dev: 개발계 볼륨을 지웠습니다. 다음 up에서 새 비밀번호와 빈 DB를 만듭니다."
    ;;
  *)
    usage
    exit 1
    ;;
esac
