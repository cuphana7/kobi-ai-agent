param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path $ProjectRoot
$QwenPath = Join-Path $Root "QWEN.md"

$Block = @"

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
"@

if (Test-Path $QwenPath) {
    $Current = Get-Content $QwenPath -Raw -Encoding UTF8
    if ($Current -match "프로젝트 메모리 사용 지침") {
        $Result = [ordered]@{
            ok = $true
            changed = $false
            message = "QWEN.md already contains project memory reference."
            path = $QwenPath
        }
        $Result | ConvertTo-Json -Depth 10
        exit 0
    }
    Add-Content -Path $QwenPath -Value $Block -Encoding UTF8
}
else {
    Set-Content -Path $QwenPath -Value ("# QWEN.md`r`n" + $Block) -Encoding UTF8
}

$Result = [ordered]@{
    ok = $true
    changed = $true
    message = "Project memory reference added to QWEN.md."
    path = $QwenPath
}

$Result | ConvertTo-Json -Depth 10
