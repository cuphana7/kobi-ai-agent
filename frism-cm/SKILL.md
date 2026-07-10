---
name: frism-cm
description: KB Frism 형상관리시스템(CM)과 연동하여 소스 코드 체크아웃/체크인, 버전 목록 조회, 특정 버전 다운로드, CM 패키지 생성 및 조회, 스테이지 환경 배포/반영 등의 작업을 수행합니다. 사원번호(--userId) 및 저장소 이름(--repoName)이 핵심 필수 파라미터입니다. 운영 환경 배포(deploy-real) 기능은 사내 보안 정책에 따라 지원하지 않습니다.
---

# KB Frism 형상관리시스템(CM) 연동 스킬

이 스킬은 KB국민카드의 Frism 형상관리시스템(CM) OpenAPI 및 내부 자바 라이브러리 인터페이스를 활용하여, 개발자가 개발 PC에서 자원(소스 코드 파일)의 형상관리 작업을 안전하고 신속하게 수행할 수 있는 기능을 제공합니다.

Node.js CLI 래퍼 스크립트를 통해 백엔드의 자바 프로그램(`CmCli`)을 원활하게 구동하여 결과를 일관된 JSON 형식으로 수신하고 보고합니다.

---

## 1. 사용 권한 및 필수 파라미터

- **사원번호 (`--userId`)**: Frism 연동 시 인증에 필수적인 사원번호(예: `MT00201` 등)입니다. 대부분의 명령어에서 반드시 필요합니다.
- **저장소이름 (`--repoName`)**: 반영하거나 체크아웃할 형상관리 저장소의 이름(예: `UBW_WEB`)입니다.
- **CM 업무코드 (`frism.cm.biz.code`)**: 사내 표준 시스템 등록 규격입니다 (기본적으로 소스 내부에서 처리되거나, 자바 CLI 인수로 지정).

---

## 2. 사용 가능한 형상관리 명령 (Core Capabilities)

모든 명령은 스킬 디렉토리 내부의 `scripts/frism-cm.cjs` 파일을 Node.js 환경에서 호출하여 가동됩니다.

### ① 형상관리 시스템 연결 및 인증 검증 (Connect / Health Check)
사용자 사원번호를 전달하여 Frism 연결 및 로그인 테스트를 수행합니다.
```bash
node scripts/frism-cm.cjs connect --userId <사원번호>
```
- 예: `node scripts/frism-cm.cjs connect --userId MT00201`

### ② CM 패키지 조회 및 자동 생성 (Get/Create CM Package)
지정된 CM ID가 있는 경우 상세 정보를 조회하고, 없는 경우 신규 CM 패키지를 자동으로 생성합니다.
```bash
node scripts/frism-cm.cjs get-cm --userId <사원번호> [--cmId <CM_ID>]
```
- 예: `node scripts/frism-cm.cjs get-cm --userId MT00201 --cmId UBW260407`

### ③ 저장소 고유 ID 조회 (Get Repository ID)
저장소 이름을 바탕으로 시스템 내부의 고유 ID(int형)를 조회합니다.
```bash
node scripts/frism-cm.cjs get-repo-id --userId <사원번호> --repoName <저장소이름>
```
- 예: `node scripts/frism-cm.cjs get-repo-id --userId MT00201 --repoName UBW_WEB`

### ④ 소스 자원 체크아웃 (Check Out Resource)
형상관리 저장소로부터 특정 소스 파일을 체크아웃하여 작업을 위해 잠금(Lock)을 설정하거나 가져옵니다.
```bash
node scripts/frism-cm.cjs check-out --userId <사원번호> --repoName <저장소이름> --filePath <파일경로> --fileName <파일명> [--isOverride <true|false>]
```
- 예: `node scripts/frism-cm.cjs check-out --userId MT00201 --repoName UBW_WEB --filePath /src/com/kbcard/ext/common/ --fileName ClassWatchServlet.java --isOverride true`

### ⑤ 소스 자원 체크인 및 반영 (Check In Resource)
작업이 완료된 소스 파일 또는 신규 추가할 파일을 형상관리 시스템에 체크인하여 반영합니다.
```bash
node scripts/frism-cm.cjs check-in --userId <사원번호> --cmId <CM_ID> --repoName <저장소이름> --filePath <파일경로> --fileName <파일명> [--isNew <true|false>] [--isCrc <true|false>] [--desc <변경설명>]
```
- 예 (기존 파일 반영): `node scripts/frism-cm.cjs check-in --userId MT00201 --cmId UBW260407 --repoName UBW_WEB --filePath /src/com/kbcard/ext/common/ --fileName ClassWatchServlet.java --desc "ClassWatchServlet 버그 수정 반영"`
- 예 (신규 파일 등록): `node scripts/frism-cm.cjs check-in --userId MT00201 --cmId UBW260407 --repoName UBW_WEB --filePath /src/com/kbcard/ext/common/ --fileName NewUtils.java --isNew true --desc "신규 공통 유틸 추가"`

### ⑥ 소스 파일 고유 ID 조회 (Get File ID)
특정 경로와 파일명에 해당하는 형상관리 자원의 고유 ID를 가져옵니다.
```bash
node scripts/frism-cm.cjs get-file-id --userId <사원번호> --repoName <저장소이름> --filePath <파일경로> --fileName <파일명>
```

### ⑦ 체크아웃 취소 (Cancel Check Out)
체크아웃되어 잠긴 파일의 잠금을 해제하고 체크아웃을 취소합니다.
```bash
node scripts/frism-cm.cjs check-out-cancel --userId <사원번호> --repoName <저장소이름> --filePath <파일경로> --fileName <파일명>
```

### ⑧ 파일 이력 버전 목록 조회 (Get Resource Versions)
특정 자원의 과거 형상 변경 이력 및 버전 목록(버전 번호, 크기, 수정자, 수정일자, 설명 등)을 조회합니다.
```bash
node scripts/frism-cm.cjs get-versions --userId <사원번호> --repoName <저장소이름> --filePath <파일경로> --fileName <파일명>
```
- 예: `node scripts/frism-cm.cjs get-versions --userId MT00201 --repoName UBW_WEB --filePath /src/com/kbcard/ext/common/ --fileName ClassWatchServlet.java`

### ⑨ 특정 버전 소스 파일 다운로드 (Download Specific Version)
이력 목록 중 특정 버전의 소스 코드를 로컬 디렉토리에 다운로드합니다.
```bash
node scripts/frism-cm.cjs download-resource --userId <사원번호> --repoName <저장소이름> --filePath <파일경로> --fileName <파일명> --version <버전> --downloadPath <다운로드경로>
```
- 예: `node scripts/frism-cm.cjs download-resource --userId MT00201 --repoName UBW_WEB --filePath /src/com/kbcard/ext/common/ --fileName ClassWatchServlet.java --version 1.1 --downloadPath ./download/temp/`

### ⑩ 스테이지(테스트) 환경 반영 및 배포 (Deploy Stage)
해당 CM 패키지에 묶인 자원들을 검증을 위해 스테이징(Stage) 환경에 배포 및 배포 처리 완료를 신청합니다.
```bash
node scripts/frism-cm.cjs deploy-stage --userId <사원번호> --cmId <CM_ID>
```

### ⑪ 사용자 등록 CM 목록 조회 (List CM Packages)
지정 사원번호의 사용자가 생성하거나 참여 중인 CM 패키지 전체 목록을 가져옵니다.
```bash
node scripts/frism-cm.cjs get-cm-list --userId <사원번호> [--cmPackageName <필터명>]
```

### ⑫ 현재 체크아웃 중인 사용자 조회 (Find Checkout User)
지정 자원을 현재 어떤 다른 사용자가 체크아웃하여 잠그고 있는지 정보를 조회합니다. (협업 충돌 예방)
```bash
node scripts/frism-cm.cjs get-checkout-user --userId <사원번호> --repoName <저장소이름> --filePath <파일경로> --fileName <파일명>
```

---

## ※ 보안 및 안전성 차단 정책 (Security Restrictions)

- **운영 환경 반영 (`deploy-real`) 차단**:
  - **운영 배포 반영 기능은 안전한 시스템 관리 및 금융 보안 규정 준수를 위해 스킬 코어 및 엔진 레벨에서 원천적으로 강력히 차단되어 있습니다.**
  - AI Assistant(`kobi`)를 통한 운영 반영 시도는 항상 차단 에러(`SECURITY_BLOCK`)를 반환하며 실행되지 않습니다. 운영 반영은 반드시 사내 표준 형상관리 포털 시스템(IQMS 등)을 직접 경유하여 정상적인 결재 라인을 거쳐 진행하십시오.

---

## 3. 출력 포맷 및 오류 처리

모든 명령어 결과는 일관된 구조의 **단일 JSON 문자열**로 콘솔(stdout)에 출력됩니다. 성공 시에는 `success: true`가 포함되며, 시스템 실패나 업무 오류 발생 시에는 `success: false`와 함께 에러 코드, 상세 메시지가 반환됩니다.

### 성공 응답 예시
```json
{
  "success": true,
  "cmId": "UBW260407",
  "repoName": "UBW_WEB",
  "repoId": 401,
  "filePath": "/src/com/kbcard/ext/common/",
  "fileName": "ClassWatchServlet.java"
}
```

### 오류 응답 예시 (Frism 에러 연동)
```json
{
  "success": false,
  "errorCode": "UCXO6811",
  "errorMessage": "형상관리 서버연동오류",
  "errorDetail": "서버 연결에 실패하였습니다. 포트 및 IP 구성을 확인해 주세요."
}
```
