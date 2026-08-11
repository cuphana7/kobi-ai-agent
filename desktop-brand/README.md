# desktop-brand — Kobi 리브랜딩 Desktop(GUI) 빌드

kobi CLI와 함께 배포할 **"Kobi" 브랜딩 데스크톱 GUI**를 만드는 도구 모음이다.
Qwen Code Desktop(공식 Electron 앱, Apache-2.0)을 포크·리브랜딩하여
`Kobi-Desktop-x64.exe` 설치물을 생성한다. 상표 정책(TRADEMARK.md)도 포크 시
다른 이름 사용을 요구하므로 "Kobi" 리브랜딩은 정책에 부합한다.

## 왜 별도 빌드가 필요한가
공식 배포물은 "Qwen Code Desktop"으로 표기된다. 화면·설치물·아이콘까지
"Kobi"로 바꾸려면 사전빌드 바이너리로는 불가능하고 **소스에서 커스텀 빌드**해야 한다.
폐쇄망 대상 PC에서는 빌드할 수 없으므로, **인터넷 되는 빌드 PC**에서 만들어
`Kobi_Installer/assets/desktop/` 에 넣어 반입한다.

## 사용법 (인터넷 되는 빌드 PC)

1. Kobi 아이콘을 `desktop-brand/icons/` 에 넣는다(`icon.ico` 필수). 자세한 내용은
   `icons/PUT_ICON_HERE.md` 참고.
2. `bun` 을 설치한다(상위 저장소 `.bun-version` 버전에 맞춤).
3. 빌드 실행:
   ```bash
   ./desktop-brand/build-desktop.sh
   ```
   - 상위 `QwenLM/qwen-code` 를 고정 태그(`UPSTREAM_TAG`, 기본 `desktop-latest`)로 clone
   - `electron-builder.yml`(productName/appId/artifactName/아이콘)과 `branding.ts` 를 Kobi로 치환
   - `QWEN_CODE_TARBALL` 로 kobi가 쓰는 것과 **동일한** `qwen-code-qwen-code-*.tgz` 를 내장 런타임으로 vendoring
   - `bun run electron:dist:win` 로 빌드
   - 산출물 `Kobi-Desktop-x64.exe` 를 `Kobi_Installer/assets/desktop/` 에 복사하고 `.sha256` 기록
4. 빌드된 앱을 실행해 **창 제목 / About / 아이콘**이 모두 "Kobi"인지 확인한다
   (`branding.ts` 자동 치환이 불완전할 수 있음).
5. 저장소 루트에서 패키징:
   ```bash
   ./make.sh windows
   ```
   → 배포 zip(`assets/desktop/Kobi-Desktop-x64.exe`)에 포함된다.

## 환경변수(선택)
| 변수 | 기본값 | 설명 |
|---|---|---|
| `UPSTREAM_TAG` | `desktop-latest` | 상위 데스크톱 소스 고정 태그 |
| `PRODUCT_NAME` | `Kobi` | 제품 표시명 |
| `APP_ID` | `com.kbcard.kobi` | 역도메인 식별자 |
| `ARTIFACT_BASENAME` | `Kobi-Desktop` | 설치물 파일명 접두 |

## 유지보수 주의
- 상위 데스크톱이 새 버전을 내면 `UPSTREAM_TAG` 를 갱신하고 재빌드한다.
- 상위 파일 구조(`electron-builder.yml`, `branding.ts` 위치)가 바뀌면 스크립트의
  치환 로직을 점검해야 한다.
- 내장 CLI 런타임은 항상 `assets/pkg` 의 tarball을 따라가므로 CLI와 버전이 일치한다.
