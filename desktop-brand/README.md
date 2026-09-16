# desktop-brand — Kobi 리브랜딩 Desktop(GUI) 빌드

kobi CLI와 함께 배포할 **"Kobi" 브랜딩 데스크톱 GUI**를 만드는 도구 모음이다.
Qwen Code Desktop(공식 Electron 앱, Apache-2.0)을 포크·리브랜딩하여
`Kobi-Desktop-x64.exe`(Windows NSIS 설치본)를 생성한다. 상표 정책(TRADEMARK.md)도
포크 시 다른 이름 사용을 요구하므로 "Kobi" 리브랜딩은 정책에 부합한다.

## 왜 별도 빌드가 필요한가
공식 배포물은 "Qwen Code Desktop"으로 표기된다. 화면·설치물·아이콘까지 "Kobi"로
바꾸려면 사전빌드 바이너리로는 불가능하고 **소스에서 커스텀 빌드**해야 한다.
폐쇄망 대상 PC에서는 빌드할 수 없으므로, **인터넷 되는 빌드 PC**에서 만들어
`Kobi_Installer/assets/desktop/` 에 넣어 반입한다.

## 리브랜딩 방식 (중요)
상위 저장소는 브랜딩을 **`branding.ts` 의 `BRAND`** 로 관리하고, 빌드 시
`electron-builder.generated.yml` 을 그 `BRAND` 로부터 **매번 재생성**한다.
따라서 `electron-builder.yml` 을 직접 고치는 방식은 무효다.
→ upstream 공식 스킬 **`packages/desktop/.agents/skills/desktop-brand-builder/scripts/brand-create.ts`**
를 `brand.json` 과 함께 실행해 브랜드를 생성하고, 빌드 때 `CRAFT_BRAND=kobi` 로 선택한다.
`brand-create.ts` 는 **로고 한 장**(`sharp`)에서 아이콘/도크/렌더러 심볼을 자동 생성한다.

## 사전 요구사항
- `git`, `bun`(상위 저장소 `.bun-version` 버전에 맞춤)
- **Kobi 로고 한 장**: `desktop-brand/icons/logo.png`(권장) 또는 `logo.svg`.
  자세한 내용은 `icons/PUT_ICON_HERE.md` 참고. (`KOBI_LOGO` 로 경로 지정도 가능)
- **Linux 빌드 PC**: NSIS 언인스톨러 생성에 Wine 이 필요하다. 반드시 **WineHQ**
  `winehq-stable`(wine 10/11) 을 쓴다(Ubuntu 기본 `wine` 9.0 repack 은 힙 크래시로 실패).
  ```bash
  sudo dpkg --add-architecture i386
  sudo mkdir -pm755 /etc/apt/keyrings
  sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
  sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources
  sudo apt-get update && sudo apt-get install -y --install-recommends winehq-stable
  sudo apt-get install -y xvfb        # 권장(설치 프로그램을 wine 으로 실행할 때 가상 디스플레이)
  ```
- **Windows 빌드 PC**(Git Bash/MSYS): Wine 불필요. rcedit/언인스톨러가 네이티브라
  내부 exe 아이콘까지 **완전 브랜딩**된다(가장 깨끗한 경로).

## 사용법 A — 인터넷 되는 빌드 PC (`build-desktop.sh`)
```bash
# 1) 로고 배치: desktop-brand/icons/logo.png
# 2) (Linux) WineHQ 설치(위 참고)
./desktop-brand/build-desktop.sh
```
스크립트가 하는 일:
- 상위 `QwenLM/qwen-code` 를 고정 태그(`UPSTREAM_TAG`, 기본 `desktop-latest`)로 clone
- `packages/desktop` 의존성 설치(루트 workspaces 는 desktop 제외)
- `brand.json` + `brand-create.ts` 로 **Kobi** 브랜드 생성
- (Linux) `win.signAndEditExecutable:false` 주입 + WineHQ 래퍼(ASLR off + `MALLOC_CHECK_=0`)
  + `WINEARCH=win32` 프리픽스 준비
- `CRAFT_BRAND=kobi` + `QWEN_CODE_TARBALL=<assets/pkg 의 tgz>` 로 `electron:dist:win` 빌드
- 산출물 `Kobi-Desktop-x64.exe` 를 `Kobi_Installer/assets/desktop/` 에 복사하고 `.sha256` 기록

## 사용법 B — 오프라인/사내망 (`build-desktop-offline.sh`)
git clone 불가(소켓 차단) 또는 사내 TLS 검사(SSL 인터셉트) 환경용. 상위 소스를
브라우저로 받아 압축 해제한 뒤 그 경로를 인자로 준다.
```bash
export NODE_EXTRA_CA_CERTS="C:/Users/K121105/Downloads/corp-ca-bundle.pem"   # TLS 인터셉트 시
./desktop-brand/build-desktop-offline.sh /c/Users/K121105/Downloads/qwen-code-desktop-latest
```
- 브랜딩·빌드 로직은 A 와 동일(차이는 "clone 대신 로컬 소스").
- 플랫폼을 자동 감지: **Windows** 면 네이티브 빌드(Wine 불필요, 완전 브랜딩),
  **Linux** 면 A 와 같은 WineHQ 경로 적용.

## 빌드 후
1. (가능하면 실제 Windows 에서) 설치·실행하여 **창 제목 / About / 아이콘**이 "Kobi"인지,
   GUI 가 내부 vLLM 에 붙는지 확인한다.
2. 저장소 루트에서 패키징:
   - `./make.sh windows` — CLI + Desktop(GUI) + 스킬을 모두 담는 **조합형** 배포 zip.
   - `./make.sh windows-gui` — **GUI 전용** 배포 zip(`Kobi_Installer_gui_v*.zip`). CLI 에이전트(qwen)와
     스킬을 빼서 용량을 줄인다(약 26% 감소). node·git·Desktop·config·computer-use 는 유지한다.
     Desktop 산출물(`assets/desktop/Kobi-Desktop-*.exe`)이 없으면 에러로 중단한다.
     - `NO_GIT=1 ./make.sh windows-gui` — 포터블 git(MinGit)까지 제외해 추가 경량화(대상 PC 에 git 이 있어야 함).
   - `./make.sh skills` — 스킬 5종만 `~/.qwen` 에 압축 해제하는 **별도 배포 번들**(`Kobi_Skills_v*.zip`).
     GUI 전용 배포와 함께 나눠 주면, 사용자가 `%USERPROFILE%\.qwen\` 에 풀어 스킬을 사용할 수 있다
     (스킬의 node 스크립트는 설치가 PATH 에 등록한 node 로 실행된다).

## 환경변수(선택)
| 변수 | 기본값 | 설명 |
|---|---|---|
| `UPSTREAM_TAG` | `desktop-latest` | 상위 데스크톱 소스 고정 태그(A 전용) |
| `BRAND_ID` | `kobi` | 브랜드 식별자(소문자/숫자/하이픈) |
| `APP_NAME` | `Kobi` | 앱 표시명 |
| `APP_ID` | `com.kbcard.kobi` | 역도메인 식별자 |
| `ARTIFACT_PREFIX` | `Kobi-Desktop` | 설치물 파일명 접두 → `Kobi-Desktop-x64.exe` |
| `KOBI_LOGO` | (자동 탐지) | 로고 이미지 경로 명시 |
| `WINE_BIN` | `/opt/wine-stable/bin/wine` | Wine 바이너리 경로(Linux) |
| `WORK_DIR` | `mktemp -d` | 작업 디렉터리(큰 디스크 권장) |

## 알아둘 트레이드오프 / 유지보수
- **Linux 크로스빌드 산출물은 미서명**이고, 내부 `Kobi.exe` 는 electron 기본 아이콘이다
  (rcedit 가 대용량 exe 에서 wine abort → 스킵). 설치 프로그램(setup) 아이콘은 Kobi.
  **내부 exe 까지 완전 브랜딩하려면 Windows/CI 에서 빌드**한다.
- Cloud Shell 등 디스크가 작은 환경: 빌드는 큰 디스크(`/tmp` overlay)에서 하고
  `/home` 에 캐시가 쌓이지 않게 한다(스크립트가 `BUN_INSTALL_CACHE_DIR`/`ELECTRON_CACHE`
  를 `WORK_DIR` 로 잡는다).
- 상위 데스크톱이 새 버전을 내면 `UPSTREAM_TAG` 를 갱신하고 재빌드한다.
- 상위 파일 구조(`branding.ts`, `electron-builder.yml`, brand-create.ts 경로, workspaces
  제외 규칙)가 바뀌면 스크립트를 점검한다.
- 내장 CLI 런타임은 항상 `assets/pkg` 의 tarball(`QWEN_CODE_TARBALL`)을 따라가므로 CLI와 버전이 일치한다.
