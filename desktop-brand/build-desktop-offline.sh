#!/usr/bin/env bash
#
# Kobi Desktop 오프라인/사내망 빌드 (git clone 없이 로컬 소스로 빌드)
# ============================================================================
# 전제: 이 PC 는 (1) MSYS(git/curl) 소켓 차단 또는 (2) 사내 TLS 검사(SSL 인터셉트)
#   → git clone 불가: 상위 소스는 브라우저로 zip 을 받아 풀어두고 그 경로를 인자로 준다.
#   → 네이티브 bun/node: NODE_EXTRA_CA_CERTS 로 회사 루트 CA 를 신뢰시키면 다운로드가 통과한다.
#
# 브랜딩·빌드 방식은 build-desktop.sh 와 동일하다(차이는 "clone 대신 로컬 소스"뿐):
#   - upstream 공식 brand-create.ts 로 "Kobi" 브랜드 생성(옛 sed 방식은 무효)
#   - packages/desktop 에서만 의존성 설치
#   - CLI 와 동일한 qwen-code tarball 을 QWEN_CODE_TARBALL 로 vendoring
#   - Windows NSIS 설치본 빌드 → Kobi_Installer/assets/desktop/ + .sha256
#
# 플랫폼:
#   - Windows(MSYS/Git Bash)에서 실행하면 rcedit/signtool/언인스톨러가 네이티브라
#     Wine 이 불필요하고 내부 exe 아이콘까지 완전 브랜딩된다(권장).
#   - Linux 에서 실행하면 build-desktop.sh 와 같은 WineHQ 경로를 자동 적용한다
#     (WineHQ winehq-stable + setarch -R + MALLOC_CHECK_=0 + win32 프리픽스,
#      rcedit 는 스킵되어 내부 exe 는 electron 기본 아이콘).
#
# 사용법:
#   export NODE_EXTRA_CA_CERTS="C:/Users/K121105/Downloads/corp-ca-bundle.pem"   # TLS 인터셉트 시
#   ./desktop-brand/build-desktop-offline.sh /c/Users/K121105/Downloads/qwen-code-desktop-latest
#
set -euo pipefail

# ── 브랜드 파라미터(환경변수로 오버라이드 가능) ────────────────────────────
BRAND_ID="${BRAND_ID:-kobi}"
APP_NAME="${APP_NAME:-Kobi}"
APP_ID="${APP_ID:-com.kbcard.kobi}"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-Kobi-Desktop}"
COPYRIGHT="${COPYRIGHT:-Copyright © $(date +%Y) KB Card}"

BRAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOBI_ROOT="$(cd "$BRAND_DIR/.." && pwd)"
ASSETS_DESKTOP_DIR="$KOBI_ROOT/Kobi_Installer/assets/desktop"

die() { echo "오류: $*" >&2; exit 1; }

case "$(uname -s)" in
  Linux) IS_LINUX=1; echo "플랫폼: Linux (WineHQ 경로 적용)";;
  *)     IS_LINUX=0; echo "플랫폼: $(uname -s) (Windows 네이티브 빌드로 간주)";;
esac

# ── 로컬 소스(clone 대체) ──────────────────────────────────────────────────
SRC_DIR="${1:-${LOCAL_SRC:-}}"
[ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/package.json" ] || \
  die "추출된 상위 소스 경로를 인자로 주세요(그 안에 package.json 존재). 예) $0 /c/Users/.../qwen-code-desktop-latest"
SRC_DIR="$(cd "$SRC_DIR" && pwd)"
DESKTOP_DIR="$SRC_DIR/packages/desktop"
ELECTRON_DIR="$DESKTOP_DIR/apps/electron"
echo "로컬 소스: $SRC_DIR"
[ -f "$ELECTRON_DIR/electron-builder.yml" ] || die "$ELECTRON_DIR/electron-builder.yml 없음(소스 구조 확인)."

# ── 사전 점검 ──────────────────────────────────────────────────────────────
command -v bun >/dev/null || die "bun 이 필요합니다."
if [ -z "${NODE_EXTRA_CA_CERTS:-}" ]; then
  echo "경고: NODE_EXTRA_CA_CERTS 미설정. 사내 TLS 검사 환경이면 다운로드가 인증서 오류로 실패합니다." >&2
else
  echo "회사 CA: $NODE_EXTRA_CA_CERTS"
fi

# vendoring tarball(CLI 런타임 = pkg 의 tgz)
QWEN_TARBALL="$(find "$KOBI_ROOT/Kobi_Installer/assets/pkg" -name 'qwen-code-qwen-code-*.tgz' | head -n 1)"
[ -n "$QWEN_TARBALL" ] || die "assets/pkg 에서 qwen-code tarball(.tgz) 없음"
QWEN_TARBALL="$(cd "$(dirname "$QWEN_TARBALL")" && pwd)/$(basename "$QWEN_TARBALL")"
echo "vendoring tarball: $QWEN_TARBALL"

# 로고(brand-create.ts 입력). KOBI_LOGO 로 명시 가능.
LOGO="${KOBI_LOGO:-}"
if [ -z "$LOGO" ]; then
  for f in logo.png logo.svg icon.png icon.svg; do
    [ -f "$BRAND_DIR/icons/$f" ] && LOGO="$BRAND_DIR/icons/$f" && break
  done
fi
[ -n "$LOGO" ] && [ -f "$LOGO" ] || die "Kobi 로고가 없습니다. desktop-brand/icons/logo.png(또는 .svg)를 넣거나 KOBI_LOGO 로 지정하세요."
LOGO="$(cd "$(dirname "$LOGO")" && pwd)/$(basename "$LOGO")"
echo "브랜드 로고: $LOGO"

# ── 로컬 git 스냅샷(빌드 스크립트의 git 조회 대비; 네트워크 불필요) ────────
if [ ! -d "$SRC_DIR/.git" ]; then
  echo "로컬 git 스냅샷 생성..."
  git -C "$SRC_DIR" init -q || true
  git -C "$SRC_DIR" add -A || true
  git -C "$SRC_DIR" -c user.email=b@b -c user.name=b commit -qm snapshot || true
fi

# ── 데스크톱 의존성 설치(루트 workspaces 는 desktop 제외) ───────────────────
echo "[install] packages/desktop ..."
( cd "$DESKTOP_DIR" && bun install )

# ── 브랜드 생성(brand-create.ts) ───────────────────────────────────────────
WORK_DIR="$(mktemp -d)"
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
[ -f "$BRAND_CREATE" ] || die "brand-create.ts 없음(상위 스킬 경로 확인): $BRAND_CREATE"
echo "[brand] brand-create.ts 실행 ($BRAND_ID)"
( cd "$SRC_DIR" && bun run "$BRAND_CREATE" --desktop-root "$DESKTOP_DIR" --config "$BRAND_JSON" )

# ── 빌드 환경 ──────────────────────────────────────────────────────────────
export CRAFT_BRAND="$BRAND_ID"
export QWEN_CODE_TARBALL="$QWEN_TARBALL"
RUN=( )

if [ "$IS_LINUX" -eq 1 ]; then
  # Linux: WineHQ 경로(자세한 근거는 build-desktop.sh 주석 참고)
  command -v setarch >/dev/null || die "setarch(util-linux) 필요."
  WINE_BIN="${WINE_BIN:-/opt/wine-stable/bin/wine}"; [ -x "$WINE_BIN" ] || WINE_BIN="$(command -v wine || true)"
  [ -n "$WINE_BIN" ] || die "wine 필요. WineHQ winehq-stable 설치 권장."
  WINE_VER="$("$WINE_BIN" --version 2>/dev/null || echo unknown)"; echo "Wine: $WINE_BIN ($WINE_VER)"
  case "$WINE_VER" in wine-9.*|wine-8.*|wine-7.*|wine-6.*|wine-5.*)
    echo "경고: 구버전/Ubuntu repack Wine 은 NSIS 언인스톨러 생성에서 실패할 수 있습니다(WineHQ 권장)." >&2;; esac

  # rcedit/signtool 스킵(대용량 exe 에서 wine abort) → win: 에 주입
  BUILDER_YML="$ELECTRON_DIR/electron-builder.yml"
  if ! grep -qE '^[[:space:]]*signAndEditExecutable:' "$BUILDER_YML"; then
    awk '/^win:[[:space:]]*$/ && !d { print; print "  signAndEditExecutable: false"; d=1; next } { print }' \
      "$BUILDER_YML" > "$BUILDER_YML.tmp" && mv "$BUILDER_YML.tmp" "$BUILDER_YML"
    echo "[patch] win.signAndEditExecutable: false 주입"
  fi

  # wine 래퍼(ASLR off + MALLOC_CHECK_=0) + win32 프리픽스(소유 디렉터리)
  WINEWRAP="$WORK_DIR/winewrap"; mkdir -p "$WINEWRAP"
  WINE64_BIN="${WINE_BIN%/wine}/wine64"; [ -x "$WINE64_BIN" ] || WINE64_BIN="$(command -v wine64 || echo "$WINE_BIN")"
  printf '#!/bin/sh\nexport MALLOC_CHECK_=0\nexec setarch "$(uname -m)" -R "%s" "$@"\n' "$WINE_BIN"   > "$WINEWRAP/wine"
  printf '#!/bin/sh\nexport MALLOC_CHECK_=0\nexec setarch "$(uname -m)" -R "%s" "$@"\n' "$WINE64_BIN" > "$WINEWRAP/wine64"
  chmod +x "$WINEWRAP/wine" "$WINEWRAP/wine64"
  export PATH="$WINEWRAP:$PATH"
  export WINEPREFIX="$WORK_DIR/wineprefix" WINEARCH=win32 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
  echo "[wine] win32 프리픽스 초기화: $WINEPREFIX"
  "$WINEWRAP/wine" wineboot --init >/dev/null 2>&1 || die "wineboot 실패(WineHQ 설치/권한 확인)."
  command -v xvfb-run >/dev/null && RUN=( xvfb-run -a )
fi

# ── 빌드 ───────────────────────────────────────────────────────────────────
echo "[build] electron:dist:win (Kobi) ..."
( cd "$DESKTOP_DIR" && "${RUN[@]}" bun run electron:dist:win:no-publish )

# ── 산출물 수집 ────────────────────────────────────────────────────────────
RELEASE_DIR="$ELECTRON_DIR/release"
BUILT_EXE="$(find "$RELEASE_DIR" -maxdepth 1 -name "${ARTIFACT_PREFIX}-*.exe" | head -n 1 || true)"
[ -n "$BUILT_EXE" ] || { echo "산출물(${ARTIFACT_PREFIX}-*.exe) 없음. release 목록:" >&2; ls -la "$RELEASE_DIR" >&2 || true; exit 1; }
mkdir -p "$ASSETS_DESKTOP_DIR"
cp "$BUILT_EXE" "$ASSETS_DESKTOP_DIR/"
( cd "$ASSETS_DESKTOP_DIR" && sha256sum "$(basename "$BUILT_EXE")" > "$(basename "$BUILT_EXE").sha256" )
echo "=========================================================="
echo " 완료: $ASSETS_DESKTOP_DIR/$(basename "$BUILT_EXE")"
[ "$IS_LINUX" -eq 1 ] && echo " (미서명; 내부 exe 는 electron 기본 아이콘 — 완전 브랜딩은 Windows 빌드 권장)"
echo " 다음: ./make.sh windows 로 배포 zip 에 포함"
echo "=========================================================="
