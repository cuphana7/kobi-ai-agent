#!/bin/bash
cd ~/kobi-package

# 1. Qwen Code 모듈 최신버전 확인 및 업데이트 검사
CURRENT_VERSION=$(grep '"@qwen-code/qwen-code"' npm-seed/package.json | head -n 1 | cut -d'"' -f4 | tr -d '^" ,')
echo "=========================================================="
echo " Checking Qwen Code core module version..."
echo " Current Version: $CURRENT_VERSION"
echo "=========================================================="

echo "Connecting to npm registry to check for updates..."
LATEST_VERSION=$(npm view @qwen-code/qwen-code version 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$LATEST_VERSION" ]; then
  echo "Latest version in registry: $LATEST_VERSION"
  if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    echo ""
    echo "🚨 [Update Alert] A newer version of @qwen-code/qwen-code is available!"
    echo "   ($CURRENT_VERSION ➔ $LATEST_VERSION)"
    echo "=========================================================="
    
    # 대화식(interactive) 환경인지 확인 후 업데이트 프롬프트 실행
    SHOULD_UPDATE="n"
    if [ -t 0 ]; then
      read -p "Would you like to update the offline package to $LATEST_VERSION? (y/N): " SHOULD_UPDATE
    else
      echo "Non-interactive shell detected. Skipping interactive update."
    fi
    
    if [[ "$SHOULD_UPDATE" =~ ^[yY]$ ]]; then
      echo "----------------------------------------------------------"
      echo " Updating package configurations and offline assets..."
      echo "----------------------------------------------------------"
      
      # (1) npm-seed/package.json의 의존성 버전 수정
      node -e "const fs = require('fs'); const pkg = JSON.parse(fs.readFileSync('npm-seed/package.json', 'utf8')); pkg.dependencies['@qwen-code/qwen-code'] = '^$LATEST_VERSION'; fs.writeFileSync('npm-seed/package.json', JSON.stringify(pkg, null, 2) + '\n', 'utf8');"
      
      # (2) npm-seed 의존성 설치 및 오프라인 캐시(npm-cache) 최신화
      echo "Updating npm seed and populating offline cache..."
      (cd npm-seed && npm install "@qwen-code/qwen-code@$LATEST_VERSION" --cache ../Kobi_Installer/assets/npm-cache --no-audit --no-fund)
      
      # (3) 오프라인 tgz 모듈 파일 다운로드 및 대체
      echo "Downloading latest offline core package (.tgz)..."
      rm -f Kobi_Installer/assets/pkg/*.tgz
      (cd Kobi_Installer/assets/pkg && npm pack "@qwen-code/qwen-code@$LATEST_VERSION")
      
      # (4) README.md의 버전 관련 기술 명세 일괄 자동 갱신
      echo "Updating version references in README.md..."
      node -e "const fs = require('fs'); let readme = fs.readFileSync('README.md', 'utf8'); readme = readme.split('qwen-code-qwen-code-$CURRENT_VERSION.tgz').join('qwen-code-qwen-code-$LATEST_VERSION.tgz'); fs.writeFileSync('README.md', readme, 'utf8');"
      
      CURRENT_VERSION=$LATEST_VERSION
      echo "SUCCESS: Successfully updated core module assets to $LATEST_VERSION!"
    else
      echo "Skipping update. Proceeding with current version $CURRENT_VERSION."
    fi
  else
    echo "Kobi is already using the latest version of Qwen Code ($CURRENT_VERSION)."
  fi
else
  echo "⚠️ Warning: Failed to connect to npm registry. Building with current local version."
fi
echo ""

# 2. 버전 정보 생성 (인자값이 전달되면 해당 값을 사용하고, 없으면 연월일_시분 'YYYYMMDD_HHMM' 형식으로 자동 생성)
VERSION=$1
if [ -z "$VERSION" ]; then
  VERSION=$(date +%Y%m%d_%H%M)
fi

ZIP_NAME="Kobi_Installer_v${VERSION}.zip"
SHA_NAME="${ZIP_NAME}.sha256"

echo "=========================================================="
echo " Packaging Kobi Version: $VERSION"
echo " Target File: $ZIP_NAME"
echo "=========================================================="

# 3. 스킬 자동 빌드 (최신 변경 사항을 .skill로 동기화)
echo "----------------------------------------------------------"
echo " Rebuilding jennifer-monitor.skill from jennifer-monitor/..."
echo "----------------------------------------------------------"
rm -f jennifer-monitor.skill Kobi_Installer/assets/jennifer-monitor.skill
(cd jennifer-monitor && zip -rq ../jennifer-monitor.skill *)
cp jennifer-monitor.skill Kobi_Installer/assets/jennifer-monitor.skill

echo "----------------------------------------------------------"
echo " Rebuilding project-bootstrap.skill from project-bootstrap/..."
echo "----------------------------------------------------------"
rm -f project-bootstrap.skill Kobi_Installer/assets/project-bootstrap.skill
(cd project-bootstrap && zip -rq ../project-bootstrap.skill *)
cp project-bootstrap.skill Kobi_Installer/assets/project-bootstrap.skill

echo "----------------------------------------------------------"
echo " Rebuilding frism-cm.skill from frism-cm/..."
echo "----------------------------------------------------------"
rm -f frism-cm.skill Kobi_Installer/assets/frism-cm.skill
(cd frism-cm && zip -rq ../frism-cm.skill *)
cp frism-cm.skill Kobi_Installer/assets/frism-cm.skill

# 4. Kobi_Runtime 빌드 준비
echo "----------------------------------------------------------"
echo " Pre-building Kobi_Runtime for Windows..."
echo "----------------------------------------------------------"
RUNTIME_DIR="Kobi_Installer/Kobi_Runtime"
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR/node"
mkdir -p "$RUNTIME_DIR/qwen"
mkdir -p "$RUNTIME_DIR/bin"
mkdir -p "$RUNTIME_DIR/config"

# (1) Node.js Windows 포터블 버전 압축 해제
echo "Extracting portable Node.js for Windows..."
NODE_ZIP=$(find Kobi_Installer/assets -name "node-v*-win-x64.zip" | head -n 1)
if [ -z "$NODE_ZIP" ]; then
  echo "Error: Node.js Windows ZIP file not found!"
  exit 1
fi
unzip -q "$NODE_ZIP" -d "$RUNTIME_DIR/node"
# unzip을 하면 폴더 아래에 node-v*-win-x64 폴더가 생성되므로 내부 파일들을 바로 위로 이동
SUB_DIR=$(find "$RUNTIME_DIR/node" -maxdepth 1 -mindepth 1 -type d | head -n 1)
if [ ! -z "$SUB_DIR" ]; then
  mv "$SUB_DIR"/* "$RUNTIME_DIR/node/"
  rm -rf "$SUB_DIR"
fi

# (2) Qwen Code 에이전트 오프라인 설치
echo "Pre-installing Qwen Code targeting Windows (win32/x64)..."
TGZ_FILE=$(find Kobi_Installer/assets/pkg -name "*.tgz" | head -n 1)
if [ -z "$TGZ_FILE" ]; then
  echo "Error: Qwen Code tgz file not found!"
  exit 1
fi

# 임시 package.json 파일 생성
cat <<EOF > "$RUNTIME_DIR/qwen/package.json"
{
  "name": "kobi-runtime",
  "version": "1.0.0",
  "private": true
}
EOF

if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm command not found in this shell. Cannot pre-install Qwen Code offline."
  exit 1
fi

# npm install 실행 (Windows 64비트 플랫폼 타겟팅)
npm install \
  --prefix "$RUNTIME_DIR/qwen" \
  "$TGZ_FILE" \
  --cache "Kobi_Installer/assets/npm-cache" \
  --offline \
  --os=win32 \
  --cpu=x64 \
  --include=optional \
  --no-audit \
  --no-fund
if [ $? -ne 0 ]; then
  echo "Error: npm install failed while pre-installing Qwen Code offline."
  exit 1
fi

QWEN_CLI_ENTRY="$RUNTIME_DIR/qwen/node_modules/@qwen-code/qwen-code/cli-entry.js"
if [ ! -f "$QWEN_CLI_ENTRY" ]; then
  echo "Error: $QWEN_CLI_ENTRY was not produced by npm install. Aborting build so a broken installer isn't packaged."
  exit 1
fi

# (3) 설정 파일 및 지침 파일 복사
echo "Copying config files into Kobi_Runtime..."
cp Kobi_Installer/assets/config/settings.json "$RUNTIME_DIR/config/"
cp Kobi_Installer/assets/config/QWEN.md "$RUNTIME_DIR/config/"

# (4) bin/ 디렉터리에 실행 스크립트 작성
echo "Generating execution scripts (kobi.cmd, kobi.ps1) in bin..."

cat <<'EOF' > "$RUNTIME_DIR/bin/kobi.cmd"
@echo off
setlocal
chcp 65001 >nul

set "KB_CODE_HOME=%~dp0.."
set "KB_CODE_PS1=%KB_CODE_HOME%\bin\kobi.ps1"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%KB_CODE_PS1%" %*

exit /b %ERRORLEVEL%
EOF

# UTF-8 with BOM 형식으로 kobi.ps1 생성
printf '\xEF\xBB\xBF' > "$RUNTIME_DIR/bin/kobi.ps1"
cat <<'EOF' >> "$RUNTIME_DIR/bin/kobi.ps1"
$ErrorActionPreference = "Stop"

$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallRoot = Split-Path -Parent $MyDir

$NodeExe     = Get-ChildItem -Path (Join-Path $InstallRoot "node") -Recurse -Filter "node.exe" | Select-Object -First 1

if (-not $NodeExe) {
    throw "node.exe 실행 파일을 찾을 수 없습니다."
}

$NodeDir    = Split-Path -Parent $NodeExe.FullName
$QwenCliJs  = Join-Path $InstallRoot "qwen\node_modules\@qwen-code\qwen-code\cli-entry.js"
$ConfigPath = Join-Path $InstallRoot "config\settings.json"

if (-not (Test-Path $QwenCliJs)) {
    throw "Qwen Code CLI 실행 파일을 찾을 수 없습니다."
}

$env:QWEN_CODE_SYSTEM_SETTINGS_PATH = $ConfigPath
$env:Path = "$NodeDir;$env:Path"

try {
    chcp 65001 | Out-Null
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new()
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
} catch {
}

$AppendPrompt = @"
반드시 한국어로 답변한다.
사용자가 영어로 요청하지 않는 한 영어로 답변하지 않는다.
코드, 명령어, 파일명은 원문을 유지하되 설명은 한국어로 작성한다.
파일 수정 전에는 변경 계획을 먼저 제시한다.
검색 결과가 없으면 같은 검색을 반복하지 말고 중단한다.
"@

$QwenArgs = @()
if ($args) {
    $QwenArgs += $args
}

& $NodeExe.FullName "$QwenCliJs" --append-system-prompt $AppendPrompt @QwenArgs
exit $LASTEXITCODE
EOF

# 5. 배포용 빌드 결과 패키징 구성 (불필요한 대용량 캐시 및 원본 압축파일 제거)
echo "----------------------------------------------------------"
echo " Packaging distribution release structure..."
echo "----------------------------------------------------------"
DIST_DIR="dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/Kobi_Installer"

# 스크립트 복사
cp Kobi_Installer/Install-Kobi.cmd "$DIST_DIR/Kobi_Installer/"
cp Kobi_Installer/Install-Kobi.ps1 "$DIST_DIR/Kobi_Installer/"
cp Kobi_Installer/Uninstall-Kobi.cmd "$DIST_DIR/Kobi_Installer/"
cp Kobi_Installer/Uninstall-Kobi.ps1 "$DIST_DIR/Kobi_Installer/"

# 필수 assets 복사
mkdir -p "$DIST_DIR/Kobi_Installer/assets"
cp Kobi_Installer/assets/jennifer-monitor.skill "$DIST_DIR/Kobi_Installer/assets/"
cp Kobi_Installer/assets/project-bootstrap.skill "$DIST_DIR/Kobi_Installer/assets/"
cp Kobi_Installer/assets/frism-cm.skill "$DIST_DIR/Kobi_Installer/assets/"

# Computer Use(화면 읽기 전용) 드라이버 자산 복사
mkdir -p "$DIST_DIR/Kobi_Installer/assets/computer-use"
cp Kobi_Installer/assets/computer-use/cua-driver-rs-0.5.2-windows-x86_64.zip "$DIST_DIR/Kobi_Installer/assets/computer-use/"

# Kobi_Runtime 복사
cp -r "$RUNTIME_DIR" "$DIST_DIR/Kobi_Installer/"

# 기존 zip 및 체크섬 파일 정리
rm -f "$ZIP_NAME" "$SHA_NAME"

# zip 압축 생성 (dist/ 폴더 내부에서 실행하여 루트 폴더를 Kobi_Installer로 유지)
echo "Creating optimized ZIP file..."
(cd "$DIST_DIR" && python3 -m zipfile -c "../$ZIP_NAME" Kobi_Installer)

# SHA-256 체크섬 생성
sha256sum "$ZIP_NAME" > "$SHA_NAME"

# 빌드 중간 작업물 정리
rm -rf "$DIST_DIR"
rm -rf "$RUNTIME_DIR"

echo "=========================================================="
echo " Packaging completed successfully!"
echo " Result Files:"
ls -lh "$ZIP_NAME" "$SHA_NAME"
echo "=========================================================="
