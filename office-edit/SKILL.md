---
name: office-edit
description: Use this skill when the user asks to read, extract, summarize, edit, or create Excel (.xlsx) or Word (.docx) files. Applies to requests like reading a spreadsheet's contents, updating specific cells, extracting text from a Word document, replacing specific text in a Word document, filling a report/template with data, or creating a brand-new Excel/Word file from scratch (title, paragraphs, tables, sheets).
---

# Office 파일 읽기/수정/생성 스킬 (Excel · Word)

이 스킬은 Kobi가 Office가 설치되지 않은 PC에서도 순수 Node.js 라이브러리(exceljs, mammoth, docxtemplater, pizzip, docx)만으로 `.xlsx`(Excel) / `.docx`(Word) 파일을 **읽고, 부분 수정하고, 백지 상태에서 새로 생성하고, 템플릿 기반으로 채워 생성**할 수 있게 해줍니다.

모든 명령은 `<스킬경로>/scripts/office-edit.cjs`를 통해 실행하며, 결과는 항상 **단일 JSON 한 줄**로 stdout에 출력됩니다.

- 성공: `{"success": true, "data": {...}, "message": "..."}`
- 실패: `{"success": false, "errorCode": "...", "errorMessage": "...", "errorDetail": "..."}`

## 안전 원칙 (중요)

- **원본 파일은 기본적으로 절대 덮어쓰지 않습니다.** `edit-xlsx`, `edit-docx`는 `--out <경로>`를 지정하지 않으면 `원본파일명.edited.확장자` 형태의 **새 파일**로 저장합니다.
- 원본을 직접 덮어쓰고 싶다면 `--in-place` 플래그를 명시적으로 추가해야 합니다. 사용자가 원본 덮어쓰기를 명확히 요청하지 않았다면 `--in-place`를 사용하지 말고, 새로 생성된 파일 경로를 사용자에게 알려주세요.
- 지원하지 않는 확장자(예: `.xls`, `.doc` 구버전 포맷)는 처리할 수 없으며 `INVALID_FORMAT` 에러를 반환합니다. 필요 시 사용자에게 `.xlsx`/`.docx`(Office 2007+ 포맷)로 저장해달라고 안내하세요.
- **`create-xlsx`, `create-docx`는 신규 파일 생성 전용이라 `--out` 경로에 이미 파일이 있으면 기본적으로 실패(`FILE_EXISTS`)합니다.** 사용자가 명확히 덮어쓰기를 원할 때만 `--force`를 추가하세요.

## 1. Excel 읽기 — `read-xlsx`

```bash
node scripts/office-edit.cjs read-xlsx --file <파일경로.xlsx> [--sheet <시트명>]
```

- `--sheet`를 생략하면 모든 시트를 반환합니다.
- 반환된 `data.sheets[].rows`는 각 행을 셀 값 배열로 표현합니다(1행부터, 빈 셀 포함).

## 2. Excel 셀 부분 수정 — `edit-xlsx`

```bash
node scripts/office-edit.cjs edit-xlsx --file <파일경로.xlsx> --sheet <시트명> --set A1=값 --set B2=123 [--out <저장경로>] [--in-place]
```

- `--set`은 `셀주소=값` 형식이며 여러 번 반복해서 여러 셀을 한 번에 수정할 수 있습니다.
- 값이 숫자 형식이면 자동으로 숫자로, 아니면 문자열로 저장됩니다.
- `--sheet` 생략 시 첫 번째 시트를 대상으로 합니다.
- 기존 서식(테두리, 색상, 열 너비 등)은 그대로 유지됩니다.

## 3. Word 읽기 — `read-docx`

```bash
node scripts/office-edit.cjs read-docx --file <파일경로.docx> [--format markdown|text]
```

- 기본값은 `markdown`(제목/목록 등 구조를 살려 변환)이며, `text`는 순수 텍스트만 추출합니다.
- 표, 이미지, 각주 등 일부 복잡한 요소는 완벽히 재현되지 않을 수 있습니다(`data.warnings` 참고).

## 4. Word 텍스트 부분 치환 — `edit-docx`

```bash
node scripts/office-edit.cjs edit-docx --file <파일경로.docx> --find "찾을 문구" --replace "바꿀 문구" [--all] [--out <저장경로>] [--in-place]
```

- 원본 문서의 서식(글꼴, 굵기, 색상 등)을 그대로 유지한 채 텍스트만 치환합니다.
- 기본은 첫 번째 일치 항목만 치환하며, 모두 치환하려면 `--all`을 추가합니다.
- **주의**: `--find` 문구가 워드 문서 내부에서 서로 다른 서식 조각(run)으로 쪼개져 있으면(예: 일부만 굵게 표시된 경우) 찾지 못할 수 있습니다(`TEXT_NOT_FOUND`). 이 경우 더 짧고 고유한 구절로 다시 시도하거나, 서식이 균일한 문구를 지정하도록 안내하세요.

## 5. 템플릿 기반 신규 문서 생성 — `fill-template`

```bash
node scripts/office-edit.cjs fill-template --file <템플릿파일.docx|xlsx> --data <데이터.json> --out <저장경로>
```

- 템플릿 파일 안에 `{필드명}` 형태의 플레이스홀더를 미리 넣어두면, `--data`로 전달한 JSON 값으로 채운 **새 파일**을 생성합니다(docx, xlsx 템플릿 모두 지원).
- 표를 반복 출력해야 하면 템플릿에 `{#목록}...{/목록}` 루프 문법을 사용하고, `--data`의 JSON에 배열 필드를 넣어주세요.
- `--data` JSON 파일은 사용자의 요청 내용을 바탕으로 Kobi가 미리 작성해서 임시 파일로 저장한 뒤 이 명령에 전달하면 됩니다.
- 템플릿에 정의되지 않은 필드가 데이터에 있어도 무시되며, 반대로 템플릿에 필요한 필드가 데이터에 없으면 `TEMPLATE_RENDER_ERROR`가 반환됩니다.

## 6. 백지 상태에서 Excel 신규 생성 — `create-xlsx`

```bash
node scripts/office-edit.cjs create-xlsx --data <데이터.json> --out <저장경로.xlsx> [--force]
```

- 기존 파일이 전혀 없어도 데이터만으로 완전히 새로운 Excel 파일을 만듭니다(양식/템플릿 불필요).
- `--data` JSON 형식 (Kobi가 사용자 요청 내용을 바탕으로 직접 작성해서 임시 파일로 저장 후 전달):
  ```json
  {
    "sheets": [
      {
        "name": "성적표",
        "columnWidths": [15, 10],
        "boldHeaderRow": true,
        "rows": [
          ["이름", "점수"],
          ["홍길동", 90],
          ["김철수", 85]
        ]
      }
    ]
  }
  ```
- `rows`는 `read-xlsx`의 출력 형식과 동일하게 행마다 셀 값 배열입니다(첫 행을 헤더로 쓰려면 `boldHeaderRow: true`로 굵게 표시).
- 여러 시트를 만들려면 `sheets` 배열에 항목을 추가하면 됩니다.

## 7. 백지 상태에서 Word 신규 생성 — `create-docx`

```bash
node scripts/office-edit.cjs create-docx --data <데이터.json> --out <저장경로.docx> [--force]
```

- 기존 파일이 전혀 없어도 제목/문단/표 구조를 지정해서 완전히 새로운 Word 문서를 만듭니다.
- `--data` JSON 형식:
  ```json
  {
    "title": "주간 업무 보고서",
    "blocks": [
      { "type": "heading", "level": 1, "text": "1. 개요" },
      { "type": "paragraph", "text": "이번 주 주요 업무 내용을 정리한 문서입니다." },
      { "type": "paragraph", "text": "강조할 내용", "bold": true },
      { "type": "table", "rows": [["항목", "상태"], ["기능 A", "완료"]] }
    ]
  }
  ```
- `blocks`의 각 항목 `type`은 `heading`(레벨 1~4), `table`, 또는 생략 시 기본값인 일반 `paragraph`입니다. 문단은 `bold`/`italic` 속성을 지원합니다.
- 표/제목 등 구조가 필요 없는 단순 문서는 `blocks`에 `paragraph` 타입만 나열하면 됩니다.

## 8. 일반적인 작업 흐름 (Workflow)

1. 사용자가 파일 내용을 물으면 먼저 `read-xlsx` 또는 `read-docx`로 내용을 확인합니다.
2. 특정 값/문구만 바꿔달라는 요청이면 `edit-xlsx`(셀 지정) 또는 `edit-docx`(문구 지정)를 사용하고, 결과로 생성된 새 파일 경로를 사용자에게 안내합니다.
3. "정해진 양식(플레이스홀더가 있는 기존 파일)에 데이터 채워서 새로 만들어줘"라는 요청이면, 템플릿에 어떤 플레이스홀더가 있는지 먼저 `read-docx`/`read-xlsx`로 확인한 뒤 `fill-template`으로 채웁니다.
4. "양식 없이 새로 작성해줘"라는 요청이면 `create-xlsx`/`create-docx`로 원하는 구조를 데이터로 구성해 처음부터 생성합니다.
5. 모든 실패 응답(`success: false`)은 `errorCode`/`errorMessage`/`errorDetail`을 그대로 사용자에게 한국어로 알기 쉽게 설명합니다.
