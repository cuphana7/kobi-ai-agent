---
name: intranet-web
description: SSO 로그인이 필요한 사내 웹서비스(HTML 화면) 내용을 읽기 전용으로 조회한다. 사용자가 Kobi 전용 Edge 창에서 직접 SSO 로그인 버튼을 눌러 로그인하면, 그 화면의 본문 텍스트·표·링크를 JSON으로 읽어오거나, 로그인 세션으로 화면이 쓰는 사내 API를 GET 호출해 JSON 결과를 받아온다. 로그인 완료를 기다렸다가 지정한 페이지로 자동 이동해 내용을 가져올 수도 있다. 클릭·입력·저장 같은 조작은 하지 않는다. "사내 ○○ 화면 목록 조회해줘", "그 웹 화면 표 내용 정리해줘", "상세 화면 내용 읽어줘", "로그인되면 ○○ 페이지 요약해줘", "○○ API 결과 가져와줘" 같은 요청에 사용한다. Windows 전용.
---

# 사내 SSO 웹서비스 조회 스킬 (intranet-web)

API 없이 HTML 화면만 제공하고, 화면에서 **SSO 로그인 버튼을 눌러야** 로그인되는 사내 웹서비스를 Kobi가 읽을 수 있게 해 준다.

- Kobi가 **Kobi 전용 프로필**로 Microsoft Edge를 연다(사용자의 평소 Edge 프로필과 분리).
- **로그인은 사용자가 직접** 그 Edge 창에서 SSO 로그인 버튼을 눌러 진행한다. Kobi는 ID/PW·쿠키·토큰을 다루지 않는다.
- 로그인된 화면의 내용을 Chrome DevTools Protocol(로컬 디버깅 포트, 127.0.0.1 전용)로 **읽기만** 한다.

스크립트는 `<스킬경로>/scripts/intranet-web.cjs`에 위치하며 Node.js(22 이상, Kobi 번들 node)로 직접 실행한다.

---

## 1. 설정 (`<스킬경로>/config.json`)

| 키 | 설명 |
|---|---|
| `allowedHosts` | 접속·조회를 허용할 사내 웹서비스 호스트 목록. 정확한 호스트명 또는 `*.example.local` 형태. **비어 있으면 동작하지 않는다(`CONFIG_REQUIRED`).** |
| `startUrl` | `open`에서 `--url`을 생략했을 때 여는 첫 화면 주소 |
| `afterLoginUrl` | 로그인 완료 후 자동으로 이동할 페이지(`open --wait` / `wait-login`에서 `--then` 생략 시 사용) |
| `loginWaitSec` / `pollIntervalSec` | 로그인 완료 대기 최대 시간(기본 180초) / 확인 간격(기본 2초) |
| `apiMaxChars` | `api-get` 응답 최대 길이(기본 100000자, 넘으면 JSON 파싱 없이 앞부분만 텍스트로 반환) |
| `apis` | 자주 쓰는 API 목록 `[{ "name", "url", "description" }]` — `apis` 명령으로 조회해 요청에 맞는 API를 고른다 |
| `loginUrlPatterns` | SSO 로그인 화면을 판별하는 문자열(URL 또는 제목에 포함되면 로그인 화면으로 간주) |
| `debugPort` | Edge 로컬 디버깅 포트 (기본 9333) |
| `maxChars` / `maxRows` | `read` 텍스트 최대 길이 / `tables` 표당 최대 행 수 |
| `navigateTimeoutSec` | `goto` 페이지 로딩 대기 시간 |

---

## 2. 사용법 (Usage)

### ① Edge 열기 + 로그인 상태 확인
```bash
node scripts/intranet-web.cjs open [--url <URL>]
```
- 결과 `data.status`가 `LOGIN_REQUIRED`이면 사용자에게 **"열린 Edge 창에서 SSO 로그인 버튼을 눌러 로그인한 뒤 알려 주세요"**라고 안내하고 기다린다. Kobi가 로그인을 대신 시도하지 않는다.

### ①-1 로그인 완료까지 기다렸다가 목표 페이지로 자동 이동 (권장)
```bash
node scripts/intranet-web.cjs open --wait [--url <첫 화면>] [--then <목표 페이지>]
node scripts/intranet-web.cjs wait-login [--then <목표 페이지>] [--timeout 180]
```
- 실행 전에 사용자에게 **"열리는 Edge 창에서 SSO 로그인 버튼을 눌러 주세요"**라고 먼저 안내한다.
- 로그인이 확인되면 `--then`(없으면 `afterLoginUrl`) 페이지로 이동해 `data.page`에 본문 텍스트(`text`)와 표(`tables`)를 함께 반환한다. 이 내용을 요약해 답변한다.
- 이동할 페이지가 없으면 로그인 확인만 하고 `READY`를 반환한다.
- 시간 안에 로그인하지 않으면 `LOGIN_TIMEOUT` — 사용자에게 로그인 후 다시 요청하라고 안내한다.

### ② 상태 확인
```bash
node scripts/intranet-web.cjs status
```
- `READY`(읽기 가능) / `LOGIN_REQUIRED`(로그인 필요) / `NO_SERVICE_TAB`(허용 화면 없음) / `BROWSER_NOT_RUNNING`(Edge 미실행 → `open`)

### ③ 화면 이동 (허용 호스트만)
```bash
node scripts/intranet-web.cjs goto --url <URL> [--tab <id>]
```
- 상세 화면 등으로 이동할 때 `links` 결과의 `href`를 사용한다.

### ④ 화면 읽기
```bash
node scripts/intranet-web.cjs read   [--tab <id>] [--max-chars 20000]   # 본문 텍스트
node scripts/intranet-web.cjs tables [--tab <id>] [--index N]          # 표 → {headers, rows}
node scripts/intranet-web.cjs links  [--tab <id>] [--filter 텍스트]     # 링크 목록(허용 호스트만)
```
- 같은 출처의 frame/iframe 내용까지 포함한다(`frame` 필드로 구분).
- 목록 조회는 보통 `tables`가 가장 정확하다. 표가 없으면 `read`를 사용한다.

### ⑤ 로그인 세션으로 API(ajax) 호출 → JSON 결과
```bash
node scripts/intranet-web.cjs apis                                   # config.json 에 등록된 API 목록
node scripts/intranet-web.cjs api-get --url </상대경로 또는 전체 URL> [--tab <id>] [--max-chars N]
```
- 로그인된 탭 안에서 `fetch(..., { credentials: 'include' })`로 **GET만** 호출하므로 SSO 세션 쿠키가 자동으로 붙는다(쿠키 값은 반환하지 않음).
- 상대 경로(`/api/list?page=1`)는 열려 있는 서비스 화면 주소 기준으로 해석한다. **API와 같은 출처(스킴·호스트·포트)의 화면이 열려 있어야 한다** — 없으면 `goto`로 먼저 연다.
- 응답이 JSON이면 `data.json`, 아니면 `data.text`로 반환한다. EUC-KR 응답도 처리한다.
- 화면 표보다 정확하므로, 등록된 API(`apis`)가 요청에 맞으면 API를 우선 사용한다.
- API 주소는 사용자가 Edge 창에서 F12 → Network → Fetch/XHR로 확인해 `config.json`의 `apis`에 등록한다.

### 권장 흐름
1. `status` → `BROWSER_NOT_RUNNING`이면 사용자에게 SSO 로그인을 안내하고 `open --wait`
2. `LOGIN_REQUIRED`이면 사용자에게 SSO 로그인을 안내하고 `wait-login`
3. `READY`이면 `apis`에 맞는 API가 있으면 `api-get`, 없으면 `tables` / `read` / `links`로 조회. 필요 시 `goto`로 이동 후 다시 조회
4. 결과를 한국어로 요약해 답변

---

## 3. 출력 형식 (Output)

성공/실패와 무관하게 stdout에는 항상 단일 JSON 한 줄만 출력된다.

```json
{"success":true,"data":{"url":"...","title":"게시판 목록","tableCount":1,"tables":[{"index":0,"headers":["번호","제목"],"rows":[["1","장애 보고"]]}]},"message":"표 1개 조회 완료"}
```
```json
{"success":false,"errorCode":"LOGIN_REQUIRED","errorMessage":"SSO 로그인이 필요합니다. ...","errorDetail":null}
```

| errorCode | 의미 / 대응 |
|---|---|
| `LOGIN_REQUIRED` | 사용자에게 Edge 창에서 SSO 로그인 요청(세션 만료 포함) |
| `LOGIN_TIMEOUT` | 대기 시간 안에 로그인되지 않음 — 로그인 후 다시 요청하도록 안내 |
| `API_AUTH_FAILED` / `API_HTTP_ERROR` / `API_REQUEST_FAILED` | API 401·403 / 그 밖의 HTTP 오류 / 호출 실패 |
| `BROWSER_NOT_RUNNING` | `open` 실행 |
| `CONFIG_REQUIRED` | `config.json`의 `allowedHosts` 등록 필요 (사용자에게 안내) |
| `SECURITY_BLOCK` | 허용되지 않은 호스트/스킴, 상태 변경 의심 주소(logout·delete·approve·save 등). **우회 시도 금지** — 사용자에게 사유 안내 |
| `DEBUG_PORT_UNAVAILABLE` | 회사 정책으로 Edge 원격 디버깅이 막혀 있을 수 있음 |
| `UNSUPPORTED_PLATFORM` / `EDGE_NOT_FOUND` / `NODE_UNSUPPORTED` | 실행 환경 문제 |

---

## 4. 보안 원칙 (스킬 코어에서 강제)

- **읽기 전용**: 클릭·입력·폼 제출·쿠키 조회 기능 자체가 없다. 화면 내용은 스킬에 내장된 고정 추출 스크립트로만 읽는다.
- **API는 GET만**: `api-get`은 메서드가 GET으로 고정되어 있고 요청 본문을 보낼 방법이 없다. 허용 호스트·차단 단어 검사가 화면 이동과 똑같이 적용되며, 리다이렉트로 허용 호스트를 벗어나면 차단한다.
- **허용 호스트만**: 이동 대상, 읽기 대상 탭, 이동 후 최종 주소를 모두 `allowedHosts`로 검사한다. 허용 호스트가 아닌 탭(SSO 인증 서버 등)은 주소·제목도 반환하지 않는다.
- **상태 변경 의심 주소 차단**: logout/logoff/signout/delete/remove/approve/save 가 포함된 주소로는 이동하지 않는다.
- **로컬 전용 포트 + 전용 프로필**: 디버깅 포트는 127.0.0.1에만 열리며, 프로필은 `%LOCALAPPDATA%\Kobi\edge-profile`을 사용한다.
