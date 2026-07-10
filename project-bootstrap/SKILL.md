---
name: project-bootstrap
description: Use this skill when the user asks to initialize, summarize, document, map, or prepare a large project for better AI coding, vibe coding, source analysis, onboarding, project memory, architecture memory, or KOBI project context. This skill creates project memory documents under .kobi after analyzing source structure.
---

# Project Bootstrap Skill

## 목적

대규모 프로젝트의 소스 구조와 업무 흐름을 KOBI가 이해하기 쉬운 형태로 정리한다.

이 Skill은 프로젝트 루트에 `.kobi` 폴더를 만들고, 이후 코드 분석과 바이브코딩 정확도를 높이기 위한 프로젝트 메모리 문서를 생성한다.

## 생성 대상 문서

기본적으로 아래 문서를 생성한다.

```text
.kobi/
├─ INDEX.md
├─ PROJECT_SUMMARY.md
├─ ARCHITECTURE.md
├─ FLOW.md
├─ API_GUIDE.md
├─ CODING_GUIDE.md
├─ OPERATIONS.md
└─ TROUBLESHOOTING.md
```

## 사용해야 하는 경우

이 Skill은 아래 요청에 사용한다.

- 이 프로젝트를 KOBI가 잘 이해하도록 정리해줘
- 바이브코딩이 잘되도록 프로젝트 정보를 정리해줘
- 대규모 프로젝트 구조를 요약해줘
- 프로젝트 메모리를 만들어줘
- 프로젝트 부트스트랩 해줘
- 신규 프로젝트 분석 문서를 만들어줘
- Controller, Service, Mapper, SQL 흐름을 정리해줘
- Java Spring 프로젝트 구조를 정리해줘
- 운영/장애/배포 관점의 프로젝트 가이드를 만들어줘

## 사용하지 말아야 하는 경우

- 단순 코드 질문
- 단일 파일 수정
- 짧은 오류 메시지 분석
- 사용자가 프로젝트 문서 생성을 원하지 않는 경우
- 프로젝트 루트가 아닌 디렉터리에서 실행된 경우

## 최우선 원칙

- 먼저 프로젝트 루트인지 확인한다.
- 파일 수정 전에 생성 계획을 먼저 제시한다.
- 사용자가 승인하기 전에는 문서를 생성하거나 수정하지 않는다.
- 기존 `.kobi` 문서가 있으면 덮어쓰기 전에 확인한다.
- 기존 `QWEN.md`가 있으면 자동 수정하지 말고, 추가할 문구만 제안한다.
- 분석 대상은 소스, 설정, 빌드 파일 중심으로 제한한다.
- 암호화 문서, 오피스 문서, PDF, 이미지, 인증서, 운영 설정 파일은 분석하지 않는다.
- 민감정보 파일은 읽지 않는다.
- 대량 파일을 무작정 모두 읽지 않는다.
- 먼저 구조를 파악한 뒤 필요한 파일만 선별해서 읽는다.
- 추정과 확정을 구분한다.
- 모르는 내용은 모른다고 표시한다.

## 읽어도 되는 대표 파일

아래 파일은 프로젝트 구조 파악에 사용할 수 있다.

```text
pom.xml
build.gradle
settings.gradle
gradle.properties
package.json
README.md
QWEN.md
.gitignore
.qwenignore
src/main/java/**/*.java
src/main/resources/**/*.xml
src/main/resources/**/*.yml
src/main/resources/**/*.yaml
src/main/resources/**/*.properties
src/test/**/*.java
```

## 읽지 말아야 하는 파일

아래 파일은 읽거나 요약하지 않는다.

```text
.env
*.jks
*.p12
*.key
*.pem
*.cer
*.crt
*.der
*.keystore
*password*
*passwd*
*secret*
*token*
*credential*
application-prod*
application-real*
application-prd*
application-live*
target/
build/
out/
.gradle/
.idea/
.git/
node_modules/
```

## 기본 절차

### 1단계. 프로젝트 루트 확인

먼저 현재 디렉터리에 아래 항목이 있는지 확인한다.

```text
pom.xml
build.gradle
settings.gradle
src/
.git/
README.md
```

프로젝트 루트가 아니면 사용자에게 프로젝트 루트로 이동하도록 안내한다.

### 2단계. 프로젝트 인벤토리 생성

가능하면 아래 스크립트를 사용한다.

```powershell
.\scripts\Get-ProjectInventory.ps1 -ProjectRoot "."
```

단, Skill 폴더 안의 scripts를 직접 참조해야 하므로 실행 전 실제 경로를 확인한다.

스크립트 사용이 어렵다면 Qwen Code의 파일 검색 기능으로 직접 구조를 확인한다.

### 3단계. 생성 계획 제시

문서를 만들기 전에 아래를 사용자에게 보여준다.

```text
생성할 폴더:
.kobi

생성할 문서:
- INDEX.md
- PROJECT_SUMMARY.md
- ARCHITECTURE.md
- FLOW.md
- API_GUIDE.md
- CODING_GUIDE.md
- OPERATIONS.md
- TROUBLESHOOTING.md

분석 대상:
- 빌드 파일
- 주요 Java 패키지
- Controller/Service/Mapper/XML
- resources 설정
- 테스트 구조

분석 제외:
- 인증서
- 운영 설정
- 비밀번호/토큰
- build 결과물
- .git
```

사용자가 승인하면 문서를 생성한다.

### 4단계. 문서 작성 기준

각 문서는 아래 기준으로 작성한다.

#### INDEX.md

- `.kobi` 문서의 목차
- 각 문서를 언제 참조해야 하는지 설명
- KOBI에게 작업 전 어떤 문서를 먼저 읽어야 하는지 안내

#### PROJECT_SUMMARY.md

- 프로젝트 목적
- 주요 업무
- 기술 스택
- 빌드 방식
- 실행 방식
- 주요 디렉터리
- 핵심 패키지
- 외부 연계
- 주의사항

#### ARCHITECTURE.md

- 전체 아키텍처
- 레이어 구조
- Controller → Service → Mapper → DB 흐름
- 공통 모듈
- 예외 처리 구조
- 트랜잭션 구조
- 캐시/세션/메시징 사용 여부
- 주요 설정 파일

#### FLOW.md

- 주요 업무별 호출 흐름
- API 진입점
- Controller
- Service
- Mapper
- SQL/XML
- 외부 연계
- 후속 처리
- 예외 흐름

#### API_GUIDE.md

- 내부 API 호출 방식
- MCI/EAI/Gateway 연계
- Timeout/Retry 기준
- 요청/응답 DTO 규칙
- 인터페이스 버전 관리
- API 분석 시 확인할 파일
- API 변경 시 영향도 확인 절차

#### CODING_GUIDE.md

- 패키지 네이밍
- 클래스 네이밍
- 메서드 작성 규칙
- DTO/VO 사용 규칙
- 로그 작성 기준
- 예외 처리 기준
- 테스트 작성 기준
- 최소 구현 원칙
- 코드 리뷰 체크리스트

#### OPERATIONS.md

- 운영 반영 전 확인사항
- 설정 변경 시 확인사항
- 로그 확인 위치
- Jennifer/APM 확인 기준
- 배포 후 점검 항목
- 장애 발생 시 1차 확인 항목

#### TROUBLESHOOTING.md

- 자주 발생하는 오류
- DB 오류
- Timeout
- 인터페이스 버전 불일치
- Redis/Session 문제
- 외부 API 오류
- 로그 확인 방법
- 추가 확인 체크리스트

## 출력 원칙

- 모든 문서는 한국어로 작성한다.
- 코드, 클래스명, 파일명, SQL, 설정 키는 원문 유지한다.
- 추정 내용은 “추정”으로 표시한다.
- 확인된 내용은 “확인”으로 표시한다.
- 파일 경로를 함께 적는다.
- 너무 긴 원문 코드는 붙여넣지 말고 요약한다.
- 문서마다 마지막에 “추가 확인 필요사항”을 둔다.

## QWEN.md 연동 제안

문서 생성 후 사용자에게 아래 내용을 프로젝트 `QWEN.md`에 추가할 것을 제안한다.

```markdown
## 프로젝트 메모리 사용 지침

이 프로젝트에서 작업할 때는 먼저 `.kobi/INDEX.md`를 확인한다.

작업 유형별 참조 문서:

- 프로젝트 구조 이해: `.kobi/PROJECT_SUMMARY.md`
- 아키텍처/레이어 분석: `.kobi/ARCHITECTURE.md`
- 업무 호출 흐름 분석: `.kobi/FLOW.md`
- API/인터페이스 분석: `.kobi/API_GUIDE.md`
- 코드 작성/리뷰: `.kobi/CODING_GUIDE.md`
- 운영 반영/점검: `.kobi/OPERATIONS.md`
- 장애 분석: `.kobi/TROUBLESHOOTING.md`

단, `.kobi` 문서가 실제 소스와 다를 수 있으므로 최종 판단 전에는 관련 소스를 다시 확인한다.
```

사용자가 승인하면 QWEN.md에 추가한다.

## 완료 보고 형식

작업 완료 후 아래 형식으로 보고한다.

```text
프로젝트 부트스트랩 완료

생성 문서:
- .kobi/INDEX.md
- .kobi/PROJECT_SUMMARY.md
- .kobi/ARCHITECTURE.md
- .kobi/FLOW.md
- .kobi/API_GUIDE.md
- .kobi/CODING_GUIDE.md
- .kobi/OPERATIONS.md
- .kobi/TROUBLESHOOTING.md

확인한 주요 항목:
- 빌드 방식:
- 주요 패키지:
- API 진입점:
- Mapper/XML:
- 운영 설정:

추가 확인 필요사항:
- ...
```
