#!/usr/bin/env node

/**
 * Kobi office-edit skill CLI
 * Excel(.xlsx) / Word(.docx) 읽기, 부분 수정, 템플릿 채우기 통합 래퍼.
 * SKILL_GUIDE.md 법칙 1에 따라 항상 단일 JSON 한 줄만 stdout에 출력한다.
 */

'use strict';

const fs = require('fs');
const path = require('path');

function ok(data, message) {
  process.stdout.write(JSON.stringify({ success: true, data, message: message || '성공' }) + '\n');
  process.exit(0);
}

function fail(errorCode, errorMessage, errorDetail) {
  process.stdout.write(
    JSON.stringify({ success: false, errorCode, errorMessage, errorDetail: errorDetail || null }) + '\n'
  );
  process.exit(1);
}

function parseArgs(argv) {
  const opts = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) {
      opts[key] = true;
    } else {
      if (key === 'set') {
        (opts.set = opts.set || []).push(next);
      } else {
        opts[key] = next;
      }
      i++;
    }
  }
  return opts;
}

// 안전 가드레일: 지정된 확장자만 허용하고, 파일 존재를 먼저 검증한다.
function requireFile(filePath, exts) {
  if (!filePath) fail('MISSING_ARGUMENT', '--file 인자가 필요합니다.', null);
  if (!fs.existsSync(filePath)) fail('FILE_NOT_FOUND', `파일을 찾을 수 없습니다: ${filePath}`, null);
  const ext = path.extname(filePath).toLowerCase();
  if (exts && !exts.includes(ext)) {
    fail('INVALID_FORMAT', `지원하지 않는 파일 형식입니다: ${ext}`, `허용된 확장자: ${exts.join(', ')}`);
  }
}

// 안전 가드레일: --in-place를 명시하지 않으면 원본을 절대 덮어쓰지 않고 새 파일에 저장한다.
function resolveOutPath(opts, defaultSuffix) {
  if (opts.out) return opts.out;
  if (opts['in-place']) return opts.file;
  const ext = path.extname(opts.file);
  const base = opts.file.slice(0, -ext.length || undefined);
  return `${base}${defaultSuffix}${ext}`;
}

function plainCellValue(v) {
  if (v == null) return null;
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'object') {
    if (Array.isArray(v.richText)) return v.richText.map((rt) => rt.text).join('');
    if ('result' in v) return v.result;
    if ('text' in v) return v.text;
    if ('error' in v) return `#ERROR:${v.error}`;
  }
  return v;
}

async function cmdReadXlsx(opts) {
  requireFile(opts.file, ['.xlsx']);
  const ExcelJS = require('exceljs');
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(opts.file);

  const sheets = [];
  wb.eachSheet((sheet) => {
    if (opts.sheet && sheet.name !== opts.sheet) return;
    const rows = [];
    sheet.eachRow({ includeEmpty: true }, (row) => {
      rows.push(row.values.slice(1).map(plainCellValue));
    });
    sheets.push({ name: sheet.name, rowCount: sheet.rowCount, columnCount: sheet.columnCount, rows });
  });

  if (opts.sheet && sheets.length === 0) {
    return fail('SHEET_NOT_FOUND', `시트를 찾을 수 없습니다: ${opts.sheet}`, null);
  }
  ok({ file: opts.file, sheets }, `${sheets.length}개 시트를 읽었습니다.`);
}

async function cmdEditXlsx(opts) {
  requireFile(opts.file, ['.xlsx']);
  if (!opts.set || !opts.set.length) {
    return fail('MISSING_ARGUMENT', '--set A1=값 형식의 인자가 최소 1개 필요합니다.', null);
  }

  const ExcelJS = require('exceljs');
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(opts.file);

  const sheet = opts.sheet ? wb.getWorksheet(opts.sheet) : wb.worksheets[0];
  if (!sheet) return fail('SHEET_NOT_FOUND', `시트를 찾을 수 없습니다: ${opts.sheet}`, null);

  const updated = [];
  for (const expr of opts.set) {
    const idx = expr.indexOf('=');
    if (idx < 0) {
      return fail('INVALID_ARGUMENT', `--set 형식이 올바르지 않습니다: ${expr}`, '예: --set A1=값');
    }
    const cellRef = expr.slice(0, idx);
    const raw = expr.slice(idx + 1);
    const value = raw !== '' && /^-?\d+(\.\d+)?$/.test(raw) ? Number(raw) : raw;
    sheet.getCell(cellRef).value = value;
    updated.push({ cell: cellRef, value });
  }

  const outFile = resolveOutPath(opts, '.edited');
  await wb.xlsx.writeFile(outFile);
  ok({ file: outFile, sheet: sheet.name, updatedCells: updated }, `${updated.length}개 셀을 수정했습니다.`);
}

async function cmdReadDocx(opts) {
  requireFile(opts.file, ['.docx']);
  const mammoth = require('mammoth');
  const format = opts.format === 'text' ? 'text' : 'markdown';
  const result =
    format === 'text'
      ? await mammoth.extractRawText({ path: opts.file })
      : await mammoth.convertToMarkdown({ path: opts.file });
  const warnings = (result.messages || []).map((m) => `[${m.type}] ${m.message}`);
  ok({ file: opts.file, format, content: result.value, warnings }, '문서를 읽었습니다.');
}

function decodeXmlEntities(s) {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function encodeXmlEntities(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

async function cmdEditDocx(opts) {
  requireFile(opts.file, ['.docx']);
  if (!opts.find) return fail('MISSING_ARGUMENT', '--find 인자가 필요합니다.', null);

  const PizZip = require('pizzip');
  const buf = fs.readFileSync(opts.file);
  const zip = new PizZip(buf);
  const docPath = 'word/document.xml';
  const zipEntry = zip.file(docPath);
  if (!zipEntry) {
    return fail('INVALID_FORMAT', 'word/document.xml을 찾을 수 없습니다.', '올바른 .docx 파일인지 확인하세요.');
  }

  const find = opts.find;
  const replace = opts.replace != null ? opts.replace : '';
  const all = !!opts.all;
  let count = 0;

  const xml = zipEntry.asText().replace(/(<w:t[^>]*>)([\s\S]*?)(<\/w:t>)/g, (match, open, text, close) => {
    if (!all && count >= 1) return match;
    const decoded = decodeXmlEntities(text);
    if (!decoded.includes(find)) return match;
    const occurrences = decoded.split(find).length - 1;
    count += all ? occurrences : 1;
    const newDecoded = all ? decoded.split(find).join(replace) : decoded.replace(find, replace);
    return open + encodeXmlEntities(newDecoded) + close;
  });

  if (count === 0) {
    return fail(
      'TEXT_NOT_FOUND',
      `텍스트를 찾지 못했습니다: "${find}"`,
      '문단이 여러 서식 조각(run)으로 나뉘어 있으면 매칭되지 않을 수 있습니다. 더 짧은 고유 구절로 다시 시도하세요.'
    );
  }

  zip.file(docPath, xml);
  const outFile = resolveOutPath(opts, '.edited');
  fs.writeFileSync(outFile, zip.generate({ type: 'nodebuffer', compression: 'DEFLATE' }));
  ok({ file: outFile, replacedCount: count }, `${count}건을 치환했습니다.`);
}

async function cmdFillTemplate(opts) {
  requireFile(opts.file, ['.docx', '.xlsx']);
  if (!opts.data) return fail('MISSING_ARGUMENT', '--data <json파일경로> 인자가 필요합니다.', null);
  if (!fs.existsSync(opts.data)) {
    return fail('FILE_NOT_FOUND', `데이터 파일을 찾을 수 없습니다: ${opts.data}`, null);
  }
  if (!opts.out) return fail('MISSING_ARGUMENT', '--out <저장경로> 인자가 필요합니다.', null);

  let data;
  try {
    data = JSON.parse(fs.readFileSync(opts.data, 'utf8'));
  } catch (e) {
    return fail('JSON_PARSE_ERROR', '--data JSON 파일 파싱에 실패했습니다.', e.message);
  }

  const PizZip = require('pizzip');
  const Docxtemplater = require('docxtemplater');
  const content = fs.readFileSync(opts.file, 'binary');
  const zip = new PizZip(content);
  const doc = new Docxtemplater(zip, { paragraphLoop: true, linebreaks: true });

  try {
    doc.render(data);
  } catch (e) {
    const details =
      e.properties && Array.isArray(e.properties.errors)
        ? e.properties.errors.map((er) => er.properties && er.properties.explanation).filter(Boolean).join('; ')
        : e.message;
    return fail('TEMPLATE_RENDER_ERROR', '템플릿 렌더링에 실패했습니다.', details);
  }

  fs.writeFileSync(opts.out, doc.getZip().generate({ type: 'nodebuffer', compression: 'DEFLATE' }));
  ok({ file: opts.out }, '템플릿을 채워 새 파일을 생성했습니다.');
}

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  const opts = parseArgs(rest);

  try {
    switch (cmd) {
      case 'read-xlsx':
        return await cmdReadXlsx(opts);
      case 'edit-xlsx':
        return await cmdEditXlsx(opts);
      case 'read-docx':
        return await cmdReadDocx(opts);
      case 'edit-docx':
        return await cmdEditDocx(opts);
      case 'fill-template':
        return await cmdFillTemplate(opts);
      case undefined:
      case 'help':
      case '--help':
        return ok(
          { commands: ['read-xlsx', 'edit-xlsx', 'read-docx', 'edit-docx', 'fill-template'] },
          '사용법은 SKILL.md를 참고하세요.'
        );
      default:
        return fail(
          'UNKNOWN_COMMAND',
          `알 수 없는 명령입니다: ${cmd}`,
          '사용 가능한 명령: read-xlsx, edit-xlsx, read-docx, edit-docx, fill-template'
        );
    }
  } catch (e) {
    fail('SYSTEM_ERROR', e.message, e.stack);
  }
}

main();
