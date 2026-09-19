$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------------------
# 공용 헬퍼 함수 (PowerShell은 정의가 사용보다 앞서야 하므로 최상단에 둔다)
# ----------------------------------------------------------------------------

# 아카이브 압축 해제: Windows 내장 tar(bsdtar)가 있으면 사용하고, 없으면 Expand-Archive로 대체한다.
function Expand-KobiArchive([string]$ZipPath, [string]$DestDir, [string]$TarExe) {
    if ($TarExe -and (Test-Path $TarExe)) {
        & $TarExe -xf $ZipPath -C $DestDir
    } else {
        Expand-Archive -Path $ZipPath -DestinationPath $DestDir -Force
    }
}

# 스킬(.skill = zip) 1종 설치: 기존 디렉터리 제거 → 생성 → temp 복사 → 압축 해제 → temp 삭제 → 성공 메시지.
# 성공 메시지는 스킬마다 문구가 달라 재조합하지 않고 원문 전체를 파라미터로 받는다.
function Install-KobiSkill([string]$Dir, [string]$Asset, [string]$Msg, [string]$SkillsDir, [string]$InstallerRoot, [string]$TarExe) {
    $TargetSkillDir = Join-Path $SkillsDir $Dir

    if (Test-Path $TargetSkillDir) {
        Remove-Item $TargetSkillDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
    New-Item -ItemType Directory -Force -Path $TargetSkillDir | Out-Null

    $SourceSkill = Join-Path $InstallerRoot "assets\$Asset"
    if (Test-Path $SourceSkill) {
        $TempZip = Join-Path $env:TEMP "kobi_skill_$($Dir)_temp.zip"
        Copy-Item $SourceSkill $TempZip -Force
        Expand-KobiArchive -ZipPath $TempZip -DestDir $TargetSkillDir -TarExe $TarExe
        Remove-Item $TempZip -Force
        Write-Host $Msg
    }
}

# UTF-8 파일 쓰기: qwen-code는 BOM 유무에 민감하므로 호출부에서 명시적으로 선택한다.
function Write-Utf8File([string]$Path, [string]$Text, [switch]$WithBom) {
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new([bool]$WithBom)
    )
}

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

# CLI 에이전트(qwen) 유무로 배포 형태를 감지한다.
# GUI 전용 패키지는 node 는 포함하지만 CLI 에이전트(qwen)와 CLI 런처(bin)는 없다.
$QwenCliJs = Join-Path $InstallRoot "qwen\node_modules\@qwen-code\qwen-code\cli-entry.js"
$IsGuiOnly = -not (Test-Path $QwenCliJs)

Write-Host "설치 대상 경로: $InstallRoot"

# 1. 기존 구동 중인 Kobi 관련 Node.js 프로세스가 있으면 파일 잠금 해제를 위해 강제 종료
Write-Host ""
Write-Host "[1/5] 실행 중인 Kobi 관련 프로세스 종료 및 정리"
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
Write-Host "[2/5] 사용자 설정, 모니터링 스킬 및 Computer Use 드라이버 배포"
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
    Write-Utf8File -Path $TargetQwenMd -Text $QwenText -WithBom
}

# 사내 배포 스킬(.skill) 자동 설치 및 압축 해제
# assets\*.skill 자산과 1:1로 대응한다(make.sh가 각 스킬 폴더에서 재빌드).
$SkillsDir = Join-Path $UserQwenRoot "skills"
$TarExe    = Join-Path $env:SystemRoot "System32\tar.exe"

$Skills = @(
    @{ Dir='jennifer-monitor';    Asset='jennifer-monitor.skill';    Msg='제니퍼 APM 모니터링 스킬이 성공적으로 추가되었습니다.' }
    @{ Dir='project-bootstrap';   Asset='project-bootstrap.skill';   Msg='프로젝트 부트스트랩 스킬이 성공적으로 추가되었습니다.' }
    @{ Dir='frism-cm';            Asset='frism-cm.skill';            Msg='Frism CM 연동 스킬이 성공적으로 추가되었습니다.' }
    @{ Dir='office-edit';         Asset='office-edit.skill';         Msg='Office(Excel/Word) 편집 스킬이 성공적으로 추가되었습니다.' }
    @{ Dir='kbpay-service-check'; Asset='kbpay-service-check.skill'; Msg='KB Pay 서비스 지연 점검 스킬이 성공적으로 추가되었습니다.' }
)

foreach ($sk in $Skills) {
    Install-KobiSkill -Dir $sk.Dir -Asset $sk.Asset -Msg $sk.Msg `
        -SkillsDir $SkillsDir -InstallerRoot $InstallerRoot -TarExe $TarExe
}

# 한국어 출력 헬퍼 설정 파일 생성
$OutputLangFile = Join-Path $UserQwenRoot "output-language.md"
$OutputLangText = @"
# Output Language

Always respond in Korean unless the user explicitly asks for another language.
"@

Write-Utf8File -Path $OutputLangFile -Text $OutputLangText -WithBom

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
        Expand-KobiArchive -ZipPath $SourceComputerUseZip -DestDir $ComputerUseVersionDir -TarExe $TarExe
        if (Test-Path $ComputerUseBin) {
            Write-Host "Computer Use(화면 읽기 전용) 드라이버가 성공적으로 배치되었습니다."
        } else {
            Write-Host "경고: Computer Use 드라이버 배치 후 실행 파일을 찾을 수 없습니다." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "안내: Computer Use 드라이버 자산이 없어 배치를 건너뜁니다(화면 읽기 기능 비활성)." -ForegroundColor Yellow
}

# 3. Kobi Desktop(GUI)이 읽는 사용자 설정(~/.qwen/settings.json)에 사내 vLLM 연결 정보 병합
#    CLI(kobi)는 번들 config\settings.json 을 QWEN_CODE_SYSTEM_SETTINGS_PATH 로 직접 읽지만,
#    Desktop(GUI)은 바로가기로 실행되어 그 환경변수가 없으므로 표준 사용자 설정을 읽는다.
#    따라서 번들 설정의 연결/보안/모델 관련 키를 ~/.qwen/settings.json 에 병합해 Desktop이 즉시
#    사내 vLLM에 연결되게 한다. CLI 전용 브랜딩(ui.*)은 GUI와 무관하므로 병합에서 제외한다.
#    기존 사용자 설정의 알 수 없는 키는 보존한다(해당 키만 갱신).
Write-Host ""
Write-Host "[3/5] Kobi Desktop용 사용자 설정(~/.qwen/settings.json) 구성"

$SourceSettings = Join-Path $InstallRoot "config\settings.json"
$TargetSettings = Join-Path $UserQwenRoot "settings.json"

if (Test-Path $SourceSettings) {
    try {
        $SourceCfg = Get-Content $SourceSettings -Raw -Encoding UTF8 | ConvertFrom-Json

        if (Test-Path $TargetSettings) {
            try {
                $TargetCfg = Get-Content $TargetSettings -Raw -Encoding UTF8 | ConvertFrom-Json
            } catch {
                $TargetCfg = [PSCustomObject]@{}
            }
        } else {
            $TargetCfg = [PSCustomObject]@{}
        }
        if ($null -eq $TargetCfg) { $TargetCfg = [PSCustomObject]@{} }

        # CLI 전용 표시 설정(ui)만 제외하고 나머지 최상위 키를 사용자 설정에 덮어쓴다.
        foreach ($Prop in $SourceCfg.PSObject.Properties) {
            if ($Prop.Name -eq 'ui') { continue }
            if ($TargetCfg.PSObject.Properties.Name -contains $Prop.Name) {
                $TargetCfg.$($Prop.Name) = $Prop.Value
            } else {
                $TargetCfg | Add-Member -NotePropertyName $Prop.Name -NotePropertyValue $Prop.Value
            }
        }

        # qwen-code는 settings.json 스키마에 엄격하므로 BOM 없는 UTF-8로 저장한다.
        $MergedJson = $TargetCfg | ConvertTo-Json -Depth 30
        Write-Utf8File -Path $TargetSettings -Text $MergedJson
        Write-Host "Kobi Desktop이 사내 vLLM에 연결되도록 사용자 설정을 구성했습니다."
    } catch {
        Write-Host "경고: 사용자 설정(settings.json) 구성 중 오류가 발생했습니다: $_" -ForegroundColor Yellow
        Write-Host "      Desktop 최초 실행 시 GUI에서 모델 공급자를 수동 설정해야 할 수 있습니다." -ForegroundColor Yellow
    }
} else {
    Write-Host "경고: 번들 설정 파일을 찾을 수 없어 Desktop용 사용자 설정 구성을 건너뜁니다." -ForegroundColor Yellow
}

# 4. Kobi Desktop(GUI) 무인 설치
#    리브랜딩 빌드 산출물(Kobi-Desktop-*.exe)이 assets\desktop 에 있으면 SHA-256 검증 후
#    NSIS 무인 플래그(/S)로 설치한다. per-user 설치(%LOCALAPPDATA%)라 관리자 권한이 필요 없다.
#    자산이 없으면(=CLI 전용 배포) 조용히 건너뛴다.
Write-Host ""
Write-Host "[4/5] Kobi Desktop(GUI) 설치"

$DesktopInstaller = Get-ChildItem -Path (Join-Path $InstallerRoot "assets\desktop") -Filter "Kobi-Desktop-*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($DesktopInstaller) {
    try {
        Write-Host "Desktop 설치 파일: $($DesktopInstaller.Name)"
        $DesktopProc = Start-Process -FilePath $DesktopInstaller.FullName -ArgumentList "/S" -Wait -PassThru
        if ($DesktopProc.ExitCode -eq 0) {
            Write-Host "Kobi Desktop(GUI)이 성공적으로 설치되었습니다. (시작 메뉴에서 실행)"
        } else {
            Write-Host "경고: Desktop 설치 관리자가 코드 $($DesktopProc.ExitCode)로 종료되었습니다. 수동 설치가 필요할 수 있습니다." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "경고: Kobi Desktop 설치 중 오류가 발생했습니다: $_" -ForegroundColor Yellow
        Write-Host "      assets\desktop 의 설치 파일을 직접 실행해 설치할 수 있습니다." -ForegroundColor Yellow
    }
} else {
    Write-Host "안내: Kobi Desktop 설치 자산이 없어 CLI 전용으로 설치를 진행합니다." -ForegroundColor DarkGray
}

# 5. 사용자 환경 변수 Path에 kobi 명령어 등록
Write-Host ""
Write-Host "[5/5] 사용자 환경 변수 Path에 kobi 명령어 등록 및 정리"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($null -eq $UserPath) {
    $UserPath = ""
}

# 기존 Path 항목 중 구버전 Kobi 관련 경로(Kobi_Runtime\bin, \git, \node 포함 경로)를 모두 걸러내어 제거합니다.
$CleanedPaths = $UserPath -split ';' | Where-Object {
    $_ -and
    ($_ -notlike "*Kobi_Runtime\bin*") -and
    ($_ -notlike "*Kobi_Runtime/bin*") -and
    ($_ -notlike "*Kobi_Runtime\git*") -and
    ($_ -notlike "*Kobi_Runtime/git*") -and
    ($_ -notlike "*Kobi_Runtime\node*") -and
    ($_ -notlike "*Kobi_Runtime/node*")
}

$NewPathParts = @($CleanedPaths)

# node 디렉터리를 영구 사용자 PATH에 등록한다. 시작 메뉴로 실행되는 Desktop(GUI)이 스킬의
# node 스크립트(node scripts\*.cjs)를 실행할 수 있도록 하기 위함이다(CLI/GUI 공통).
$NodeExeForPath = Get-ChildItem -Path (Join-Path $InstallRoot "node") -Recurse -Filter "node.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
$NodeDirForPath = $null
if ($NodeExeForPath) {
    $NodeDirForPath = Split-Path -Parent $NodeExeForPath.FullName
    $NewPathParts = $NewPathParts + $NodeDirForPath
}

# CLI 런처(kobi)가 있는 조합형 패키지에서만 bin 경로를 등록한다(GUI 전용은 bin 없음).
if (Test-Path (Join-Path $BinRoot "kobi.cmd")) {
    $NewPathParts = $NewPathParts + $BinRoot
}

# 번들 git(MinGit)이 있으면 그 cmd 디렉터리도 함께 등록해, 시작 메뉴로 실행되는 Desktop(GUI)과
# CLI 모두 별도 git 설치 없이 git 을 사용할 수 있게 한다.
$GitCmdRoot = Join-Path $InstallRoot "git\cmd"
if (Test-Path (Join-Path $GitCmdRoot "git.exe")) {
    $NewPathParts = $NewPathParts + $GitCmdRoot
}
$NewPath = ($NewPathParts | Where-Object { $_ }) -join ';'

[Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
Write-Host "환경 변수 Path가 등록 및 최신화되었습니다."
if ($NodeDirForPath) {
    Write-Host "node 경로가 등록되었습니다: $NodeDirForPath"
}
if (Test-Path (Join-Path $BinRoot "kobi.cmd")) {
    Write-Host "CLI 런처(kobi) 경로가 등록되었습니다: $BinRoot"
}
if (Test-Path (Join-Path $GitCmdRoot "git.exe")) {
    Write-Host "번들 git(MinGit) 경로가 등록되었습니다: $GitCmdRoot"
}

# 4. 에이전트 구동 및 최종 설치 상태 검증
Write-Host ""
Write-Host "최종 설치 상태 검증 중..."

# 위 [5/5] 단계에서 이미 찾은 node.exe를 재사용한다(동일 경로 스캔).
$NodeExe = $NodeExeForPath
if (-not $NodeExe) {
    throw "node.exe 실행 파일을 찾을 수 없습니다."
}

$NodeDir = Split-Path -Parent $NodeExe.FullName
$env:Path = "$NodeDir;$env:Path"

if ($IsGuiOnly) {
    # GUI 전용: CLI(qwen)가 없으므로 node 구동만 확인한다(Desktop 은 자체 런타임으로 동작).
    & $NodeExe.FullName --version
} else {
    if (-not (Test-Path $QwenCliJs)) {
        throw "Qwen Code CLI 실행 파일을 찾을 수 없습니다."
    }
    # 임시 PATH 적용하여 에이전트 버전 구동 확인
    $env:Path = "$BinRoot;$env:Path"
    & $NodeExe.FullName "$QwenCliJs" --version
}

Write-Host ""
Write-Host "============================================================"
Write-Host " KB AI Assistant 설치가 성공적으로 완료되었습니다!"
Write-Host "============================================================"
Write-Host ""
if ($IsGuiOnly) {
    Write-Host "사용 방법:"
    Write-Host "  시작 메뉴에서 'Kobi'(Desktop)를 실행하세요. 사내 vLLM에 사전 연결되어 있습니다."
    Write-Host ""
    if (-not $DesktopInstaller) {
        Write-Host "경고: Desktop(GUI) 설치 자산이 없어 GUI가 설치되지 않았습니다. 패키지를 확인하세요." -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host "※ 스킬을 사용하려면 스킬 번들(Kobi_Skills_*.zip)을 사용자 홈의 .qwen 폴더에 압축 해제하세요."
    Write-Host "   (스킬의 node 스크립트는 이 설치가 PATH에 등록한 node로 실행됩니다.)"
    Write-Host ""
} else {
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
    if ($DesktopInstaller) {
        Write-Host "※ GUI로 사용하려면 시작 메뉴에서 'Kobi'(Desktop)를 실행하세요. 사내 vLLM에 사전 연결되어 있습니다."
        Write-Host ""
    }
}
