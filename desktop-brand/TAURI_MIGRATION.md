# Kobi Desktop — Tauri 마이그레이션 조사·계획

작성일 2026-09-17. 대상: 현행 Electron 기반 `Kobi-Desktop-x64.exe` →
업스트림 신규 **Tauri 2 셸(`packages/desktop-shell`, desktop-v0.3.0)** 기반으로 전환.

---

## 1. 배경 — 왜 마이그레이션인가

업스트림 `QwenLM/qwen-code`가 데스크톱을 **완전히 재아키텍처**했다.

| 항목 | 구(현 Kobi) | 신(desktop-v0.3.0) |
|---|---|---|
| 패키지 경로 | `packages/desktop` | `packages/desktop-shell` (구 경로 삭제됨) |
| 프레임워크 | Electron | **Tauri 2** (Rust + 시스템 WebView) |
| UI | Electron 렌더러 | 별도 UI 없음 — **Web Shell**을 `qwen serve` 데몬으로 띄워 WebView에 로드 |
| 브랜딩 도구 | `brand-create.ts` (`CRAFT_BRAND`, `electron-builder.generated.yml`) | `brand-create.mjs` (`brand.json` + `tauri.conf.json` 패치) |
| Windows 산출물 | electron-builder NSIS | Tauri NSIS (`*_x64-setup.exe`) |
| 자동 업데이트 | electron 0.0.5 매니페스트 | Tauri updater (서명키 필요) |
| 런타임 번들 | `QWEN_CODE_TARBALL` tgz 주입 | `prepare-runtime.js`가 Node+qwen CLI+web-shell을 `runtime/qwen-code/`에 조립 |

→ 현행 `desktop-brand/build-desktop.sh`(Electron+Wine 경로)는 **신 구조에서 전부 무효**.
`branding.ts`, `electron-builder.yml`, `CRAFT_BRAND`, `QWEN_CODE_TARBALL` 모두 사라짐.

목표 구성: **Tauri Desktop v0.3.0 셸 + Runtime(qwen CLI) v0.24.0 + 내장 Computer Use**.

---

## 2. 신 아키텍처 동작 (desktop-shell README 기준)

1. `npm run build:runtime` (= `scripts/prepare-runtime.js`)가 `runtime/qwen-code/`에:
   - 대상 플랫폼 Node.js 런타임 (nodejs.org에서 다운로드, SHASUMS 검증)
   - 번들된 `qwen` CLI (`lib/cli-entry.js` + 런처 `qwen`/`qwen.cmd`)
   - 빌드된 Web Shell (`lib/web-shell/`)
   를 조립하고 `checksums.json` 생성.
2. `tauri build`가 Rust `src-tauri`를 컴파일하고 `runtime/`을 리소스로 번들 → 설치본 생성.
3. 실행 시 Tauri가 임시 루프백 포트 + 런치별 베어러 토큰으로 `qwen serve` 기동 →
   `/health` 대기 → 같은 데몬이 서빙하는 Web Shell을 네이티브 창에 로드.

산출물 위치: `packages/desktop-shell/src-tauri/target/release/bundle/{nsis,appimage,deb,dmg}/`
(크로스 타깃 시 `src-tauri/target/<triple>/release/bundle/`).

---

## 3. 브랜딩 방식 (신 `brand-create.mjs`)

입력은 `brand.json` 최소 3필드:
```json
{
  "brandId": "kobi",
  "logo": "/abs/path/desktop-brand/icons/logo.png",
  "website": "https://www.kbcard.com",
  "appName": "Kobi",
  "appId": "com.kbcard.kobi",
  "artifactPrefix": "Kobi-Desktop",
  "updaterEndpoints": [],
  "updaterPubkey": ""
}
```
실행:
```bash
node packages/desktop-shell/.agents/skills/desktop-brand-builder/scripts/brand-create.mjs \
  --shell-root <clone>/packages/desktop-shell --config /abs/brand.json
```
스크립트가 하는 일:
1. `src-tauri/tauri.conf.json` 패치: `productName`, `identifier`,
   `bundle.shortDescription`, `plugins.updater.endpoints`.
   `updaterEndpoints=[]`이면 `createUpdaterArtifacts` 해제 + 공식 pubkey 공란화
   (→ 브랜디드 빌드가 공식 업데이트 피드를 절대 폴링하지 않음. **중요**).
2. `npx @tauri-apps/cli icon <logo>`로 전체 아이콘 세트 재생성.
3. `bootstrap/` 시작 UI 문자열/로고 교체.

제약:
- `brandId`는 `^[a-z][a-z0-9-]*$`. 로고는 정사각 ≥1024px PNG 권장.
- **단회성 스크립트**: 이미 패치된 트리에서 재실행 금지(기본 productName 아니면 거부).
  실패 시 clone을 버리고 새로 시작.
- `updaterEndpoints`가 비어 있으면 in-app 자동업데이트 비활성 — 폐쇄망 배포에 오히려 적합.

---

## 4. 핵심 리스크 — 빌드 호스트 (가장 큰 결정 사항)

### 4.1 런타임 번들(Node) 크로스 준비: ✅ 리눅스에서 가능
`prepare-runtime.js`의 `QWEN_DESKTOP_TARGET=x86_64-pc-windows-msvc` →
`node-v<ver>-win-x64.zip`을 받아 `qwen.cmd` 런처 작성. 리눅스에서 문제 없음.
(단, `tar`로 zip 추출 → 리눅스 `tar`가 zip 지원해야 함. GNU tar은 미지원일 수 있어
`bsdtar`/`libarchive` 필요할 수 있음 — 빌드 전 확인 항목.)

### 4.2 Tauri 앱 빌드(Rust+NSIS+WebView): ❌ Linux→Windows 크로스 사실상 불가
- Tauri Windows 타깃은 `x86_64-pc-windows-msvc`가 표준. MSVC 링커는 리눅스에서 불가.
- `x86_64-pc-windows-gnu`는 이론상 가능하나 Tauri **NSIS 번들러 + WebView2 연동이
  리눅스 크로스에서 미지원/취약**. 구 Electron+Wine 경로처럼 안정적이지 않음.
- **결론: Windows 설치본은 Windows 빌드 호스트(또는 Windows CI)에서 빌드해야 한다.**
  이것이 구 대비 가장 큰 변화이며, 기존 "Linux + WineHQ 크로스빌드"
  (메모리 `kobi-desktop-linux-crossbuild`) 노하우는 **폐기**된다.

권장 빌드 호스트 우선순위:
1. **Windows 빌드 PC** (Rust MSVC 툴체인 + WebView2 SDK + NSIS). 가장 깨끗.
2. **GitHub Actions windows-latest** (업스트림 `Desktop Release` 워크플로 참고).
3. (비권장) Linux + `windows-gnu` 실험 — PoC 수준, 프로덕션 부적합.

### 4.3 폐쇄망(air-gap) WebView2 의존
- Tauri Windows 앱은 실행 시 **Edge WebView2 런타임** 필요.
  Windows 11 및 최신 10은 기본 탑재이나, 폐쇄망 구형 이미지엔 없을 수 있음.
- 대응: `tauri.conf.json`의 `bundle.windows.webviewInstallMode`를
  `fixedRuntime`(고정 런타임 동봉) 또는 `offlineInstaller`로 설정 →
  설치본 용량 +100~180MB. 반입 대상 PC WebView2 유무 확인 필수.

### 4.4 Rust 툴체인 신규 도입
- 빌드에 Rust(stable) + cargo 필요. 첫 빌드 시 crate 다운로드(네트워크).
  폐쇄망 빌드면 `cargo vendor`로 crate 사전 확보 필요.

---

## 5. 런타임 버전(v0.24.0) 고정 전략

`prepare-runtime.js`는 CLI를 **현재 체크아웃 소스에서 직접 빌드**한다
(`npm run build -- --cli-only` → `bundle` → `prepare:package`).
desktop-v0.3.0 태그는 2026-09-10 컷 → 그 시점 core CLI는 0.23.x일 수 있음.

**0.24.0 런타임을 보장하려면 택1:**
- (A) `QWEN_CODE_ROOT=<0.24.0 체크아웃>` 환경변수로 런타임 번들 소스를 0.24.0으로 지정
  (README에 명시된 오버라이드). 셸은 v0.3.0, 런타임만 0.24.0 → **목표 구성과 정확히 일치**.
- (B) desktop-shell을 v0.3.0이 아닌, core가 0.24.0인 더 최신 커밋/태그에서 빌드.
  단 셸 버전이 v0.3.0과 달라질 수 있음.

→ **권장: (A)**. "Tauri 셸 v0.3.0 + Runtime 0.24.0"을 깔끔히 분리 달성.

---

## 6. 마이그레이션 작업 계획 (단계별)

### Phase 0 — 사전 확보
- [ ] Windows 빌드 호스트 확보 (or GitHub Actions windows-latest 사용 결정)
- [ ] Rust stable + `@tauri-apps/cli` + NSIS + (필요시) WebView2 fixed runtime
- [ ] Kobi 로고 `desktop-brand/icons/logo.png` (≥1024² PNG) 재확인
- [ ] 반입 대상 PC의 WebView2 탑재 여부 조사 → `webviewInstallMode` 결정

### Phase 1 — 신 빌드 스크립트 작성 (구 build-desktop.sh 대체)
- [x] §6-quater 결정에 따라 셸 스크립트 대신 **`.github/workflows/build-desktop-tauri.yml`**
      (GitHub Actions, `windows-latest`)로 구현 — 원래 계획한 6단계(clone → brand-create.mjs
      → npm install → 빌드 → rename → sha256)를 CI 스텝으로 그대로 수행, 2026-09-21 검증 완료.
      `QWEN_CODE_ROOT` 오버라이드는 불필요(§6-quater: `desktop-v0.24.0` 태그 자체가
      CLI 0.24.0과 일치).
- [x] `webviewInstallMode`: `offlineInstaller`로 주입(워크플로 내 스텝). `fixedRuntime`은
      보류(§6-quater 참고).
- [ ] 구 `build-desktop.sh`/`build-desktop-offline.sh`는 그대로 보존(Electron 재사용
      가능성 대비) — 삭제/이동은 보류.

### Phase 2 — 패키징 연동
- [x] 산출물 파일명을 워크플로에서 `Kobi-Desktop-x64.exe`로 rename하는 스텝을 넣어
      `make.sh`/`Install-Kobi.ps1`/`.gitignore`를 전혀 안 건드려도 되게 함.
- [ ] `windows-gui` 플로우가 신 산출물과 실제로 맞물리는지는 아직 미검증(아래 Phase 3와 동일 사유).

### Phase 3 — 검증
- [ ] 실제 Windows(가능하면 폐쇄망 유사 이미지)에서 설치·실행
- [ ] 창 제목/About/아이콘이 "Kobi"인지, `qwen serve`가 내부 vLLM에 붙는지
- [ ] Computer Use 동작 (0.24.0 내장) 확인
- [ ] WebView2 없는 PC에서 실행 실패/성공 확인 → 번들 정책 확정
- [ ] `session_transcript_changed` 관련(메모리 `kobi-session-transcript-changed`)
      로컬 폴더 사용 가이드 여전히 유효한지 재확인

### Phase 4 — 문서·마무리
- [ ] `desktop-brand/README.md` 신 절차로 갱신 (Electron/Wine 서술 제거)
- [ ] 새 설치본 zip 재패키징 (`make.sh windows` / `windows-gui`)
- [ ] 메모리 `kobi-desktop-linux-crossbuild` 갱신(Wine 크로스빌드 폐기 → Windows 호스트)

---

## 6-bis. 결정 사항 (2026-09-17 확정) — ⚠️ 2026-09-21 §6-quater로 대체됨

- **빌드 호스트: Windows 빌드 PC** (사내). 단 **일부 사이트 접근 제한/사내 TLS 인터셉트
  가능성** → §6-ter의 네트워크 프리플라이트가 이 계획의 최대 실무 리스크.
- **WebView2: 먼저 조사** (Phase 0 항목 유지). 결과에 따라 온라인 부트스트랩 vs
  `fixedRuntime` 동봉 결정.
- 런타임 0.24.0 고정: (A) `QWEN_CODE_ROOT` 오버라이드 채택.
- 자동업데이트: `updaterEndpoints=[]` 유지.
- 셸 버전: `desktop-v0.3.0` 태그 고정.

## 6-quater. 결정 번복 — public GitHub Actions 채택 (2026-09-21)

**빌드 호스트를 사내 Windows PC → `windows-latest` GitHub Actions(공개 저장소
`cuphana7/kobi-ai-agent`)로 변경한다.** §6-bis의 "사내 PC" 결정을 번복.

- **검증 완료**: `.github/workflows/build-desktop-tauri.yml`로 end-to-end 2회 빌드
  시도 끝에 실제 `Kobi-Desktop-x64.exe` 산출 확인(첫 시도는 brand.json JSON 이스케이프
  버그, 두 번째는 `shell: bash`에서 MSYS `tar`가 Windows 기본 tar.exe를 가리는 버그로
  실패 → 둘 다 수정 후 3회차 성공, 총 25분). 상세는 워크플로 파일 주석 참고.
- **셸 태그를 `desktop-v0.3.0` → `desktop-v0.24.0`으로 변경**: `desktop-v0.24.0`
  태그의 `packages/cli` 자체 버전이 정확히 0.24.0이라, §5에서 논의한
  `QWEN_CODE_ROOT` 오버라이드(셸 v0.3.0 + 런타임만 0.24.0로 분리 지정) 없이도
  "셸 버전 = 런타임 CLI 버전"이 자연히 일치한다. 현재 `Kobi_Installer/assets/pkg`의
  pinned CLI(0.24.0)와도 그대로 맞음 — CLI를 올릴 때마다 매칭되는 `desktop-v*` 태그를
  다시 확인할 것.
- **WebView2**: `offlineInstaller`로 결정(§4.3의 두 옵션 중 더 가벼운 쪽, +127MB).
  `fixedRuntime`(+180MB)은 대상 이미지에 WebView2가 전혀 없다고 확인되면 전환 검토.
- 자동업데이트: 기존 결정대로 `updaterEndpoints=[]` 유지(브랜디드 빌드가 공식
  업데이트 피드를 절대 폴링하지 않음).
- **공개 저장소 노출 트레이드오프**: 이 방식은 빌드 로그와 아티팩트가 (저장소가
  public이므로) 일정 기간 외부에 노출된다 — `kbcard.com` 도메인 문자열, "Kobi"
  브랜딩/로고 정도가 노출 범위. 민감도는 낮다고 판단해 승인됨.
- §6-ter(네트워크 프리플라이트)·`preflight-network.sh`·`prefetch-offline-bundle.sh`는
  **사내 PC 경로를 다시 쓰게 될 경우를 위한 참고 자료로 보존**한다(현재는 미사용).

## 6-ter. 네트워크 제약 Windows 빌드 — 외부 다운로드 지점 (최우선 점검)

사내 Windows PC는 **제한 사이트/SSL 인터셉트**가 있으므로, Tauri 빌드가 건드리는
아웃바운드를 사전에 전부 뚫거나 오프라인 캐시로 대체해야 한다. 하나라도 막히면 빌드 실패.

| # | 단계 | 접속 대상 | 막힐 때 대응 |
|---|---|---|---|
| 1 | 소스 확보 | `github.com` (git clone) | 브라우저로 소스 zip 받아 드롭(구 offline 방식) |
| 2 | `npm install` (root+shell) | `registry.npmjs.org` | 사내 npm 미러 or `npm-cache`/`npm-seed` 재사용 + `NODE_EXTRA_CA_CERTS`(사내 CA) |
| 3 | `build:runtime` Node 다운로드 | `nodejs.org` (`node-v*-win-x64.zip`+SHASUMS) | `QWEN_DESKTOP_NODE_CACHE_DIR`에 사전 배치 |
| 4 | `brand-create.mjs` 아이콘 | `npx @tauri-apps/cli` (이미 devDep) | 캐시된 CLI 사용, 안 되면 로고 수동 복사 |
| 5 | **`tauri build` — cargo crate** | `crates.io` / `static.crates.io` | **`cargo vendor` + `.cargo/config.toml`**로 오프라인 벤더링 |
| 6 | **`tauri build` — NSIS 번들러** | `github.com` (Tauri가 NSIS/plugins를 `%LOCALAPPDATA%\tauri`로 자동 다운로드) | **가장 잘 막히는 지점.** 온라인 PC에서 1회 빌드해 `%LOCALAPPDATA%\tauri` 캐시를 그대로 반입 |
| 7 | WebView2 (fixedRuntime 선택 시) | `go.microsoft.com` (Evergreen 부트스트랩/고정런타임) | 고정 런타임 cab을 수동 다운로드해 `src-tauri` 리소스로 지정 |

**프리플라이트 스크립트**: `desktop-brand/preflight-network.sh` (작성 완료).
위 다운로드 호스트들에 대해 HTTP 도달성 + TLS 발급자(사내 MITM 탐지)를 실측하고,
막힌 항목별 대응을 출력한다. 사내 Windows PC(Git Bash)와 인터넷 Linux 양쪽에서 동작.
```bash
./desktop-brand/preflight-network.sh                          # 전체 점검
NODE_EXTRA_CA_CERTS=/path/corp-ca.pem ./desktop-brand/preflight-network.sh  # 사내 CA
```
막힌 항목만 오프라인 캐시로 전환. 특히 **#5 crates, #6 Tauri NSIS 캐시**가 핵심 실패점.

권장 순서: 먼저 **인터넷 되는 PC(또는 Cloud)에서 1회 풀빌드**하여
(a) `cargo vendor` 산출물, (b) `%LOCALAPPDATA%\tauri` NSIS 캐시,
(c) Node 캐시, (d) npm 캐시를 확보 → 사내 Windows PC로 반입해 **오프라인 빌드**.

**프리페치 스크립트**: `desktop-brand/prefetch-offline-bundle.sh` (작성 완료).
인터넷 Linux에서 실행하면 source(desktop-v0.3.0) · npm 캐시(전 플랫폼 optional 포함,
lockfile의 name@version 2013개) · Windows용 Node(zip+체크섬) · cargo vendor ·
rustup-init.exe 를 한 폴더에 모아 `kobi-desktop-offline-bundle_*.tar.gz` 로 묶고,
`BUILD-ON-WINDOWS.md`(오프라인 빌드 절차) · `brand.json.example` 을 생성한다.
```bash
./desktop-brand/prefetch-offline-bundle.sh                 # 전체
./desktop-brand/prefetch-offline-bundle.sh --install-rust  # cargo 없으면 rustup 부트스트랩
```
단, (b) **Tauri NSIS 캐시와 최종 .exe 는 Windows 에서만** 생성(MSVC 링킹) — 이 번들은
그 Windows 오프라인 빌드의 "입력"을 채운다. NSIS 는 Windows 첫 빌드가 github 에서 받거나,
막혔으면 온라인 Windows 1회 빌드로 `%LOCALAPPDATA%\tauri` 를 확보해 반입.

## 7. 남은 조사/의사결정 항목

1. **WebView2**(Phase 0): 대상 PC 이미지에 런타임 존재? → 부트스트랩 vs `fixedRuntime`.
2. **네트워크 프리플라이트**(§6-ter): 사내 Windows PC에서 7개 호스트 접근성 실측.
3. **사내 CA 번들** 경로 확보(`NODE_EXTRA_CA_CERTS`, cargo/git `http.sslCAInfo`).

---

## 8. 요약

- 구조가 Electron→Tauri로 근본 변경 → **구 크로스빌드 스크립트/노하우 폐기**.
- **가장 큰 제약: Windows 설치본은 Windows 호스트/CI에서 빌드**(Linux+Wine 경로 종료).
- 런타임 Node 준비는 리눅스에서도 가능하나 Tauri Rust/NSIS/WebView 빌드가 발목.
- "Tauri v0.3.0 셸 + Runtime 0.24.0"은 `QWEN_CODE_ROOT` 오버라이드로 깔끔히 달성 가능.
- 폐쇄망 반입은 **WebView2 번들 + (필요시) cargo vendor** 두 가지 신규 고려사항 추가.
