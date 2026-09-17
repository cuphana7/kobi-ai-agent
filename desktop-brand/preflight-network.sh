#!/usr/bin/env bash
# preflight-network.sh — Kobi Desktop(Tauri) 빌드 전 네트워크/도구 프리플라이트
#
# 목적: Tauri 데스크톱 빌드가 건드리는 외부 다운로드 지점(crates.io, github,
#       nodejs.org, npm, WebView2, rustup)에 대한 접근성과 사내 TLS 인터셉트(MITM)
#       여부를 실측한다. 막힌 항목만 오프라인 캐시로 전환하면 된다.
#
# 어디서 실행하나:
#   - 사내 Windows 빌드 PC(Git Bash/MSYS)  → 무엇이 막혔는지 확인
#   - 인터넷 되는 Linux/맥              → "여기서 다 받아 옮기기" 전략 가능 여부 확인
#   둘 다 curl + openssl 만 있으면 동작한다.
#
# 사용:
#   ./desktop-brand/preflight-network.sh                 # 전체 점검
#   ./desktop-brand/preflight-network.sh --no-tls        # HTTP 도달성만(빠름)
#   NODE_EXTRA_CA_CERTS=/path/corp-ca.pem ./preflight-network.sh   # 사내 CA 지정
#
# 종료코드: 0=전부 OK, 1=하나 이상 BLOCK, 2=필수 도구 없음
set -u

# ---- 옵션 ----------------------------------------------------------------
DO_TLS=1
TIMEOUT="${PREFLIGHT_TIMEOUT:-15}"
for a in "$@"; do
  case "$a" in
    --no-tls) DO_TLS=0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

# ---- 색상(터미널이면) ----------------------------------------------------
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'
else G=; R=; Y=; B=; Z=; fi
ok(){ printf '%s' "${G}OK${Z}"; }
bad(){ printf '%s' "${R}BLOCK${Z}"; }
warn(){ printf '%s' "${Y}MITM?${Z}"; }

have(){ command -v "$1" >/dev/null 2>&1; }

# ---- 필수 도구 -----------------------------------------------------------
if ! have curl; then echo "${R}curl 없음 — 설치 필요${Z}" >&2; exit 2; fi
if [ "$DO_TLS" = 1 ] && ! have openssl; then
  echo "${Y}openssl 없음 → TLS 인터셉트 점검 생략(--no-tls 모드로 동작)${Z}" >&2
  DO_TLS=0
fi

CURL_CA=()
[ -n "${NODE_EXTRA_CA_CERTS:-}" ] && CURL_CA=(--cacert "$NODE_EXTRA_CA_CERTS")

# 정상(공용) CA 발급자 키워드. 이 중 하나도 안 걸리면 사내 MITM 의심.
PUBLIC_CA_RE='DigiCert|Let'"'"'s Encrypt|ISRG|Amazon|Google Trust|GlobalSign|Sectigo|Baltimore|USERTrust|Microsoft|GTS|Cloudflare|Entrust|Go Daddy|DFN'

# host<TAB>url<TAB>build-phase<TAB>대응
ENTRIES=$(cat <<'EOF'
github.com	https://github.com/QwenLM/qwen-code	소스 clone	브라우저로 소스 zip 받아 오프라인 드롭
codeload.github.com	https://codeload.github.com/QwenLM/qwen-code/tar.gz/refs/heads/main	소스 zip/tarball	위와 동일
objects.githubusercontent.com	https://objects.githubusercontent.com	릴리스 자산 CDN	온라인 PC에서 자산 사전 다운로드
registry.npmjs.org	https://registry.npmjs.org/@tauri-apps%2fcli	npm install	사내 미러 or npm-cache/npm-seed 재사용 + 사내 CA
nodejs.org	https://nodejs.org/dist/index.json	build:runtime Node	QWEN_DESKTOP_NODE_CACHE_DIR 사전 배치
index.crates.io	https://index.crates.io/config.json	cargo sparse index	cargo vendor + .cargo/config.toml
static.crates.io	https://static.crates.io	cargo crate 다운로드	cargo vendor로 오프라인 벤더링
static.rust-lang.org	https://static.rust-lang.org/dist/channel-rust-stable.toml	rustup/toolchain	rustup-init + toolchain 오프라인 반입
go.microsoft.com	https://go.microsoft.com/fwlink/p/?LinkId=2124703	WebView2 부트스트랩	고정 런타임 cab 수동 반입(fixedRuntime)
EOF
)

echo "${B}== Kobi Desktop(Tauri) 빌드 네트워크 프리플라이트 ==${Z}"
echo "호스트: $(hostname 2>/dev/null)   OS: $(uname -s 2>/dev/null)   $(date)"
[ -n "${https_proxy:-${HTTPS_PROXY:-}}" ] && echo "proxy: ${https_proxy:-$HTTPS_PROXY}"
[ -n "${NODE_EXTRA_CA_CERTS:-}" ] && echo "사내 CA: $NODE_EXTRA_CA_CERTS"
echo

printf '%s\n' "${B}단계                호스트                          결과   HTTP   TLS발급자${Z}"
printf '%s\n' "------------------------------------------------------------------------------------"

blocked=0; mitm=0
# IFS 를 탭/개행으로
OLDIFS=$IFS
IFS=$'\n'
for line in $ENTRIES; do
  IFS=$'\t' read -r host url phase fix <<EOF
$line
EOF
  # --- HTTP 도달성 ---
  # 본문 다운로드를 피하려고 1바이트만 요청(range). 서버가 무시하고 큰 본문을 보내도
  # --max-time 이 끊지만, 이미 받은 상태코드로 판정한다.
  code=$(curl "${CURL_CA[@]}" -sS -o /dev/null -w '%{http_code}' \
              -r 0-0 --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
              -A 'kobi-preflight' "$url" 2>/dev/null)
  # 유효한 HTTP 상태코드(1xx~5xx)를 받았으면 TCP+TLS+HTTP 모두 도달한 것.
  # 정책상 403/404 도 "도달"로 본다. 000/빈값 = TCP/TLS 차단.
  if printf '%s' "$code" | grep -Eq '^[1-5][0-9][0-9]$'; then
    result=$(ok); reachable=1
  else
    result=$(bad); blocked=$((blocked+1)); code="${code:-000}"
    reachable=0
  fi

  # --- TLS 발급자(MITM 탐지) ---
  issuer='-'
  if [ "$DO_TLS" = 1 ] && [ "$reachable" = 1 ]; then
    issuer=$(printf '' | openssl s_client -connect "$host:443" -servername "$host" \
              -verify_quiet 2>/dev/null \
             | openssl x509 -noout -issuer 2>/dev/null \
             | sed 's/^issuer=//; s/.*\(O *= *[^,\/]*\).*/\1/; s/O *= *//')
    [ -z "$issuer" ] && issuer='?'
    if ! printf '%s' "$issuer" | grep -Eq "$PUBLIC_CA_RE"; then
      result="$result $(warn)"; mitm=$((mitm+1))
    fi
  fi

  printf '%-18s %-30s %-14b %-6s %s\n' "$phase" "$host" "$result" "$code" "$issuer"
  eval "FIX_${host//[.-]/_}=\$fix"
done
IFS=$OLDIFS

echo
# ---- 로컬 빌드 도구 ------------------------------------------------------
echo "${B}== 로컬 빌드 도구 ==${Z}"
tool_line(){ printf '  %-10s %s\n' "$1" "$(have "$1" && "$1" ${2:-} 2>/dev/null | head -1 || echo "${R}(없음)${Z}")"; }
tool_line git --version
tool_line node --version
tool_line npm --version
tool_line cargo --version
tool_line rustc --version
tool_line openssl version
# zip 추출 능력(리눅스에서 win32 Node.zip 추출에 필요) — prepare-runtime 는 'tar -xf' 사용
if have bsdtar; then
  echo "  ${G}zip추출   bsdtar 있음 (Node win-x64.zip 추출 OK)${Z}"
elif tar --version 2>/dev/null | grep -qi 'GNU tar'; then
  echo "  ${Y}zip추출   GNU tar 만 있음 → prepare-runtime 의 'tar -xf *.zip' 실패 위험."
  echo "            (Linux에서 win 런타임 준비 시) libarchive-tools(bsdtar) 설치 권장${Z}"
fi

echo
echo "${B}== 요약 ==${Z}"
echo "  BLOCK: $blocked 개, MITM?: $mitm 개"
if [ "$blocked" -gt 0 ] || [ "$mitm" -gt 0 ]; then
  echo
  echo "${B}== 막힌/의심 항목 대응 ==${Z}"
  IFS=$'\n'
  for line in $ENTRIES; do
    IFS=$'\t' read -r host url phase fix <<EOF
$line
EOF
    printf '  - %-28s → %s\n' "$host" "$fix"
  done
  IFS=$OLDIFS
  echo
  echo "${Y}권장: 인터넷 되는 PC에서 1회 풀빌드로 (a)cargo vendor (b)Tauri NSIS 캐시"
  echo "      (%LOCALAPPDATA%\\tauri) (c)Node 캐시 (d)npm 캐시를 확보해 반입 후 오프라인 빌드.${Z}"
fi

if [ "$blocked" -gt 0 ]; then exit 1; else exit 0; fi
