@echo off
chcp 65001 > nul
title Jennifer AI Monitor
setlocal EnableDelayedExpansion

rem ============================================================
rem  Jennifer AI Monitor
rem  Version : 2.0  (2026-07-28)
rem  - 색상 라이브 뷰 유지(FORCE_COLOR) + tee
rem  - 일별 로그 파일(logs\monitor_YYYY-MM-DD.log)
rem  - 날짜가 바뀌면 화면 clear
rem ============================================================

rem === 환경별 경로 설정 (머신에 맞게 이 두 줄만 수정) ===
set "KOBI_NODE=D:\Kobi_Installer_v20260724_0559\Kobi_Installer\Kobi_Runtime\node\node.exe"
set "CHECK_SCRIPT=C:\Users\K121105\.qwen\skills\kbpay-service-check\scripts\kbpay-service-check.cjs"

rem === 색상 강제 출력 (파이프로 넘겨도 색이 유지되도록) ===
set "FORCE_COLOR=3"

rem === 로그 설정 ===
set "LOGDIR=logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set "LAST_DAY="

:loop

rem --- 현재 시각(KST, 로캘 무관) 및 오늘 날짜 ---
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"') do set "NOW=%%i"
set "TODAY=!NOW:~0,10!"
set "LOGFILE=%LOGDIR%\monitor_!TODAY!.log"

rem --- 날짜가 바뀌면 화면 clear ---
if not "!TODAY!"=="!LAST_DAY!" (
    cls
    set "LAST_DAY=!TODAY!"
)

rem --- 헤더 (화면 + 로그 파일) ---
call :log "──────────────────────────────────────────────────────────────────────────────"
call :log "[!NOW!] 디지털 시스템 AI 점검"

rem --- 점검 스크립트 실행 ---
"%KOBI_NODE%" "%CHECK_SCRIPT%" check > result.json 2> check_error.log

rem --- kobi 분석 결과: 화면은 색상 그대로, 로그 파일은 ANSI 제거한 평문으로 저장 ---
rem     --core-tools read_file 로 파일 읽기 도구 하나만 허용:
rem     kobi 는 파일 읽기만 가능하고 실행/수정/생성(run_shell_command/write_file/edit 등)은 불가
call kobi -p "result.json 은 KB Pay 통합 서비스 상태 점검 결과이며 그 분석을 모니터링 전광판에 실시간 표출한다. 파일을 읽고 아래 규칙대로 한국어 상태 화면을 출력하라. 화면은 자동 스크롤되고 장애 시 임원도 함께 보므로 기술 상세는 위쪽에, 임원용 평이한 요약은 아래쪽에 배치한다. [데이터 구조] data.checkedAt 는 KST 점검시각, data.thresholdMs 는 지연 판단 임계값(밀리초), data.domainCount 는 전체 도메인 수, data.delayedDomainCount 는 지연 도메인 수, data.errorDomainCount 는 조회오류 도메인 수, data.domains 배열의 각 항목은 serviceName(서비스명), status(OK 정상·DELAYED 지연·ERROR 조회오류), activeServiceCount(활성 서비스 수), delayedCount(지연 트랜잭션 수), delayedServices(지연 상세 목록이며 각 항목에 runningTime 밀리초 응답시간, application, 사전 매핑된 mappedServiceName 한글 서비스명 또는 빈 값 포함), error(오류 메시지)로 구성된다. result.json 의 success 가 false 이면 점검 시스템 자체 오류이다. [판정] delayedDomainCount 와 errorDomainCount 가 모두 0 이면 전체 정상, delayedDomainCount 가 1 이상이면 지연 발생, errorDomainCount 가 1 이상이면 점검오류로 판정한다. 지연 기준은 thresholdMs 를 1000 으로 나눈 초 단위로 표기한다. [출력] 1행에 종합 상태 배지를 낸다. 전체 정상이면 [정상], 지연이면 [주의 지연], 오류이면 [장애의심 점검오류], 시스템 오류이면 [점검 시스템 오류] 로 하고 배지 뒤에 KB Pay 서비스 상태 문구와 점검시각을 시분초로 붙인다. 2행에 요약을 한 줄로 낸다. 전체 도메인 수와 정상·지연·오류 도메인 수, 지연기준 초를 함께 표기한다. 전체 정상이면 여기까지만 간결히 출력하고 상세는 생략한다. 지연 또는 오류가 있을 때만 이어서 상단에 기술 상세를 낸다. 지연·오류 도메인마다 한 줄로 serviceName, 상태, 지연 트랜잭션 건수, delayedServices 의 runningTime 최댓값을 초 단위로, 도메인ID를 표기하고, 각 지연 상세에는 이미 매핑된 mappedServiceName 필드가 있으니 그 값을 서비스명으로 사용하고, 비어 있거나 없으면 application 원문을 사용하며, 외부 파일(csv 등)은 조회하지 않는다. ERROR 도메인은 error 메시지를 한 줄로 요약해 조회 실패 사유로 표기한다. 그 아래 하단에 임원용 요약을 2~3줄로 낸다. 숫자와 전문용어를 최소화하고 어떤 서비스가 느리거나 문제인지, 고객 이용에 예상되는 영향, 현재 자동 점검이 지속되는 대응 상태를 평이한 문장으로 쓴다. 자동 스크롤 시 이 요약이 화면 하단에 남도록 반드시 뒤쪽에 둔다. 마지막 행에 내부 전파용 짧은 보고문구를 한 줄로 낸다. 사내 메신저에 그대로 붙일 수 있게 점검시각, 종합 상태, 영향 서비스명 service_name 반영 과 건수를 한 문장으로 압축하며 전체 정상일 때도 KB Pay 전체 정상 형태로 항상 생성한다. [원칙] result.json 에 없는 값은 추측하지 않는다. 같은 데이터에는 항상 같은 형식과 문구로 출력한다." --core-tools read_file 2>&1 | powershell -NoProfile -Command "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false); $input | ForEach-Object { $p = ($_ -replace '\x1B\[[0-?]*[ -/]*[@-~]',''); if ($p -match '\uC2E4\uD589 \uC900\uBE44|\uC5D0\uC774\uC804\uD2B8') { return }; $_; $p | Add-Content -Path '!LOGFILE!' -Encoding UTF8 }"

echo.
timeout /t 10 /nobreak > nul
goto loop

rem === 화면(색상 없는 헤더) + 로그 파일에 동시에 한 줄 출력 ===
:log
echo %~1
>> "!LOGFILE!" echo %~1
goto :eof
