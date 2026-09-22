#!/usr/bin/env bash
# KB AI Assistant (Kobi) 리눅스 제거 스크립트
# Windows용 Uninstall-Kobi.ps1 의 리눅스(bash) 이식본이다.

echo ""
echo "============================================================"
echo " KB AI Assistant 제거 프로그램 (리눅스 오프라인 배포판)"
echo "============================================================"

INSTALLER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
INSTALL_ROOT="$INSTALLER_ROOT/Kobi_Runtime"
QWEN_HOME="$HOME/.qwen"
SKILLS_DIR="$QWEN_HOME/skills"
LOCAL_BIN="$HOME/.local/bin"
PATH_MARKER_BEGIN="# >>> Kobi PATH >>>"
PATH_MARKER_END="# <<< Kobi PATH <<<"

echo "제거 대상 경로: $INSTALL_ROOT"

# 1. 실행 중인 Kobi 관련 프로세스 종료
echo ""
echo "[1/3] 실행 중인 Kobi 관련 프로세스 검사 및 종료"
pkill -f "Kobi_Runtime" 2>/dev/null || true
echo "프로세스 정리가 완료되었습니다."

# 2. 실행 경로(PATH) 정리: 심링크 제거 + 셸 rc 마커 블록 삭제
echo ""
echo "[2/3] kobi 실행 경로(PATH) 제거"
if [ -L "$LOCAL_BIN/kobi" ] || [ -e "$LOCAL_BIN/kobi" ]; then
    rm -f "$LOCAL_BIN/kobi"
    echo "심볼릭 링크가 제거되었습니다: $LOCAL_BIN/kobi"
fi
for _rc in "$HOME/.profile" "$HOME/.bashrc"; do
    if [ -f "$_rc" ] && grep -qF "$PATH_MARKER_BEGIN" "$_rc"; then
        sed -i "\|$PATH_MARKER_BEGIN|,\|$PATH_MARKER_END|d" "$_rc"
        echo "PATH 설정이 제거되었습니다: $_rc"
    fi
done

# 3. 홈 디렉토리 내 .qwen 설정 및 스킬 데이터 정리
echo ""
echo "[3/3] 사용자 홈 디렉토리의 설정 및 스킬 데이터 정리"
rm -f "$QWEN_HOME/QWEN.md"
rm -f "$QWEN_HOME/output-language.md"
for _skill in jennifer-monitor project-bootstrap frism-cm office-edit kbpay-service-check; do
    rm -rf "$SKILLS_DIR/$_skill"
done
# (Computer Use 드라이버는 리눅스에서 배포하지 않으므로 삭제 대상 없음)

# 비어 있는 경우에만 skills/ 및 .qwen/ 폴더 제거
rmdir "$SKILLS_DIR" 2>/dev/null || true
rmdir "$QWEN_HOME" 2>/dev/null || true
echo "설정 및 스킬 정리가 완료되었습니다."

echo ""
echo "============================================================"
echo " KB AI Assistant 제거가 완료되었습니다!"
echo "============================================================"
echo ""
echo "압축을 풀었던 원본 폴더를 삭제하면 완전히 제거됩니다."
echo ""
