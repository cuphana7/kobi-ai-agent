#!/usr/bin/env bash
#
# Kobi Desktop(GUI) 리브랜딩 + Windows NSIS 설치본 크로스 빌드
# ============================================================================
# 인터넷이 되는 Linux 빌드 PC(예: Google Cloud Shell)에서 실행한다.
# 상위 QwenLM/qwen-code 의 Electron 데스크톱 앱을 고정 태그로 받아
#   1) upstream 공식 리브랜딩 스킬(brand-create.ts)로 "Kobi" 브랜드를 생성하고
#      (제품명/appId/artifactName/아이콘/앱 내부 표시명을 한 번에 처리)
#   2) 내장 CLI 런타임을 kobi CLI 와 동일한 qwen-code tarball 로 vendoring 하고
#   3) Windows NSIS 설치본(Kobi-Desktop-x64.exe)을 빌드하여
#   4) Kobi_Installer/assets/desktop/ 에 넣고 SHA-256 을 기록한다.
#
# ── 왜 이렇게 하나 (실측으로 확인된 사실) ──────────────────────────────────
# * 리브랜딩은 electron-builder.yml 을 직접 고치면 안 된다. 상위 빌드는
#   branding.ts 의 BRAND 로부터 electron-builder.generated.yml 을 매번 재생성한다.
#   → 반드시 brand-create.ts 로 브랜드를 만들고 CRAFT_BRAND 로 선택한다.
# * Linux 호스트에서 electron-builder 26.x 는 (1)rcedit (2)signtool
#   (3)NSIS 언인스톨러 생성 에 Wine 을 쓴다. (3)은 끌 수 없어 Wine 이 필요하다.
#   "app-builder 가 rcedit 를 네이티브로" 는 호스트가 win/mac 일 때만 참이다.
# * Ubuntu 의 wine 9.0 repack 은 이 워크로드에서 세그폴트/glibc 힙 abort 로 실패한다.
#   → WineHQ winehq-stable(wine-10/11) + ASLR off(setarch -R) + MALLOC_CHECK_=0
#     + WINEARCH=win32 프리픽스 조합이라야 통과한다.
# * rcedit 는 대용량(≈180MB) electron exe 에서 여전히 abort 하므로
#   signAndEditExecutable:false 로 끈다(내부 exe 는 electron 기본 아이콘,
#   설치 프로그램 setup 아이콘은 Kobi). 내부 exe 까지 완전 브랜딩하려면
#   실제 Windows/CI 에서 빌드한다.
#
# ── 사전 요구사항 ──────────────────────────────────────────────────────────
#   - git, bun, setarch(util-linux)
#   - WineHQ winehq-stable (Ubuntu 24.04/noble 예):
#       sudo dpkg --add-architecture i386
#       sudo mkdir -pm755 /etc/apt/keyrings
#       sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
#       sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources
#       sudo apt-get update && sudo apt-get install -y --install-recommends winehq-stable
#   - (권장) xvfb: sudo apt-get install -y xvfb
#   - Kobi 로고 이미지 한 장: desktop-brand/icons/logo.png (또는 logo.svg).
#     brand-create.ts 가 sharp 로 아이콘/심볼을 생성한다(SVG 도 입력 가능).
#
set -euo pipefail

# ── 브랜드 파라미터(필요 시 환경변수로 오버라이드) ──────────────────────────
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/QwenLM/qwen-code.git}"
UPSTREAM_TAG="${UPSTREAM_TAG:-desktop-latest}"

BRAND_ID="${BRAND_ID:-kobi}"
APP_NAME="${APP_NAME:-Kobi}"
APP_ID="${APP_ID:-com.kbcard.kobi}"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-Kobi-Desktop}"   # 산출물명 접두 → Kobi-Desktop-x64.exe
COPYRIGHT="${COPYRIGHT:-Copyright © $(date +%Y) KB Card}"

# ── 경로 계산(이 스크립트는 kobi-package/desktop-brand/ 안에 있다고 가정) ───
BRAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOBI_ROOT="$(cd "$BRAND_DIR/.." && pwd)"
ASSETS_DESKTOP_DIR="$KOBI_ROOT/Kobi_Installer/assets/desktop"

die() { echo "오류: $*" >&2; exit 1; }

# ── 사전 점검 ──────────────────────────────────────────────────────────────
command -v git >/dev/null      || die "git 이 필요합니다."
command -v bun >/dev/null      || die "bun 이 필요합니다(상위 저장소 .bun-version 참고)."
command -v setarch >/dev/null  || die "setarch(util-linux) 가 필요합니다."

# WineHQ 바이너리 탐지(가급적 /opt/wine-stable). Ubuntu repack 이면 경고.
WINE_BIN="${WINE_BIN:-/opt/wine-stable/bin/wine}"
[ -x "$WINE_BIN" ] || WINE_BIN="$(command -v wine || true)"
[ -n "$WINE_BIN" ] || die "wine 이 필요합니다. WineHQ winehq-stable 설치를 권장합니다(상단 주석 참고)."
WINE_VER="$("$WINE_BIN" --version 2>/dev/null || echo unknown)"
echo "Wine: $WINE_BIN ($WINE_VER)"
case "$WINE_VER" in
  wine-9.*|wine-8.*|wine-7.*|wine-6.*|wine-5.*)
    echo "경고: 구버전/Ubuntu repack Wine 은 NSIS 언인스톨러 생성에서 실패한 사례가 있습니다." >&2
    echo "      실패 시 WineHQ winehq-stable 로 교체하세요." >&2 ;;
esac

# 내장 CLI 런타임으로 vendoring 할 tarball(= CLI 와 동일 버전 보장)
QWEN_TARBALL="$(find "$KOBI_ROOT/Kobi_Installer/assets/pkg" -name 'qwen-code-qwen-code-*.tgz' | head -n 1)"
[ -n "${QWEN_TARBALL:-}" ] || die "Kobi_Installer/assets/pkg 에서 qwen-code tarball(.tgz)을 찾지 못했습니다."
QWEN_TARBALL="$(cd "$(dirname "$QWEN_TARBALL")" && pwd)/$(basename "$QWEN_TARBALL")"
echo "vendoring CLI tarball: $QWEN_TARBALL"

# 로고 탐지(brand-create.ts 입력). KOBI_LOGO 로 명시 가능.
LOGO="${KOBI_LOGO:-}"
if [ -z "$LOGO" ]; then
  for f in logo.png logo.svg icon.png icon.svg; do
    [ -f "$BRAND_DIR/icons/$f" ] && LOGO="$BRAND_DIR/icons/$f" && break
  done
fi
[ -n "$LOGO" ] && [ -f "$LOGO" ] || die "Kobi 로고가 없습니다. desktop-brand/icons/logo.png(또는 .svg)를 넣거나 KOBI_LOGO 로 지정하세요."
LOGO="$(cd "$(dirname "$LOGO")" && pwd)/$(basename "$LOGO")"
echo "브랜드 로고: $LOGO"

# ── 작업 디렉터리(큰 디스크 권장; Cloud Shell 은 /tmp=overlay 가 크고 /home 은 작다) ─
WORK_DIR="${WORK_DIR:-$(mktemp -d)}"
SRC_DIR="$WORK_DIR/qwen-code"
DESKTOP_DIR="$SRC_DIR/packages/desktop"
ELECTRON_DIR="$DESKTOP_DIR/apps/electron"
echo "작업 디렉터리: $WORK_DIR"

# bun/electron 캐시를 작업 디스크로(특히 Cloud Shell 의 작은 /home 회피)
export BUN_INSTALL_CACHE_DIR="${BUN_INSTALL_CACHE_DIR:-$WORK_DIR/.bun-cache}"
export ELECTRON_CACHE="${ELECTRON_CACHE:-$WORK_DIR/.electron-cache}"
export TMPDIR="${TMPDIR:-$WORK_DIR/.tmp}"
mkdir -p "$BUN_INSTALL_CACHE_DIR" "$ELECTRON_CACHE" "$TMPDIR"

# ── 1) 상위 소스 clone ─────────────────────────────────────────────────────
echo "상위 소스 clone: $UPSTREAM_REPO ($UPSTREAM_TAG)"
rm -rf "$SRC_DIR"
git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$SRC_DIR"
[ -f "$ELECTRON_DIR/electron-builder.yml" ] || die "$ELECTRON_DIR/electron-builder.yml 없음(상위 구조 변경 확인)."

# ── 2) 데스크톱 의존성 설치 ────────────────────────────────────────────────
# 상위 루트 workspaces 는 packages/desktop 을 제외("!packages/desktop")하므로
# 루트 install 대신 desktop 에서 직접 설치한다(brand-create 의 sharp 도 여기 있음).
# (루트 bun install 은 vscode-ide-companion 의 esbuild postinstall 로 실패할 수 있어 생략)
echo "[install] packages/desktop ..."
( cd "$DESKTOP_DIR" && bun install )

# ── 3) 브랜드 생성(brand-create.ts) ────────────────────────────────────────
BRAND_JSON="$WORK_DIR/brand.json"
cat > "$BRAND_JSON" <<JSON
{
  "brandId": "$BRAND_ID",
  "logo": "$LOGO",
  "appName": "$APP_NAME",
  "appId": "$APP_ID",
  "artifactPrefix": "$ARTIFACT_PREFIX",
  "copyright": "$COPYRIGHT"
}
JSON
BRAND_CREATE="$DESKTOP_DIR/.agents/skills/desktop-brand-builder/scripts/brand-create.ts"
[ -f "$BRAND_CREATE" ] || die "brand-create.ts 를 찾지 못했습니다(상위 스킬 경로 변경 확인): $BRAND_CREATE"
echo "[brand] brand-create.ts 실행 ($BRAND_ID)"
( cd "$SRC_DIR" && bun run "$BRAND_CREATE" --desktop-root "$DESKTOP_DIR" --config "$BRAND_JSON" )

# ── 4) win 설정에 signAndEditExecutable:false 주입 ─────────────────────────
# rcedit(exe 아이콘/버전 삽입)는 대용량 electron exe 에서 wine abort 를 일으킨다.
# 이 스텝과 signtool 을 끄면 남는 wine 사용처는 NSIS 언인스톨러 생성뿐이다.
# electron-builder.generated.yml 은 electron-builder.yml 을 로드해 파생되므로
# 원본 win: 블록에 넣으면 보존된다.
BUILDER_YML="$ELECTRON_DIR/electron-builder.yml"
if ! grep -qE '^[[:space:]]*signAndEditExecutable:' "$BUILDER_YML"; then
  awk '
    /^win:[[:space:]]*$/ && !done {
      print
      print "  # Linux 크로스빌드: rcedit(대용량 exe 에서 wine abort)+signtool 스킵."
      print "  signAndEditExecutable: false"
      done = 1
      next
    }
    { print }
  ' "$BUILDER_YML" > "$BUILDER_YML.tmp" && mv "$BUILDER_YML.tmp" "$BUILDER_YML"
  echo "[patch] win.signAndEditExecutable: false 주입"
fi

# ── 5) Wine 래퍼 + win32 프리픽스 준비 ─────────────────────────────────────
# electron-builder 는 PATH 의 bare `wine` 를 호출한다. ASLR off(setarch -R)+
# MALLOC_CHECK_=0 로 감싼 래퍼를 PATH 앞에 둬 세그폴트/glibc 힙 abort 를 피한다.
WINEWRAP="$WORK_DIR/winewrap"
mkdir -p "$WINEWRAP"
WINE64_BIN="${WINE_BIN%/wine}/wine64"; [ -x "$WINE64_BIN" ] || WINE64_BIN="$(command -v wine64 || echo "$WINE_BIN")"
cat > "$WINEWRAP/wine" <<EOF
#!/bin/sh
export MALLOC_CHECK_=0
exec setarch "\$(uname -m)" -R "$WINE_BIN" "\$@"
EOF
cat > "$WINEWRAP/wine64" <<EOF
#!/bin/sh
export MALLOC_CHECK_=0
exec setarch "\$(uname -m)" -R "$WINE64_BIN" "\$@"
EOF
chmod +x "$WINEWRAP/wine" "$WINEWRAP/wine64"

# 프리픽스는 반드시 사용자 소유 디렉터리에(예: WORK_DIR 하위). /tmp 루트는 wine 이 거부.
export WINEPREFIX="$WORK_DIR/wineprefix"
export WINEARCH=win32
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree,mshtml="
echo "[wine] win32 프리픽스 초기화: $WINEPREFIX"
"$WINEWRAP/wine" wineboot --init >/dev/null 2>&1 || die "wineboot 실패(WineHQ 설치/권한 확인)."

# ── 6) 빌드(내장 CLI 런타임 vendoring + Kobi 브랜드 선택) ───────────────────
export PATH="$WINEWRAP:$PATH"
export CRAFT_BRAND="$BRAND_ID"
export QWEN_CODE_TARBALL="$QWEN_TARBALL"

# NSIS 언인스톨러 생성 시 설치 프로그램을 wine 으로 실행 → 가상 디스플레이 권장.
RUN=( )
if command -v xvfb-run >/dev/null; then RUN=( xvfb-run -a ); fi

echo "[build] electron:dist:win (Kobi, wine=$WINE_VER) ..."
( cd "$DESKTOP_DIR" && "${RUN[@]}" bun run electron:dist:win:no-publish )

# ── 7) 산출물 수집 ─────────────────────────────────────────────────────────
RELEASE_DIR="$ELECTRON_DIR/release"
BUILT_EXE="$(find "$RELEASE_DIR" -maxdepth 1 -name "${ARTIFACT_PREFIX}-*.exe" | head -n 1 || true)"
[ -n "${BUILT_EXE:-}" ] || { echo "산출물(${ARTIFACT_PREFIX}-*.exe) 없음. release 목록:" >&2; ls -la "$RELEASE_DIR" >&2 || true; exit 1; }

mkdir -p "$ASSETS_DESKTOP_DIR"
cp "$BUILT_EXE" "$ASSETS_DESKTOP_DIR/"
DEST_EXE="$ASSETS_DESKTOP_DIR/$(basename "$BUILT_EXE")"
( cd "$ASSETS_DESKTOP_DIR" && sha256sum "$(basename "$BUILT_EXE")" > "$(basename "$BUILT_EXE").sha256" )

echo "=========================================================="
echo " Kobi Desktop 빌드 완료 (미서명; 내부 exe 는 electron 기본 아이콘)"
echo "  산출물 : $DEST_EXE"
echo "  체크섬 : $DEST_EXE.sha256"
echo " 다음: ./make.sh windows 로 배포 zip 에 포함"
echo "=========================================================="
