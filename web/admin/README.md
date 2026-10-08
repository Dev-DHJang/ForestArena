# Forest Arena 관리자 화면

Vue 3·TypeScript·Vue Router·Element Plus로 한국어 표·검색·편집 화면을 제공한다. 인증 상태는 서버 세션에서 확인하며 비밀번호·세션 값을 브라우저 저장소에 보관하지 않는다. 화면의 권한 제한과 별도로 Spring 서버가 모든 요청의 권한을 검사한다.

## 실행

저장소의 관리자 실행 명령은 `docs/operations/admin-web.md`를 따른다. 화면만 개발할 때:

```sh
cd web/admin
npm ci
npm run dev
```

Node 22.12 이상을 사용한다. Vite는 `127.0.0.1:5173`에서 실행하고 `/admin/api`를 로컬 Spring `127.0.0.1:8080`으로 전달한다. 프록시 요청의 Origin도 해당 Spring 주소로 고정한다. 운영 빌드는 `npm run build`로 `dist/`에 생성한다. Spring이 제공하는 루트 페이지는 해시 경로(`#/`)를 사용하므로 서버의 별도 페이지 경로 처리가 필요 없다.

## 프로필 저장

첫 지급 상태는 수정하지 않는다. 선택 중인 항목을 회수하면 보유 항목의 대체 선택도 지정해야 한다. 변경 번호가 달라 `409`를 받으면 최신 프로필을 보여 주며, **최신 데이터로 다시 열기**로 다시 편집한다. 통신 실패로 저장 결과를 알 수 없으면 폼을 잠그고 **같은 요청 재시도**로 동일한 요청 ID와 데이터를 다시 보낸다. 저장 성공 후 게임에서 프로필을 다시 조회해야 한다는 안내를 표시한다.

## 브라우저 검사

```sh
npx playwright install chromium
npm run test:browser
```

가짜 API를 사용한 화면 검사는 로그인 → 관리자 생성 → 운영자 프로필 수정 → 같은 요청 재시도 → 작업 이력 → 조회자 수정 제한을 확인한다. 실제 DB·서버 검사는 아래 환경변수를 설정할 때 실행한다. 테스트 계정은 비밀번호 변경 의무를 먼저 해제해야 한다. 실제 검사는 새 조회자 계정을 만들고 지정한 프로필에 같은 데이터를 다시 저장하여 변경 번호·이력을 추가한다.

- `ADMIN_BROWSER_URL`: 실제 관리자 주소(예: `http://127.0.0.1:8080`)
- `ADMIN_E2E_SUPER_ID`, `ADMIN_E2E_SUPER_PASSWORD`
- `ADMIN_E2E_OPERATOR_ID`, `ADMIN_E2E_OPERATOR_PASSWORD`
- `ADMIN_E2E_VIEWER_ID`, `ADMIN_E2E_VIEWER_PASSWORD`
- `ADMIN_E2E_PLAYER_ID`: 검사할 게스트 UUID

비밀번호를 명령줄에 직접 쓰거나 테스트 결과에 출력하지 않는다. 환경변수 파일은 Git 밖에 보관한다. 실행 결과는 실제 서버 검사가 생략되었는지도 구분해 기록한다.

## 버전 확인

2026-10-08에 [Vue 릴리스 정책](https://vuejs.org/about/releases), [Vite 시작 가이드](https://vite.dev/guide/), [Vue Router 설치 안내](https://router.vuejs.org/installation.html), [Element Plus 설치 안내](https://element-plus.org/en-US/guide/installation.html)를 확인하고 npm의 stable 배포 번호를 정확한 버전으로 고정했다. Vue 3.5.43, Vite 8.3.3, Vue Router 5.4.0, Element Plus 2.14.7이다. TypeScript 7.0.2는 vue-tsc 3.3.12와 함께 실행할 때 `lib/tsc` 경로 오류가 발생하여 호환되는 TypeScript 5.9.3으로 고정했다. 직접 의존성과 전체 해석 결과를 `package.json`, `package-lock.json`에 남긴다.
