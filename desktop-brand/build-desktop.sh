#!/usr/bin/env bash
#
# Kobi Desktop(GUI) 리브랜딩 빌드 스크립트
# ------------------------------------------------------------
# 인터넷이 되는 빌드 PC에서 실행한다(폐쇄망 아님).
# 상위 QwenLM/qwen-code 의 Electron 데스크톱 앱을 고정 태그로 받아
#   1) 브랜딩(제품명/appId/설치물명/아이콘)을 Kobi로 교체하고
#   2) 내장 CLI 런타임을 kobi가 쓰는 것과 동일한 qwen-code tarball 로 vendoring 한 뒤
#   3) Windows 설치물(Kobi-Desktop-x64.exe)을 빌드하여
#   4) Kobi_Installer/assets/desktop/ 에 넣고 SHA-256 을 기록한다.
#
# 이후 ./make.sh windows 로 패키징하면 이 설치물이 배포 zip 에 포함된다.
#
# 사전 요구사항: git, bun(상위 저장소 .bun-version 참고), 그리고 electron-builder 의
#               Windows 타겟 빌드 요건. Windows/WSL 또는 cross-build 가능 환경에서 수행.
#
set -euo pipefail

# ── 설정(필요 시 환경변수로 오버라이드) ─────────────────────────
# 상위 데스크톱 릴리스에 대응하는 고정 태그. 새 버전으로 올릴 때만 변경한다.
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/QwenLM/qwen-code.git}"
UPSTREAM_TAG="${UPSTREAM_TAG:-desktop-latest}"

PRODUCT_NAME="${PRODUCT_NAME:-Kobi}"
APP_ID="${APP_ID:-com.kbcard.kobi}"
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-Kobi-Desktop}"

# 경로 계산(이 스크립트는 kobi-package/desktop-brand/ 안에 있다고 가정)
BRAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOBI_ROOT="$(cd "$BRAND_DIR/.." && pwd)"
ASSETS_DESKTOP_DIR="$KOBI_ROOT/Kobi_Installer/assets/desktop"

# 내장 CLI 런타임으로 vendoring 할 tarball(= CLI 와 동일 버전 보장)
QWEN_TARBALL="$(find "$KOBI_ROOT/Kobi_Installer/assets/pkg" -name 'qwen-code-qwen-code-*.tgz' | head -n 1)"
if [ -z "${QWEN_TARBALL:-}" ]; then
  echo "오류: Kobi_Installer/assets/pkg 에서 qwen-code tarball(.tgz)을 찾지 못했습니다." >&2
  exit 1
fi
QWEN_TARBALL="$(cd "$(dirname "$QWEN_TARBALL")" && pwd)/$(basename "$QWEN_TARBALL")"
echo "vendoring 할 CLI 런타임 tarball: $QWEN_TARBALL"

# ── 상위 소스 체크아웃 ─────────────────────────────────────────
WORK_DIR="${WORK_DIR:-$(mktemp -d)}"
SRC_DIR="$WORK_DIR/qwen-code"
echo "상위 소스 clone: $UPSTREAM_REPO ($UPSTREAM_TAG) → $SRC_DIR"
rm -rf "$SRC_DIR"
git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$SRC_DIR"

DESKTOP_DIR="$SRC_DIR/packages/desktop"
ELECTRON_DIR="$DESKTOP_DIR/apps/electron"
BUILDER_YML="$ELECTRON_DIR/electron-builder.yml"
if [ ! -f "$BUILDER_YML" ]; then
  echo "오류: $BUILDER_YML 을 찾을 수 없습니다. 상위 구조가 바뀌었을 수 있으니 태그/경로를 확인하세요." >&2
  exit 1
fi

# ── 1) 아이콘 교체 ─────────────────────────────────────────────
# desktop-brand/icons/ 의 Kobi 아이콘을 상위 브랜드 폴더에 kobi 이름으로 배치한다.
BRAND_ICON_DIR="$ELECTRON_DIR/resources/brands/kobi"
mkdir -p "$BRAND_ICON_DIR"
COPIED_ICON=0
for f in icon.ico icon.icns icon.png; do
  if [ -f "$BRAND_DIR/icons/$f" ]; then
    cp "$BRAND_DIR/icons/$f" "$BRAND_ICON_DIR/$f"
    COPIED_ICON=1
  fi
done
if [ "$COPIED_ICON" -eq 0 ]; then
  echo "경고: desktop-brand/icons/ 에 Kobi 아이콘(icon.ico 등)이 없습니다." >&2
  echo "      기존 qwen-code 아이콘으로 빌드됩니다. icon.ico 를 추가한 뒤 다시 빌드하세요." >&2
  # 아이콘이 없으면 electron-builder 가 경로를 못 찾을 수 있으므로 원본 브랜드 폴더를 재사용한다.
  BRAND_ICON_REF="resources/brands/qwen-code"
else
  BRAND_ICON_REF="resources/brands/kobi"
fi

# ── 2) electron-builder.yml 브랜딩 치환 ────────────────────────
# 알려진 키만 안전하게 치환한다(들여쓰기 보존).
sed -i -E "s|^([[:space:]]*productName:).*|\1 ${PRODUCT_NAME}|" "$BUILDER_YML"
sed -i -E "s|^([[:space:]]*appId:).*|\1 ${APP_ID}|" "$BUILDER_YML"
sed -i -E "s|Qwen-Code-Desktop|${ARTIFACT_BASENAME}|g" "$BUILDER_YML"
sed -i -E "s|resources/brands/qwen-code|${BRAND_ICON_REF}|g" "$BUILDER_YML"

# ── 3) 앱 내부 표시명(branding.ts) 최선 노력 치환 ──────────────
# 위치가 버전마다 달라질 수 있어 탐색 후 치환한다. 자동 치환이 불완전할 수 있으니
# 빌드 후 About/창 제목을 반드시 눈으로 확인한다.
BRANDING_TS="$(find "$DESKTOP_DIR" -name 'branding.ts' | head -n 1 || true)"
if [ -n "${BRANDING_TS:-}" ]; then
  echo "branding.ts 치환: $BRANDING_TS"
  sed -i -E "s|Qwen Code Desktop|${PRODUCT_NAME}|g; s|Qwen Code|${PRODUCT_NAME}|g" "$BRANDING_TS"
  echo "  ↳ 자동 치환됨. 빌드 후 표시명을 반드시 검증하세요."
else
  echo "안내: branding.ts 를 찾지 못했습니다. 앱 내부 표시명은 productName 로만 반영됩니다." >&2
fi

# ── 4) 빌드(내장 CLI 런타임 vendoring) ─────────────────────────
echo "bun install (루트)..."
( cd "$SRC_DIR" && bun install )

echo "Windows 데스크톱 설치물 빌드... (QWEN_CODE_TARBALL 로 CLI 런타임 고정)"
( cd "$DESKTOP_DIR" && QWEN_CODE_TARBALL="$QWEN_TARBALL" bun run electron:dist:win )

# ── 5) 산출물 수집 ─────────────────────────────────────────────
RELEASE_DIR="$ELECTRON_DIR/release"
BUILT_EXE="$(find "$RELEASE_DIR" -maxdepth 1 -name "${ARTIFACT_BASENAME}-*.exe" | head -n 1 || true)"
if [ -z "${BUILT_EXE:-}" ]; then
  echo "오류: 빌드 산출물(${ARTIFACT_BASENAME}-*.exe)을 $RELEASE_DIR 에서 찾지 못했습니다." >&2
  exit 1
fi

mkdir -p "$ASSETS_DESKTOP_DIR"
cp "$BUILT_EXE" "$ASSETS_DESKTOP_DIR/"
DEST_EXE="$ASSETS_DESKTOP_DIR/$(basename "$BUILT_EXE")"
( cd "$ASSETS_DESKTOP_DIR" && sha256sum "$(basename "$BUILT_EXE")" > "$(basename "$BUILT_EXE").sha256" )

echo "=========================================================="
echo " Kobi Desktop 빌드 완료"
echo "  산출물 : $DEST_EXE"
echo "  체크섬 : $DEST_EXE.sha256"
echo " 이제 ./make.sh windows 로 패키징하면 배포 zip 에 포함됩니다."
echo "=========================================================="
