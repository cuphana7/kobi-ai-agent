# Kobi Desktop 브랜드 로고 배치 위치

`build-desktop.sh` 는 upstream 공식 리브랜딩 스킬(`brand-create.ts`)을 사용한다.
이 스킬은 **로고 이미지 한 장**을 입력받아 `sharp` 로 아이콘/도크/렌더러 심볼을
자동 생성한다. 따라서 여기에는 개별 `.ico/.icns` 대신 **로고 한 장**만 넣으면 된다.

필요 파일(둘 중 하나):

- `logo.png` — **권장**. 정사각형, 512x512 이상, 투명 배경 권장.
- `logo.svg` — 벡터도 가능(sharp 가 래스터화).

없으면 `KOBI_LOGO=/abs/path/logo.png ./build-desktop.sh` 로 경로를 직접 지정할 수 있다.
로고가 전혀 없으면 빌드는 로고를 찾지 못해 중단된다.

참고:
- Windows 설치 프로그램(setup) 아이콘은 이 로고에서 생성된 아이콘이 쓰인다.
- 내부 실행 파일(`Kobi.exe`) 아이콘은 Linux 크로스빌드에서는 electron 기본값으로
  남는다(rcedit 가 대용량 exe 에서 wine abort 를 일으켜 스킵). 내부 exe 까지 완전
  브랜딩하려면 실제 Windows/CI 에서 빌드한다.
- CLI 배너 ASCII 로고(설치기 settings.json 의 `customAsciiArt`)와 톤을 맞추면 일관적이다.
