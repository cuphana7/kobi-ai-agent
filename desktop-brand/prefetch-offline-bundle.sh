#!/usr/bin/env bash
# prefetch-offline-bundle.sh — 인터넷 되는 Linux에서 실행 → Kobi Desktop(Tauri) 오프라인
# 빌드 번들을 만든다. 산출 번들을 사내 Windows 빌드 PC로 옮겨 "제한 사이트 없이"
# tauri build 하는 것이 목표.
#
# 모으는 것:
#   1) source/        qwen-code 소스(desktop-v0.3.0 고정)   — vendor/lock 기준
#   2) npm-cache/      npm 오프라인 캐시(전 플랫폼 optional 포함)
#   3) node-cache/     Windows용 Node(node-v<ver>-win-x64.zip)+SHASUMS
#   4) cargo-vendor/   cargo vendor 결과(+ .cargo/config.toml)  [cargo 필요]
#   5) windows-tools/  rustup-init.exe 등 편의 도구
#   + BUILD-ON-WINDOWS.md, brand.json.example, MANIFEST.txt
#
# 사용:
#   ./desktop-brand/prefetch-offline-bundle.sh                 # 전체
#   ./desktop-brand/prefetch-offline-bundle.sh --install-rust  # cargo 없으면 rustup 부트스트랩
#   ./desktop-brand/prefetch-offline-bundle.sh --skip-cargo    # vendor 생략(Windows에서 vendor)
#   ./desktop-brand/prefetch-offline-bundle.sh --dry-run
#
# 주의: Tauri NSIS 번들러 캐시(%LOCALAPPDATA%\tauri)와 최종 .exe 는 Windows에서만
#       생성된다(MSVC 링킹). 이 번들은 그 Windows 오프라인 빌드의 "입력"을 채운다.
set -euo pipefail

# ---- 기본값 ----
TAG="${TAG:-desktop-v0.3.0}"
REPO="${REPO:-https://github.com/QwenLM/qwen-code.git}"
OUT="${OUT:-$PWD/kobi-desktop-offline-bundle}"
NODE_VERSION="${NODE_VERSION:-}"          # 비우면 소스 .nvmrc(major)에서 최신 patch 해석
WIN_TRIPLE="x86_64-pc-windows-msvc"
DO_SOURCE=1 DO_NPM=1 DO_NODE=1 DO_CARGO=1 DO_RUSTTOOL=1 DO_ARCHIVE=1
INSTALL_RUST=0 DRYRUN=0

log(){ printf '\033[1m[prefetch]\033[0m %s\n' "$*"; }
warn(){ printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
run(){ if [ "$DRYRUN" = 1 ]; then echo "  + $*"; else "$@"; fi; }
have(){ command -v "$1" >/dev/null 2>&1; }

for a in "$@"; do case "$a" in
  --tag=*)          TAG="${a#*=}" ;;
  --out=*)          OUT="${a#*=}" ;;
  --node-version=*) NODE_VERSION="${a#*=}" ;;
  --skip-source)    DO_SOURCE=0 ;;
  --skip-npm)       DO_NPM=0 ;;
  --skip-node)      DO_NODE=0 ;;
  --skip-cargo)     DO_CARGO=0 ;;
  --skip-rust-installer) DO_RUSTTOOL=0 ;;
  --install-rust)   INSTALL_RUST=1 ;;
  --no-archive)     DO_ARCHIVE=0 ;;
  --dry-run)        DRYRUN=1 ;;
  -h|--help)        sed -n '2,30p' "$0"; exit 0 ;;
  *) die "unknown option: $a (try --help)" ;;
esac; done

for t in curl git; do have "$t" || die "$t 필요"; done
[ "$DO_NPM" = 1 ] && { have npm || die "npm 필요"; have node || die "node 필요"; }

SRC="$OUT/source"
mkdir -p "$OUT"
log "출력: $OUT   태그: $TAG"

# ---- 1) 소스 ----
if [ "$DO_SOURCE" = 1 ]; then
  if [ -d "$SRC/.git" ]; then
    log "소스 이미 있음: $SRC (재사용)"
  else
    log "소스 clone: $REPO @ $TAG"
    run git clone --depth 1 --branch "$TAG" "$REPO" "$SRC"
  fi
else
  [ -d "$SRC" ] || die "--skip-source 인데 $SRC 없음"
fi

# Node 버전 해석(.nvmrc major → nodejs.org 최신 patch)
if [ "$DO_NODE" = 1 ] || [ "$DO_NPM" = 1 ]; then
  if [ -z "$NODE_VERSION" ]; then
    NVMRC=""
    [ -f "$SRC/.nvmrc" ] && NVMRC="$(tr -dc '0-9' < "$SRC/.nvmrc")"
    if [ -z "$NVMRC" ] && [ "$DRYRUN" = 1 ]; then NVMRC="22"; fi   # dry-run: clone 안 함
    [ -n "$NVMRC" ] || die ".nvmrc 를 못 읽음. --node-version 지정"
    log ".nvmrc major=$NVMRC → nodejs.org 최신 patch 조회"
    if [ "$DRYRUN" = 1 ]; then NODE_VERSION="${NVMRC}.x"; else
      NODE_VERSION="$(curl -fsSL https://nodejs.org/dist/index.json \
        | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const m=process.argv[1];const v=JSON.parse(d).map(x=>x.version).filter(x=>x.startsWith("v"+m+".")).sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));console.log((v.pop()||"").replace(/^v/,""))})' "$NVMRC")"
      [ -n "$NODE_VERSION" ] || die "Node $NVMRC.x 버전 해석 실패"
    fi
  fi
  log "대상 Node 버전: v$NODE_VERSION (Windows에도 정확히 이 버전 설치 필요)"
fi

# ---- 2) npm 오프라인 캐시(전 플랫폼) ----
if [ "$DO_NPM" = 1 ]; then
  CACHE="$OUT/npm-cache"; mkdir -p "$CACHE"
  export npm_config_cache="$CACHE"
  log "npm 캐시 채우기(root + desktop-shell). 시간이 좀 걸립니다."
  # 이 플랫폼 기준 설치로 캐시 시딩(node_modules 는 버려도 됨 → --ignore-scripts)
  run bash -c "cd '$SRC' && npm install --ignore-scripts --no-audit --no-fund"
  run bash -c "cd '$SRC/packages/desktop-shell' && npm install --workspaces=false --ignore-scripts --no-audit --no-fund"
  # lockfile 의 모든 name@version 을 캐시에 추가 → Windows/타 플랫폼 optional 까지 확보.
  # (최신 npm 은 'cache add <URL>' 를 EALLOWREMOTE 로 막으므로 name@version 로 추가한다)
  log "lockfile 의 전 플랫폼 패키지를 캐시에 추가"
  if [ "$DRYRUN" = 1 ]; then
    echo "  + (dry-run) parse package-lock → npm cache add <name>@<version> ..."
  else
    LOCKS=("$SRC/package-lock.json" "$SRC/packages/desktop-shell/package-lock.json")
    SPECS="$(node -e '
      const fs=require("fs"); const s=new Set();
      for (const f of process.argv.slice(1)) {
        let j; try{ j=JSON.parse(fs.readFileSync(f,"utf8")); }catch{ continue; }
        for (const [k,v] of Object.entries(j.packages||{})) {
          if (!v || !v.version || !v.resolved || !/^https?:/.test(v.resolved)) continue;
          const i=k.lastIndexOf("node_modules/");
          // v.name 이 있으면(=npm: 별칭) 실제 패키지명을 쓴다. 아니면 경로에서 유도.
          const name = v.name || (i>=0 ? k.slice(i+13) : "");
          if (name) s.add(name+"@"+v.version);
        }
      }
      process.stdout.write([...s].sort().join("\n"));
    ' "${LOCKS[@]}")"
    total=$(printf '%s\n' "$SPECS" | grep -c . || true); i=0; fail=0
    while IFS= read -r spec; do
      [ -n "$spec" ] || continue; i=$((i+1))
      printf '\r  cache add %d/%d  ' "$i" "$total"
      npm cache add "$spec" >/dev/null 2>&1 || { fail=$((fail+1)); echo; warn "실패: $spec"; }
    done <<< "$SPECS"
    echo; log "npm 캐시 완료 (실패 $fail/$total)"
  fi
  # seeding 용 node_modules 는 번들에서 제외(Windows 에서 npm ci 로 재생성)
  [ "$DRYRUN" = 1 ] || rm -rf "$SRC/node_modules" "$SRC/packages/desktop-shell/node_modules"
fi

# ---- 3) Windows용 Node ----
if [ "$DO_NODE" = 1 ]; then
  NDIR="$OUT/node-cache/v$NODE_VERSION"; mkdir -p "$NDIR"
  ZIP="node-v$NODE_VERSION-win-x64.zip"
  log "Node 다운로드: $ZIP (+SHASUMS256.txt)"
  run curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/$ZIP" -o "$NDIR/$ZIP"
  run curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" -o "$NDIR/SHASUMS256.txt"
  if [ "$DRYRUN" != 1 ]; then
    exp="$(grep " $ZIP\$" "$NDIR/SHASUMS256.txt" | awk '{print $1}')"
    act="$(sha256sum "$NDIR/$ZIP" | awk '{print $1}')"
    [ "$exp" = "$act" ] || die "Node zip 체크섬 불일치"
    log "Node zip 체크섬 OK"
  fi
fi

# ---- 4) cargo vendor ----
if [ "$DO_CARGO" = 1 ]; then
  if ! have cargo; then
    if [ "$INSTALL_RUST" = 1 ]; then
      log "cargo 없음 → rustup 부트스트랩(--install-rust)"
      run bash -c "curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable"
      # shellcheck disable=SC1090
      [ "$DRYRUN" = 1 ] || { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"; }
      # 기존 rustup 이 있었으나 툴체인이 없을 수 있음 → 기본 stable 보장
      run rustup default stable
    else
      warn "cargo 없음 → vendor 생략. --install-rust 로 설치하거나 --skip-cargo 명시."
      DO_CARGO=0
    fi
  fi
fi
if [ "$DO_CARGO" = 1 ]; then
  VDIR="$OUT/cargo-vendor"; mkdir -p "$VDIR"
  MANIFEST="$SRC/packages/desktop-shell/src-tauri/Cargo.toml"
  [ -f "$MANIFEST" ] || [ "$DRYRUN" = 1 ] || die "Cargo.toml 없음: $MANIFEST"
  # cargo 의 crate 다운로드/전개는 CARGO_HOME(기본 ~/.cargo=/home)에서 일어난다.
  # /home 이 작을 수 있으므로 번들과 같은 디스크(overlay)에 임시 CARGO_HOME 을 둔다.
  CARGO_TMP=""
  if [ -z "${CARGO_HOME:-}" ]; then
    CARGO_TMP="$OUT/.cargo-home"; export CARGO_HOME="$CARGO_TMP"; mkdir -p "$CARGO_TMP"
  fi
  log "cargo vendor 실행(src-tauri)  CARGO_HOME=$CARGO_HOME"
  # vendor 산출은 config 조각을 stdout 으로 준다 → 파일로 저장
  if [ "$DRYRUN" = 1 ]; then
    echo "  + cargo vendor --manifest-path $MANIFEST $VDIR/vendor"
  else
    ( cd "$SRC/packages/desktop-shell/src-tauri" \
      && cargo vendor --manifest-path "$MANIFEST" "$VDIR/vendor" ) > "$VDIR/cargo-config-fragment.toml"
    # 임시 CARGO_HOME(다운로드 캐시)은 vendor/ 가 자립적이므로 제거해 용량 절약
    [ -n "$CARGO_TMP" ] && rm -rf "$CARGO_TMP"
    log "vendor 완료 → $VDIR/vendor ($(ls "$VDIR/vendor" 2>/dev/null | wc -l) crates)"
  fi
fi

# ---- 5) Windows 편의 도구 ----
if [ "$DO_RUSTTOOL" = 1 ]; then
  WT="$OUT/windows-tools"; mkdir -p "$WT"
  log "rustup-init.exe(x64) 다운로드"
  run curl -fsSL "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" \
      -o "$WT/rustup-init.exe" || warn "rustup-init 다운로드 실패(수동 반입)"
fi

# ---- 산출 문서 ----
# node/npm 단계를 건너뛴 재실행이면 NODE_VERSION 이 비어 있으므로 node-cache 에서 유추
if [ -z "${NODE_VERSION:-}" ] && [ -d "$OUT/node-cache" ]; then
  NODE_VERSION="$(ls "$OUT/node-cache" 2>/dev/null | sed -n 's/^v//p' | head -1)"
fi
if [ "$DRYRUN" != 1 ]; then
  cat > "$OUT/brand.json.example" <<JSON
{
  "brandId": "kobi",
  "logo": "C:/build/logo.png",
  "website": "https://www.kbcard.com",
  "appName": "Kobi",
  "appId": "com.kbcard.kobi",
  "artifactPrefix": "Kobi-Desktop",
  "updaterEndpoints": [],
  "updaterPubkey": ""
}
JSON

  cat > "$OUT/BUILD-ON-WINDOWS.md" <<MD
# Kobi Desktop(Tauri) — Windows 오프라인 빌드 절차

이 번들을 Windows 빌드 PC로 옮긴 뒤(예: C:\\build\\bundle) Git Bash 에서 진행.

## 사전 설치(Windows, 1회)
- Node **v$NODE_VERSION** (반드시 이 버전 — prepare-runtime 이 이 버전 zip 을 캐시에서 찾음)
- Rust MSVC 툴체인: \`windows-tools/rustup-init.exe\` 실행 → \`x86_64-pc-windows-msvc\`
- Visual Studio Build Tools(C++)  ← MSVC 링커
- (WebView2 없는 대상 PC면) tauri.conf.json 에 webviewInstallMode=fixedRuntime

## 빌드
\`\`\`bash
BUNDLE=/c/build/bundle
cd \$BUNDLE/source

# 1) 브랜딩 (brand.json 은 brand.json.example 복사·수정, logo 경로 실제로)
node packages/desktop-shell/.agents/skills/desktop-brand-builder/scripts/brand-create.mjs \\
  --shell-root "\$PWD/packages/desktop-shell" --config /c/build/brand.json

# 2) 의존성 오프라인 설치(캐시 사용)
export npm_config_cache="\$BUNDLE/npm-cache"
npm ci --offline --no-audit --no-fund
( cd packages/desktop-shell && npm ci --offline --workspaces=false --no-audit --no-fund )

# 3) cargo 오프라인 벤더 연결
mkdir -p packages/desktop-shell/src-tauri/.cargo
cp "\$BUNDLE/cargo-vendor/cargo-config-fragment.toml" \\
   packages/desktop-shell/src-tauri/.cargo/config.toml
# config.toml 의 vendor 경로를 절대경로로: directory = "\$BUNDLE/cargo-vendor/vendor"

# 4) 런타임 준비(Windows Node 캐시 사용) + 빌드
export QWEN_DESKTOP_NODE_CACHE_DIR="\$BUNDLE/node-cache"
export QWEN_DESKTOP_TARGET=$WIN_TRIPLE
# (선택) 런타임 CLI 를 0.24.0 으로 고정하려면 0.24.0 체크아웃 경로 지정:
# export QWEN_CODE_ROOT=/c/build/qwen-code-0.24.0
cd packages/desktop-shell
npm run build:runtime --workspaces=false
npx tauri build

# 산출물: src-tauri/target/release/bundle/nsis/*_x64-setup.exe
\`\`\`

## 알아둘 것
- **nodejs.org 접근**: build:runtime 은 SHASUMS256.txt 를 매번 조회한다. nodejs.org 가
  막혀 있으면 prepare-runtime.js 를 패치(캐시 존재 시 재다운로드/검증 스킵)해야 한다.
- **Tauri NSIS 캐시**: 첫 tauri build 시 %LOCALAPPDATA%\\tauri 로 NSIS 를 github 에서
  받는다. github 이 막혔으면 인터넷 되는 PC에서 1회 빌드해 그 폴더를 반입한다.
- 산출 exe 를 Kobi_Installer/assets/desktop/Kobi-Desktop-x64.exe 로 rename 후 make.sh 패키징.
MD

  {
    echo "# Kobi Desktop offline bundle"
    echo "date: $(date -u +%FT%TZ)"
    echo "tag:  $TAG"
    echo "node: v${NODE_VERSION:-?}"
    echo "win-triple: $WIN_TRIPLE"
    echo "--- du ---"
    du -sh "$OUT"/* 2>/dev/null || true
  } > "$OUT/MANIFEST.txt"
  log "문서 생성: BUILD-ON-WINDOWS.md, brand.json.example, MANIFEST.txt"
fi

# ---- 아카이브 ----
if [ "$DO_ARCHIVE" = 1 ] && [ "$DRYRUN" != 1 ]; then
  STAMP="$(date +%Y%m%d_%H%M)"
  TAR="$(dirname "$OUT")/kobi-desktop-offline-bundle_${STAMP}.tar.gz"
  log "아카이브 생성: $TAR (source/.git 제외)"
  tar -C "$(dirname "$OUT")" --exclude='*/.git' -czf "$TAR" "$(basename "$OUT")"
  sha256sum "$TAR" | tee "$TAR.sha256"
  log "완료. 이 파일과 .sha256 을 Windows 빌드 PC로 반입하세요."
else
  log "완료(아카이브 생략). 폴더: $OUT"
fi
