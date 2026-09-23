#!/bin/bash
cd ~/kobi-package

# 1. Qwen Code 모듈 최신버전 확인 및 업데이트 검사
# (skills 서브타깃은 스킬만 묶으므로 qwen 레지스트리 점검이 불필요 → 건너뛴다)
if [ "$1" != "skills" ]; then
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
fi  # end: qwen 레지스트리 점검(skills 서브타깃 제외)

# 2. 타겟 플랫폼 및 버전 정보 결정
#    사용법: ./make.sh [linux|windows|windows-gui|skills] [version]
#    - 첫 인자가 linux/windows(win)/windows-gui(gui)/skills 면 타겟으로 소비하고, 아니면 windows(기본, 하위호환)로 간주한다.
#    - windows-gui(gui): CLI(qwen)·스킬을 빼고 Desktop(GUI) 중심으로만 패키징한다(용량 절감).
#    - skills: 스킬 5종만 ~/.qwen 에 압축 해제하는 별도 배포 번들로 묶는다.
#    - 남은 인자를 버전으로 쓰고, 없으면 연월일_시분 'YYYYMMDD_HHMM' 형식으로 자동 생성한다.
#    - NO_GIT=1 환경변수: 포터블 git(MinGit)을 제외해 추가 경량화(대상 PC에 git 이 있을 때).
#    - NO_SKILLS=1 환경변수: 스킬 5종을 패키지에서 제외한다(별도 배포: ./make.sh skills).
#    - NO_DESKTOP=1 환경변수: Kobi Desktop(GUI)을 제외해 CLI 전용으로 패키징한다(full 빌드에만 적용).
#    - NO_COMPUTER_USE=1 환경변수: Computer Use(화면 읽기) 드라이버 자산을 제외하고 settings.json의
#      tools.computerUse를 비활성화한다(linux 타겟은 원래부터 항상 비활성).
#      예: 코어 CLI만(GUI·스킬·Computer Use 모두 제외) → NO_DESKTOP=1 NO_SKILLS=1 NO_COMPUTER_USE=1 ./make.sh windows
TARGET="windows"
FLAVOR="full"
case "$1" in
  linux)           TARGET="linux";   shift ;;
  windows|win)     TARGET="windows"; shift ;;
  windows-gui|gui) TARGET="windows"; FLAVOR="gui"; shift ;;
  skills)          TARGET="skills";  shift ;;
esac

# 리눅스에는 데스크톱(GUI) 산출물이 없으므로 GUI 전용 조합을 금지한다.
if [ "$TARGET" = "linux" ] && [ "$FLAVOR" = "gui" ]; then
  echo "Error: linux 타겟은 GUI 전용(FLAVOR=gui)을 지원하지 않습니다."
  exit 1
fi

VERSION=$1
if [ -z "$VERSION" ]; then
  VERSION=$(date +%Y%m%d_%H%M)
fi

if [ "$TARGET" = "skills" ]; then
  PKG_NAME="Kobi_Skills_v${VERSION}.zip"
elif [ "$TARGET" = "linux" ]; then
  DIST_ROOT_NAME="Kobi_Installer_linux"
  PKG_NAME="Kobi_Installer_linux_v${VERSION}.tar.gz"
elif [ "$FLAVOR" = "gui" ]; then
  DIST_ROOT_NAME="Kobi_Installer"
  PKG_NAME="Kobi_Installer_gui_v${VERSION}.zip"
else
  DIST_ROOT_NAME="Kobi_Installer"
  PKG_NAME="Kobi_Installer_v${VERSION}.zip"
fi
SHA_NAME="${PKG_NAME}.sha256"

echo "=========================================================="
echo " Packaging Kobi Version: $VERSION (target: $TARGET)"
echo " Target File: $PKG_NAME"
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

echo "----------------------------------------------------------"
echo " Rebuilding office-edit.skill from office-edit/..."
echo "----------------------------------------------------------"
rm -f office-edit.skill Kobi_Installer/assets/office-edit.skill
(cd office-edit && zip -rq ../office-edit.skill *)
cp office-edit.skill Kobi_Installer/assets/office-edit.skill

echo "----------------------------------------------------------"
echo " Rebuilding kbpay-service-check.skill from kbpay-service-check/..."
echo "----------------------------------------------------------"
rm -f kbpay-service-check.skill Kobi_Installer/assets/kbpay-service-check.skill
(cd kbpay-service-check && zip -rq ../kbpay-service-check.skill *)
cp kbpay-service-check.skill Kobi_Installer/assets/kbpay-service-check.skill

# 3-b. skills 서브타깃: 스킬 5종만 별도 배포 번들로 묶고 종료한다.
#      각 .skill 은 스킬 내용의 zip 이므로 skills/<name>/ 레이아웃으로 풀어, 사용자가
#      %USERPROFILE%\.qwen\ 에 압축만 해제하면 GUI(및 CLI)가 스킬을 인식하도록 한다.
if [ "$TARGET" = "skills" ]; then
  echo "=========================================================="
  echo " Packaging standalone skills bundle: $PKG_NAME"
  echo "=========================================================="
  SKILLS_DIST="dist_skills"
  rm -rf "$SKILLS_DIST"
  SKILLS_ROOT="$SKILLS_DIST/skills"
  mkdir -p "$SKILLS_ROOT"
  for S in jennifer-monitor project-bootstrap frism-cm office-edit kbpay-service-check; do
    if [ ! -f "$S.skill" ]; then
      echo "Error: $S.skill 을 찾을 수 없습니다. 스킬 재빌드 단계를 확인하세요."
      exit 1
    fi
    mkdir -p "$SKILLS_ROOT/$S"
    unzip -q "$S.skill" -d "$SKILLS_ROOT/$S"
  done

  cat <<'SKILLS_README_EOF' > "$SKILLS_DIST/README-skills.txt"
Kobi 스킬 번들 (별도 배포)
==========================

설치 방법
1) 이 zip 안의 skills 폴더를 사용자 홈의 .qwen 폴더로 복사(병합)합니다.
   - 대상 경로: %USERPROFILE%\.qwen\skills\
   - 예: 압축을 %USERPROFILE%\.qwen\ 에 그대로 풀면 됩니다.
2) Kobi(CLI/Desktop)를 다시 실행하면 스킬이 인식됩니다.

참고
- 스킬의 node 스크립트(scripts\*.cjs)는 Kobi 설치가 PATH 에 등록한 node 로 실행됩니다.
  (Kobi 설치본이 있으면 별도 node 설치가 필요 없습니다.)
- 포함 스킬: jennifer-monitor, project-bootstrap, frism-cm, office-edit, kbpay-service-check
SKILLS_README_EOF

  rm -f "$PKG_NAME" "$SHA_NAME"
  echo "Creating skills ZIP file..."
  (cd "$SKILLS_DIST" && python3 -m zipfile -c "../$PKG_NAME" skills README-skills.txt)
  sha256sum "$PKG_NAME" > "$SHA_NAME"
  rm -rf "$SKILLS_DIST"

  echo "=========================================================="
  echo " Skills bundle completed successfully!"
  echo " Result Files:"
  ls -lh "$PKG_NAME" "$SHA_NAME"
  echo "=========================================================="
  exit 0
fi

# 4. Kobi_Runtime 빌드 준비
echo "----------------------------------------------------------"
echo " Pre-building Kobi_Runtime for $TARGET..."
echo "----------------------------------------------------------"
RUNTIME_DIR="Kobi_Installer/Kobi_Runtime"
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR/node"
mkdir -p "$RUNTIME_DIR/config"
# GUI 전용 빌드는 CLI 에이전트(qwen)와 CLI 런처(bin)를 넣지 않는다(용량 절감). node 는 스킬의
# node 스크립트 실행을 위해 GUI 전용에도 포함한다.
if [ "$FLAVOR" != "gui" ]; then
  mkdir -p "$RUNTIME_DIR/qwen"
  mkdir -p "$RUNTIME_DIR/bin"
fi

# (1) Node.js 포터블 버전 압축 해제 (타겟 플랫폼별 자산 선택)
if [ "$TARGET" = "linux" ]; then
  echo "Extracting portable Node.js for Linux..."
  NODE_ARCHIVE=$(find Kobi_Installer/assets -name "node-v*-linux-x64.tar.xz" | head -n 1)
  if [ -z "$NODE_ARCHIVE" ]; then
    echo "Error: Node.js Linux tarball (node-v*-linux-x64.tar.xz) not found!"
    exit 1
  fi
  tar -xf "$NODE_ARCHIVE" -C "$RUNTIME_DIR/node"
else
  echo "Extracting portable Node.js for Windows..."
  NODE_ARCHIVE=$(find Kobi_Installer/assets -name "node-v*-win-x64.zip" | head -n 1)
  if [ -z "$NODE_ARCHIVE" ]; then
    echo "Error: Node.js Windows ZIP file not found!"
    exit 1
  fi
  unzip -q "$NODE_ARCHIVE" -d "$RUNTIME_DIR/node"
fi
# 압축을 풀면 폴더 아래에 node-v*-<platform> 폴더가 생성되므로 내부 파일들을 바로 위로 이동
SUB_DIR=$(find "$RUNTIME_DIR/node" -maxdepth 1 -mindepth 1 -type d | head -n 1)
if [ ! -z "$SUB_DIR" ]; then
  mv "$SUB_DIR"/* "$RUNTIME_DIR/node/"
  rm -rf "$SUB_DIR"
fi

# (1-1) 포터블 git(MinGit) 압축 해제 (윈도우 전용)
# qwen-code 런타임(CLI·Desktop 공용)은 git 에 의존한다. 폐쇄망 개발 PC에 git 이 없으면
# 특히 Desktop(GUI) 실행이 실패하므로, Git for Windows 가 서드파티 번들용으로 제공하는
# 최소 배포판 MinGit(zip)을 함께 넣어 오프라인으로 git 을 제공한다. cmd\git.exe 가 PATH 진입점.
# 자산(MinGit-*-64-bit.zip)이 없으면 경고만 하고 계속 진행한다(시스템 git 이 있는 CLI 전용 배포 대비).
# NO_GIT=1 이면 대상 PC에 git 이 있다고 보고 포터블 git 을 제외해 추가 경량화한다.
if [ "$TARGET" != "linux" ] && [ "${NO_GIT:-0}" = "1" ]; then
  echo "NO_GIT=1: 포터블 git(MinGit) 제외로 패키징합니다(대상 PC에 git 이 설치되어 있어야 합니다)."
elif [ "$TARGET" != "linux" ]; then
  MINGIT_ARCHIVE=$(find Kobi_Installer/assets -maxdepth 2 -name "MinGit-*-64-bit.zip" | head -n 1)
  if [ -n "$MINGIT_ARCHIVE" ]; then
    echo "Extracting portable git (MinGit) for Windows..."
    mkdir -p "$RUNTIME_DIR/git"
    unzip -q "$MINGIT_ARCHIVE" -d "$RUNTIME_DIR/git"
    if [ ! -f "$RUNTIME_DIR/git/cmd/git.exe" ]; then
      echo "Error: MinGit 압축 해제 후 cmd/git.exe 를 찾을 수 없습니다. 자산 구조를 확인하세요."
      exit 1
    fi
  else
    echo "안내: MinGit-*-64-bit.zip 자산이 없어 포터블 git 없이 패키징합니다."
    echo "      (Desktop(GUI) 배포 시 대상 PC에 git 이 없으면 실행이 실패할 수 있습니다.)"
  fi
fi

# (2) Qwen Code 에이전트 오프라인 설치
# GUI 전용 빌드는 Desktop(GUI)이 자체 qwen-code 런타임을 내장하므로 CLI 에이전트를 설치하지 않는다.
if [ "$FLAVOR" = "gui" ]; then
  echo "GUI 전용 빌드: CLI 에이전트(qwen) 오프라인 설치를 건너뜁니다."
else
  if [ "$TARGET" = "linux" ]; then
    NPM_OS="linux"
  else
    NPM_OS="win32"
  fi
  echo "Pre-installing Qwen Code targeting $NPM_OS (x64)..."
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

  # npm install 실행 (타겟 플랫폼 64비트 타겟팅)
  npm install \
    --prefix "$RUNTIME_DIR/qwen" \
    "$TGZ_FILE" \
    --cache "Kobi_Installer/assets/npm-cache" \
    --offline \
    --os="$NPM_OS" \
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
fi

# (3) 설정 파일 및 지침 파일 복사
echo "Copying config files into Kobi_Runtime..."
cp Kobi_Installer/assets/config/settings.json "$RUNTIME_DIR/config/"
cp Kobi_Installer/assets/config/QWEN.md "$RUNTIME_DIR/config/"

# 리눅스 타겟은 단일 소스(settings.json)에서 플랫폼 차이만 인플레이스 패치한다.
#  - Computer Use: 리눅스용 cua-driver 바이너리가 없으므로 비활성화한다.
#  - 파괴적 명령 deny: 리눅스 전용 위험 명령을 추가한다(윈도우 전용 del/format 항목은 무해하여 유지).
if [ "$TARGET" = "linux" ]; then
  echo "Patching settings.json for Linux (disable computerUse, add Linux deny commands)..."
  SETTINGS_PATH="$RUNTIME_DIR/config/settings.json" node -e '
    const fs = require("fs");
    const p = process.env.SETTINGS_PATH;
    const cfg = JSON.parse(fs.readFileSync(p, "utf8"));
    cfg.tools = cfg.tools || {};
    cfg.tools.computerUse = { enabled: false };
    cfg.permissions = cfg.permissions || {};
    const deny = cfg.permissions.deny || [];
    for (const cmd of ["Bash(rmdir *)", "Bash(dd *)", "Bash(mkfs *)", "Bash(shred *)", "Bash(truncate *)"]) {
      if (!deny.includes(cmd)) deny.push(cmd);
    }
    cfg.permissions.deny = deny;
    fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n", "utf8");
  '
fi

# NO_COMPUTER_USE=1: Computer Use 자산을 아예 패키지에 넣지 않는 경우, settings.json도 함께
# 비활성화해 둔다(자산이 없는데 기능만 켜져 있으면 최초 사용 시 온라인 드라이버 다운로드를
# 시도하다 실패하므로). 리눅스는 이미 위에서 항상 비활성화되므로 중복 패치하지 않는다.
if [ "$TARGET" != "linux" ] && [ "${NO_COMPUTER_USE:-0}" = "1" ]; then
  echo "NO_COMPUTER_USE=1: settings.json의 Computer Use 기능을 비활성화합니다..."
  SETTINGS_PATH="$RUNTIME_DIR/config/settings.json" node -e '
    const fs = require("fs");
    const p = process.env.SETTINGS_PATH;
    const cfg = JSON.parse(fs.readFileSync(p, "utf8"));
    cfg.tools = cfg.tools || {};
    cfg.tools.computerUse = { enabled: false };
    fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n", "utf8");
  '
fi

# (4) bin/ 디렉터리에 실행 스크립트 작성 (GUI 전용은 CLI 런처가 불필요하므로 생략)
if [ "$FLAVOR" = "gui" ]; then
echo "GUI 전용 빌드: CLI 런처(kobi) 생성을 건너뜁니다."
elif [ "$TARGET" = "linux" ]; then
echo "Generating execution script (kobi) in bin..."
cat <<'KOBI_SH_EOF' > "$RUNTIME_DIR/bin/kobi"
#!/usr/bin/env bash
# Kobi(KB AI Assistant) 리눅스 실행 런처
# 설치 폴더 구조(Kobi_Runtime/{node,qwen,config,bin})를 기준으로 번들된 node로 qwen-code를 실행한다.

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
BIN_DIR="$(dirname "$SCRIPT_PATH")"
INSTALL_ROOT="$(dirname "$BIN_DIR")"

NODE="$INSTALL_ROOT/node/bin/node"
QWEN_CLI="$INSTALL_ROOT/qwen/node_modules/@qwen-code/qwen-code/cli-entry.js"
CONFIG_PATH="$INSTALL_ROOT/config/settings.json"

if [ ! -x "$NODE" ]; then
  echo "node 실행 파일을 찾을 수 없습니다: $NODE" >&2
  exit 1
fi
if [ ! -f "$QWEN_CLI" ]; then
  echo "Qwen Code CLI 실행 파일을 찾을 수 없습니다: $QWEN_CLI" >&2
  exit 1
fi

export QWEN_CODE_SYSTEM_SETTINGS_PATH="$CONFIG_PATH"
export PATH="$INSTALL_ROOT/node/bin:$PATH"

# 사내 vLLM 서버 API 키 사전 점검
# 저장된 키로 /models 를 미리 호출해 401(인증 필요)이면 그 자리에서 키를 입력받아 settings.json 에 저장한다.
# 네트워크 미연결 등 401 이외의 오류는 무시하고 평소대로 에이전트를 실행한다(접속 가능한 baseUrl만 있어도 되도록 순서대로 시도).
check_api_key() {
  [ -f "$CONFIG_PATH" ] || return 0
  command -v curl >/dev/null 2>&1 || return 0

  local meta env_key current_key urls url code new_key
  meta="$("$NODE" -e '
    const c = require(process.argv[1]);
    const p = (c.modelProviders && c.modelProviders.openai) || [];
    const envKey = (p[0] && p[0].envKey) || "";
    const cur = (c.env && c.env[envKey]) || "";
    process.stdout.write(envKey + "\n" + cur);
  ' "$CONFIG_PATH" 2>/dev/null)" || return 0

  env_key="$(printf '%s' "$meta" | sed -n '1p')"
  current_key="$(printf '%s' "$meta" | sed -n '2p')"
  [ -n "$env_key" ] || return 0

  urls="$("$NODE" -e '
    const c = require(process.argv[1]);
    const p = (c.modelProviders && c.modelProviders.openai) || [];
    process.stdout.write(p.map(x => x.baseUrl).filter(Boolean).join("\n"));
  ' "$CONFIG_PATH" 2>/dev/null)"
  [ -n "$urls" ] || return 0

  while IFS= read -r url; do
    [ -n "$url" ] || continue
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
      -H "Authorization: Bearer $current_key" "$url/models" 2>/dev/null)" || code=""
    if [ "$code" = "401" ]; then
      echo ""
      echo "============================================================"
      echo " [알림] 사내 vLLM 서버에 API 키 인증이 추가되었습니다."
      echo " 발급받은 API 키를 입력하면 설정 파일에 저장되어, 다음부터는 다시 묻지 않습니다."
      echo "============================================================"
      read -r -p "API 키 입력: " new_key
      if [ -z "$new_key" ]; then
        echo "키가 입력되지 않아 기존 설정으로 계속 진행합니다."
        return 0
      fi
      NEW_KEY="$new_key" ENV_KEY="$env_key" "$NODE" -e '
        const fs = require("fs");
        const p = process.argv[1];
        const c = JSON.parse(fs.readFileSync(p, "utf8"));
        c.env = c.env || {};
        c.env[process.env.ENV_KEY] = process.env.NEW_KEY.trim();
        fs.writeFileSync(p, JSON.stringify(c, null, 2) + "\n", "utf8");
      ' "$CONFIG_PATH"
      echo "API 키가 저장되었습니다."
      return 0
    fi
    # 401이 아니면(통신 불가, 또는 이미 인증 통과) 이 baseUrl은 넘어가고 나머지도 계속 확인한다.
    # 특정 단말에서는 통신이 안 되는 baseUrl이 방화벽/게이트웨이에 막혀 401이 아닌 다른
    # 응답(200/403 등)으로 위장될 수 있으므로, 하나가 "성공"처럼 보여도 검사를 멈추지 않고
    # 중요단말/업무단말 baseUrl을 전부 확인해야 실제로 통신되는 쪽의 401을 놓치지 않는다.
  done <<< "$urls"
}

check_api_key

APPEND_PROMPT='반드시 한국어로 답변한다.
사용자가 영어로 요청하지 않는 한 영어로 답변하지 않는다.
코드, 명령어, 파일명은 원문을 유지하되 설명은 한국어로 작성한다.
파일 수정 전에는 변경 계획을 먼저 제시한다.
검색 결과가 없으면 같은 검색을 반복하지 말고 중단한다.'

echo "Kobi 에이전트를 시작합니다..." >&2
exec "$NODE" "$QWEN_CLI" --append-system-prompt "$APPEND_PROMPT" "$@"
KOBI_SH_EOF
chmod +x "$RUNTIME_DIR/bin/kobi"
else
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

# node.exe 탐색은 파일이 많아 시간이 걸릴 수 있으므로, 백그라운드에서 찾는 동안
# 스피너 애니메이션을 표시해 "멈춘 것"처럼 보이지 않도록 한다.
function Show-Spinner {
    param(
        [System.Management.Automation.Job]$Job,
        [string]$Label
    )
    $SpinnerChars = @('|', '/', '-', '\')
    $i = 0
    while ($Job.State -eq 'Running') {
        $Frame = $SpinnerChars[$i % $SpinnerChars.Length]
        Write-Host -NoNewline ("`r{0} {1} " -f $Frame, $Label)
        Start-Sleep -Milliseconds 120
        $i++
    }
    # 스피너 라인 지우기
    Write-Host -NoNewline ("`r" + (' ' * ($Label.Length + 4)) + "`r")
}

$NodeSearchJob = Start-Job -ScriptBlock {
    param($NodeRoot)
    Get-ChildItem -Path $NodeRoot -Recurse -Filter "node.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
} -ArgumentList (Join-Path $InstallRoot "node")

Show-Spinner -Job $NodeSearchJob -Label "Kobi 실행 준비 중입니다..."
$NodeExePath = Receive-Job -Job $NodeSearchJob
Remove-Job -Job $NodeSearchJob -Force

if (-not $NodeExePath) {
    throw "node.exe 실행 파일을 찾을 수 없습니다."
}

$NodeDir    = Split-Path -Parent $NodeExePath
$QwenCliJs  = Join-Path $InstallRoot "qwen\node_modules\@qwen-code\qwen-code\cli-entry.js"
$ConfigPath = Join-Path $InstallRoot "config\settings.json"

if (-not (Test-Path $QwenCliJs)) {
    throw "Qwen Code CLI 실행 파일을 찾을 수 없습니다."
}

$env:QWEN_CODE_SYSTEM_SETTINGS_PATH = $ConfigPath
$env:Path = "$NodeDir;$env:Path"

# 번들 git(MinGit)이 있으면 이 세션 PATH 앞에 추가한다(별도 git 설치 없이 CLI 동작 보장).
$GitCmdDir = Join-Path $InstallRoot "git\cmd"
if (Test-Path (Join-Path $GitCmdDir "git.exe")) {
    $env:Path = "$GitCmdDir;$env:Path"
}

try {
    chcp 65001 | Out-Null
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new()
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
} catch {
}

# 사내 vLLM 서버 API 키 사전 점검
# vLLM 서버에 API 키 인증이 추가되어 있으면 기존에 저장된 키로 /models 를 미리 호출해 보고,
# 401(인증 필요) 응답이면 그 자리에서 키를 입력받아 settings.json 에 저장한다.
# 네트워크 미연결 등 401 이외의 오류는 무시하고 평소대로 에이전트를 실행한다(두 단말 baseUrl 중
# 접속 가능한 쪽만 있어도 되도록 순서대로 시도).
function Test-KobiApiKey {
    param([string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) { return }

    try {
        $RawConfig = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $Config = $RawConfig | ConvertFrom-Json
    } catch {
        return
    }

    $Providers = $Config.modelProviders.openai
    if (-not $Providers -or $Providers.Count -eq 0) { return }

    $EnvKeyName = $Providers[0].envKey
    $CurrentKey = $Config.env.$EnvKeyName

    foreach ($Provider in $Providers) {
        $ModelsUrl = "$($Provider.baseUrl)/models"
        try {
            Invoke-WebRequest -Uri $ModelsUrl `
                -Headers @{ "Authorization" = "Bearer $CurrentKey" } `
                -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
            # 통신도 되고 인증도 통과한 baseUrl이지만, 다른 단말(baseUrl)이 방화벽/게이트웨이에
            # 막혀 401이 아닌 다른 응답(200/403 등)으로 위장되는 경우가 있으므로 여기서 멈추지
            # 않고 나머지 baseUrl(중요단말/업무단말)도 계속 확인한다.
        } catch {
            $StatusCode = $null
            if ($_.Exception.Response) {
                $StatusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($StatusCode -eq 401) {
                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Yellow
                Write-Host " [알림] 사내 vLLM 서버에 API 키 인증이 추가되었습니다." -ForegroundColor Yellow
                Write-Host " 발급받은 API 키를 입력하면 설정 파일에 저장되어, 다음부터는 다시 묻지 않습니다." -ForegroundColor Yellow
                Write-Host "============================================================" -ForegroundColor Yellow
                $NewKey = Read-Host "API 키 입력"
                if ([string]::IsNullOrWhiteSpace($NewKey)) {
                    Write-Host "키가 입력되지 않아 기존 설정으로 계속 진행합니다." -ForegroundColor Yellow
                    return
                }

                $Config.env.$EnvKeyName = $NewKey.Trim()
                $UpdatedJson = $Config | ConvertTo-Json -Depth 20
                [System.IO.File]::WriteAllText($ConfigPath, $UpdatedJson, [System.Text.UTF8Encoding]::new($false))
                Write-Host "API 키가 저장되었습니다." -ForegroundColor Green
                return
            }
            # 401이 아니면(네트워크 오류 등) 다음 baseUrl을 시도한다.
        }
    }
}

# 현재 설정된 API 키와 연결 대상(단말/서버)을 콘솔에 표시한다.
function Show-KobiApiKey {
    param([string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) { return }
    try {
        $Config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { return }

    $Providers = $Config.modelProviders.openai
    if (-not $Providers -or $Providers.Count -eq 0) { return }

    $EnvKeyName = $Providers[0].envKey
    $CurrentKey = $Config.env.$EnvKeyName

    Write-Host ""
    Write-Host "설정된 API 키: $CurrentKey" -ForegroundColor Cyan
    Write-Host "  (envKey: $EnvKeyName)" -ForegroundColor DarkGray
    foreach ($Provider in $Providers) {
        Write-Host ("  - {0}: {1}" -f $Provider.name, $Provider.baseUrl) -ForegroundColor DarkGray
    }
    Write-Host ""
}

Test-KobiApiKey -ConfigPath $ConfigPath
Show-KobiApiKey -ConfigPath $ConfigPath

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

Write-Host "Kobi 에이전트를 시작합니다..." -ForegroundColor DarkGray

& $NodeExePath "$QwenCliJs" --append-system-prompt $AppendPrompt @QwenArgs
exit $LASTEXITCODE
EOF
fi

# 5. 배포용 빌드 결과 패키징 구성 (불필요한 대용량 캐시 및 원본 압축파일 제거)
echo "----------------------------------------------------------"
echo " Packaging distribution release structure..."
echo "----------------------------------------------------------"
DIST_DIR="dist"
rm -rf "$DIST_DIR"
DIST_PKG_DIR="$DIST_DIR/$DIST_ROOT_NAME"
mkdir -p "$DIST_PKG_DIR"

# 설치/제거 스크립트 복사 (타겟별)
if [ "$TARGET" = "linux" ]; then
  cp Kobi_Installer/install.sh "$DIST_PKG_DIR/"
  cp Kobi_Installer/uninstall.sh "$DIST_PKG_DIR/"
  chmod +x "$DIST_PKG_DIR/install.sh" "$DIST_PKG_DIR/uninstall.sh"
else
  cp Kobi_Installer/Install-Kobi.cmd "$DIST_PKG_DIR/"
  cp Kobi_Installer/Install-Kobi.ps1 "$DIST_PKG_DIR/"
  cp Kobi_Installer/Uninstall-Kobi.cmd "$DIST_PKG_DIR/"
  cp Kobi_Installer/Uninstall-Kobi.ps1 "$DIST_PKG_DIR/"
fi

# 필수 assets 복사 (스킬 5종)
# GUI 전용 빌드는 스킬을 담지 않는다(별도 배포: ./make.sh skills → Kobi_Skills_v*.zip).
mkdir -p "$DIST_PKG_DIR/assets"
if [ "$FLAVOR" = "gui" ] || [ "$NO_SKILLS" = "1" ]; then
  echo "스킬 5종을 패키지에서 제외합니다(별도 배포 번들 사용: ./make.sh skills)."
else
  cp Kobi_Installer/assets/jennifer-monitor.skill "$DIST_PKG_DIR/assets/"
  cp Kobi_Installer/assets/project-bootstrap.skill "$DIST_PKG_DIR/assets/"
  cp Kobi_Installer/assets/frism-cm.skill "$DIST_PKG_DIR/assets/"
  cp Kobi_Installer/assets/office-edit.skill "$DIST_PKG_DIR/assets/"
  cp Kobi_Installer/assets/kbpay-service-check.skill "$DIST_PKG_DIR/assets/"
fi

# Computer Use(화면 읽기 전용) 드라이버 자산 복사 (윈도우 전용; 리눅스는 드라이버 없음 → 생략)
# NO_COMPUTER_USE=1 이면 자산 자체를 빼서 패키지를 경량화한다(settings.json은 이미 위에서 비활성화됨).
if [ "$TARGET" != "linux" ] && [ "${NO_COMPUTER_USE:-0}" = "1" ]; then
  echo "NO_COMPUTER_USE=1: Computer Use 드라이버 자산을 패키지에서 제외합니다."
elif [ "$TARGET" != "linux" ]; then
  mkdir -p "$DIST_PKG_DIR/assets/computer-use"
  cp Kobi_Installer/assets/computer-use/cua-driver-rs-0.5.2-windows-x86_64.zip "$DIST_PKG_DIR/assets/computer-use/"
fi

# Kobi Desktop(GUI) 설치물 복사 (윈도우 전용)
# 리브랜딩 빌드 산출물(desktop-brand/build-desktop.sh 참고)이 있을 때만 포함한다.
# 폐쇄망 반입용으로 미리 빌드해 assets/desktop 에 넣어두는 것이 전제이며,
# 아직 빌드하지 않았다면 경고만 출력하고 CLI 전용 패키지로 계속 진행한다.
if [ "$TARGET" != "linux" ] && [ "$NO_DESKTOP" = "1" ] && [ "$FLAVOR" != "gui" ]; then
  echo "NO_DESKTOP=1: Kobi Desktop(GUI)을 패키지에서 제외합니다(CLI 전용)."
elif [ "$TARGET" != "linux" ]; then
  DESKTOP_EXE=$(find Kobi_Installer/assets/desktop -maxdepth 1 -name "Kobi-Desktop-*.exe" 2>/dev/null | head -n 1)
  if [ -n "$DESKTOP_EXE" ]; then
    mkdir -p "$DIST_PKG_DIR/assets/desktop"
    cp "$DESKTOP_EXE" "$DIST_PKG_DIR/assets/desktop/"
    echo "Kobi Desktop 설치물이 배포 패키지에 포함되었습니다: $(basename "$DESKTOP_EXE")"
  elif [ "$FLAVOR" = "gui" ]; then
    echo "Error: GUI 전용 빌드인데 Kobi-Desktop-*.exe 자산이 없습니다."
    echo "       desktop-brand/build-desktop.sh 로 먼저 Desktop 을 빌드해 assets/desktop 에 넣으세요."
    exit 1
  else
    echo "안내: Kobi-Desktop-*.exe 자산이 없어 Desktop(GUI) 없이 CLI 전용으로 패키징합니다."
    echo "      (Desktop 포함 배포를 원하면 desktop-brand/build-desktop.sh 로 먼저 빌드하세요.)"
  fi
fi

# Kobi_Runtime 복사
cp -r "$RUNTIME_DIR" "$DIST_PKG_DIR/"

# 기존 산출물 및 체크섬 파일 정리
rm -f "$PKG_NAME" "$SHA_NAME"

# 압축 생성 (dist/ 폴더 내부에서 실행하여 루트 폴더명을 유지)
if [ "$TARGET" = "linux" ]; then
  echo "Creating tar.gz archive..."
  (cd "$DIST_DIR" && tar -czf "../$PKG_NAME" "$DIST_ROOT_NAME")
else
  echo "Creating optimized ZIP file..."
  (cd "$DIST_DIR" && python3 -m zipfile -c "../$PKG_NAME" "$DIST_ROOT_NAME")
fi

# SHA-256 체크섬 생성
sha256sum "$PKG_NAME" > "$SHA_NAME"

# 빌드 중간 작업물 정리
rm -rf "$DIST_DIR"
rm -rf "$RUNTIME_DIR"

echo "=========================================================="
echo " Packaging completed successfully!"
echo " Result Files:"
ls -lh "$PKG_NAME" "$SHA_NAME"
echo "=========================================================="
