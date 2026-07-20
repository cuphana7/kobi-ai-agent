$ErrorActionPreference = "Stop"

# [보안 권한 제약] 허가된 PC 사용자 계정 검증
$AllowedUsers = @("K121105", "K121086", "K122226", "K122518", "K122522", "K123624", "K123863")
$CurrentUn    = $env:USERNAME

if ($AllowedUsers -notcontains $CurrentUn) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " [오류] 설치 권한이 없는 PC 사용자 계정입니다." -ForegroundColor Red
    Write-Host " 사용자 계정: $CurrentUn" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " 본 패키지는 허가된 사용자만 설치할 수 있는 전용 배포판입니다." -ForegroundColor Yellow
    Write-Host " 설치 권한 및 라이선스 요청은 사내 배포 관리자에게 문의하세요." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "============================================================"
Write-Host " KB AI Code Assistant 설치 프로그램 (오프라인 배포판)"
Write-Host "============================================================"

$InstallerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallRoot   = Join-Path $InstallerRoot "Kobi_Runtime"
$BinRoot       = Join-Path $InstallRoot "bin"
$UserQwenRoot  = Join-Path $HOME ".qwen"

Write-Host "설치 대상 경로: $InstallRoot"

# 1. 기존 구동 중인 Kobi 관련 Node.js 프로세스가 있으면 파일 잠금 해제를 위해 강제 종료
Write-Host ""
Write-Host "[1/3] 실행 중인 Kobi 관련 프로세스 종료 및 정리"
Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { 
    $_.Path -and (
        ($_.Path -like "*Kobi_Runtime*") -or 
        ($_.Path -like "*Kobi*") -or 
        ($_.Path -like "*qwen-code*") -or
        ($_.Path -like "*node-pty*")
    )
} | Stop-Process -Force -ErrorAction SilentlyContinue

# 2. 사내 환경설정 파일 및 제니퍼 모니터링 스킬 배포
Write-Host ""
Write-Host "[2/3] 사용자 설정, 모니터링 스킬 및 Computer Use 드라이버 배포"
New-Item -ItemType Directory -Force -Path $UserQwenRoot | Out-Null

$SourceQwenMd = Join-Path $InstallRoot "config\QWEN.md"
$TargetQwenMd = Join-Path $UserQwenRoot "QWEN.md"

if (Test-Path $SourceQwenMd) {
    Set-ItemProperty -Path $SourceQwenMd -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
    if (Test-Path $TargetQwenMd) {
        Set-ItemProperty -Path $TargetQwenMd -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        Remove-Item $TargetQwenMd -Force -ErrorAction SilentlyContinue
    }
    $QwenText = Get-Content $SourceQwenMd -Raw -Encoding UTF8
    [System.IO.File]::WriteAllText(
        $TargetQwenMd,
        $QwenText,
        [System.Text.UTF8Encoding]::new($true)
    )
}

# 제니퍼 APM Monitoring Skill 자동 설치 및 압축 해제
$SkillsDir = Join-Path $UserQwenRoot "skills"
$TargetSkillDir = Join-Path $SkillsDir "jennifer-monitor"

if (Test-Path $TargetSkillDir) {
    Remove-Item $TargetSkillDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}
New-Item -ItemType Directory -Force -Path $TargetSkillDir | Out-Null

$TarExe = Join-Path $env:SystemRoot "System32\tar.exe"
$SourceSkill = Join-Path $InstallerRoot "assets\jennifer-monitor.skill"
if (Test-Path $SourceSkill) {
    $TempZip = Join-Path $env:TEMP "jennifer_monitor_temp.zip"
    Copy-Item $SourceSkill $TempZip -Force
    if (Test-Path $TarExe) {
        & $TarExe -xf $TempZip -C $TargetSkillDir
    } else {
        Expand-Archive -Path $TempZip -DestinationPath $TargetSkillDir -Force
    }
    Remove-Item $TempZip -Force
    Write-Host "제니퍼 APM 모니터링 스킬이 성공적으로 추가되었습니다."
}

# 프로젝트 부트스트랩 스킬 자동 설치 및 압축 해제
$TargetBootstrapSkillDir = Join-Path $SkillsDir "project-bootstrap"

if (Test-Path $TargetBootstrapSkillDir) {
    Remove-Item $TargetBootstrapSkillDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}
New-Item -ItemType Directory -Force -Path $TargetBootstrapSkillDir | Out-Null

$SourceBootstrapSkill = Join-Path $InstallerRoot "assets\project-bootstrap.skill"
if (Test-Path $SourceBootstrapSkill) {
    $TempZip = Join-Path $env:TEMP "project_bootstrap_temp.zip"
    Copy-Item $SourceBootstrapSkill $TempZip -Force
    if (Test-Path $TarExe) {
        & $TarExe -xf $TempZip -C $TargetBootstrapSkillDir
    } else {
        Expand-Archive -Path $TempZip -DestinationPath $TargetBootstrapSkillDir -Force
    }
    Remove-Item $TempZip -Force
    Write-Host "프로젝트 부트스트랩 스킬이 성공적으로 추가되었습니다."
}

# Frism CM 연동 스킬 자동 설치 및 압축 해제
$TargetFrismCmSkillDir = Join-Path $SkillsDir "frism-cm"

if (Test-Path $TargetFrismCmSkillDir) {
    Remove-Item $TargetFrismCmSkillDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}
New-Item -ItemType Directory -Force -Path $TargetFrismCmSkillDir | Out-Null

$SourceFrismCmSkill = Join-Path $InstallerRoot "assets\frism-cm.skill"
if (Test-Path $SourceFrismCmSkill) {
    $TempZip = Join-Path $env:TEMP "frism_cm_temp.zip"
    Copy-Item $SourceFrismCmSkill $TempZip -Force
    if (Test-Path $TarExe) {
        & $TarExe -xf $TempZip -C $TargetFrismCmSkillDir
    } else {
        Expand-Archive -Path $TempZip -DestinationPath $TargetFrismCmSkillDir -Force
    }
    Remove-Item $TempZip -Force
    Write-Host "Frism CM 연동 스킬이 성공적으로 추가되었습니다."
}

# 한국어 출력 헬퍼 설정 파일 생성
$OutputLangFile = Join-Path $UserQwenRoot "output-language.md"
$OutputLangText = @"
# Output Language

Always respond in Korean unless the user explicitly asks for another language.
"@

[System.IO.File]::WriteAllText(
    $OutputLangFile,
    $OutputLangText,
    [System.Text.UTF8Encoding]::new($true)
)

# Computer Use(화면 읽기 전용) 드라이버 오프라인 배치
# qwen-code에 내장된 Computer Use 툴은 cua-driver-rs 바이너리가
# ~/.qwen/computer-use/cua-driver-rs-<버전>/cua-driver-rs-<버전>-windows-x86_64/cua-driver.exe
# 경로에 있으면 온라인 다운로드를 시도하지 않고 그대로 사용하므로, 오프라인 패키지에
# 미리 포함해 둔 자산을 해당 경로에 그대로 풀어준다. 마우스/키보드 조작 툴은
# settings.json의 permissions.deny에서 차단되어 화면 읽기 용도로만 동작한다.
$ComputerUseVersion    = "0.5.2"
$ComputerUseAssetName  = "cua-driver-rs-$ComputerUseVersion-windows-x86_64"
$ComputerUseRoot       = Join-Path $UserQwenRoot "computer-use"
$ComputerUseVersionDir = Join-Path $ComputerUseRoot "cua-driver-rs-$ComputerUseVersion"
$ComputerUseBin        = Join-Path $ComputerUseVersionDir "$ComputerUseAssetName\cua-driver.exe"
$SourceComputerUseZip  = Join-Path $InstallerRoot "assets\computer-use\$ComputerUseAssetName.zip"
$ExpectedComputerUseSha256 = "9c7d34c2a778b9791d3649ceebcc82f14a770901790c3a81c474fb20a5e446f4"

if (Test-Path $SourceComputerUseZip) {
    $ActualComputerUseSha256 = (Get-FileHash -Path $SourceComputerUseZip -Algorithm SHA256).Hash.ToLower()
    if ($ActualComputerUseSha256 -ne $ExpectedComputerUseSha256) {
        Write-Host "경고: Computer Use 드라이버 체크섬이 일치하지 않아 배치를 건너뜁니다(화면 읽기 기능 비활성)." -ForegroundColor Yellow
    } else {
        if (Test-Path $ComputerUseVersionDir) {
            Remove-Item $ComputerUseVersionDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Force -Path $ComputerUseVersionDir | Out-Null
        if (Test-Path $TarExe) {
            & $TarExe -xf $SourceComputerUseZip -C $ComputerUseVersionDir
        } else {
            Expand-Archive -Path $SourceComputerUseZip -DestinationPath $ComputerUseVersionDir -Force
        }
        if (Test-Path $ComputerUseBin) {
            Write-Host "Computer Use(화면 읽기 전용) 드라이버가 성공적으로 배치되었습니다."
        } else {
            Write-Host "경고: Computer Use 드라이버 배치 후 실행 파일을 찾을 수 없습니다." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "안내: Computer Use 드라이버 자산이 없어 배치를 건너뜁니다(화면 읽기 기능 비활성)." -ForegroundColor Yellow
}

# 3. 사용자 환경 변수 Path에 kobi 명령어 등록
Write-Host ""
Write-Host "[3/3] 사용자 환경 변수 Path에 kobi 명령어 등록 및 정리"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($null -eq $UserPath) {
    $UserPath = ""
}

# 기존 Path 항목 중 구버전 Kobi 관련 경로(Kobi_Runtime\bin 포함 경로)를 모두 걸러내어 제거합니다.
$CleanedPaths = $UserPath -split ';' | Where-Object {
    $_ -and 
    ($_ -notlike "*Kobi_Runtime\bin*") -and 
    ($_ -notlike "*Kobi_Runtime/bin*")
}

# 현재 설치 경로를 신규 및 고유 경로로 등록합니다.
$NewPathParts = $CleanedPaths + $BinRoot
$NewPath = $NewPathParts -join ';'

[Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
Write-Host "환경 변수 Path가 등록 및 최신화되었습니다: $BinRoot"

# 4. 에이전트 구동 및 최종 설치 상태 검증
Write-Host ""
Write-Host "최종 설치 상태 검증 중..."

$NodeExe = Get-ChildItem -Path (Join-Path $InstallRoot "node") -Recurse -Filter "node.exe" | Select-Object -First 1
if (-not $NodeExe) {
    throw "node.exe 실행 파일을 찾을 수 없습니다."
}

$NodeDir   = Split-Path -Parent $NodeExe.FullName
$QwenCliJs = Join-Path $InstallRoot "qwen\node_modules\@qwen-code\qwen-code\cli-entry.js"

if (-not (Test-Path $QwenCliJs)) {
    throw "Qwen Code CLI 실행 파일을 찾을 수 없습니다."
}

# 임시 PATH 적용하여 에이전트 버전 구동 확인
$env:Path = "$BinRoot;$NodeDir;$env:Path"
& $NodeExe.FullName "$QwenCliJs" --version

Write-Host ""
Write-Host "============================================================"
Write-Host " KB AI Assistant 설치가 성공적으로 완료되었습니다!"
Write-Host "============================================================"
Write-Host ""
Write-Host "사용 방법:"
Write-Host "  1. 새로운 PowerShell 또는 CMD 창을 실행합니다."
Write-Host "  2. 분석하려는 프로젝트 폴더로 이동합니다."
Write-Host "     cd C:\work\my-java-project"
Write-Host "  3. kobi 명령어를 실행하여 도우미를 호출합니다:"
Write-Host "     kobi"
Write-Host ""
Write-Host "※ 긴 프롬프트(지침문)를 클립보드에 복사(Ctrl+C)한 뒤 아래와 같이 즉시 실행할 수도 있습니다:"
Write-Host "     kobi -p (Get-Clipboard)"
Write-Host ""
