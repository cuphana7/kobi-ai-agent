# Kobi Desktop 아이콘 배치 위치

이 폴더에 Kobi 브랜드 아이콘 실물을 넣으면 `build-desktop.sh` 가 빌드 시
상위 소스의 `apps/electron/resources/brands/kobi/` 로 복사해 사용합니다.

필요 파일:

- `icon.ico`  — **Windows 필수** (256x256 포함 멀티 사이즈 권장)
- `icon.icns` — macOS 배포 시 (Windows만 배포하면 생략 가능)
- `icon.png`  — Linux 배포 시 (512x512 권장, Windows만 배포하면 생략 가능)

아이콘이 없으면 빌드는 진행되지만 기존 qwen-code 아이콘으로 산출됩니다.
CLI 배너 ASCII 로고(설치기 settings.json 의 `customAsciiArt`)를 기반으로
디자인해 일관성을 맞추는 것을 권장합니다.
