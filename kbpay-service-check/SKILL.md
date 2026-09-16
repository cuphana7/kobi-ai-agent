---
name: kbpay-service-check
description: KB Pay 및 연계된 33개 도메인의 서비스 정상 여부를 한 번에 점검한다. 각 도메인의 Jennifer APM 액티브 서비스 목록을 조회하여 runningTime이 임계치(기본 10000ms)를 초과하는 지연건만 추려낸 전체 도메인 현황 리포트를 반환하며, 정상/지연 여부 판단과 지연 현황 요약은 이 리포트를 읽는 kobi 에이전트가 직접 수행한다. "KB Pay 서비스 정상이야?", "지연되는 서비스 있어?", "전체 서비스 상태 점검해줘" 같은 요청에 사용한다.
---

# KB Pay 서비스 지연 점검 스킬 (kbpay-service-check)

`jennifer-monitor` 스킬은 도메인/인스턴스/에러룰 등 세분화된 API를 다수 제공하지만, "지금 지연되는 서비스가 있는지 → 있다면 무엇이 얼마나 지연 중인지"를 한 번에 알고 싶을 때는 어떤 API를 어떤 순서로 조합해야 할지 판단하기 번거롭다.

이 스킬은 그 워크플로우 하나만을 위해 만들어졌다:

1. 아래 **[도메인별 서비스명]** 표에 등록된 33개 도메인 전체에 대해 Jennifer APM의 `get-active-services`(`/api/activeService/list`)를 호출한다.
2. 응답에서 `runningTime`이 임계치(기본 10000ms)를 초과하는 항목만 남기되, 원본 필드(`txid`, `sqls`, `status`, `clientIp`, `threadHash`, `sessionId` 등)는 하나도 누락하지 않고 그대로 포함한다.
3. **도메인 전체 현황 + 도메인별 지연 서비스 목록**을 정리한 리포트(JSON)를 stdout으로 반환한다.

스크립트는 여기서 역할을 마친다. 이 리포트를 근거로 "서비스가 정상인지, 지연이 있다면 어디서 얼마나 지연 중인지"를 실제로 판단하고 사용자 질문에 답하는 것은 **이 스크립트를 호출하는 kobi 에이전트 자신**이 담당한다 — kobi는 이미 사내 vLLM(Qwen3-Next-80B-A3B-Instruct) 위에서 동작하는 어시스턴트이므로, 별도로 vLLM에 재차 HTTP 요청을 보낼 필요 없이 이 리포트를 읽고 곧바로 한국어로 추론/답변하면 된다.

스크립트는 `<스킬경로>/scripts/kbpay-service-check.cjs`에 위치하며 Node.js로 직접 실행한다.

---

## 1. 연결 정보 (Connection Settings)

### Jennifer APM (jennifer-monitor 스킬과 동일 서버)
- **URL**: `http://10.95.252.10:7900` (환경변수 `JENNIFER_URL` 또는 `--jennifer-url`로 재정의 가능)
- **Token**: 기본값 내장 (환경변수 `JENNIFER_TOKEN` 또는 `--jennifer-token`으로 재정의 가능)

---

## 2. 사용법 (Usage)

### ① 전체 점검 (지연건 필터링 리포트 반환)
```bash
node scripts/kbpay-service-check.cjs check
```
- 33개 도메인 전체에 대해 `get-active-services`를 동시 호출(기본 동시성 8)한 뒤, `runningTime > 10000` 인 항목만 남긴 전체 도메인 현황 리포트를 반환한다. 정상/지연 여부 판단은 이 결과를 읽는 kobi 에이전트가 직접 수행한다.

### ② 임계치 변경
```bash
node scripts/kbpay-service-check.cjs check --threshold 5000
```

### ③ 특정 도메인만 점검 (콤마로 구분된 domainId)
```bash
node scripts/kbpay-service-check.cjs check --domains 1008,1043,1046,1041
```

### ④ 도메인 매핑표만 확인 (네트워크 호출 없음)
```bash
node scripts/kbpay-service-check.cjs list-domains
```

---

## 3. 출력 형식 (Output)

성공/실패와 무관하게 stdout에는 항상 아래와 같은 단일 JSON 한 줄만 출력된다.

**성공 시**
```json
{
  "success": true,
  "message": "지연 도메인 2건 발견",
  "data": {
    "checkedAt": "2026-07-24T14:00:00.000+09:00",
    "thresholdMs": 10000,
    "domainCount": 33,
    "delayedDomainCount": 2,
    "errorDomainCount": 0,
    "domains": [
      {
        "domainId": 1046,
        "serviceName": "KBPay-결제-PAYMENT",
        "status": "DELAYED",
        "activeServiceCount": 42,
        "delayedCount": 1,
        "delayedServices": [
          {
            "domainId": 1046,
            "domainName": "PAYMENT",
            "instanceId": 10007,
            "instanceOid": 75543,
            "instanceName": "pubwifo8(ubwif08_i01_prd)",
            "application": "UBW_1_GBCS00080",
            "elapseTime": 15234,
            "txid": "-1895986269861072068",
            "cpuTime": 1,
            "sqls": 6,
            "fetches": 6,
            "status": "EXTERNALCALL",
            "statusElapseTime": 15230,
            "clientIp": "10.81.111.35",
            "threadHash": 2097571125,
            "startTime": 1784857091995,
            "statusName": "EXTERNALCALL_EXECUTING",
            "runningMode": "EXTERNALCALL",
            "runningFullText": "send",
            "runningHash": -1485620531,
            "runningTime": 15234,
            "sessionId": 5087
          }
        ],
        "error": null
      }
    ]
  }
}
```
- `status`는 도메인별로 `OK`(지연 없음) / `DELAYED`(임계치 초과 건 존재) / `ERROR`(Jennifer 조회 실패)로 표시된다.
- `delayedServices`의 각 항목은 Jennifer가 반환한 원본 필드를 하나도 누락 없이 그대로 담고 있다(`runningTime`만 숫자로 정규화하여 덧붙임). `txid`/`sessionId`/`threadHash`/`sqls`/`clientIp` 등은 정상/지연 여부 판단뿐 아니라 후속 심층 진단(`jennifer-monitor`의 `get-active-detail`, `get-profile`)에도 그대로 활용할 수 있다.

**실패 시**
```json
{"success": false, "errorCode": "INVALID_ARGUMENT", "errorMessage": "...", "errorDetail": null}
```

---

## 4. [도메인별 서비스명]

| domainId | 서비스명 |
|---|---|
| 1031 | 대내외통신-본업연계-HOME_IF |
| 1050 | 대내외통신-그룹OpenAPI-OPEN_API_GW |
| 1042 | 대내외통신-KBPay연계-LINK |
| 1012 | 대내외통신-마이데이터연계-MYDATA_MCIEAI |
| 1008 | KBPay-앱-APP |
| 1043 | KBPay-회원-MEMBER |
| 1046 | KBPay-결제-PAYMENT |
| 1041 | KBPay-서비스-BANK |
| 1048 | KBPay-쇼핑/여행-LIFE |
| 1044 | KBPay-토큰발급-TR.TSP |
| 1045 | KBPay-공중망연계-API |
| 1047 | KBPay-해외결제등-ETC |
| 1009 | KBPay-어드민-ADP |
| 1023 | 본업-어드민-UBW_ADM |
| 1024 | 본업-혜택-UBW_BON |
| 1025 | 본업-공통-UBW_CMN |
| 1026 | 본업-카드-UBW_CRD |
| 1027 | 본업-API-UBW_EXT |
| 1028 | 본업-금융-UBW_FNC |
| 1029 | 본업-MyKB-UBW_MKB |
| 1030 | 본업-서비스-UBW_SVC |
| 1032 | 본업-MIAPS-UBW_MIAPS |
| 1033 | 본업-통합로그등-WEBSHELL |
| 1002 | 자산-G/W-KBaaS |
| 1000 | 자산-서비스-Liivmate |
| 1013 | 마이데이터제공-메인-UBD_MAIN |
| 1014 | 마이데이터제공-승인-UBD_APPR |
| 1015 | 마이데이터제공-청구-UBD_BILL |
| 1010 | 마이데이터제공-어드민-Portal |
| 1004 | 온라인결제-코드발급-CodeIssue |
| 1006 | 온라인결제-안심클릭-SafeClick |
| 1017 | 오픈뱅킹-공통-UBF_MAIN |
| 1016 | 오픈뱅킹-제공-UBE_MAIN |

이 표는 `scripts/kbpay-service-check.cjs` 내부에도 동일하게 하드코딩되어 있어, 스킬 실행 시 별도 조회 없이 즉시 사용된다. 도메인 구성이 바뀌면 이 파일과 스크립트 내 `DOMAINS` 배열을 함께 갱신해야 한다.

---

## 5. 개발자 요청 응대 가이드

개발자가 **"KB Pay 서비스 정상이야?"**, **"지금 지연되는 서비스 있어?"**, **"전체 서비스 상태 점검해줘"** 라고 요청하거나 `/kbpay-service-check`로 질문하면:

1. `node scripts/kbpay-service-check.cjs check`를 실행한다. (스크립트는 판단 없이 데이터만 반환한다.)
2. 반환된 JSON을 **kobi 에이전트가 직접 해석**하여 질문에 답한다 — 별도로 vLLM에 재질문할 필요 없이, 이 JSON을 컨텍스트로 삼아 그 자리에서 추론한다.
   - `data.delayedDomainCount`가 0이면 "현재 지연 없이 전체 정상"이라고 간단히 답한다.
   - 0보다 크면 `data.domains`에서 `status: "DELAYED"`인 항목들의 `serviceName`, `delayedCount`, `delayedServices`(원본 필드 전부 포함: `txid`, `sqls`, `status`, `statusName`, `clientIp`, `threadHash`, `sessionId`, `runningTime` 등)를 근거로 어떤 서비스에서 몇 건이, 얼마나(몇 ms) 지연되고 있는지, 어떤 상태(`runningMode`/`status`, 예: SQL 실행 중·외부 호출 대기 중 등)인지 한국어로 요약 보고한다.
   - `status: "ERROR"`인 도메인이 있으면 Jennifer 조회 자체가 실패한 것이므로, 지연 여부와 별개로 "해당 도메인은 조회 실패"라고 명확히 구분하여 안내한다.
3. 더 깊은 원인 분석이 필요하면, 지연이 확인된 항목의 `txid`/`sessionId`/`threadHash`를 그대로 `jennifer-monitor` 스킬의 `get-active-detail --tx <txid> --session <sessionId> --hash <threadHash>` 또는 `get-profile`로 이어서 심층 진단한다.
