#!/usr/bin/env bash
# KB AI Assistant (Kobi) 리눅스 오프라인 설치 스크립트
# Windows용 Install-Kobi.ps1 의 리눅스(bash) 이식본이다.
# 대상: x86_64 glibc 리눅스 배포판. 필요 도구: unzip(또는 bsdtar), curl, tar.

# ============================================================
# [보안 권한 제약] 허가된 사용자 계정 검증
# ------------------------------------------------------------
# 아래 배열에는 설치를 허용할 "리눅스 로그인 계정명"을 넣는다.
# (윈도우 배포판은 도메인 계정 K1210xx 를 사용하므로 리눅스 계정과 다를 수 있음)
# ★ 배포 관리자는 배포 전 반드시 실제 허용 계정으로 이 배열을 갱신해야 하며,
#   목록에 없는 계정은 설치가 차단된다.
# ============================================================
ALLOWED_USERS=("K121105" "K121086" "K122226" "K122518" "K122522" "K123624" "K123863")

CURRENT_USER="$(id -un)"
_allowed=0
for _u in "${ALLOWED_USERS[@]}"; do
    if [ "$_u" = "$CURRENT_USER" ]; then _allowed=1; break; fi
done
if [ "$_allowed" -ne 1 ]; then
    echo ""
    echo "============================================================"
    echo " [오류] 설치 권한이 없는 사용자 계정입니다."
    echo " 사용자 계정: $CURRENT_USER"
    echo "============================================================"
    echo " 본 패키지는 허가된 사용자만 설치할 수 있는 전용 배포판입니다."
    echo " 설치 권한 및 라이선스 요청은 사내 배포 관리자에게 문의하세요."
    echo ""
    exit 1
fi

echo ""
echo "============================================================"
echo " KB AI Assistant 설치 프로그램 (리눅스 오프라인 배포판)"
echo "============================================================"

INSTALLER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
INSTALL_ROOT="$INSTALLER_ROOT/Kobi_Runtime"
BIN_DIR="$INSTALL_ROOT/bin"
QWEN_HOME="$HOME/.qwen"
SKILLS_DIR="$QWEN_HOME/skills"
LOCAL_BIN="$HOME/.local/bin"
PATH_MARKER_BEGIN="# >>> Kobi PATH >>>"
PATH_MARKER_END="# <<< Kobi PATH <<<"

echo "설치 대상 경로: $INSTALL_ROOT"

# 1. 기존 구동 중인 Kobi 관련 프로세스 종료 및 정리
echo ""
echo "[1/3] 실행 중인 Kobi 관련 프로세스 종료 및 정리"
pkill -f "Kobi_Runtime" 2>/dev/null || true

# 2. 사내 환경설정 파일 및 스킬 배포
echo ""
echo "[2/3] 사용자 설정 및 스킬 배포"
mkdir -p "$QWEN_HOME"

# QWEN.md 배포
if [ -f "$INSTALL_ROOT/config/QWEN.md" ]; then
    cp -f "$INSTALL_ROOT/config/QWEN.md" "$QWEN_HOME/QWEN.md"
fi

# 한국어 출력 헬퍼 설정 파일 생성
cat > "$QWEN_HOME/output-language.md" <<'OUTPUT_LANG_EOF'
# Output Language

Always respond in Korean unless the user explicitly asks for another language.
OUTPUT_LANG_EOF

# 스킬(.skill = zip) 압축 해제
mkdir -p "$SKILLS_DIR"
install_skill() {
    local name="$1"
    local src="$INSTALLER_ROOT/assets/$name.skill"
    local dest="$SKILLS_DIR/$name"
    if [ ! -f "$src" ]; then
        echo "안내: $name.skill 자산이 없어 건너뜁니다."
        return
    fi
    rm -rf "$dest"
    mkdir -p "$dest"
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$src" -d "$dest"
    elif command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$src" -C "$dest"
    else
        echo "오류: unzip 또는 bsdtar 가 필요합니다. 스킬 '$name' 설치를 건너뜁니다." >&2
        return
    fi
    echo "스킬이 설치되었습니다: $name"
}

for _skill in jennifer-monitor project-bootstrap frism-cm office-edit kbpay-service-check; do
    install_skill "$_skill"
done

# 참고: Computer Use(화면 읽기) 기능은 리눅스용 드라이버가 없어 비활성화되어 있으므로 배포 단계가 없다.

# 3. 실행 경로(PATH) 등록: ~/.local/bin 심볼릭 링크 + 셸 rc 반영
echo ""
echo "[3/3] kobi 실행 경로 등록"
chmod +x "$BIN_DIR/kobi" 2>/dev/null || true
mkdir -p "$LOCAL_BIN"
ln -sfn "$BIN_DIR/kobi" "$LOCAL_BIN/kobi"
echo "심볼릭 링크가 등록되었습니다: $LOCAL_BIN/kobi -> $BIN_DIR/kobi"

# ~/.local/bin 이 PATH 에 없으면 로그인/대화형 셸 rc 에 1회 추가(멱등)
case ":$PATH:" in
    *":$LOCAL_BIN:"*) : ;;  # 이미 포함됨
    *)
        for _rc in "$HOME/.profile" "$HOME/.bashrc"; do
            if ! grep -qF "$PATH_MARKER_BEGIN" "$_rc" 2>/dev/null; then
                {
                    echo ""
                    echo "$PATH_MARKER_BEGIN"
                    echo 'export PATH="$HOME/.local/bin:$PATH"'
                    echo "$PATH_MARKER_END"
                } >> "$_rc"
                echo "PATH 설정이 추가되었습니다: $_rc"
            fi
        done
        ;;
esac

# 4. 최종 설치 상태 검증
echo ""
echo "최종 설치 상태 검증 중..."
NODE="$INSTALL_ROOT/node/bin/node"
QWEN_CLI="$INSTALL_ROOT/qwen/node_modules/@qwen-code/qwen-code/cli-entry.js"
if [ ! -x "$NODE" ]; then
    echo "오류: node 실행 파일을 찾을 수 없습니다: $NODE" >&2
    exit 1
fi
if [ ! -f "$QWEN_CLI" ]; then
    echo "오류: Qwen Code CLI 실행 파일을 찾을 수 없습니다: $QWEN_CLI" >&2
    exit 1
fi
QWEN_CODE_SYSTEM_SETTINGS_PATH="$INSTALL_ROOT/config/settings.json" "$NODE" "$QWEN_CLI" --version || true

echo ""
echo "============================================================"
echo " KB AI Assistant 설치가 성공적으로 완료되었습니다!"
echo "============================================================"
echo ""
echo "사용 방법:"
echo "  1. 새 터미널을 열거나 'source ~/.profile' 을 실행해 PATH를 반영합니다."
echo "  2. 분석하려는 프로젝트 폴더로 이동합니다."
echo "     cd ~/work/my-java-project"
echo "  3. kobi 명령어를 실행하여 도우미를 호출합니다:"
echo "     kobi"
echo ""
echo "※ 긴 프롬프트(지침문)를 실행하려면 파일이나 클립보드 내용을 넘길 수 있습니다:"
echo "     kobi -p \"\$(cat prompt.txt)\""
echo "     kobi -p \"\$(xclip -o -selection clipboard)\"   # xclip 설치 시"
echo ""
