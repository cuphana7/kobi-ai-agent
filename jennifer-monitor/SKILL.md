---
name: jennifer-monitor
description: Monitor service status of all registered domains using Jennifer APM OpenAPI. Use when asked to check if any registered service (including KB Pay) is running normally, examine active service details, metric events, check real-time domain/instance metrics, fetch transaction profiles, search errors/events, or check Jennifer connection.
---

# Jennifer APM OpenAPI Monitoring Skill (v1 & v2 Unified)

이 스킬은 Jennifer APM OpenAPI 규격을 활용하여 제니퍼에 등록된 모든 서비스 도메인(**KB Pay** 등)의 정상 동작 여부를 모니터링하고, 실시간성 지표 수집, 상세 프로파일 추적, 경과시간 임계치 설정 및 다양한 이벤트 룰 상태를 조회할 수 있는 전문 기능을 제공합니다.

기본적으로 제공되는 Node.js CLI 모니터링 스크립트를 실행하여, 폐쇄망 환경의 뷰 서버에 안전하고 정확하게 API를 요청하여 결과를 가공 및 리포트할 수 있습니다.

---

## 1. 연결 정보 및 기본 설정 (Connection Settings)

기본 연결 정보는 다음과 같습니다:
- **Jennifer View Server URL**: `http://10.95.252.10:7900`
- **Jennifer API Token**: `RLf7MMrrU5s`

위 연결 정보는 스크립트 내부에 기본값으로 설정되어 있지만, 필요 시 `--url` 및 `--token` 인수 또는 `JENNIFER_URL`, `JENNIFER_TOKEN` 환경변수를 통해 유연하게 변경할 수 있습니다.

---

## 2. 사용 가능한 모니터링 명령 (Core Capabilities)

모니터링 스크립트는 `<스킬경로>/scripts/monitor.cjs`에 위치하며, Node.js 환경에서 직접 실행하여 결과를 얻습니다.

### ① 제니퍼 서버 연결 상태 확인 (Connection Health Check)
제니퍼 뷰 서버가 활성화되어 있고, API 토큰이 유효한지 가장 먼저 검증합니다. v2 `/api-v2/auth-test`를 먼저 테스트하고 불가할 경우 v1 `/api/domain`으로 자동 Fallback 동작합니다.
```bash
node scripts/monitor.cjs test-connection
```

### ② 액티브 서비스 경과시간 임계값(색상 경계) 조회 (Response Time Boundaries)
액티브 서비스의 상태 판단 기준이 되는 파랑(Blue), 연두(Green), 주황(Orange), 빨강(Red) 간 경계 시간(ms)을 확인합니다.
```bash
node scripts/monitor.cjs get-boundaries
```

### ③ 도메인 목록 조회 (Get Domains)
등록된 전체 도메인의 ID와 이름을 조회합니다.
```bash
node scripts/monitor.cjs get-domains
```

### ④ 인스턴스 목록 조회 (Get Instances)
특정 도메인에 속한 제니퍼 에이전트 인스턴스 목록을 조회합니다.
```bash
node scripts/monitor.cjs get-instances --domain <DomainID>
```
- 예: `node scripts/monitor.cjs get-instances --domain 7002`

### ⑤ 실시간 도메인 데이터 조회 (Get Real-time Domain Data)
특정 도메인의 실시간 TPS, 액티브 서비스 수, 응답시간, 시스템 CPU 등 모니터링 핵심 실시간 데이터를 조회합니다.
```bash
node scripts/monitor.cjs get-realtime-domain --domain <DomainID>
```
- 예: `node scripts/monitor.cjs get-realtime-domain --domain 7002`

### ⑥ 실시간 인스턴스 데이터 조회 (Get Real-time Instance Data)
특정 에이전트 인스턴스의 CPU 사용량, 힙 메모리 사용량, 가용 쓰레드 상태 등 실시간 상태를 조회합니다.
```bash
node scripts/monitor.cjs get-realtime-instance --domain <DomainID> --instance <InstanceID>
```
- 예: `node scripts/monitor.cjs get-realtime-instance --domain 7002 --instance 10001`

### ⑦ 실시간 액티브 서비스 목록 조회 (Get Live Active Services)
현재 실행 중인 트랜잭션 목록, 경과 시간, 수행 중인 SQL 질의나 External Call 정보를 실시간 추적합니다. (응답지연 병목 분석의 첫 단계)
```bash
node scripts/monitor.cjs get-active-services --domain <DomainID> [--instance <InstanceID>]
```
- 예: `node scripts/monitor.cjs get-active-services --domain 7002`

### ⑧ 트랜잭션 프로파일 텍스트 조회 (Get Transaction Profile Text)
과거 특정 트랜잭션ID(TXID)에 대해 실제 실행된 소스코드 레벨의 Call Stack/Profile trace와 소요시간, SQL 쿼리 본문을 텍스트 형태로 조회하여 정확한 지연 원인을 소스 레벨에서 디버깅합니다.
```bash
node scripts/monitor.cjs get-profile --domain <DomainID> --tx <TxID> --time <Time>
```
- 예: `node scripts/monitor.cjs get-profile --domain 7002 --tx 876543210123 --time 202606251430` (13자리 Unix 타임스탬프 또는 12자리 YYYYMMddHHmm 날짜 형식 모두 지원하며, 내부적으로 13자리 밀리초 타임스탬프로 자동 변환됩니다.)

### ⑨ 과거 에러 검색 결과 조회 (Search Historical Errors)
지정 시간 내에 발생한 에러 발생 정보(클래스명, 에러 메시지, 해당 트랜잭션 ID 등) 이력을 검색하여 예외 발생을 추적합니다.
```bash
node scripts/monitor.cjs get-dbsearch-errors --domain <DomainID> --start <StartTime> --end <EndTime> [--error-type <ErrorType>]
```
- 예: `node scripts/monitor.cjs get-dbsearch-errors --domain 7002 --start 202606251400 --end 202606251410` (13자리 Unix 타임스탬프 또는 12자리 YYYYMMddHHmm 날짜 형식 모두 지원하며, 내부적으로 13자리 밀리초 타임스탬프로 자동 변환됩니다.)

### ⑩ 과거 이벤트 검색 결과 조회 (Search Historical Alert Events)
지정 시간 내 제니퍼 시스템에서 감지하여 경보를 울린 이벤트(Fatal, Warning 등) 감지 이력을 검색합니다.
```bash
node scripts/monitor.cjs get-dbsearch-events --domain <DomainID> --start <StartTime> --end <EndTime> [--level <normal,warning,fatal>]
```
- 예: `node scripts/monitor.cjs get-dbsearch-events --domain 7002 --start 202606251400 --end 202606251410` (13자리 Unix 타임스탬프 또는 12자리 YYYYMMddHHmm 날짜 형식 모두 지원하며, 내부적으로 13자리 밀리초 타임스탬프로 자동 변환됩니다.)

### ⑪ 에러 이벤트 룰 설정 조회 (Error Event Rules)
특정 도메인의 장애 및 에러 상태 정의 룰을 조회하여, 예외 발생 기준 및 조치 자동화 스크립트 설정 현황을 파악합니다.
```bash
node scripts/monitor.cjs get-errors --domain <DomainID>
```

### ⑫ 메트릭 이벤트 룰 설정 조회 (Metric Event Rules)
Heap 사용량, 응답 속도, 요청 수 등 성능 지표에 대해 경고를 발생시키는 임계치 설정을 확인합니다.
```bash
node scripts/monitor.cjs get-metrics --domain <DomainID> --type <domain|instance|business>
```

### ⑬ 비교 이벤트 룰 설정 조회 (Comparison Event Rules)
지난주 대비 응답 성능 등 통계적/이전 시점 대비 모니터링 경보 조건을 확인합니다.
```bash
node scripts/monitor.cjs get-comparisons --domain <DomainID> --type <domain|instance>
```

### ⑭ 액티브 서비스 상세 트랜잭션 조회 (Active Transaction Detail)
실시간 실행 중인 지연 트랜잭션에 대해 SQL 쿼리, HTTP 요청 매개변수 등 세부 동작 컨텍스트를 조회하여 병목 지점을 진단합니다.
```bash
node scripts/monitor.cjs get-active-detail --domain <DomainID> --tx <TxID> --session <SessionID> --hash <ThreadHash>
```

### ⑮ 프로세스 ID 및 호스트명으로 인스턴스 검색 (Instance Resolver)
특정 OS 호스트와 PID를 매핑하는 Jennifer 인스턴스(Agent ID 및 Domain ID)를 확인합니다.
```bash
node scripts/monitor.cjs get-instance --pid <ProcessID> --hostname <Hostname>
```

---

## 3. 장애 및 상태 분석 워크플로우 (Troubleshooting Workflow)

개발자가 **"제니퍼 등록 서비스 상태를 점검해줘"** 또는 **"특정 서비스(예: KB Pay) 장애 발생 요인을 분석해줘"**라고 요청할 때 다음과 같은 종합적이고 체계적인 단계로 장애 진단을 수행합니다:

1. **연결성 확인 및 메타데이터 획득**:
   - `test-connection`으로 제니퍼 연결 상태를 점검합니다.
   - `get-domains`로 등록된 전체 서비스 도메인 목록과 ID를 조회하여 파악합니다. (예: KB Pay의 경우 `7002`, `1000`)
   - `get-instances`를 사용해 대상 도메인 아래 활성화된 인스턴스 ID 목록을 획득합니다.

2. **실시간 성능 수준 및 병목 감지**:
   - `get-realtime-domain`으로 선택한 도메인의 현재 TPS 및 응답 속도, Active Service 숫자를 점검하여 이상 폭증이나 지연이 있는지 감지합니다.
   - 지연이 감지되면 `get-boundaries`로 빨간색(Red, 심각 지연) 경고 상태를 판별하는 시간 구간 기준을 획득합니다.
   - `get-active-services`를 실행하여 현재 실행 시간이 비정상적으로 길고 밀려 있는 액티브 서비스 트랜잭션 목록과 `txid`를 찾아냅니다.

3. **장애 원인 심층 분석 (Root Cause Analysis)**:
   - 긴 대기 시간을 유발하는 트랜잭션의 상세한 SQL문 및 호출 환경을 진단하기 위해 `get-active-detail`을 호출하거나, 최근 끝난 트랜잭션이라면 `get-profile`을 실행하여 소스코드 라인별/SQL 실행시간별 병목 구간을 역추적합니다.
   - 시스템 자원 고갈 의심 시 `get-realtime-instance`로 대상 인스턴스의 CPU 및 Heap 메모리 사용 지표를 추적합니다.

4. **과거 이력 및 룰 연동 대조**:
   - 장애 발생 시간대에 대해 `get-dbsearch-errors`와 `get-dbsearch-events`를 호출하여, 과거 로그에 기록된 구체적인 Exception 정보와 제니퍼 경보 이벤트를 결합 분석합니다.
   - 필요 시 `get-errors`, `get-metrics` 룰 설정을 조회하여 특정 경보가 발생했던 정량적 임계치를 역산하여 향후 재발 방지를 제안합니다.

5. **종합 보고서 작성 및 한국어 가이드**:
   - 수집된 모든 실시간 지표, 에러 스택, 프로파일 병목 위치, 임계치를 한글화된 마크다운 보고서로 일목요연하게 정리합니다.
   - 소스코드 및 인프라 레이어의 개선 권고안을 명확하게 제시하여 개발자가 즉시 조치할 수 있도록 돕습니다.
