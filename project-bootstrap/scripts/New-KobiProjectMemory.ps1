param(
    [string]$ProjectRoot = ".",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path $ProjectRoot
$KobiRoot = Join-Path $Root ".kobi"

if ((Test-Path $KobiRoot) -and (-not $Force)) {
    throw ".kobi folder already exists. Use -Force to overwrite template files."
}

New-Item -ItemType Directory -Force -Path $KobiRoot | Out-Null

$Docs = @{
    "INDEX.md" = "# KOBI Project Memory Index`r`n`r`n이 문서는 KOBI가 프로젝트 작업 전 참조할 문서 목록입니다.`r`n"
    "PROJECT_SUMMARY.md" = "# Project Summary`r`n`r`n## 프로젝트 목적`r`n`r`n## 주요 업무`r`n`r`n## 기술 스택`r`n`r`n## 주요 디렉터리`r`n`r`n## 추가 확인 필요사항`r`n"
    "ARCHITECTURE.md" = "# Architecture`r`n`r`n## 전체 구조`r`n`r`n## 레이어 구조`r`n`r`n## 공통 모듈`r`n`r`n## 예외 처리`r`n`r`n## 트랜잭션`r`n`r`n## 추가 확인 필요사항`r`n"
    "FLOW.md" = "# Business Flow`r`n`r`n## 주요 업무 흐름`r`n`r`n## Controller → Service → Mapper → SQL`r`n`r`n## 외부 연계`r`n`r`n## 추가 확인 필요사항`r`n"
    "API_GUIDE.md" = "# API Guide`r`n`r`n## API 호출 방식`r`n`r`n## 인터페이스 연계`r`n`r`n## Timeout / Retry`r`n`r`n## 영향도 확인`r`n`r`n## 추가 확인 필요사항`r`n"
    "CODING_GUIDE.md" = "# Coding Guide`r`n`r`n## 네이밍 규칙`r`n`r`n## 코드 작성 기준`r`n`r`n## 로그 기준`r`n`r`n## 예외 처리 기준`r`n`r`n## 테스트 기준`r`n`r`n## 코드 리뷰 체크리스트`r`n"
    "OPERATIONS.md" = "# Operations Guide`r`n`r`n## 운영 반영 전 확인사항`r`n`r`n## 설정 변경 확인사항`r`n`r`n## 로그 확인`r`n`r`n## APM 확인`r`n`r`n## 배포 후 점검`r`n"
    "TROUBLESHOOTING.md" = "# Troubleshooting`r`n`r`n## 자주 발생하는 오류`r`n`r`n## DB 오류`r`n`r`n## Timeout`r`n`r`n## 인터페이스 오류`r`n`r`n## 추가 확인 체크리스트`r`n"
}

foreach ($name in $Docs.Keys) {
    $path = Join-Path $KobiRoot $name
    if ((-not (Test-Path $path)) -or $Force) {
        Set-Content -Path $path -Value $Docs[$name] -Encoding UTF8
    }
}

$result = [ordered]@{
    ok = $true
    projectRoot = $Root.Path
    kobiRoot = $KobiRoot
    createdFiles = @($Docs.Keys | Sort-Object)
}

$result | ConvertTo-Json -Depth 10
