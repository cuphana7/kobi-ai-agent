# JENNIFER5 Open API 명세서 — Markdown 변환본

> 원본: `https://jennifersoft.github.io/jennifer-developer-guide/#/openapi.html`  
> 원본 페이지는 `docs/openapi.html`에서 `openapi/index.html`을 iframe으로 표시하며, 실제 Swagger 2.0 명세는 `docs/openapi/static/js/main.fe3c35d2.chunk.js` 안에 포함되어 있음.  
> 용도: Qwen Code / Codex / 내부 Agent Skill 등록용 API Reference.

---

## 1. 기본 정보

| 항목 | 값 |
|---|---|
| 문서 제목 | JENNIFER5 API Reference |
| Swagger 버전 | 2.0 |
| Host | `localhost` |
| Base Path | `/` |
| API 그룹 | `open-api-controller`, `rest-api-user-controller` |
| 원본 설명 | 신규 RESTful API 개발 중이며, 기존 Open API는 호환성을 위해 제거하지 않지만 더 이상 유지보수하지 않는다는 안내가 포함됨. |

### 내부 사용 메모

- 이 명세의 경로는 `/api/...` 및 `/restapi/...` 기준이다.
- `/api-v2/...` 명세가 필요한 경우에는 별도 `jennifer5-open-api-v2-manual` 문서를 함께 등록해야 한다.
- 조회성 API는 대부분 `GET`과 `POST`가 모두 제공되며, 파라미터는 `query` 방식이다.
- `POST` 조회 API는 대체로 `Consumes: application/json`을 명시하지만, 실제 파라미터는 Swagger 명세상 `query`에 정의되어 있다.
- 인증 방식은 이 Swagger 객체에는 명시되어 있지 않다. 운영 환경에서 인증 토큰이 필요한 경우 `Authorization: Bearer <TOKEN>` 헤더 또는 설치 환경의 인증 방식을 별도 적용한다.

### 공통 시간 파라미터 관례

| 파라미터 | 의미 |
|---|---|
| `start_time` | 조회 시작 시각. 기본은 Unix timestamp milliseconds. `time_pattern` 지정 시 해당 패턴 문자열 사용. |
| `end_time` | 조회 종료 시각. `end_time < start_time`이면 오류. |
| `time` | 단일 거래/프로파일 조회 기준 시각. |
| `time_pattern` | 입력/출력 시간 패턴. 예: `YYYYMMdd`, `YYYYMMddHH`. 미지정 시 Unix timestamp milliseconds 사용. |
| `interval_minute` | DB Metrics 집계 간격, 분 단위. |

### 공통 응답 코드

| 코드 | 의미 |
|---:|---|
| 200 | OK |
| 201 | Created. 주로 POST/PUT 또는 생성·수정 성공 응답에 포함. |
| 204 | No Content. 일부 DELETE 응답에 포함. |
| 400 | Invalid API request parameter value. |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 500 | Server error or unexpected exception |

---

## 2. 전체 API 목록

총 25개 Path, 48개 Operation.

| No | Path | Methods | Controller | 200 응답 Schema |
|---:|---|---|---|---|
| 1 | `/api/activeService/list` | GET, POST | open-api-controller | `ActiveServiceListSet` |
| 2 | `/api/auth/userlist` | GET, POST | open-api-controller | `UserListSet` |
| 3 | `/api/business` | GET, POST | open-api-controller | `BusinessSet` |
| 4 | `/api/dbmetrics/business` | GET, POST | open-api-controller | `DBMetricsSet` |
| 5 | `/api/dbmetrics/domain` | GET, POST | open-api-controller | `DBMetricsSet` |
| 6 | `/api/dbmetrics/instance` | GET, POST | open-api-controller | `DBMetricsSet` |
| 7 | `/api/dbsearch/error` | GET, POST | open-api-controller | `ErrorListSet` |
| 8 | `/api/dbsearch/event` | GET, POST | open-api-controller | `EventListSet` |
| 9 | `/api/domain` | GET, POST | open-api-controller | `DomainSet` |
| 10 | `/api/instance` | GET, POST | open-api-controller | `InstanceSet` |
| 11 | `/api/metrics` | GET, POST | open-api-controller | `MetricsSet` |
| 12 | `/api/realtime/business` | GET, POST | open-api-controller | `RealtimeBusinessDataSet` |
| 13 | `/api/realtime/domain` | GET, POST | open-api-controller | `RealtimeDomainDataSet` |
| 14 | `/api/realtime/instance` | GET, POST | open-api-controller | `RealtimeInstanceDataSet` |
| 15 | `/api/status/application` | GET, POST | open-api-controller | `ApplicationStatusListSet` |
| 16 | `/api/status/external_call` | GET, POST | open-api-controller | `SqlAndExternalCallStatusListSet` |
| 17 | `/api/status/sql` | GET, POST | open-api-controller | `SqlAndExternalCallStatusListSet` |
| 18 | `/api/transaction/guid` | GET, POST | open-api-controller | `TransactionListSet` |
| 19 | `/api/transaction/profile.txt` | GET | open-api-controller | `string` |
| 20 | `/api/transaction/sql` | GET, POST | open-api-controller | `PiSqlSet` |
| 21 | `/api/transaction/time` | GET, POST | open-api-controller | `TransactionListSet` |
| 22 | `/api/transaction/txid` | GET, POST | open-api-controller | `TransactionSet` |
| 23 | `/restapi/user/` | POST | rest-api-user-controller | `object` |
| 24 | `/restapi/user/{id}` | GET, PUT, DELETE | rest-api-user-controller | `User` / `object` |
| 25 | `/restapi/users` | GET | rest-api-user-controller | `User[]` |

---

## 3. API 상세

### 3.1 GET `/api/activeService/list`

실시간 Active Service 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `activeServiceListJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `ActiveServiceListSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y |  | 도메인 ID |
| `instance_id` | query | integer(int32) | N | `0` | 특정 인스턴스 조회 시 지정. 다중 인스턴스는 쉼표 구분. Null이면 도메인 전체 인스턴스 조회. |

응답 코드: 200, 401, 403, 404

### 3.2 POST `/api/activeService/list`

실시간 Active Service 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `activeServiceListJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `ActiveServiceListSet` |

파라미터는 GET `/api/activeService/list`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.3 GET `/api/auth/userlist`

JENNIFER 인증 사용자 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `authUserListUsingGET` |
| Produces | `*/*` |
| 200 Schema | `UserListSet` |

파라미터 없음.

응답 코드: 200, 401, 403, 404

### 3.4 POST `/api/auth/userlist`

JENNIFER 인증 사용자 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `authUserListUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `UserListSet` |

파라미터 없음.

응답 코드: 200, 201, 401, 403, 404

---

### 3.5 GET `/api/business`

Business 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `businessJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `BusinessSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | 도메인 ID |

응답 코드: 200, 401, 403, 404

### 3.6 POST `/api/business`

Business 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `businessJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `BusinessSet` |

파라미터는 GET `/api/business`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.7 GET `/api/dbmetrics/business`

DB Metrics를 Business 기준으로 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `dbMetricsBusinessJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `DBMetricsSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `business_id` | query | integer(int32) | Y | Business ID |
| `domain_id` | query | integer(int32) | Y | 도메인 ID |
| `end_time` | query | string | Y | 종료 시각. 시작 시각보다 작으면 오류. |
| `interval_minute` | query | integer(int32) | Y | 집계 간격(분). |
| `metrics` | query | string | Y | 조회할 메트릭 이름. |
| `start_time` | query | string | Y | 시작 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |

응답 코드: 200, 401, 403, 404

### 3.8 POST `/api/dbmetrics/business`

DB Metrics를 Business 기준으로 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `dbMetricsBusinessJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `DBMetricsSet` |

파라미터는 GET `/api/dbmetrics/business`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.9 GET `/api/dbmetrics/domain`

DB Metrics를 Domain 기준으로 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `dbMetricsDomainJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `DBMetricsSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | 도메인 ID |
| `end_time` | query | string | Y | 종료 시각. 시작 시각보다 작으면 오류. |
| `interval_minute` | query | integer(int32) | Y | 집계 간격(분). |
| `metrics` | query | string | Y | 조회할 메트릭 이름. |
| `start_time` | query | string | Y | 시작 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |

응답 코드: 200, 401, 403, 404

### 3.10 POST `/api/dbmetrics/domain`

DB Metrics를 Domain 기준으로 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `dbMetricsDomainJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `DBMetricsSet` |

파라미터는 GET `/api/dbmetrics/domain`과 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.11 GET `/api/dbmetrics/instance`

DB Metrics를 Instance 기준으로 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `dbMetricsInstanceJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `DBMetricsSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | 도메인 ID |
| `end_time` | query | string | Y | 종료 시각. 시작 시각보다 작으면 오류. |
| `instance_id` | query | integer(int32) | Y | 인스턴스 ID |
| `interval_minute` | query | integer(int32) | Y | 집계 간격(분). |
| `metrics` | query | string | Y | 조회할 메트릭 이름. |
| `start_time` | query | string | Y | 시작 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |

응답 코드: 200, 401, 403, 404

### 3.12 POST `/api/dbmetrics/instance`

DB Metrics를 Instance 기준으로 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `dbMetricsInstanceJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `DBMetricsSet` |

파라미터는 GET `/api/dbmetrics/instance`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.13 GET `/api/dbsearch/error`

DB Search의 ERROR 검색 결과 목록을 조회한다. 5.2.3 이후 목록 조회만 지원한다.

| 항목 | 값 |
|---|---|
| Operation ID | `errorListJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `ErrorListSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | 도메인 ID |
| `end_time` | query | string | Y | 종료 시각. 시작 시각보다 작으면 오류. |
| `error_type` | query | array(string) | N | ERROR 타입. 문자열은 대문자 기준. `collectionFormat=multi`. |
| `instance_id` | query | array(integer int32) | N | Null이면 도메인 전체 인스턴스. 특정 인스턴스는 `10001,10002` 형태. `collectionFormat=multi`. |
| `start_time` | query | string | Y | 시작 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N | `YYYYMMdd` 또는 `YYYYMMddHH` 등. 미지정 시 Unix timestamp milliseconds. |

응답 코드: 200, 401, 403, 404

### 3.14 POST `/api/dbsearch/error`

DB Search의 ERROR 검색 결과 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `errorListJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `ErrorListSet` |

파라미터는 GET `/api/dbsearch/error`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.15 GET `/api/dbsearch/event`

DB Search의 EVENT 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `eventListJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `EventListSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y |  | 도메인 ID |
| `end_time` | query | string | Y |  | 종료 시각. 시작 시각보다 작으면 오류. |
| `instance_id` | query | array(integer int32) | N |  | Null이면 도메인 전체 인스턴스. 특정 인스턴스는 `10001,10002` 형태. |
| `level` | query | array(string) | N | `normal,warning,fatal` | 조회할 EVENT 레벨. `collectionFormat=multi`. |
| `start_time` | query | string | Y |  | 시작 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N |  | `YYYYMMdd` 또는 `YYYYMMddHH` 등. 미지정 시 Unix timestamp milliseconds. |

응답 코드: 200, 401, 403, 404

### 3.16 POST `/api/dbsearch/event`

DB Search의 EVENT 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `eventListJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `EventListSet` |

파라미터는 GET `/api/dbsearch/event`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.17 GET `/api/domain`

Domain 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `domainJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `DomainSet` |

파라미터 없음.

응답 코드: 200, 401, 403, 404

### 3.18 POST `/api/domain`

Domain 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `domainJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `DomainSet` |

파라미터 없음.

응답 코드: 200, 201, 401, 403, 404

---

### 3.19 GET `/api/instance`

Instance 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `instanceJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `InstanceSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | 도메인 ID |

응답 코드: 200, 401, 403, 404

### 3.20 POST `/api/instance`

Instance 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `instanceJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `InstanceSet` |

파라미터는 GET `/api/instance`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.21 GET `/api/metrics`

사용 가능한 Metrics 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `metricsJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `MetricsSet` |

파라미터 없음.

응답 코드: 200, 401, 403, 404

### 3.22 POST `/api/metrics`

사용 가능한 Metrics 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `metricsJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `MetricsSet` |

파라미터 없음.

응답 코드: 200, 201, 401, 403, 404

---

### 3.23 GET `/api/realtime/business`

실시간 Business 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `realtimeBusinessUsingGET` |
| Produces | `*/*` |
| 200 Schema | `RealtimeBusinessDataSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `business_id` | query | integer(int32) | N | `0` | Business ID. |
| `domain_id` | query | integer(int32) | Y |  | 도메인 ID |

응답 코드: 200, 401, 403, 404

### 3.24 POST `/api/realtime/business`

실시간 Business 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `realtimeBusinessUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `RealtimeBusinessDataSet` |

파라미터는 GET `/api/realtime/business`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.25 GET `/api/realtime/domain`

실시간 Domain 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `realtimeDomainUsingGET` |
| Produces | `*/*` |
| 200 Schema | `RealtimeDomainDataSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | N | `0` | 도메인 ID |

응답 코드: 200, 401, 403, 404

### 3.26 POST `/api/realtime/domain`

실시간 Domain 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `realtimeDomainUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `RealtimeDomainDataSet` |

파라미터는 GET `/api/realtime/domain`과 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.27 GET `/api/realtime/instance`

실시간 Instance 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `realtimeInstanceUsingGET` |
| Produces | `*/*` |
| 200 Schema | `RealtimeInstanceDataSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y |  | 도메인 ID |
| `instance_id` | query | integer(int32) | N | `0` | 인스턴스 ID |

응답 코드: 200, 401, 403, 404

### 3.28 POST `/api/realtime/instance`

실시간 Instance 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `realtimeInstanceUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `RealtimeInstanceDataSet` |

파라미터는 GET `/api/realtime/instance`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.29 GET `/api/status/application`

Application Status의 Application Service 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `applicationStatusListJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `ApplicationStatusListSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y |  | 도메인 ID |
| `end_time` | query | string | Y |  | 종료 시각. 시작 시각보다 작으면 오류. 시간 이하 단위는 0이어야 함. |
| `instance_id` | query | array(integer int32) | N |  | Null이면 도메인 전체 인스턴스. 특정 인스턴스는 `10001,10002` 형태. |
| `max_row` | query | integer(int32) | N | `1000` | 최대 결과 건수. |
| `sort_by_metrics` | query | string | N | `calls` | 정렬 기준 메트릭. |
| `start_time` | query | string | Y |  | 시작 시각. 시간 이하 단위는 0이어야 함. |
| `time_pattern` | query | string | N |  | `YYYYMMdd` 또는 `YYYYMMddhh` 형식. 미지정 시 Unix timestamp. |

응답 코드: 200, 401, 403, 404

### 3.30 POST `/api/status/application`

Application Status의 Application Service 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `applicationStatusListJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `ApplicationStatusListSet` |

파라미터는 GET `/api/status/application`과 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.31 GET `/api/status/external_call`

Application Status의 External Call 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `externalCallStatusListJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `SqlAndExternalCallStatusListSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y |  | 도메인 ID |
| `end_time` | query | string | Y |  | 종료 시각. 시작 시각보다 작으면 오류. 시간 이하 단위는 0이어야 함. |
| `instance_id` | query | array(integer int32) | N |  | Null이면 도메인 전체 인스턴스. 특정 인스턴스는 `10001,10002` 형태. |
| `max_row` | query | integer(int32) | N | `1000` | 최대 결과 건수. |
| `sort_by_metrics` | query | string | N | `calls` | 정렬 기준 메트릭. |
| `start_time` | query | string | Y |  | 시작 시각. 시간 이하 단위는 0이어야 함. |
| `time_pattern` | query | string | N |  | `YYYYMMdd` 또는 `YYYYMMddhh` 형식. 미지정 시 Unix timestamp. |

응답 코드: 200, 401, 403, 404

### 3.32 POST `/api/status/external_call`

Application Status의 External Call 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `externalCallStatusListJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `SqlAndExternalCallStatusListSet` |

파라미터는 GET `/api/status/external_call`과 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.33 GET `/api/status/sql`

Application Status의 SQL 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `sqlStatusListJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `SqlAndExternalCallStatusListSet` |

파라미터는 GET `/api/status/external_call`과 동일하다.

응답 코드: 200, 401, 403, 404

### 3.34 POST `/api/status/sql`

Application Status의 SQL 검색 결과를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `sqlStatusListJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `SqlAndExternalCallStatusListSet` |

파라미터는 GET `/api/status/external_call`과 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.35 GET `/api/transaction/guid`

GUID로 X-View 기본 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `transactionGuidJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `TransactionListSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | 도메인 ID |
| `end_time` | query | string | Y | 종료 시각. 시작 시각보다 작으면 오류. |
| `guid` | query | string | Y | GUID |
| `start_time` | query | string | Y | 시작 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |

응답 코드: 200, 401, 403, 404

### 3.36 POST `/api/transaction/guid`

GUID로 X-View 기본 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `transactionGuidJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `TransactionListSet` |

파라미터는 GET `/api/transaction/guid`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.37 GET `/api/transaction/profile.txt`

TXID로 트랜잭션 프로파일 데이터를 텍스트로 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `transactionProfilesTextUsingGET` |
| Produces | `text/plain;charset=utf-8` |
| 200 Schema | `string` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | `-1` | 도메인 ID |
| `time` | query | string | Y |  | 거래 기준 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N |  | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |
| `txid` | query | integer(int64) | Y | `-1` | Transaction ID |

응답 코드: 200, 401, 403, 404

---

### 3.38 GET `/api/transaction/sql`

트랜잭션의 SQL 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `getPiSqlJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `PiSqlSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | `-1` | 도메인 ID |
| `profile_no` | query | integer(int32) | N | `-1` | 프로파일 번호 |
| `time` | query | string | Y |  | 거래 기준 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N |  | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |
| `txid` | query | integer(int64) | Y | `-1` | Transaction ID |

응답 코드: 200, 401, 403, 404

### 3.39 POST `/api/transaction/sql`

트랜잭션의 SQL 정보를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `getPiSqlJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `PiSqlSet` |

파라미터는 GET `/api/transaction/sql`과 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.40 GET `/api/transaction/time`

시간 범위로 X-View 기본 데이터를 조회한다. 조회 시간 범위는 1분으로 제한된다.

| 항목 | 값 |
|---|---|
| Operation ID | `transactionTimeJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `TransactionListSet` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | 도메인 ID |
| `end_time` | query | string | Y | 종료 시각. 시작 시각보다 작으면 오류. |
| `instance_id` | query | array(integer int32) | N | Null이면 도메인 전체 인스턴스. 특정 인스턴스는 `10001,10002` 형태. |
| `start_time` | query | string | Y | 시작 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |

응답 코드: 200, 401, 403, 404

### 3.41 POST `/api/transaction/time`

시간 범위로 X-View 기본 데이터를 조회한다. 조회 시간 범위는 1분으로 제한된다.

| 항목 | 값 |
|---|---|
| Operation ID | `transactionTimeJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `TransactionListSet` |

파라미터는 GET `/api/transaction/time`과 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.42 GET `/api/transaction/txid`

TXID로 X-View 기본 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `transactionTxidJSONUsingGET` |
| Produces | `*/*` |
| 200 Schema | `TransactionSet` |

| 파라미터 | 위치 | 타입 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| `domain_id` | query | integer(int32) | Y | `-1` | 도메인 ID |
| `time` | query | string | Y |  | 거래 기준 시각. 기본 Unix timestamp milliseconds. |
| `time_pattern` | query | string | N |  | 시간 입력/출력 패턴. 미지정 시 Unix timestamp milliseconds. |
| `txid` | query | integer(int64) | Y | `-1` | Transaction ID |

응답 코드: 200, 401, 403, 404

### 3.43 POST `/api/transaction/txid`

TXID로 X-View 기본 데이터를 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `transactionTxidJSONUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `TransactionSet` |

파라미터는 GET `/api/transaction/txid`와 동일하다.

응답 코드: 200, 201, 401, 403, 404

---

### 3.44 POST `/restapi/user/`

JENNIFER 사용자를 생성한다.

| 항목 | 값 |
|---|---|
| Operation ID | `createUserUsingPOST` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `object` |
| 201 Schema | `object` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `user` | body | `User` | Y | 생성할 사용자 객체 |

응답 코드: 200, 201, 400, 401, 403, 404, 500

400 조건: 이미 존재하는 사용자, 그룹 없음, 필수 데이터 누락 등.

---

### 3.45 GET `/restapi/user/{id}`

JENNIFER 사용자를 단건 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `getUserUsingGET` |
| Produces | `*/*` |
| 200 Schema | `User` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `id` | path | string | Y | 사용자 ID |

응답 코드: 200, 401, 403, 404

### 3.46 PUT `/restapi/user/{id}`

JENNIFER 사용자를 수정한다.

| 항목 | 값 |
|---|---|
| Operation ID | `modifyUserUsingPUT` |
| Consumes | `application/json` |
| Produces | `*/*` |
| 200 Schema | `object` |
| 201 Schema | `object` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `id` | path | string | Y | 사용자 ID |
| `user` | body | `User` | Y | 수정할 사용자 객체 |

응답 코드: 200, 201, 400, 401, 403, 404, 500

400 조건: 그룹 없음, 필수 데이터 누락 등.

### 3.47 DELETE `/restapi/user/{id}`

JENNIFER 사용자를 삭제한다.

| 항목 | 값 |
|---|---|
| Operation ID | `deleteUserUsingDELETE` |
| Produces | `*/*` |
| 200 Schema | `object` |

| 파라미터 | 위치 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| `id` | path | string | Y | 사용자 ID |

응답 코드: 200, 204, 400, 401, 403, 500

400 조건: 사용자가 존재하지 않음.

---

### 3.48 GET `/restapi/users`

JENNIFER 사용자 전체 목록을 조회한다.

| 항목 | 값 |
|---|---|
| Operation ID | `getUsersUsingGET` |
| Produces | `*/*` |
| 200 Schema | `array<User>` |

파라미터 없음.

응답 코드: 200, 401, 403, 404

---

## 4. Schema Definitions

### 4.1 `ActiveServiceData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `alias` | string | Application alias |
| `application` | string | Application Service 이름 |
| `business` | array<int32> | `businessId`와 같은 값 |
| `businessId` | array<int32> | Business ID 배열 |
| `businessName` | array<string> | Business 이름 배열 |
| `businessOid` | array<int32> | Business OID 배열 |
| `clientIp` | string | Client IP |
| `cpuTime` | integer(int32) | CPU Time |
| `domainId` | integer(int32) | Domain ID |
| `domainName` | string | Domain 이름 |
| `elapseTime` | integer(int32) | Application Service elapsed time |
| `fetches` | integer(int32) | Fetch count |
| `instanceId` | integer(int32) | Instance ID |
| `instanceName` | string | Instance 이름 |
| `instanceOid` | integer(int32) | Instance OID |
| `runningConnectionName` | string | 현재 SQL 실행 DB connection 이름 |
| `runningDataSourceName` | string | 현재 SQL 실행 DataSource 이름 |
| `runningFullText` | string | Active Service 상태의 SQL 또는 external call text |
| `runningHash` | integer(int32) | 실행 중인 active service hash |
| `runningMode` | string | SQL 또는 External Call 실행 여부 |
| `runningSherpaOracleInstanceName` | string | 연결 중인 SherpaOracle instance 이름 |
| `runningSherpaOracleSequence` | integer(int32) | 연결 중인 SherpaOracle sequence |
| `runningTime` | integer(int32) | 실행 중 active service 응답 시간 |
| `sqls` | integer(int32) | SQL count |
| `startTime` | integer(int64) | Active Service 시작 시각 |
| `status` | string | Application Service 상태 |
| `statusElapseTime` | integer(int32) | 해당 상태에서 경과한 시간(ms) |
| `statusMessage` | string | 상태 메시지 |
| `statusName` | string | Active Service 상태 타입 |
| `threadHash` | integer(int32) | Application Service thread hash |
| `txid` | string | Transaction ID |

### 4.2 `ActiveServiceListSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<ActiveServiceData> | Active Service 목록 |

### 4.3 `ApplicationStatus`

| 필드 | 타입 | 설명 |
|---|---|---|
| `badResponses` | integer(int32) | Bad Responses |
| `calls` | integer(int32) | Calls |
| `cpuTimePerTransaction` | integer(int32) | CPU Time per Transaction(ms) |
| `externalCallTimePerTransaction` | number(double) | External Call Time per Transaction(ms) |
| `externalCalls` | integer(int32) | External Calls |
| `externalCallsPerTransaction` | number(double) | External Calls per Transaction |
| `failures` | integer(int32) | Failures |
| `fetchTimePerTransaction` | number(double) | Fetch Time per Transaction(ms) |
| `fetches` | integer(int32) | Fetches |
| `fetchesPerTransaction` | number(double) | Fetches per Transaction |
| `frontendMeasurements` | integer(int64) | Frontend Measurements |
| `frontendTime` | integer(int64) | Frontend Time(ms) |
| `maxResponseTime` | integer(int32) | Max response time |
| `name` | string | Application Service 이름 |
| `networkTime` | integer(int64) | Network Time(ms) |
| `responseTime` | number(double) | Response Time(ms) |
| `sqlTimePerTransaction` | number(double) | SQL Time per Transaction(ms) |
| `sqls` | integer(int32) | SQL count |
| `sqlsPerTransaction` | number(double) | SQLs per Transaction |
| `totalCpuTime` | integer(int64) | Total CPU time |
| `totalExternalCallTime` | integer(int64) | Total External Call time |
| `totalFetchTime` | integer(int64) | Total Fetch time |
| `totalResponseTime` | integer(int64) | Total response time |
| `totalSqlTime` | integer(int64) | Total SQL time |

### 4.4 `ApplicationStatusListSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<ApplicationStatus> | Application Status 목록 |

### 4.5 `Business`

| 필드 | 타입 | 설명 |
|---|---|---|
| `badResponseTime` | integer(int32) | BAD_RESPONSE_TIME_ERROR 기본값 |
| `businessId` | integer(int32) | Business ID |
| `businessIndex` | string | Business index |
| `businessOid` | integer(int32) | Business OID |
| `description` | string | 설명 |
| `name` | string | Business 이름 |
| `ruleList` | array<string> | Business rule 목록 |

### 4.6 `BusinessSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<Business> | Business 목록 |

### 4.7 `DBMetrics`

| 필드 | 타입 | 설명 |
|---|---|---|
| `time` | string | 값 기준 시각 |
| `value` | number(double) | 조회 옵션에 따른 결과값 |

### 4.8 `DBMetricsSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<DBMetrics> | DB Metrics 목록 |

### 4.9 `Domain`

| 필드 | 타입 | 설명 |
|---|---|---|
| `description` | string | 설명 |
| `domainId` | integer(int32) | Domain ID |
| `instanceCount` | InstanceCountByStateInDomain | 상태별 인스턴스 수 |
| `ipAddress` | string | IP 주소 |
| `name` | string | Domain 이름 |
| `port` | integer(int32) | Port |

### 4.10 `DomainSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<Domain> | Domain 목록 |

### 4.11 `ErrorData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `applicationName` | string | ERROR 발생 Application Service 이름. 없으면 Null |
| `domainId` | integer(int32) | Domain ID |
| `domainName` | string | Domain 이름 |
| `errorType` | string | ERROR 타입 |
| `instanceId` | integer(int32) | Instance ID |
| `instanceName` | string | Instance 이름 |
| `instanceOid` | integer(int32) | Instance OID |
| `message` | string | ERROR 메시지 |
| `profileIndex` | integer(int32) | Transaction ERROR profile index. 없으면 Null |
| `time` | string | ERROR 발생 시각 |
| `txid` | string | EVENT/ERROR 발생 Transaction ID. 없으면 Null |
| `value` | number(double) | ERROR 값. 없으면 Null |

### 4.12 `ErrorListSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<ErrorData> | Error 목록 |

### 4.13 `EventData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `applicationName` | string | EVENT 발생 Application Service 이름 |
| `domainId` | integer(int32) | Domain ID |
| `domainName` | string | Domain 이름 |
| `errorType` | string | ERROR 기반 EVENT인 경우 ERROR 타입 |
| `eventLevel` | string | EVENT 심각도 |
| `instanceId` | integer(int32) | Instance ID |
| `instanceName` | string | Instance 이름 |
| `instanceOid` | integer(int32) | Instance OID |
| `message` | string | EVENT 메시지 |
| `metricsName` | string | Metrics 기반 EVENT인 경우 Metrics 이름 |
| `time` | string | EVENT 발생 시각 |
| `txid` | string | EVENT 발생 X-View 기본 데이터 ID |
| `value` | number(double) | EVENT 값 |

### 4.14 `EventListSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<EventData> | Event 목록 |

### 4.15 `Instance`

| 필드 | 타입 | 설명 |
|---|---|---|
| `configFilePath` | string | 설정 파일 경로 |
| `description` | string | 사용자가 입력한 Instance 설명 |
| `hostName` | string | Host name |
| `instanceId` | integer(int32) | Instance ID |
| `instanceOid` | integer(int32) | Instance OID |
| `ipAddress` | string | Instance IP 주소 |
| `name` | string | Instance 이름 |
| `platform` | string | Platform |
| `status` | string | 상태 |
| `version` | string | 설치된 JENNIFER agent 버전 |

### 4.16 `InstanceCountByStateInDomain`

| 필드 | 타입 | 설명 |
|---|---|---|
| `live` | integer(int32) | Live instance 수 |
| `stopped` | integer(int32) | Stopped instance 수 |
| `total` | integer(int32) | 전체 instance 수 |
| `unlicensed` | integer(int32) | Unlicensed instance 수 |

### 4.17 `InstanceSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<Instance> | Instance 목록 |

### 4.18 `Message`

| 필드 | 타입 | 설명 |
|---|---|---|
| `message` | string | 메시지 |

### 4.19 `Metrics`

| 필드 | 타입 | 설명 |
|---|---|---|
| `application` | array<string> | Application 단위 Metrics 목록 |
| `business` | array<string> | Business 단위 Metrics 목록 |
| `domain` | array<string> | Domain 단위 Metrics 목록 |
| `externalCall` | array<string> | External Call Metrics 목록 |
| `instance` | array<string> | Instance 단위 Metrics 목록 |
| `sql` | array<string> | SQL Metrics 목록 |

### 4.20 `MetricsSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | Metrics | 사용 가능한 Metrics |

### 4.21 `PiSqlData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `parameter` | array<string> | SQL parameter 목록 |
| `sql` | string | SQL 본문 |

### 4.22 `PiSqlSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<PiSqlData> | SQL 정보 목록 |

### 4.23 `RealtimeBusinessData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `activeService` | integer(int32) | Active Services |
| `activeServiceRangeCount0` | integer(int32) | Active Service Equalizer blue count |
| `activeServiceRangeCount1` | integer(int32) | Active Service Equalizer yellow count |
| `activeServiceRangeCount2` | integer(int32) | Active Service Equalizer orange count |
| `activeServiceRangeCount3` | integer(int32) | Active Service Equalizer red count |
| `businessId` | integer(int32) | Business ID |
| `businessName` | string | Business 이름 |
| `domainId` | integer(int32) | Domain ID |
| `responseTime` | number(float) | Response Time(ms) |
| `tps` | number(float) | TPS |

### 4.24 `RealtimeBusinessDataSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<RealtimeBusinessData> | 실시간 Business 데이터 목록 |

### 4.25 `RealtimeDomainData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `activeService` | integer(int32) | Active Services |
| `activeServiceRangeCount0` | integer(int32) | Active Service Equalizer blue count |
| `activeServiceRangeCount1` | integer(int32) | Active Service Equalizer yellow count |
| `activeServiceRangeCount2` | integer(int32) | Active Service Equalizer orange count |
| `activeServiceRangeCount3` | integer(int32) | Active Service Equalizer red count |
| `activeUser` | integer(int32) | Active users |
| `concurrentUser` | number(float) | Concurrent Users |
| `domainId` | integer(int32) | Domain ID |
| `domainName` | string | Domain 이름 |
| `hitDay` | integer(int32) | Daily calls |
| `hitHour` | integer(int32) | Hourly call total |
| `ipAddress` | string | Data Server IP |
| `port` | integer(int32) | Data Server port |
| `rejectRate` | number(float) | PLC에 의해 거부된 application service rate |
| `responseTime` | number(float) | Response Time(ms) |
| `tps` | number(float) | TPS |
| `visitDay` | integer(int32) | Daily Visitors |
| `visitHour` | integer(int32) | Hourly Visitors |

### 4.26 `RealtimeDomainDataSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<RealtimeDomainData> | 실시간 Domain 데이터 목록 |

### 4.27 `RealtimeInstanceData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `activeService` | integer(int32) | Active Services |
| `activeServiceRangeCount0` | integer(int32) | Active Service Equalizer blue count |
| `activeServiceRangeCount1` | integer(int32) | Active Service Equalizer yellow count |
| `activeServiceRangeCount2` | integer(int32) | Active Service Equalizer orange count |
| `activeServiceRangeCount3` | integer(int32) | Active Service Equalizer red count |
| `concurrentUser` | number(float) | Concurrent Users |
| `domainId` | integer(int32) | Domain ID |
| `heapCommitted` | number(float) | Heap Memory Size(MB) |
| `heapUsed` | number(float) | Heap Memory Usage(MB) |
| `hitHour` | integer(int32) | Hourly calls |
| `instanceDescription` | string | Instance 설명 |
| `instanceId` | integer(int32) | Instance ID |
| `instanceName` | string | Instance 이름 |
| `instanceOid` | integer(int32) | Instance OID |
| `procCPU` | number(float) | Process CPU Usage(%) |
| `procMemory` | number(float) | Process Memory Usage(MB) |
| `rejectRate` | number(float) | PLC에 의해 거부된 application service rate |
| `responseTime` | number(float) | Response Time(ms) |
| `tps` | number(float) | TPS |
| `visitDay` | integer(int32) | Daily Visitors |
| `visitHour` | integer(int32) | Hourly Visitors |

### 4.28 `RealtimeInstanceDataSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<RealtimeInstanceData> | 실시간 Instance 데이터 목록 |

### 4.29 `Response`

| 필드 | 타입 | 설명 |
|---|---|---|
| `exception` | Message | 예외 메시지 |

### 4.30 `SqlAndExternalCallStatus`

| 필드 | 타입 | 설명 |
|---|---|---|
| `badResponses` | integer(int32) | Bad Responses |
| `calls` | integer(int32) | Calls |
| `failures` | integer(int32) | Failures |
| `maxResponseTime` | integer(int32) | Max response time |
| `name` | string | SQL 또는 External Call 이름 |
| `responseTime` | number(double) | Response Time(ms) |
| `totalResponseTime` | integer(int64) | Total response time |

### 4.31 `SqlAndExternalCallStatusListSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<SqlAndExternalCallStatus> | SQL/External Call 상태 목록 |

### 4.32 `TransactionData`

| 필드 | 타입 | 설명 |
|---|---|---|
| `applicationName` | string | Application 이름 |
| `business` | array<int32> | Business ID 배열 |
| `businessId` | array<int32> | Business ID. 단일 transaction이 여러 business에 속할 수 있음. |
| `businessName` | array<string> | Business 이름. 단일 transaction이 여러 business에 속할 수 있음. |
| `clientId` | string | HTTP cookie 기반 client-specific ID. 웹 앱 서버 모니터링 시 수집. |
| `clientIp` | string | Client IP. 웹 앱 서버 모니터링 및 header 포함 시 수집. |
| `cpuTime` | integer(int32) | Transaction 수행 중 사용 CPU time |
| `domainId` | integer(int32) | Domain ID |
| `domainName` | string | Domain 이름 |
| `endTime` | string | Transaction 종료 시각 |
| `errorType` | string | Transaction 수행 중 마지막 오류 타입 |
| `externalcallTime` | integer(int32) | External transaction 수행 시간 |
| `fetchTime` | integer(int32) | SQL FETCH 수행 시간 |
| `frontendTime` | integer(int32) | Browser frontend time. 별도 설정 필요. |
| `guid` | string | 여러 transaction을 그룹화하는 Global key |
| `instanceId` | integer(int32) | Instance ID |
| `instanceName` | string | Instance 이름 |
| `instanceOid` | integer(int32) | Instance OID |
| `networkTime` | integer(int32) | Network time |
| `responseTime` | integer(int32) | 서버 transaction 수행 시간 |
| `sqlTime` | integer(int32) | SQL 실행 시간 |
| `startTime` | string | Transaction 시작 시각 |
| `txid` | string | Transaction 고유 key |
| `userId` | string | 업무 의미의 User ID. 별도 설정 필요. |

### 4.33 `TransactionListSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<TransactionData> | Transaction 목록 |

### 4.34 `TransactionSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<TransactionData> | Transaction 목록 |

### 4.35 `User`

| 필드 | 타입 | 설명 |
|---|---|---|
| `group` | string | 사용자 그룹 |
| `id` | string | 사용자 ID |
| `name` | string | 사용자 이름 |
| `password` | string | 비밀번호 |

### 4.36 `UserListSet`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | array<User> | 사용자 목록 |

---

## 5. 호출 예시

### 5.1 Domain 목록 조회

```bash
curl -X GET "http://<VIEW_SERVER_HOST>:<PORT>/api/domain"
```

인증 토큰이 필요한 환경:

```bash
curl -X GET "http://<VIEW_SERVER_HOST>:<PORT>/api/domain" \
  -H "Authorization: Bearer <TOKEN>"
```

### 5.2 Instance 목록 조회

```bash
curl -X GET "http://<VIEW_SERVER_HOST>:<PORT>/api/instance?domain_id=1000"
```

### 5.3 Active Service 목록 조회

```bash
curl -X GET "http://<VIEW_SERVER_HOST>:<PORT>/api/activeService/list?domain_id=1000&instance_id=20001"
```

### 5.4 시간 범위 Transaction 조회

```bash
curl -X GET "http://<VIEW_SERVER_HOST>:<PORT>/api/transaction/time?domain_id=1000&start_time=202606251200&end_time=202606251201&time_pattern=YYYYMMddHHmm"
```

> 원본 Swagger 설명상 `/api/transaction/time`은 1분 범위 제한이 있음.

### 5.5 TXID 프로파일 텍스트 조회

```bash
curl -X GET "http://<VIEW_SERVER_HOST>:<PORT>/api/transaction/profile.txt?domain_id=1000&txid=123456789&time=202606251200&time_pattern=YYYYMMddHHmm"
```

### 5.6 사용자 생성

```bash
curl -X POST "http://<VIEW_SERVER_HOST>:<PORT>/restapi/user/" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "tester",
    "password": "1234",
    "name": "Tester",
    "group": "guest"
  }'
```

---

## 6. Agent Skill 작성 시 권장 지침

### 6.1 엔드포인트 선택 규칙

- 실시간 현황: `/api/realtime/domain`, `/api/realtime/instance`, `/api/realtime/business`
- 현재 실행 중 거래/Active Service: `/api/activeService/list`
- 과거 거래 검색: `/api/transaction/time`, `/api/transaction/txid`, `/api/transaction/guid`
- 거래 상세 SQL: `/api/transaction/sql`
- 거래 Profile 텍스트: `/api/transaction/profile.txt`
- 오류/이벤트 이력: `/api/dbsearch/error`, `/api/dbsearch/event`
- 통계성 상태 조회: `/api/status/application`, `/api/status/sql`, `/api/status/external_call`
- Metrics 시계열: `/api/dbmetrics/domain`, `/api/dbmetrics/instance`, `/api/dbmetrics/business`
- 기준 정보: `/api/domain`, `/api/instance`, `/api/business`, `/api/metrics`
- 사용자 관리: `/restapi/user/`, `/restapi/user/{id}`, `/restapi/users`

### 6.2 안전한 호출 원칙

- 조회 API는 우선 `GET`을 사용한다.
- 조회 범위가 큰 API는 `start_time`, `end_time`, `instance_id`, `max_row`를 반드시 제한한다.
- `/api/transaction/time`은 1분 범위 제한이 있으므로 긴 기간은 분 단위로 나누어 호출한다.
- `time_pattern`을 지정할 때는 입력값과 출력값 해석이 함께 바뀌므로 호출 전 패턴을 명시한다.
- 인증 토큰, 호스트, 포트는 Skill 설정값 또는 환경변수로 분리한다.
- 장애 대응 자동화에서는 원문 payload와 HTTP status를 로그에 남긴다.

### 6.3 Skill 환경변수 예시

```yaml
jennifer:
  view_server_url: "http://<VIEW_SERVER_HOST>:<PORT>"
  api_token: "<TOKEN>"
  default_domain_id: 1000
  timeout_seconds: 10
```

### 6.4 내부망 경로 주의

- 이 Markdown은 `jennifer-developer-guide`의 기존 API 명세 기준이다.
- 경로는 `/api/...` 기준이다.
- `/api-v2/...`만 지원하는 서버나, 반대로 내부에서 `/api-v2`를 `/api`로 치환해야 하는 서버는 Skill의 base path 변환 로직에서 조정한다.
---

# 부록 A. JENNIFER5 Open API v2 Manual 추가 명세

> 원본: `https://github.com/jennifersoft/jennifer5-open-api-v2-manual`  
> 기준 브랜치: `main`  
> 용도: Qwen Code / Codex / 내부 Agent Skill 등록용 API Reference.  
> v2 매뉴얼은 제니퍼 서버 5.5.3 이후 새로 추가된 Open API를 간이 문서 형태로 정리한 저장소이다.

## A.1 v2 기본 사용 규칙

### 인증 방식

모든 v2 API는 인증정보가 필요하다. 요청 헤더에 다음과 같이 인증 토큰을 넣어 요청한다.

```http
Authorization: Bearer <인증토큰>
```

인증 토큰은 JENNIFER5 화면의 `[관리 > 인증 토큰 관리]` 메뉴에서 발급한다.

일부 조회 API는 브라우저에서 간편하게 호출할 수 있으며, 이 경우 `token` query parameter를 사용할 수 있다. 단, 브라우저 방식은 인증 토큰이 브라우저 기록에 남을 수 있으므로 운영 자동화에서는 `Authorization` 헤더 방식을 우선 사용한다.

### 인증 테스트 API

| 항목 | 값 |
|---|---|
| Method | `GET` |
| Path | `/api-v2/auth-test` |
| URL 형식 | `http(s)://<호스트>:<포트>/api-v2/auth-test` |
| 응답 | `OK` |

```bash
curl --request GET "https://java.jennifersoft.com/api-v2/auth-test" \
  -H "Authorization: Bearer ABCD1234"
```

브라우저 호출 예시:

```text
https://java.jennifersoft.com/api-v2/auth-test?token=ABCD1234
```

### 공통 HTTP 응답 코드

| 코드 | 의미 |
|---|---|
| `200` | 처리되었음을 의미한다. API 명세에서 특별한 언급이 없으면 이 응답으로 내려간다. |
| `400 Bad Request` | 잘못된 요청이다. 응답 메시지와 API 명세를 확인한다. |
| `401 Unauthorized` | 인증 실패. 인증 토큰이 유효한지, 형식에 맞게 요청했는지 확인한다. |
| `404 Not Found` | 요청한 데이터가 없거나 유효하지 않은 API를 요청했을 때 발생한다. |
| `405 Method Not Allowed` | 유효하지 않은 HTTP Method로 요청했다. API별 지원 Method를 확인한다. |
| `500~599` | 서버 문제. 응답 메시지와 뷰서버 로그를 확인한다. |

## A.2 v2 API 전체 인덱스

| 구분 | Method | Path | 설명 | 출처 파일 |
|---|---:|---|---|---|
| 인증 | GET | `/api-v2/auth-test` | 인증 토큰 정상 여부 확인 | `README.md` |
| 관리/인스턴스 | GET | `/api-v2/manage/instance?processId=<프로세스ID>&hostname=<호스트네임>` | 호스트네임과 프로세스 ID로 인스턴스 찾기 | `instance-list-by-process-id.md` |
| 관리/액티브서비스 | GET | `/api-v2/active-service/detail/<도메인아이디>/<트랜잭션아이디>?sessionId=<에이전트 세션 아이디>&threadHash=<스레드 해시>` | 단일 액티브 서비스 상세 조회 | `active-service-detail.md` |
| 관리/DB | GET | `/api-v2/manage/db/path/<도메인ID>` | JENNIFER DB 경로 조회 | `db-path.md` |
| 관리/EVENT 룰 | GET | `/api-v2/manage/rule/event/error/<도메인아이디>` | ERROR EVENT 설정 조회 | `manage-rule-event.md` |
| 관리/EVENT 룰 | GET | `/api-v2/manage/rule/event/metric/<도메인아이디>/<대상타입>` | Metric EVENT 설정 조회 | `manage-rule-event.md` |
| 관리/EVENT 룰 | GET | `/api-v2/manage/rule/event/compare/<도메인아이디>/<대상타입>` | 비교 EVENT 설정 조회 | `manage-rule-event.md` |
| 관리/EVENT 룰 | GET | `/api-v2/manage/rule/event/error/<도메인아이디>/<ERROR유형>/applied` | ERROR EVENT 룰 적용 여부 조회 | `manage-rule-event-error-applied.md` |
| 관리/EVENT 룰 | PUT | `/api-v2/manage/rule/event/error/<도메인아이디>/<ERROR유형>/applied` | ERROR EVENT 룰 적용 On/Off 저장 | `manage-rule-event-error-applied.md` |
| 관리/EVENT 룰 | GET | `/api-v2/manage/rule/event/error/<도메인아이디>/<ERROR유형>/individual-setting/<인스턴스아이디>` | ERROR EVENT 대상별 설정 조회 | `manage-rule-event-error-individual.md` |
| 관리/EVENT 룰 | PUT | `/api-v2/manage/rule/event/error/<도메인아이디>/<ERROR유형>/individual-setting/<인스턴스아이디>` | ERROR EVENT 대상별 설정 저장 | `manage-rule-event-error-individual.md` |
| 관리/EVENT 룰 | DELETE | `/api-v2/manage/rule/event/error/<도메인아이디>/<ERROR유형>/individual-setting/<인스턴스아이디>` | ERROR EVENT 대상별 설정 제거 | `manage-rule-event-error-individual.md` |
| 관리/룰 | GET | `/api-v2/manage/rule/active-service-color-range-boundary` | 액티브 서비스 경과시간 색상 경계값 조회 | `active-service-color-range-boundary.md` |
| RDB Export | POST | `/api-v2/manual-rdb-export?date=<YYYY-MM-DD>` | 지난 날짜의 RDB Export 작업 추가 | `manual-rdb-export.md` |
| RDB Export | GET | `/api-v2/manual-rdb-export` | RDB Export 작업 진행 상태 조회 | `manual-rdb-export.md` |
| RDB Export | PUT | `/api-v2/configuration/rdb-export-password-override` | RDB Export 대상 DB 접속 암호 설정 | `rdb-export-password-override.md` |
| RDB Export | DELETE | `/api-v2/configuration/rdb-export-password-override` | RDB Export 대상 DB 접속 암호 삭제 | `rdb-export-password-override.md` |
| 분석/배포 | GET | `/api-v2/deploy/<도메인ID>?startTime=<조회범위시작시간>&endTime=<끝시간>` | 소스코드/리소스 변경 이력 조회 | `deploy.md` |
| 분석/클래스 | GET | `/api-v2/loaded-class/<도메인ID>/<인스턴스ID>?search=<클래스이름의일부>` | 로디드 클래스 조회 | `loaded-class.md` |
| 분석/환경변수 | GET | `/api-v2/environment-variable/<도메인ID>` | 시스템 환경변수 조회 | `environment-variable.md` |

> 주의: `manage-rule-event.md` 원문에서 비교 EVENT는 Path 형식에 `/compare/`로 표기되어 있으나 요청 예제는 `/comparing/`으로 표기되어 있다. Skill 구현 시 실제 운영 서버에서 지원되는 경로를 확인하거나, 필요 시 둘 다 fallback 처리한다.

---

## A.3 원문 README 통합본

## JENNIFER5 Open API

제니퍼 서버 5.5.3 이후 새로 추가하는 Open API에 대해 간이로 작성하고 있는 문서입니다. 기존 API는 다음 사이트를 참고하시기 바랍니다.

https://jennifersoft.github.io/jennifer-developer-guide

### 인증 하기

모든 API는 인증정보가 필요합니다. 요청 헤더에 다음과 같이 인증토큰을 넣어 요청합니다. 인증토큰은 제니퍼5 화면의 [관리 > 인증 토큰 관리] 메뉴에서 발급합니다.

`Authorization: Bearer <인증토큰>`

일부 조회API는 브라우저에서 간편하게 호출할 수 있습니다. 아래 예제를 참고합니다.

### 가장 간단한 API - 인증 테스트하기

다음 URL로 HTTP를 요청하면 인증이 잘 되는지 확인할 수 있습니다. Open API 사용이 처음이면, 먼저 이 API를 이용해서 인증까지 확인하는 것을 권장합니다.

- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/auth-test`
- 요청 예제
    - curl : `> curl --request GET https://java.jennifersoft.com/api-v2/auth-test -H "Authorization: Bearer ABCD1234"`
    - 브라우저 : `https://java.jennifersoft.com/api-v2/auth-test?token=ABCD1234` (GET만 가능)
    - 인증토큰이 `ABCD1234`일 때의 예입니다. 브라우저 방식은 인증토큰이 브라우저 기록에 남을 수 있습니다. 주의하시기 바랍니다.

응답으로 `OK`를 확인하면 인증이 제대로 된 것입니다. 문제가 있으면 아래의 [공통 HTTP 응답 코드 설명](#공통-http-응답-코드)과 메시지를 확인합니다.

### API 명세

- 관리
    - 인스턴스
        - [호스트네임과 프로세스ID로 인스턴스 찾기](#a42-호스트네임과-프로세스id로-인스턴스-찾기)
        - [액티브 서비스 상세 조회하기](#a41-액티브-서비스-상세-조회하기)
    - [JENNIFER DB 경로 조회](#a43-jennifer-db-경로-조회하기)
    - EVENT 룰
        - [EVENT 룰 설정 조회](#a48-event-룰-설정-조회)
        - [ERROR EVENT 룰 적용 On/Off 제어](#a46-error-event-룰-적용-onoff-제어)
        - [ERROR EVENT 대상별 설정 제어](#a47-error-event-대상별-설정)
    - [액티브 서비스 경과시간 범위 조회하기](#a44-액티브-서비스-경과시간-범위-조회하기)
- RDB Export
    - [지난 날짜의 RDB Export 작업 추가하기](#a49-수동-rdb-export-작업)
    - [RDB Export 대상 DB의 접속 암호 설정하기](#a410-rdb-export-대상-db의-접속-암호-설정하기)
- [소스코드(리소스) 변경이력 조회](#a45-소스코드리소스변경이력-조회하기)
- [로디드 클래스 조회하기](#a412-로디드-클래스-조회하기)
- [시스템 환경변수 조회하기](#a411-시스템-환경변수-조회하기)

### 공통 HTTP 응답 코드

- 400 Bad Request : 잘못된 요청입니다. 응답의 메시지와 API명세를 확인합니다.
- 401 Unauthorized : 인증에 실패했습니다. 인증 토큰이 유효한지, 형식에 맞게 요청했는지 확인합니다.
- 404 Not Found : 요청한 데이터가 없습니다. 응답의 메시지를 확인합니다. 유효하지 않은 API를 요청했을 때도 발생합니다.
- 405 Method Not Allowed : 유효하지 않은 메소드(GET,POST 등)로 요청했습니다. API의 명세를 보고 지원하는 메소드인지 확인합니다.
- 500~599 : 서버에서 문제가 발생했습니다. 응답의 메시지와 뷰서버의 로그를 확인합니다. 그래도 문제를 해결할 수 없으면 지원을 요청합니다.
- 200 : 처리되었음을 의미합니다. API명세에서 특별한 언급이 없으면 이 응답으로 내려갑니다.

---

## A.4 v2 Spec 원문 통합본

### A.4.1 액티브 서비스 상세 조회하기

## Open API 명세 - 액티브 서비스 상세 조회하기 (5.6.1)

액티브 서비스 목록의 단일 액티브 서비스 상세 정보를 조회합니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

- Method : GET
- URL 형식 : `http(s)://<호스트>:<포트>/api-v2/active-service/detail/<도메인아이디>/<트랜잭션아이디>?sessionId=<에이전트 세션 아이디>&threadHash=<액티브 서비스를 실행중인 스레드의 해시>`
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/active-service/detail/1000/1234567?sessionId=1&threadHash=10" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/active-service/detail/1000/1234567?sessionId=1&threadHash=10&token=ABCD1234`
- 응답 예제 :
```json
{
  "userId": "jennifer",
  "guid": "guid",
  "sql": "select * from jennifer",
  "http": {
    "method": "get",
    "query": "a=1&b=2"
  }
}
```

* 요청 파라미터의 각종 정보는 액티브 서비스 상세 조회 api 의 결과에 포함된 값입니다.

### A.4.2 호스트네임과 프로세스ID로 인스턴스 찾기

## Open API 명세 - 호스트네임과 프로세스ID로 인스턴스 찾기 (서버 5.6.0.21 이상)

호스트네임과 프로세스ID로 인스턴스를 찾습니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.
- Method : GET
- URL 형식 : `http(s)://<호스트>:<포트>/api-v2/manage/instance?processId=<프로세스ID>&hostname=<호스트네임>`
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/manage/instance?processId=1234&hostname=myhost" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/instance?processId=1234&hostname=myhost&token=ABCD1234`
* 응답 예제 :
  ```json
  {
    "1000": {
      "20000": { "hostname":"myhost" }
    }
  }
  ```
  * 도메인ID 1000, 인스턴스ID 20000인 인스턴스가 검색된 응답입니다.
  * 일반적인 경우 응답의 인스턴스는 1개를 초과하지 않습니다. 조건에 맞는 인스턴스가 없으면 비어 있습니다. -> ```{}```
- 지원하는 에이전트 최소 버전: Java 5.6.0.8, PHP 5.6.0.6, .Net 5.6.0.21
  - 지원하지 않는 버전의 인스턴스는 찾아지지 않습니다.

### A.4.3 JENNIFER DB 경로 조회하기

## Open API 명세 - JENNIFER DB 경로 조회하기 (5.6.0.6 이상)

화면 [설정 > JENNIFER DB > 보관 설정 > 경로] 데이터를 조회합니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

- Method : GET
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/manage/db/path/<도메인ID>`
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/manage/db/path/1000" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/db/path/1000?token=ABCD1234`
- 응답 예제 :
```json
{
  "main": "/home/jennifer/jennifer5/db/data",
  "backup": "/home/jennifer/jennifer5/db/data"
}
```

### A.4.4 액티브 서비스 경과시간 범위 조회하기

## Open API 명세 - 액티브 서비스 경과시간 범위 조회하기 (5.6.0.11)

[설정 > 룰 > 액티브 서비스 경과시간 범위] 화면의 데이터를 조회합니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

- Method : GET
- URL 형식 : `http(s)://<호스트>:<포트>/api-v2/manage/rule/active-service-color-range-boundary`
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/manage/rule/active-service-color-range-boundary" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/rule/active-service-color-range-boundary?token=ABCD1234`
- 응답 예제 :
```json
[3000, 5000, 8000]
```
- 응답 형식 : 경과시간이 작은 순서입니다. 순서대로 파란색, 연두색, 주황색, 빨간색 사이의 경계값입니다.

### A.4.5 소스코드(리소스)변경이력 조회하기

## Open API 명세 - 소스코드(리소스)변경이력 조회하기 (5.6.0.5 이상)

화면 [분석 > 소스코드(리소스)변경이력] 데이터 중 일부를 조회합니다. 변경된 시각과 인스턴스ID를 조회할 수 있습니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

- Method : GET
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/deploy/<도메인ID>?startTime=<조회범위시작시간>&endTime=<끝시간>`
  - 조회범위는 ms단위이고, 25시간(endTime-startTime) 이하만 지원합니다.
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/deploy/1000?startTime=1628757635000&endTime=1628758635000" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/deploy/1000?startTime=1628757635000&endTime=1628758635000&token=ABCD1234`
- 응답 예제 :
```json
[
  { "collectTime": 1628757730967, "instanceId": 20000 },
  { "collectTime": 1628757910322, "instanceId": 20003 }
]
```
응답 중 `collectTime`은 제니퍼5 데이터서버 기준으로 변경을 인지한 시간입니다.

### A.4.6 ERROR EVENT 룰 적용 On/Off 제어

## API 명세 - ERROR EVENT 룰 적용 On/Off 제어 (5.5.3.3 이상)

화면의 [관리 > 룰 > EVENT룰 > ERROR EVENT > ERROR유형 > 룰 적용] On/Off여부를 API로 제어합니다.

Open API 사용이 처음이면 먼저 [기본적인 사용법](#a3-원문-readme-통합본)을 숙지합니다.

#### 조회하기
- Method : GET
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/manage/rule/event/error/<도메인아이디>/<ERROR유형>/applied`
- 요청 예제 (7002 도메인의 AGENT_STOP ERROR EVENT의 룰 적용 여부 조회하기)
    - curl : `> curl --request GET https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002/AGENT_STOP/applied -H "Authorization: Bearer ABCD1234"`
    - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002/AGENT_STOP/applied?token=ABCD1234`
- 응답: `true` 또는 `false`

#### 저장하기
- Method : PUT
- Content-Type: application/json
- Content : 설정값. `true` 또는 `false`
- 요청 예제 (Off로 변경하기)
  - `> curl --request PUT https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002/AGENT_STOP/applied -H "Authorization: Bearer ABCD1234" -H "Content-Type: application/json" -d "false"`
- 응답 : 없음

### A.4.7 ERROR EVENT 대상별 설정

# API 명세 - ERROR EVENT 대상별 설정
화면의 [관리 > 룰 > EVENT룰 > ERROR EVENT > ERROR유형 > 대상별 설정] 기능을 API로 제어합니다. 화면으로 사용성을 충분히 이해한 후에 사용하시기 바랍니다. Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

#### Path 형식
`http(s)://<호스트>:<포트>/api-v2/manage/rule/event/error/<도메인아이디>/<ERROR유형>/individual-setting/<인스턴스아이디>`

#### 조회하기
- Method : GET
- 요청 예제
    - curl : `> curl --request GET https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002/AGENT_STOP/individual-setting/10001 -H "Authorization: Bearer ABCD1234"`
    - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002/AGENT_STOP/individual-setting/10001?token=ABCD1234`
- 응답: 설정 값이 있으면 `true` 또는 `false`, 없으면 404.

#### 저장하기
- Method : PUT
- Content-Type: application/json
- Content : 설정값. `true` 또는 `false`
- 요청 예제 (7002 도메인 10001 인스턴스의 AGENT_STOP EVENT가 발생하지 않도록 설정하기)
    - `> curl --request PUT https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002/AGENT_STOP/individual-setting/10001 -H "Authorization: Bearer ABCD1234" -H "Content-Type: application/json" -d "false"`
- 응답 데이터: 없음

#### 제거하기
- Method : DELETE
- 요청 예제
    - `> curl --request DELETE https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002/AGENT_STOP/individual-setting/10001 -H "Authorization: Bearer ABCD1234"`
- 응답 데이터: 없음

### A.4.8 EVENT 룰 설정 조회

## Open API 명세 - EVENT 룰 설정 조회 (5.5.3.5 이상)

화면의 [관리 > 룰 > EVENT룰] 화면의 설정정보를 API로 조회합니다. 응답 데이터는 화면을 참고하면 대부분 직관적으로 알 수 있습니다. 몇몇 데이터에 대한 추가 설명은 [응답 데이터에 대한 추가 설명](#응답-데이터에-대한-추가-설명)을 참고합니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

#### ERROR EVENT 설정 조회하기
- Method : GET
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/manage/rule/event/error/<도메인아이디>`
- 요청 예제
  - curl : `> curl --request GET https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002 -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/rule/event/error/7002?token=ABCD1234`
- 응답 예제
```json
[
  {
    "errorType" : "SERVICE_EXCEPTION",
    "applied" : true,
    "level" : "WARNING",
    "checkTimeRange" : 60000,
    "thresholdErrorCount" : 1,
    "iconRecoveryTime" : 60000,
    "customMessage" : "hello world",
    "autoScriptCommand" : "/etc/handle_event.sh"
  }
  ...
]
```

#### Metric EVENT 설정 조회하기
- Method : GET
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/manage/rule/event/metric/<도메인아이디>/<대상타입>`
  - `<대상타입>` : `domain`, `instance`, `business` 중 하나.
- 요청 예제
  - curl : `> curl --request GET https://java.jennifersoft.com/api-v2/manage/rule/event/metric/7002 -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/rule/event/metric/7002?token=ABCD1234`
- 응답 예제 :
```json
[
  {
    "metricId" : "heap_usage",
    "level" : "NORMAL",
    "applied" : true,
    "expression" : "value>30",
    "checkTimeRange" : 60000,
    "thresholdErrorCount" : 1,
    "iconRecoveryTime" : 60000,
    "customMessage" : "hello world",
    "autoScriptCommand" : "/etc/handle_event.sh"
  }
  ...
]
```

#### 비교 EVENT 설정 조회하기
- Method : GET
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/manage/rule/event/compare/<도메인아이디>/<대상타입>`
  - `<대상타입>` : `domain`, `instance` 중 하나.
- 요청 예제
  - curl : `> curl --request GET https://java.jennifersoft.com/api-v2/manage/rule/event/comparing/1006/instance -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/manage/rule/event/comparing/1006/instance?token=ABCD1234`
- 응답 예제 :
```json
[
  {
    "metricId" : "service_rate",
    "level" : "NORMAL",
    "applied" : true,
    "iconRecoveryTime" : 60000,
    "target" : {
      "operator" : ">",
      "period" : "PREVIOUS_WEEK",
      "ratioInPercent" : 130
    },
    "filter" : {
      "metricId" : "service_rate",
      "minimumValue" : 3.0
    }
  }
  ...
]
```

#### 응답 데이터에 대한 추가 설명
- 모든 시간 값은 ms 단위입니다.
- level : NORMAL, WARNING, FATAL 중 하나입니다.
- autoScriptCommand, filter : 활성화 하지 않은 경우 null 입니다.

### A.4.9 수동 RDB Export 작업

## Open API 명세 - 수동 RDB Export 작업 (5.6.0.1 이상)

지난 날짜의 데이터를 RDB Export하는 API입니다. RDB Export 기능은 제니퍼5 엔지니어 문서를 참고하여 숙지하시기 바랍니다.
API파라메터인 날짜를 제외한 다른 설정은 conf파일에 명시한 RDB Export설정(rdb_export_)을 따릅니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

#### 작업 추가하기
- Method : POST
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/manual-rdb-export?date=<YYYY-MM-DD>`
- 요청 예제
  - curl : `> curl --request POST "https://java.jennifersoft.com/api-v2/manual-rdb-export?date=2021-05-29" -H "Authorization: Bearer ABCD1234"`
- 응답 예제
```text
OK. id=311d6aaa
```

#### 진행 상태 조회하기
- 현재 상태를 조회합니다. 어떤 작업이 진행 중이고 대기 중인지 알 수 있습니다. 진행 단계의 자세한 기록은 뷰서버의 RDB Export 로그파일에 기록됩니다.
- Method : GET
- Path 형식 : `http(s)://<호스트>:<포트>/api-v2/manual-rdb-export`
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/manual-rdb-export" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/manual-rdb-export?token=ABCD1234`
- 응답 예제 :
```json
[
   {"id":"2e96102f","date":"2021-05-27","statusDescription":"COMPLETED"},
   {"id":"311d6aaa","date":"2021-05-29","statusDescription":"EXPORTING"}
]
```

### A.4.10 RDB Export 대상 DB의 접속 암호 설정하기

## Open API 명세 - RDB Export 대상 DB의 접속 암호 설정하기 (서버 5.6.1.2 이상)

RDB Export 대상 DB의 접속 암호를 설정합니다. RDB Export 기능은 제니퍼5 엔지니어 문서를 참고하여 숙지하시기 바랍니다.

이 API는 뷰서버 conf 파일에 지정하는 `rdb_export_jdbc_password` 옵션의 대안입니다. 이 API를 이용하면 옵션과 다르게 암호를 파일에 노출시키지 않을 수 있습니다. conf 파일의 옵션으로도 암호가 설정된 경우 이 API로 설정한 값을 사용합니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

#### 암호 설정하기

- Method : PUT
- URL : `http(s)://<호스트>:<포트>/api-v2/configuration/rdb-export-password-override`
- Content-Type: text/plain
- Request Body: 설정할 암호
- 요청 예제
  - curl : `> curl --request PUT "https://java.jennifersoft.com/api-v2/configuration/rdb-export-password-override" -H "Content-type: text/plain" -H "Authorization: Bearer ABCD1234" -d "XYZ1234"`
* 응답 예제 :
  ```json
  "Password: XYZ1234"
  ```
  * 설정된 값을 응답으로 줍니다. 보안을 위해 별도의 조회 API는 제공하지 않습니다.

#### 암호 삭제하기
- Method : DELETE
- URL : `http(s)://<호스트>:<포트>/api-v2/configuration/rdb-export-password-override`
- 요청 예제
  - curl : `> curl --request DELETE "https://java.jennifersoft.com/api-v2/configuration/rdb-export-password-override" -H "Authorization: Bearer ABCD1234"`

### A.4.11 시스템 환경변수 조회하기

## Open API 명세 - 시스템 환경변수 조회하기 (5.6.0.9 이상)

[분석 > 시스템 환경변수] 화면의 데이터를 조회합니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

- Method : GET
- URL 형식 : `http(s)://<호스트>:<포트>/api-v2/environment-variable/<도메인ID>`
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/environment-variable/1000" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/environment-variable/1000?token=ABCD1234`
- 응답 예제 :
```json
{
  "20001": {
    "SYSTEM": {
      "PATH": "/usr/local/sbin:/usr/local/bin",
      "JAVA_HOME": "/usr/java/jdk1.6.0_45"
    },
    "JAVA": {
      "java.vendor": "Sun Microsystems Inc."
    }
  },
  "20002": {
    "SYSTEM": {}
  }
}
```

### A.4.12 로디드 클래스 조회하기

## Open API 명세 - 로디드 클래스 조회하기 (5.6.0.8 이상)

화면 [분석 > 로디드 클래스] 데이터를 조회합니다.

Open API 사용이 처음이라면 기본적인 사용법을 [README](#a3-원문-readme-통합본)를 참고하여 숙지합니다.

- Method : GET
- URL 형식 : `http(s)://<호스트>:<포트>/api-v2/loaded-class/<도메인ID>/<인스턴스ID>?search=<클래스이름의일부(optional)>`
- 요청 예제
  - curl : `> curl --request GET "https://java.jennifersoft.com/api-v2/loaded-class/1000/20001?search=jennifersoft" -H "Authorization: Bearer ABCD1234"`
  - 브라우저 : `https://java.jennifersoft.com/api-v2/loaded-class/1000/20001?search=jennifersoft&token=ABCD1234`
- 응답 예제 :
```json
[
  {
    "className": "com.jennfiersoft.StringUtil",
    "superClassName": "java.lang.Object",
    "interfaceClassNames": [ "javax.servlet.ServletContextListener", "java.lang.Cloneable" ],
    "classLoaderName": "BootstrapClassLoader module java.base"
  },
  {
    "className": "com.jennifersoft.Log"
  }
]
```
- 제약
  - 로드된 클래스가 6만개 이하인 경우에만 조회할 수 있습니다.
  - 검색은 클래스이름 검색만 지원합니다.

## A.5 v2 Skill 구현 메모

### A.5.1 Base URL 처리

v2 원문은 `/api-v2/...` 기준이다. 다만 내부 환경에서 `/api-v2/`가 지원되지 않고 `/api/`만 지원되는 경우에는 Skill 내부에서 다음과 같이 변환한다.

| 원문 경로 | 내부 치환 예시 |
|---|---|
| `/api-v2/auth-test` | `/api/auth-test` |
| `/api-v2/manage/instance` | `/api/manage/instance` |
| `/api-v2/active-service/detail/...` | `/api/active-service/detail/...` |

### A.5.2 인증 처리

```yaml
jennifer:
  view_server_url: "http://<VIEW_SERVER_HOST>:<PORT>"
  api_token: "<TOKEN>"
  default_domain_id: 1000
  api_v2_path_mode: "api"   # 원문 그대로면 api-v2, 내부 치환이면 api
  timeout_seconds: 10
```

요청 시 기본 헤더:

```http
Authorization: Bearer ${api_token}
```

### A.5.3 장애 모니터링 Skill에서 우선 활용할 v2 API

| 목적 | 우선 API |
|---|---|
| 인증 확인 | `GET /api-v2/auth-test` |
| 서버/인스턴스 식별 | `GET /api-v2/manage/instance?processId=&hostname=` |
| 실시간 액티브 서비스 상세 | `GET /api-v2/active-service/detail/{domainId}/{txid}?sessionId=&threadHash=` |
| 이벤트 룰 확인 | `GET /api-v2/manage/rule/event/error/{domainId}` |
| 시스템 환경 확인 | `GET /api-v2/environment-variable/{domainId}` |
| 로디드 클래스 확인 | `GET /api-v2/loaded-class/{domainId}/{instanceId}?search=` |
| 배포/리소스 변경 확인 | `GET /api-v2/deploy/{domainId}?startTime=&endTime=` |
