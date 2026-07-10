# KB AI Assistant (Kobi) 무설치 오프라인 스킬 개발 가이드 (바이브코딩 가이드)

본 가이드는 대규모 언어 모델(LLM) 기반의 KB AI Assistant(`kobi`) 환경에서 작동하는 **사용자 정의 스킬(Custom Skill)**을 신속하게 설계, 구현, 검증 및 패키징하기 위한 표준 매뉴얼입니다.

이 가이드를 다른 프로젝트의 AI 세션에 입력하면, AI 에이전트가 이 규격을 그대로 학습하여 단 한 번의 대화만으로 완벽한 스킬 패키지를 스스로 제작하는 **'바이브코딩(Vibe Coding)'** 가이드라인으로 활용할 수 있습니다.

---

## 1. Kobi 스킬(Skill)의 개념 및 필요성

Kobi 스킬은 오프라인 사내망 환경의 로컬 PC에서 작동하는 Kobi AI 어시스턴트에게 **사내 고유 레거시 솔루션(형상관리, 모니터링, 데이터베이스 등)을 제어할 수 있는 도구(Tool)와 눈(Eye)을 제공하는 확장 모듈**입니다.

### 핵심 동작 원리
1. **자동 인식**: Kobi 에이전트 기동 시 홈 프로필(`~/.qwen/skills/`) 아래 설치된 각 스킬 폴더의 `SKILL.md` 명세를 읽어 스킬의 존재와 기능을 자동 인식합니다.
2. **적재적소 호출**: 사용자가 질문을 하면, AI가 자연어 의도를 분석하여 적절한 스킬의 CLI 래퍼 스크립트를 필요한 인자값과 함께 백엔드 터미널로 자동 실행합니다.
3. **결과 해석**: CLI 실행 결과 출력값(stdout)을 AI가 읽고 해석하여 개발자에게 자연스러운 한국어로 답변 및 후속 수정을 지원합니다.

---

## 2. 표준 스킬 구조 (Anatomy of a Skill)

Kobi의 모든 스킬은 아래와 같이 완전히 독립적이고 자가 수용적(Self-contained)인 디렉토리 구조를 가져야 합니다.

```
~/.qwen/skills/<스킬이름>/
├── SKILL.md                  # 스킬의 존재 정의, AI 인식용 Frontmatter 및 가이드라인
├── scripts/                  # Kobi가 직접 호출하는 통합 실행 스크립트 폴더
│   └── <스킬이름>.cjs        # Node.js 기반 CLI 통합 래퍼 (CommonJS 규격 필수)
├── bin/                      # [선택] 컴파일된 실행 파일 또는 자바 .class 파일 폴더
├── lib/                      # [선택] 외부 의존 라이브러리 및 3rd Party JAR 파일 폴더
├── license/                  # [선택] 프로퍼티 파일 및 라이선스 키 자산 폴더
└── src/                      # [선택] 디버깅 및 컴파일을 위한 오리지널 소스 파일 폴더
```

---

## 3. 핵심 설계 법칙 (The Golden Rules of Skill Development)

### 법칙 1: 출력은 항상 일관된 규격의 JSON 문자열(stdout)이어야 합니다.
AI 에이전트가 결과를 완벽하고 정밀하게 오차 없이 읽기 위해서, 스킬 실행 스크립트는 성공이든 실패든 **항상 콘솔(stdout)에 표준화된 단일 JSON 한 줄**만 출력하는 것을 원칙으로 합니다.

* **성공 응답 표준**: `{"success": true, "data": { ... }, "message": "성공 메시지"}`
* **실패 응답 표준**: `{"success": false, "errorCode": "에러코드", "errorMessage": "요약", "errorDetail": "상세 가이드"}`

### 법칙 2: 절대 보안 차단 가드레일(Safe-Guardrail)을 설계해야 합니다.
시스템 파괴 행위나 기밀 정보 탈취, 혹은 승인되지 않은 비인증 액션(예: 운영 환경 반영 `deploy-real`)은 **스킬 백엔드 코어 단계에서 즉시 원천 차단**하고, 가독성 높은 한국어 안내문과 함께 `SECURITY_BLOCK` 에러 객체를 리턴해야 합니다.

### 법칙 3: OS 이식성을 고려한 하이브리드 바인딩 (Node.js ➔ Java/C++)
Kobi 에이전트는 포터블 Node.js 환경에서 작동합니다. 따라서 레거시 API가 Java나 C++로 만들어져 있더라도, **Node.js CLI 스크립트(`*.cjs`)가 중간 매개체가 되어 백엔드의 자바 프로그램 등을 동적으로 실행(spawn)**하게 구성하는 것이 가장 이식성이 높고 안정적입니다.

---

## 4. 단계별 스킬 개발 프로세스 (Vibe Coding Workflow)

### [단계 1] 백엔드 CLI 코어 구현 (Java 예시: `CmCli.java`)
레거시 API(JAR 파일 등)를 연동하고 파라미터를 파싱하여 성공/실패 여부를 JSON으로 파싱 출력하는 자바 실행 클래스를 만듭니다.

```java
package com.kbcard.cm.cli;

import java.util.HashMap;

public class CmCli {
    public static void main(String[] args) {
        try {
            // 1. 매개변수 파싱 (--userId 사번 등)
            HashMap<String, String> params = parseArgs(args);
            
            // 2. 보안 가드레일 작동
            if ("deploy-real".equalsIgnoreCase(args[0])) {
                printError("SECURITY_BLOCK", "Real deploy is blocked", "보안 정책상 차단되었습니다.");
                System.exit(4);
            }
            
            // 3. 비즈니스 로직 연동 및 JSON 출력
            System.out.println("{\"success\":true,\"userId\":\"" + params.get("userId") + "\"}");
            
        } catch (Exception e) {
            printError("SYSTEM_ERROR", e.getMessage(), null);
            System.exit(1);
        }
    }
    
    private static void printError(String code, String msg, String detail) {
        System.out.println("{\"success\":false,\"errorCode\":\""+code+"\",\"errorMessage\":\""+msg+"\",\"errorDetail\":\""+detail+"\"}");
    }
}
```

### [단계 2] 구형 인프라 호환성 보장 (Crucial Tips)
사내 PC 및 서버 환경이 구형인 경우(예: JDK 1.8)에도 실행 가능하도록 컴파일 및 소스 코딩 시 다음의 방어 전략을 적용합니다.

1. **바이트코드 버전 제어**: 최신 JDK(11~21) 환경에서 컴파일을 진행하더라도, 자바 8 JRE에서 에러 없이 실행되도록 반드시 **`--release 8`** 옵션을 주고 교차 컴파일을 수동 가동합니다.
   ```bash
   javac --release 8 -classpath "..." -d ./bin ...
   ```
2. **문자열 인코딩 충돌 방지**: 한글 윈도우 환경(EUC-KR)과 리눅스 서버 환경(UTF-8) 간 소스 인코딩 오류를 차단하기 위해, 자바 소스 파일 내부의 모든 한글 리터럴은 **유니코드 이스케이프 시퀀스(`\uXXXX`)**로 변환하여 기록합니다.
   - 예: `"사내 보안 정책"` ➔ `"\uc0ac\ub0b4 \ubcf4\uc548 \uc815\ucc45"`
   - 컴파일 명령어에 문자 인코딩을 명시적으로 부여합니다: `-encoding EUC-KR`

### [단계 3] OS 이식성 보장형 Node.js CLI 래퍼 제작 (`frism-cm.cjs`)
윈도우 개발자의 로컬 PC 경로와 실행 가상 클래스패스를 안전하게 매핑하는 CommonJS 스크립트를 작성합니다.

```javascript
#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

const skillDir = path.resolve(__dirname, '..');
const binDir = path.join(skillDir, 'bin');
const libDir = path.join(skillDir, 'lib');

// Windows와 Linux 환경에 따라 다른 클래스패스(Classpath) 구분자 유연하게 대응
const cpSeparator = process.platform === 'win32' ? ';' : ':';
const classpath = [
  skillDir,
  binDir,
  path.join(libDir, 'legacy-api.jar')
].join(cpSeparator);

const argv = process.argv.slice(2);

// Java 프로세스 실행 및 환경 프로퍼티 세팅
const javaArgs = [
  `-Dfrism.license.path=${path.join(skillDir, 'license')}`,
  '-classpath', classpath,
  'com.kbcard.cm.cli.CmCli',
  ...argv
];

const javaProcess = spawn('java', javaArgs, { cwd: skillDir, env: process.env });

let stdout = '';
javaProcess.stdout.on('data', (data) => { stdout += data.toString(); });
javaProcess.on('close', (code) => {
  // 결과 출력
  console.log(stdout.trim());
});
```

### [단계 4] AI 인식 및 사용법 명세서 기술 (`SKILL.md`)
이 파일은 Kobi 에이전트의 대뇌 피질 역할을 합니다. 상단에 **YAML Frontmatter**로 명확한 이름과 호출 상황을 정의해 주어야 합니다.

```markdown
---
name: 스킬아이디 (예: frism-cm)
description: 이 스킬이 사용되어야 하는 자연어 패턴 설명. (예: KB Frism 형상관리와 연동해 달라고 하거나 체크아웃, 체크인, 스테이지 배포 등을 요구할 때 사용합니다.)
---

# 스킬 타이틀

스킬에 대한 상세한 한글 설명과 AI가 터미널에서 어떤 커맨드를 호출해야 하는지 가이드 예시를 작성합니다.

## 사용 가능한 스킬 명령

### ① 연결 상태 검증 (Connect)
```bash
node scripts/frism-cm.cjs connect --userId <사원번호>
```
...
```

---

## 5. 설치 패키지 인스톨러 연동 가이드

개발된 스킬은 zip 포맷으로 압축하여 `<스킬이름>.skill` 확장자로 만듭니다. 이를 Kobi 전체 오프라인 통합 인스톨러에 반영하기 위해 다음 절차를 진행합니다.

1. **`make.sh` (빌드 체인)**: 신규 스킬 폴더를 압축해서 자산 폴더로 이동시키는 코드를 추가합니다.
   ```bash
   echo "Rebuilding frism-cm.skill..."
   rm -f frism-cm.skill Kobi_Installer/assets/frism-cm.skill
   (cd frism-cm && zip -rq ../frism-cm.skill *)
   cp frism-cm.skill Kobi_Installer/assets/frism-cm.skill
   ```
2. **`Install-Kobi.ps1` (클라이언트 윈도우 인스톨러)**: 사용자 PC 설치 시 스킬 압축파일을 홈 디렉토리에 풀어서 사전 연동해 주도록 파워셸 코드를 한 줄 삽입합니다.
   ```powershell
   $TargetFrismCmSkillDir = Join-Path $SkillsDir "frism-cm"
   New-Item -ItemType Directory -Force -Path $TargetFrismCmSkillDir | Out-Null
   # assets\frism-cm.skill 압축 파일을 $TargetFrismCmSkillDir 경로에 tar.exe 등으로 압축 해제
   ```
3. **`Uninstall-Kobi.ps1` (클라이언트 언인스톨러)**: 프로그램 영구 제거 시 폴더를 말끔하게 제거하도록 가이드라인을 삽입합니다.
   ```powershell
   Remove-Item (Join-Path $SkillsDir "frism-cm") -Recurse -Force -ErrorAction SilentlyContinue
   ```

---

## 6. AI에게 바이브코딩을 요청하는 실전 프롬프트 (템플릿)

다른 프로젝트에서 이 가이드를 사용하여 AI에게 고속 제작을 지시할 때 사용하는 실제 명령 템플릿입니다:

> **[바이브코딩 지시 프롬프트 템플릿]**
>
> "우리가 가진 legacy-api.jar와 관련 소스(A.java, B.java)를 활용하여 `Kobi` AI Assistant 전용 신규 스킬 `my-legacy-skill`을 제작해 주려고 해.
> 
> 첨부한 `SKILL_GUIDE.md` 파일에 정의된 설계 규칙과 뼈대 코드 양식(Java CLI Wrapper, Unicode Escape 치환, JDK 1.8 교차 컴파일 `--release 8`, Node.js CJS Wrapper, SKILL.md Frontmatter 정의)을 철저히 분석 및 준수해서:
>
> 1. 레거시 소스를 커맨드라인 매개변수 기반으로 구동하고 JSON 결과를 stdout으로 출력하는 `com.kbcard.cli.MyCli.java` 코드를 작성해 줘. 한글 리터럴은 유니코드 이스케이프로 바꿔줘.
> 2. OS 이식성 보장형 Node.js CLI 래퍼 스크립트인 `scripts/my-legacy.cjs`를 만들어 줘.
> 3. AI 에이전트 인식을 위한 Frontmatter 가이드가 포함된 `SKILL.md`를 한국어로 미려하게 작성해 줘.
> 4. JDK 1.8 타겟으로 빌드하고 패키지화하는 계획을 세우고 실행해 줘."

---

위 설계 지침서(`SKILL_GUIDE.md`)를 복사해 다른 프로젝트의 AI(Gemini, Claude 등)에 던지는 것만으로도, 개발자는 고도의 소스 분석이나 이식성 설정 고민 없이 단 몇 초 만에 사내 맞춤형 AI 스킬을 완성해낼 수 있습니다.
