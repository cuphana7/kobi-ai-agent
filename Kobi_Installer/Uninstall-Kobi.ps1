$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " KB AI Assistant 제거 프로그램 (오프라인 배포판)"
Write-Host "============================================================"

$InstallerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallRoot   = Join-Path $InstallerRoot "Kobi_Runtime"
$BinRoot       = Join-Path $InstallRoot "bin"
$UserQwenRoot  = Join-Path $HOME ".qwen"

Write-Host "제거 대상 경로: $InstallRoot"

# 1. 실행 중인 Kobi 관련 Node.js 프로세스가 있으면 강제 종료 (파일 잠금 해제)
Write-Host ""
Write-Host "[1/3] 실행 중인 Kobi 관련 프로세스 검사 및 종료"
try {
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { 
        $_.Path -and (
            ($_.Path -like "*Kobi_Runtime*") -or 
            ($_.Path -like "*Kobi*") -or 
            ($_.Path -like "*qwen-code*") -or
            ($_.Path -like "*node-pty*")
        )
    } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "프로세스 정리가 완료되었습니다."
} catch {
    Write-Host "프로세스 정리 중 일부 오류가 발생했으나 계속 진행합니다: $_"
}

# 2. 사용자 환경 변수 Path에서 Kobi 실행 경로 제거
Write-Host ""
Write-Host "[2/3] 사용자 환경 변수 Path에서 Kobi 명령어 제거"
try {
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath) {
        # 세미콜론 기준으로 분할 후 Kobi 관련 모든 bin 경로 필터링하여 제거
        $Parts = $UserPath -split ';' | Where-Object { 
            $_ -and 
            ($_ -notlike "*Kobi_Runtime\bin*") -and 
            ($_ -notlike "*Kobi_Runtime/bin*")
        }
        $NewPath = $Parts -join ';'
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "환경 변수 Path에서 Kobi 실행 경로가 정상적으로 제거 및 정리되었습니다."
    } else {
        Write-Host "사용자 환경 변수 Path가 존재하지 않습니다."
    }
} catch {
    Write-Host "환경 변수 제거 중 오류가 발생했습니다: $_"
}

# 3. 홈 디렉토리 내 .qwen 폴더 내 관련 파일 제거 (비어 있는 경우 폴더 자체도 정리)
Write-Host ""
Write-Host "[3/3] 사용자 홈 디렉토리의 설정 및 스킬 데이터 정리"

$QwenMd = Join-Path $UserQwenRoot "QWEN.md"
$OutputLangFile = Join-Path $UserQwenRoot "output-language.md"
$SkillsDir = Join-Path $UserQwenRoot "skills"
$JenniferMonitorSkill = Join-Path $SkillsDir "jennifer-monitor"
$ProjectBootstrapSkill = Join-Path $SkillsDir "project-bootstrap"
$FrismCmSkill = Join-Path $SkillsDir "frism-cm"
$ComputerUseDir = Join-Path $UserQwenRoot "computer-use"

if (Test-Path $ComputerUseDir) {
    Remove-Item $ComputerUseDir -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $QwenMd) {
    Remove-Item $QwenMd -Force -ErrorAction SilentlyContinue
}
if (Test-Path $OutputLangFile) {
    Remove-Item $OutputLangFile -Force -ErrorAction SilentlyContinue
}
if (Test-Path $JenniferMonitorSkill) {
    Remove-Item $JenniferMonitorSkill -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $ProjectBootstrapSkill) {
    Remove-Item $ProjectBootstrapSkill -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $FrismCmSkill) {
    Remove-Item $FrismCmSkill -Recurse -Force -ErrorAction SilentlyContinue
}

# 비어있는 skills 폴더 삭제
if (Test-Path $SkillsDir) {
    $SkillsContents = Get-ChildItem $SkillsDir -ErrorAction SilentlyContinue
    if (-not $SkillsContents) {
        Remove-Item $SkillsDir -Force -ErrorAction SilentlyContinue
    }
}

# 비어있는 .qwen 폴더 삭제
if (Test-Path $UserQwenRoot) {
    $QwenContents = Get-ChildItem $UserQwenRoot -ErrorAction SilentlyContinue
    if (-not $QwenContents) {
        Remove-Item $UserQwenRoot -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "설정 및 스킬 정리가 완료되었습니다."

Write-Host ""
Write-Host "============================================================"
Write-Host " KB AI Assistant 제거가 완료되었습니다!"
Write-Host "============================================================"
Write-Host ""
