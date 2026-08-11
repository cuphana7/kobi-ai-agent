# KB AI Assistant (Kobi) 오프라인 설치 패키지

본 패키지는 사내 보안망(내부망) 환경의 Windows 개발 PC에서 외부 네트워크 연결 없이 **KB AI Assistant**(`kobi`)를 로컬에 설치하고 사용할 수 있도록 구성된 오프라인 전용 배포 패키지입니다.

이 도구는 대규모 언어 모델(LLM)인 **Qwen3-Next-80B-A3B-Instruct** 기반의 사내 자체 API 서비스와 연동하여 개발자의 소스 코드 분석, 리팩토링, 장애 진단 및 개발 생산성 향상을 안전하고 효율적으로 지원합니다.

---

## 1. 패키지 주요 특징

- **100% 무설치 포터블(Portable) 구동**: 런타임(Node.js)과 의존성 라이브러리(Qwen Code)가 빌드 단계에서 이미 완벽하게 설치 및 추출되어 있어, 별도의 압축 해제나 오프라인 캐시 빌드 없이 즉시 압축만 풀어 포터블 형태로 가동됩니다.
- **초고속 및 높은 신뢰성**: 클라이언트 PC에서 NPM 패키지 설치나 ZIP 압축 해제 단계를 완전히 제거하여 실패율 0%의 단순하고 안정적인 연동을 자랑합니다.
- **사내 전용 LLM 서버 연동**: 사내망 전용 고성능 AI 모델 서버(`http://10.210.169.48:8103`)와 기본 연동하도록 사전 설정되어 있습니다.
- **안전한 보안 및 차단 정책**: 
  - 인증서 및 키 파일(`*.jks`, `*.p12`, `*.pem`, `*.key`), 비밀번호, `.env` 파일 등 민감한 자산 조회를 원천 차단합니다.
  - 시스템 손상을 야기할 수 있는 위험 명령어(`git push`, `del`, `rm`, `format` 등)의 실행을 자동 차단합니다.
  - 소스 코드 변경 시 개발자에게 사전에 수정 계획을 명확히 제시하고 동의를 구하는 검토 및 승인 장치(Approval Mode)가 내장되어 있습니다.
- **한국어 우선주의**: 사내 개발 환경에 최적화된 프롬프트 엔진 및 한국어 기본 응답 지침이 탑재되어 있습니다.

---

## 2. 패키지 구성 요소

배포 패키지는 다음과 같이 구성되어 있습니다.

```
kobi-package/
├── Kobi_Installer_v[버전].zip        # 배포용 전체 설치 압축 파일 (예: Kobi_Installer_v20260702_0205.zip)
├── Kobi_Installer_v[버전].zip.sha256 # 압축 파일 무결성 확인용 SHA-256 체크섬
├── make.sh                     # [배포관리자용] 패키징 빌드 스크립트
└── Kobi_Installer/           # 설치 원본 폴더 (추출용)
    ├── Install-Kobi.cmd      # 설치 실행 배치 파일 (원클릭 실행)
    ├── Install-Kobi.ps1      # 파워셸 기반 핵심 설치 스크립트
    ├── Uninstall-Kobi.cmd    # 삭제 실행 배치 파일 (원클릭 삭제)
    ├── Uninstall-Kobi.ps1    # 파워셸 기반 삭제 스크립트
    ├── assets/                 # 필수 자원 폴더
    │   ├── jennifer-monitor.skill # 제니퍼 APM 모니터링 스킬 파일
    │   ├── project-bootstrap.skill # 프로젝트 부트스트랩 스킬 파일
    │   ├── frism-cm.skill      # Frism 형상관리 연동 스킬 파일
    │   ├── office-edit.skill   # Office(Excel/Word) 파일 읽기/수정 스킬 파일
    │   └── computer-use/       # Computer Use(화면 읽기 전용) 드라이버 자산
    │       └── cua-driver-rs-0.5.2-windows-x86_64.zip
    └── Kobi_Runtime/           # [빌드 시 자동생성] 사전 구축된 무설치 런타임 폴더
        ├── node/               # 사전 추출된 포터블 Node.js 런타임
        ├── qwen/               # 사전 빌드된 Qwen Code 에이전트 및 의존성
        ├── config/             # 사내 환경설정(settings.json) 및 지침(QWEN.md)
        └── bin/                # 실행 커맨드(kobi.cmd, kobi.ps1) 래퍼 폴더
```

> **Linux 배포판**은 별도의 `Kobi_Installer_linux_v[버전].tar.gz`로 산출되며, 위 구조에서 다음이 달라집니다.
> - 설치/삭제 스크립트가 `install.sh` / `uninstall.sh` (bash)로 대체
> - `Kobi_Runtime/node/`가 리눅스 포터블 Node.js, `Kobi_Runtime/bin/`에 bash 런처 `kobi` 포함
> - `assets/computer-use/` 드라이버 미포함(리눅스 미지원)

---

## 3. 설치 전 요구사항

### Windows
- **운영체제**: Windows 10 / 11 (64-bit)
- **실행 권한**: 일반 사용자 권한으로 설치 가능 (시스템 전역 설정을 건드리지 않고 환경 변수 및 홈 경로 설정만 변경하므로 관리자 권한이 불필요합니다)
- **PowerShell 설정**: PowerShell v5.1 이상 지원 (Windows 기본 탑재)

### Linux
- **운영체제**: x86_64(64-bit) glibc 기반 배포판 (예: Ubuntu, RHEL/Rocky, Debian 등). ※ Alpine 등 musl 기반 배포판은 미지원입니다.
- **실행 권한**: 일반 사용자 권한으로 설치 가능 (홈 디렉터리 `~/.qwen`, `~/.local/bin` 및 셸 설정 파일만 변경하므로 root 권한이 불필요합니다)
- **필수 도구**: `bash`, `tar`, `unzip`(또는 `bsdtar`), `curl` (대부분의 배포판 기본 탑재)
- **참고**: Linux 배포판에서는 Computer Use(화면 읽기) 기능이 제공되지 않습니다(8장 참고).

---

## 4. 설치 가이드 (Installation)

### Windows

1. 배포받은 **`Kobi_Installer_v[버전].zip`** (예: `Kobi_Installer_v20260702_0205.zip`) 파일의 압축을 로컬 드라이브(예: `C:\Temp` 또는 `D:\Download` 등 **원하는 보존 위치**)에 해제합니다.
2. 압축이 해제된 폴더 내부로 이동하여 **`Install-Kobi.cmd`** 파일을 마우스 더블클릭으로 실행합니다.
3. 자동으로 PowerShell 창이 열리며 다음과 같이 총 5단계의 무설치 연동 작업이 실행됩니다.
   - **[1/5] 기존 실행 중인 Kobi 프로세스 종료 및 정리**
   - **[2/5] 사용자 설정, 모니터링 스킬 및 Computer Use 드라이버 배포** (`~/.qwen/` 폴더에 QWEN.md, 스킬, Computer Use 드라이버 연동)
   - **[3/5] Kobi Desktop용 사용자 설정 구성** (`~/.qwen/settings.json`에 사내 vLLM 연결 정보 병합; GUI가 읽는 표준 설정)
   - **[4/5] Kobi Desktop(GUI) 설치** (설치물이 패키지에 있을 때만 무인 설치, 없으면 CLI 전용으로 건너뜀)
   - **[5/5] 사용자 환경 변수 `Path`에 kobi 실행 경로 등록** (압축 해제된 폴더 내 `Kobi_Runtime\bin` 경로 등록)
4. 최종 구동 상태와 버전 검증 결과가 성공적으로 출력되고 아무 키나 누르면 설치 창이 닫힙니다.

### Linux

1. 배포받은 **`Kobi_Installer_linux_v[버전].tar.gz`** 파일을 원하는 보존 위치(예: `~/tools`)에 해제합니다.
   ```bash
   mkdir -p ~/tools && tar -xzf Kobi_Installer_linux_v[버전].tar.gz -C ~/tools
   cd ~/tools/Kobi_Installer_linux
   ```
2. 설치 스크립트를 실행합니다.
   ```bash
   ./install.sh
   ```
   총 3단계로 다음 작업이 자동 수행됩니다.
   - **[1/3] 기존 실행 중인 Kobi 관련 프로세스 종료 및 정리**
   - **[2/3] 사용자 설정 및 스킬 배포** (`~/.qwen/`에 QWEN.md 및 스킬 연동. Computer Use 드라이버는 리눅스 미제공)
   - **[3/3] kobi 실행 경로 등록** (`~/.local/bin/kobi` 심볼릭 링크 생성 및 필요 시 `~/.profile`·`~/.bashrc`에 PATH 반영)
3. 버전 검증 결과가 출력되면 설치가 완료됩니다. **새 터미널을 열거나 `source ~/.profile`** 로 PATH를 반영한 뒤 `kobi`를 사용합니다.

> ⚠️ 본 패키지는 허가된 사용자만 설치할 수 있도록 `install.sh` 상단의 `ALLOWED_USERS` 계정 목록으로 설치를 제한합니다. 리눅스 로그인 계정 기준이므로, 배포 관리자는 배포 전 실제 허용 계정으로 목록을 갱신해야 합니다.

---

## 5. 사용 가이드 (Usage)

설치가 완료되면 환경 변수 설정을 반영하기 위해 **새로운 PowerShell 창**을 실행해 주세요.

### 기본 실행 방법
1. 개발 중인 프로젝트 폴더(예: Java/Spring, Node.js 등)로 이동합니다.
   ```powershell
   cd C:\work\my-java-project
   ```
2. 터미널에 `kobi`를 입력하여 AI 개발 도우미를 호출합니다.
   ```powershell
   kobi
   ```
3. 대화형 CLI 모드가 실행되면 질문이나 요구사항을 한국어로 자유롭게 입력하여 AI와 소통할 수 있습니다.

### 유용한 기능 및 팁
- **클립보드를 통한 긴 프롬프트 실행**: 사내 메신저나 메모장에서 작성한 길고 세밀한 지침을 클립보드에 복사(`Ctrl+C`)한 뒤 아래 명령어를 입력하면 간편하게 실행할 수 있습니다.
  ```powershell
  kobi -p (Get-Clipboard)
  ```

### Kobi Desktop (GUI) — 선택 사항
CLI(`kobi`)에 더해, 터미널이 익숙하지 않은 사용자를 위한 **그래픽 데스크톱 앱(Kobi Desktop)**을 함께 배포할 수 있습니다.

- **동시 설치**: 배포 패키지에 Desktop 설치물(`assets/desktop/Kobi-Desktop-x64.exe`)이 포함되어 있으면, `Install-Kobi.cmd` 실행 시 CLI와 함께 **무인 설치**됩니다(per-user 설치라 관리자 권한 불필요). 설치 후 **시작 메뉴에서 "Kobi"**를 실행하면 됩니다.
- **사내 vLLM 사전 연결**: 설치기가 `~/.qwen/settings.json`에 사내 vLLM 연결 정보를 구성하므로, Desktop 최초 실행부터 바로 사내 모델로 대화할 수 있습니다. CLI와 동일한 스킬/지침(`~/.qwen/skills`, `QWEN.md`)도 그대로 공유됩니다.
- **포터블 git 자동 포함**: qwen-code 런타임(CLI·Desktop 공용)은 `git`에 의존하며, git이 없는 PC에서는 특히 Desktop 실행이 실패합니다. 이를 위해 패키지에 **MinGit**(Git for Windows 최소 번들판)을 함께 넣어 `Kobi_Runtime\git`으로 추출하고 설치 시 `git\cmd`를 PATH에 등록합니다. 별도 git 설치가 필요 없습니다. (빌드 시 `Kobi_Installer/assets/`에 `MinGit-*-64-bit.zip`을 넣어두어야 포함됩니다.)
- **CLI 전용 배포**: Desktop 설치물이 패키지에 없으면 기존과 동일하게 **CLI 전용**으로 설치됩니다(경고 없이 건너뜀).
- **자동 업데이트**: 폐쇄망 환경이므로 앱 자체 자동 업데이트는 동작하지 않습니다(정상).
- **API 키 주의**: 사내 vLLM에 키 인증이 켜지면, CLI는 실행 시 자동으로 키를 저장하지만 **Desktop은 별도로** GUI 설정 또는 `~/.qwen/settings.json`에 키를 반영해야 할 수 있습니다.

> Desktop 설치물은 별도 빌드 산출물입니다. "Kobi"로 리브랜딩한 설치물을 만드는 방법은 [`desktop-brand/README.md`](desktop-brand/README.md)를 참고하세요(인터넷 되는 빌드 PC에서 `desktop-brand/build-desktop.sh` 실행 → `assets/desktop/`에 산출 → `make.sh windows`로 패키징).

---

## 6. 제니퍼 APM 모니터링 스킬 (Jennifer APM Monitoring Skill)

본 배포 패키지에는 APM 솔루션인 Jennifer 5 OpenAPI를 활용하여 제니퍼에 등록된 전체 서비스 도메인(**KB Pay** 등)의 정상 동작 상태를 점검하고 모니터링할 수 있는 전용 스킬이 탑재되어 있습니다.

- **스킬 파일**: `Kobi_Installer/assets/jennifer-monitor.skill`
- **자동 탑재**: 
  - 본 패키지는 설치 스크립트 실행 시 **자동으로 제니퍼 APM 모니터링 스킬의 압축을 해제하고 홈 프로필(`~/.qwen/skills/jennifer-monitor`)에 사전 연동**합니다.
  - 따라서 사용자는 별도의 번거로운 스킬 설치 명령어 없이, `kobi`를 실행하여 즉시 모니터링 스킬의 강력한 어시스트를 활용할 수 있습니다.
- **핵심 탑재 기능**:
  - 제니퍼 뷰 서버 연결 상태 및 인증 토큰 무결성 검증
  - 서비스 응답지연(Blue/Green/Orange/Red) 판단 임계치 조회
  - 도메인별 예외 에러 감지 정책 및 조치 스크립트 설정 상태 파악
  - JVM Heap 사용량, 요청수, 처리 속도 등의 성능 메트릭 확인
  - SQL 질의, HTTP 요청 모니터링을 통한 실시간 액티브 트랜잭션 추적

---

## 7. Frism 형상관리시스템(CM) 연동 스킬 (Frism CM Integration Skill)

본 배포 패키지에는 사내 표준 형상관리 솔루션인 Frism CM 연동 스킬이 기본 탑재되어 있어, AI와 대화하며 소스 코드 파일을 체크아웃/체크인하거나 변경 이력 버전을 검색하고, 원클릭 배포 반영을 신청할 수 있습니다.

- **스킬 파일**: `Kobi_Installer/assets/frism-cm.skill`
- **자동 탑재**: 
  - 본 패키지는 설치 스크립트 실행 시 **자동으로 Frism CM 연동 스킬의 압축을 해제하고 홈 프로필(`~/.qwen/skills/frism-cm`)에 사전 연동**합니다.
- **핵심 탑재 기능**:
  - 사용자 인증 및 연결 상태 검증 (`connect`)
  - CM 패키지 조회 및 자동 생성 (`get-cm`, `get-cm-list`)
  - 소스 자원 체크아웃 및 잠금 (`check-out`)
  - 소스 자원 체크인 반영 (`check-in`)
  - 체크아웃 취소 및 잠금 해제 (`check-out-cancel`)
  - 파일 변경 이력 버전 조회 (`get-versions`) 및 특정 버전 코드 다운로드 (`download-resource`)
  - 스테이지(테스트) 환경 배포/반영 처리 신청 (`deploy-stage`) (※ 운영 환경 반영 기능은 사내 보안 정책상 차단)

---

## 8. Computer Use 화면 읽기 기능 (Read-only Screen Awareness)

본 배포 패키지는 Qwen Code에 내장된 Computer Use 기능을 **화면 읽기 전용**으로 제한하여 탑재합니다. 개발자가 열어둔 로그/에러창/실행결과 등 화면에 보이는 정보를 AI가 텍스트로 읽어 분석을 보조하는 용도이며, 마우스/키보드로 PC를 직접 조작하는 기능이 아닙니다.

> ℹ️ **본 기능은 Windows 배포판에서만 제공됩니다.** 리눅스 배포판에는 cua-driver 바이너리가 포함되지 않으며, 리눅스용 `settings.json`에서 `tools.computerUse.enabled`가 `false`로 설정되어 기능이 비활성화됩니다.

- **드라이버 자산**: `Kobi_Installer/assets/computer-use/cua-driver-rs-0.5.2-windows-x86_64.zip`
- **자동 배치**: 설치 스크립트 실행 시 SHA-256 체크섬을 검증한 뒤 홈 프로필(`~/.qwen/computer-use/`)에 압축을 해제합니다. 드라이버가 이미 해당 경로에 존재하면 Qwen Code는 외부망으로 추가 다운로드를 시도하지 않습니다.
- **텍스트 기반 화면 읽기**: 연동된 사내 LLM(Qwen3-Next-80B-A3B-Instruct, vLLM 서빙)은 이미지(비전) 입력을 지원하지 않으므로, 스크린샷(PNG) 캡처 대신 `get_window_state`를 `mode: "ax"`로 호출해 화면 UI를 **Markdown 텍스트 트리**로 읽도록 `QWEN.md`에 지침이 내재화되어 있습니다.
- **조작 기능 차단**: `settings.json`의 `permissions.deny`에서 `click`, `double_click`, `drag`, `type_text`, `press_key`, `hotkey`, `scroll`, `launch_app`, `kill_app` 등 PC를 직접 조작하는 모든 Computer Use 툴을 차단합니다. `list_windows`, `list_apps`, `get_accessibility_tree`, `get_screen_size` 등 읽기 전용 조회 툴만 허용됩니다.
- **민감정보 인용 정책**: 본 배포본은 내부망 전용 단일 사용자 PC(실제 사용자 본인만 접근 가능한 업무 PC)에서 구동됨을 전제로 합니다. 이에 따라 메신저 쪽지, 알림 팝업 등 **개인 알림/메시지 내용**은 화면에 보이는 그대로 인용하여 분석을 보조합니다. 다만 인증서, 비밀번호, API 키, OTP/인증코드 등 **자격증명 정보**는 화면에서 조회되더라도 원문 그대로 인용하지 않으며 마스킹하거나 존재 여부만 언급합니다. (`QWEN.md`에 지침 내재화)
- **개별 승인 필수**: 차단되지 않은 읽기 전용 툴도 Qwen Code의 기본 정책에 따라 호출 시마다 사용자 승인(Approval) 대화상자가 노출됩니다.
- ⚠️ 본 기능 활성화는 사내 보안팀 검토 및 승인을 거쳤습니다. 배포 범위를 조작 기능까지 확장하려는 경우 반드시 보안팀 재검토가 필요합니다.

---

## 9. Office(Excel/Word) 파일 편집 스킬 (Office Edit Skill)

본 배포 패키지에는 Office가 설치되어 있지 않은 PC에서도 순수 Node.js 라이브러리만으로 Excel(`.xlsx`)과 Word(`.docx`) 파일을 읽고, 부분 수정하고, 백지 상태에서 새로 만들고, 템플릿 기반으로 채워 생성할 수 있는 전용 스킬이 탑재되어 있습니다.

- **스킬 파일**: `Kobi_Installer/assets/office-edit.skill`
- **자동 탑재**:
  - 본 패키지는 설치 스크립트 실행 시 **자동으로 Office 편집 스킬의 압축을 해제하고 홈 프로필(`~/.qwen/skills/office-edit`)에 사전 연동**합니다.
  - 필요한 라이브러리(exceljs, mammoth, docxtemplater, pizzip, docx)가 스킬 폴더 내부에 이미 포함되어 있어(오프라인 자가수용형 구조) 별도 설치나 네트워크 연결이 필요 없습니다.
- **핵심 탑재 기능**:
  - Excel 시트/셀 내용 조회 (`read-xlsx`)
  - Excel 특정 셀 값만 부분 수정, 기존 서식 유지 (`edit-xlsx`)
  - Word 문서 내용 텍스트/마크다운 추출 (`read-docx`)
  - Word 문서 내 특정 문구 치환, 기존 서식 유지 (`edit-docx`)
  - 보고서 등 템플릿에 데이터를 채워 새 Excel/Word 파일 생성 (`fill-template`)
  - 양식 없이 제목/표/문단 구조를 지정해 완전히 새로운 Excel 파일 생성 (`create-xlsx`)
  - 양식 없이 제목/표/문단 구조를 지정해 완전히 새로운 Word 문서 생성 (`create-docx`)
- **안전 원칙**: `--in-place`를 명시하지 않는 한 원본 파일을 덮어쓰지 않고 항상 새 파일로 저장하며, `create-xlsx`/`create-docx`는 `--force` 없이는 기존 파일을 덮어쓰지 않습니다.

---

## 10. 개발 지침 및 보안 정책 (Security & Guardrails)

KB AI Code Assistant는 사내 보안 지침을 철저히 준수하도록 기본 동작이 고정되어 있습니다.

### 주요 보안 설정 (`settings.json`)
- **WebFetch 차단**: AI 에이전트가 외부 웹 URL의 데이터를 수집하거나 외부망으로 통신을 시도하는 것을 원천 차단합니다.
- **민감 파일 접근 불가**: `.jks`, `.p12`, `.key`, `.pem`, `.env` 등의 확장자를 갖는 암호키, 인증서, 기밀 정보 파일을 AI가 절대 읽거나 수정할 수 없도록 사전에 차단 정책이 걸려 있습니다.
- **파괴적/수정 명령어 차단**: 터미널을 통해 소스를 삭제하거나 원격 저장소에 반영할 수 있는 명령어(`git push`, `del`, `rm`, `format`)는 에이전트 판단으로 실행할 수 없습니다.

### 사내 기본 동작 지침 (`QWEN.md`)
- **한국어 답변**: 모든 지침과 분석 결과, 코드 가이드는 개발자가 한눈에 파악할 수 있도록 친절한 한국어로 출력됩니다.
- **상호 작용 보조**: AI가 단독으로 코드를 편집하지 않으며, 수정이 필요할 경우 항상 **수정 계획**을 사전에 명확히 제시하고 개발자의 검토 후 동의를 얻습니다.
- **개발 단순화 및 코드 최적화 (Ponytail 원칙)**: 불필요한 오버엔지니어링을 배제(YAGNI)하고 JDK 표준 라이브러리 및 프로젝트 내 기존 의존성을 우선 활용하되, 사내 공통 보안 및 아키텍처 가이드를 완벽히 준수하고 가독성이 극대화된 코드를 작성합니다.
- **Java 프로젝트 최적화**: 사내 Java 프로젝트 분석 시 가독성과 신뢰성을 극대화하기 위해 `Controller ➔ Service ➔ Repository/Mapper ➔ XML SQL ➔ 설정파일` 흐름의 계층별 추적 모델을 적용합니다.

---

## 11. 삭제 가이드 (Uninstallation)

이 도구는 설치 시 사용자 시스템의 레지스트리나 전체 시스템 영역을 변경하지 않고, 개발자가 임의로 추출해 둔 폴더 구조 그대로(`Kobi_Runtime`) 가동되며, 단지 사용자 프로필(`~\.qwen`) 내부의 일부 캐시 및 스킬 파일만 가집니다.

도구를 더 이상 사용하지 않아 깨끗이 제거하고 싶다면 아래 단계를 따릅니다.

1. 압축 해제했던 폴더 내부의 **`Uninstall-Kobi.cmd`** 파일을 마우스 더블클릭으로 실행합니다.
2. 실행 시 자동으로 다음 항목이 영구 삭제됩니다.
   - 사용자 환경 변수 `Path`에서 Kobi 실행 경로(`Kobi_Runtime\bin`) 자동 분리 및 정리
   - 사용자 홈 디렉토리 내부의 `~/.qwen` 설정, 스킬 폴더 및 Computer Use 드라이버(`~/.qwen/computer-use`) 삭제
3. 이후 압축을 풀었던 원본 폴더 자체를 휴지통에 버리면 완전히 안전하게 제거됩니다.

---

## 12. 패키지 변경 이력 (Changelog)

| 버전 | 변경 일자 | 변경 구분 | 상세 변경 내용 | 작업자 |
| :--- | :--- | :--- | :--- | :--- |
| **v20260811** | 2026-08-11 | 기능 추가 (GUI 확장) | - **Kobi Desktop(GUI) 오프라인 번들 통합 (Windows)** — CLI(`kobi`)에 더해 그래픽 데스크톱 앱을 함께 배포<br>- 공식 Qwen Code Desktop(Electron, Apache-2.0)을 **"Kobi"로 리브랜딩**하는 빌드 도구 신설(`desktop-brand/build-desktop.sh` + `electron-builder`/`branding.ts`/아이콘 오버라이드) — 내장 CLI 런타임은 `QWEN_CODE_TARBALL`로 CLI와 동일한 qwen-code 0.21.0 tarball vendoring<br>- `make.sh`: Desktop 설치물(`Kobi-Desktop-*.exe`) 있을 때만 배포 zip에 포함, 포터블 **MinGit**(`MinGit-*-64-bit.zip`)을 `Kobi_Runtime\git`으로 추출(qwen-code 런타임의 git 의존성 대응 — git 없는 PC에서 Desktop 실행 실패 방지)<br>- `Install-Kobi.ps1`: 설치 5단계로 확장 — Desktop이 읽는 `~/.qwen/settings.json`에 사내 vLLM 연결 정보 병합(`ui.*` 제외, 기존 키 보존), Desktop 무인 설치(`/S`, per-user, 관리자 불필요), 번들 `git\cmd`를 User PATH에 등록(Desktop·CLI 공용)<br>- `Uninstall-Kobi.ps1`: HKCU/HKLM 레지스트리 기반 Desktop 무인 제거 및 git/settings 정리 추가<br>- README에 Desktop 사용 가이드 및 리브랜딩 빌드 절차 추가<br>- ⚠️ 선행 검증 필요: GUI가 커스텀 OpenAI 호환(사내 vLLM) 공급자를 존중하는지 인터넷 PC에서 확인 후 배포 | Claude Opus 4.8 / 개발지원팀 |
| **v20260728** | 2026-07-28 | 기능 추가 (플랫폼 확장) | - **Linux(x86_64 glibc) 오프라인 설치 지원 추가**<br>- `make.sh`에 타겟 인자 도입(`./make.sh linux`) — 리눅스용 `Kobi_Installer_linux_v[버전].tar.gz` 별도 산출, 기존 `./make.sh` Windows 빌드는 그대로 유지<br>- 리눅스 포터블 Node.js(`node-v22.16.0-linux-x64`) 자산 추가 및 `npm install --os=linux` 오프라인 설치 적용(node-pty/clipboard/audio-capture 리눅스 네이티브 모듈 캐시 활용)<br>- bash 실행 런처(`Kobi_Runtime/bin/kobi`) 및 `install.sh`/`uninstall.sh` 신규 작성(프로세스 정리, 스킬 압축해제, `~/.local/bin` 심링크 및 셸 rc PATH 등록/정리, API 키 사전 점검 이식)<br>- 리눅스 `settings.json` 자동 패치 — Computer Use 비활성(`computerUse.enabled=false`) 및 리눅스 파괴 명령(`rmdir`/`dd`/`mkfs`/`shred`/`truncate`) deny 추가<br>- office-edit/jennifer-monitor/kbpay-service-check 등 순수 JS 스킬 리눅스 동작 확인(frism-cm·project-bootstrap의 Windows 전용 런처 스크립트는 후속 포팅 예정)<br>- README에 리눅스 설치 가이드 추가 | Claude Opus 4.8 / 개발지원팀 |
| **v20260721** | 2026-07-21 | 기능 추가 / 개선 | - **Office(Excel/Word) 파일 편집 스킬(`office-edit`) 추가**<br>- Excel 시트/셀 조회(`read-xlsx`) 및 서식 유지 부분 수정(`edit-xlsx`) 지원<br>- Word 문서 텍스트 추출(`read-docx`) 및 서식 유지 문구 치환(`edit-docx`) 지원<br>- 템플릿에 데이터를 채워 신규 Excel/Word 파일 생성(`fill-template`) 지원<br>- 양식 없이 제목/표/문단 구조를 지정해 완전히 새로운 Excel/Word 파일 생성(`create-xlsx`, `create-docx`) 지원<br>- exceljs/mammoth/docxtemplater/pizzip/docx 라이브러리를 스킬 내부에 오프라인 자가수용형으로 번들<br>- `--in-place` 미지정 시 원본 미덮어쓰기, `create-xlsx`/`create-docx`는 `--force` 없이는 기존 파일 미덮어쓰기 안전 원칙 적용<br>- Install/Uninstall 파워셸 스크립트에 자동 압축해제 및 정리 로직 추가<br>- Qwen Code 코어 모듈 0.19.9 → **0.20.0** 업데이트 및 오프라인 캐시 갱신<br>- 실행 스크립트 시작 안내 개선 — `node.exe` 탐색 중 스피너 애니메이션(`Kobi 실행 준비 중입니다...`) 표시, 실행 직전 `Kobi 에이전트를 시작합니다...` 안내 메시지 추가<br>- 배포 패키지 리빌드 및 SHA-256 해시 갱신 | Claude Sonnet 5 / 개발지원팀 |
| **v20260720** | 2026-07-20 | 기능 추가 / UI 개선 | - **시작 배너 활성화 및 Kobi 브랜딩 적용** (`hideBanner: false`로 전환, `customBannerTitle: "Kobi"`, `customBannerSubtitle: "KB AI Assistant"`, Kobi 아스키 아트 로고 추가 — 실행 시 상단에 노출)<br>- Computer Use 기능 활성화(`tools.computerUse.enabled: true`) 및 관련 조회 툴 권한 목록(`permissions.ask`) 세분화 반영<br>- Qwen Code 코어 모듈 0.19.9 번들 및 오프라인 캐시 갱신 | Claude Sonnet 5 / 개발지원팀 |
| **v20260713** | 2026-07-13 | 기능 추가 (보안팀 승인) | - **Computer Use 화면 읽기 전용 기능 추가** (`cua-driver-rs` 0.5.2 오프라인 번들)<br>- 마우스/키보드 조작 툴 전체 차단, 읽기 전용 조회 툴만 허용(`permissions.deny`)<br>- 비전 미지원 사내 LLM 대응을 위해 `get_window_state(mode:"ax")` 텍스트 UI 트리 읽기 방식 채택 및 `QWEN.md` 지침 반영<br>- Install/Uninstall 스크립트에 드라이버 체크섬 검증 배치/정리 로직 추가<br>- 내부망 전용 단일 사용자 PC 전제 하에 개인 알림/메시지 인용 정책 완화(자격증명 정보는 계속 인용 금지)로 `QWEN.md` 세분화<br>- 배포 패키지 리빌드 및 SHA-256 해시 갱신 | 개발지원팀 |
| **v20260709_1200** | 2026-07-09 | 기능 추가 | - **Frism 형상관리시스템(CM) 연동 스킬 추가**<br>- 자바 기반 CLI 프로그램 및 Node.js 래퍼 구현 및 연동<br>- 체크아웃/체크인, 버전이력조회, CM패키지 조회/생성, 다운로드, 배포 명령 통합 지원<br>- Install 및 Uninstall 파워셸 스크립트에 자동 압축해제 및 데이터 정리 프로세스 추가<br>- 배포 패키지 리빌드 및 SHA-256 해시 갱신 | Gemini CLI / 개발지원팀 |
| **v20260702_0205** | 2026-07-02 | 성능/사용성 개선 | - **무설치 포터블 패키지 구조 전면 도입** (NPM 및 압축해제 과정 생략)<br>- 배포 패키지 빌드 자동화 스크립트(`make.sh`)에 Windows x64 타겟팅 크로스 빌드(Cross-build) 체인 내장<br>- 사용자 PC 설치 과정을 3단계로 초경량 간소화하여 연동 안정성 극대화<br>- 제니퍼 모니터링 스킬 자동 무설치 압축해제 설치 적용<br>- 배포 패키지 리빌드 및 SHA-256 해시 갱신 | Gemini CLI / 개발지원팀 |
| **v20260626_0100** | 2026-06-26 | 기능 추가 / 개선 | - 제니퍼 APM 모니터링 스킬 (`jennifer-monitor`) 범용화 (특정 서비스 국한 해제)<br>- Qwen Code 시스템 지침(`QWEN.md`), README.md 및 설치 가이드 업데이트<br>- 배포 패키지 리빌드 및 SHA-256 해시 갱신 | Gemini CLI / 개발지원팀 |
| **v20260625_0340** | 2026-06-25 | 기능 추가 / 개선 | - KB Pay 전용 제니퍼 APM 모니터링 스킬 (`kbpay-jennifer-monitor`) 추가<br>- Qwen Code 시스템 지침(`QWEN.md`)에 제니퍼 연동 점검 가이드 내재화<br>- 모니터링 CLI 스크립트(`monitor.cjs`) 구현 및 컴파일 패키징 배포<br>- 배포 패키지 리빌드 및 SHA-256 해시 갱신 | Gemini CLI / 개발지원팀 |
| **v20260624_0105** | 2026-06-24 | 초기 배포 | - KB AI Code Assistant 오프라인 설치 패키지 v0.18.3 릴리스 | 배포 관리자 |
