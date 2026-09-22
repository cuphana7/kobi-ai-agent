#!/usr/bin/env node

/**
 * Kobi kbpay-service-check skill CLI
 * 등록된 도메인별로 Jennifer APM의 액티브 서비스 목록을 조회하여 runningTime이
 * 임계치(threshold)를 초과하는 지연 트랜잭션만 추려낸 리포트(전체 도메인 현황 + 도메인별 지연 서비스)를
 * 반환한다. 이 리포트를 근거로 서비스 정상 여부/지연 현황을 판단하는 것은 이 스크립트를 호출하는
 * kobi 에이전트 자신(내부적으로 이미 사내 vLLM 기반)이 수행한다.
 * SKILL_GUIDE.md 법칙 1에 따라 항상 단일 JSON 한 줄만 stdout에 출력한다.
 */

'use strict';

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// --- Jennifer APM 연결 기본값 (jennifer-monitor 스킬과 동일한 서버를 사용) ---
const DEFAULT_JENNIFER_URL = process.env.JENNIFER_URL || 'http://10.95.252.10:7900';
const DEFAULT_JENNIFER_TOKEN = process.env.JENNIFER_TOKEN || 'RLf7MMrrU5s';

const DEFAULT_THRESHOLD_MS = 10000;
const DEFAULT_CONCURRENCY = 8;

// 현재 시각을 KST(UTC+9) ISO-8601 문자열로 반환 (예: 2026-07-24T14:00:00.000+09:00)
function nowKstIso() {
  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return kst.toISOString().replace('Z', '+09:00');
}

// --- 도메인별 서비스명 매핑표 ---
const DOMAINS = [
  { domainId: 1031, serviceName: '대내외통신-본업연계-HOME_IF' },
  { domainId: 1050, serviceName: '대내외통신-그룹OpenAPI-OPEN_API_GW' },
  { domainId: 1042, serviceName: '대내외통신-KBPay연계-LINK' },
  { domainId: 1012, serviceName: '대내외통신-마이데이터연계-MYDATA_MCIEAI' },
  { domainId: 1008, serviceName: 'KBPay-앱-APP' },
  { domainId: 1043, serviceName: 'KBPay-회원-MEMBER' },
  { domainId: 1046, serviceName: 'KBPay-결제-PAYMENT' },
  { domainId: 1041, serviceName: 'KBPay-서비스-BANK' },
  { domainId: 1048, serviceName: 'KBPay-쇼핑/여행-LIFE' },
  { domainId: 1044, serviceName: 'KBPay-토큰발급-TR.TSP' },
  { domainId: 1045, serviceName: 'KBPay-공중망연계-API' },
  { domainId: 1047, serviceName: 'KBPay-해외결제등-ETC' },
  { domainId: 1009, serviceName: 'KBPay-어드민-ADP' },
  { domainId: 1023, serviceName: '본업-어드민-UBW_ADM' },
  { domainId: 1024, serviceName: '본업-혜택-UBW_BON' },
  { domainId: 1025, serviceName: '본업-공통-UBW_CMN' },
  { domainId: 1026, serviceName: '본업-카드-UBW_CRD' },
  { domainId: 1027, serviceName: '본업-API-UBW_EXT' },
  { domainId: 1028, serviceName: '본업-금융-UBW_FNC' },
  { domainId: 1029, serviceName: '본업-MyKB-UBW_MKB' },
  { domainId: 1030, serviceName: '본업-서비스-UBW_SVC' },
  { domainId: 1032, serviceName: '본업-MIAPS-UBW_MIAPS' },
  { domainId: 1033, serviceName: '본업-통합로그등-WEBSHELL' },
  { domainId: 1002, serviceName: '자산-G/W-KBaaS' },
  { domainId: 1000, serviceName: '자산-서비스-Liivmate' },
  { domainId: 1013, serviceName: '마이데이터제공-메인-UBD_MAIN' },
  { domainId: 1014, serviceName: '마이데이터제공-승인-UBD_APPR' },
  { domainId: 1015, serviceName: '마이데이터제공-청구-UBD_BILL' },
  { domainId: 1010, serviceName: '마이데이터제공-어드민-Portal' },
  { domainId: 1004, serviceName: '온라인결제-코드발급-CodeIssue' },
  { domainId: 1006, serviceName: '온라인결제-안심클릭-SafeClick' },
  { domainId: 1017, serviceName: '오픈뱅킹-공통-UBF_MAIN' },
  { domainId: 1016, serviceName: '오픈뱅킹-제공-UBE_MAIN' },
];

// --- service_name.csv 사전 매핑 ---
// 헤더 domain,application,service_name 인 CSV를 읽어, 지연 서비스의 application 값이
// CSV의 application 값 안에 포함(부분 문자열)되는 첫 행의 service_name 을 미리 붙여 준다.
// (domain 컬럼은 사용하지 않고 application 만으로 매칭한다.)

// 따옴표(", "" 이스케이프) 포함 CSV 한 줄을 필드 배열로 파싱한다.
function parseCsvLine(line) {
  const out = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (inQuotes) {
      if (c === '"') {
        if (line[i + 1] === '"') {
          cur += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cur += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ',') {
      out.push(cur);
      cur = '';
    } else {
      cur += c;
    }
  }
  out.push(cur);
  return out;
}

// service_name.csv 를 찾아 { application, service_name }[] 로 로드한다. 없거나 실패하면 [].
function loadServiceNameRows() {
  const candidates = [
    process.env.SERVICE_NAME_CSV,
    path.join(process.cwd(), 'service_name.csv'),
    path.join(__dirname, 'service_name.csv'),
  ].filter(Boolean);

  let file = null;
  for (const c of candidates) {
    try {
      if (fs.existsSync(c)) {
        file = c;
        break;
      }
    } catch (e) {
      // ignore
    }
  }
  if (!file) return [];

  let text;
  try {
    text = fs.readFileSync(file, 'utf8');
  } catch (e) {
    return [];
  }
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1); // BOM 제거

  const lines = text.split(/\r?\n/).filter((l) => l.trim() !== '');
  if (lines.length < 2) return [];

  const header = parseCsvLine(lines[0]).map((h) => h.trim().toLowerCase());
  const iApp = header.indexOf('application');
  const iName = header.indexOf('service_name');
  if (iApp === -1 || iName === -1) return [];

  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const cols = parseCsvLine(lines[i]);
    const application = (cols[iApp] || '').trim();
    const service_name = (cols[iName] || '').trim();
    if (application) rows.push({ application, service_name });
  }
  return rows;
}

// 지연 항목에서 매칭 키로 쓸 application 값을 추출한다.
function pickApplication(item) {
  for (const k of ['application', 'applicationName', 'appName', 'app']) {
    if (item && item[k] != null && String(item[k]).trim() !== '') {
      return String(item[k]).trim();
    }
  }
  return null;
}

// application 값이 CSV application 안에 포함되는 첫 행의 service_name 반환(대소문자 무시), 없으면 null.
function mapServiceName(app, rows) {
  if (!app) return null;
  const needle = app.toLowerCase();
  for (const r of rows) {
    if (r.application.toLowerCase().includes(needle)) {
      return r.service_name || null;
    }
  }
  return null;
}

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
      opts[key] = next;
      i++;
    }
  }
  return opts;
}

// 범용 HTTP(S) 요청 헬퍼. Node 버전에 상관없이 동작하도록 내장 http/https 모듈만 사용한다.
function request(urlStr, { method = 'GET', headers = {}, body, timeoutMs = 10000 } = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const payload = body ? Buffer.from(typeof body === 'string' ? body : JSON.stringify(body)) : null;
    const options = {
      method,
      headers: {
        ...headers,
        ...(payload ? { 'Content-Length': payload.length } : {}),
      },
      timeout: timeoutMs,
    };

    const protocol = url.protocol === 'https:' ? https : http;
    const req = protocol.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: data });
      });
      res.on('error', reject);
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timed out'));
    });

    if (payload) req.write(payload);
    req.end();
  });
}

// 동시 실행 개수를 제한하며 배열 전체에 async 작업을 적용하는 헬퍼
async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let cursor = 0;
  async function runNext() {
    while (cursor < items.length) {
      const idx = cursor++;
      results[idx] = await worker(items[idx], idx);
    }
  }
  const runners = Array.from({ length: Math.min(limit, items.length) }, runNext);
  await Promise.all(runners);
  return results;
}

function extractRunningTime(item) {
  // 실제 Jennifer 응답은 runningTime을 항상 포함하지만, elapseTime(트랜잭션 총 경과시간)을 안전망으로 둔다.
  const raw = item.runningTime ?? item.elapseTime;
  const num = Number(raw);
  return Number.isFinite(num) ? num : null;
}

async function fetchActiveServices(jenniferUrl, jenniferToken, domainId) {
  const url = `${jenniferUrl}/api/activeService/list?domain_id=${domainId}&instance_id=0`;
  const res = await request(url, {
    headers: {
      Authorization: `Bearer ${jenniferToken}`,
      'Content-Type': 'application/json',
    },
  });
  if (res.statusCode !== 200) {
    throw new Error(`HTTP ${res.statusCode}: ${res.body}`);
  }
  const parsed = JSON.parse(res.body);
  // Jennifer v1 API는 배열, { result: [...] }, { list: [...] }, { data: [...] } 형태로
  // 응답할 수 있어 모두 대응한다. (실제 운영 서버는 { result: [...] } 형태로 응답함)
  if (Array.isArray(parsed)) return parsed;
  if (Array.isArray(parsed?.result)) return parsed.result;
  if (Array.isArray(parsed?.list)) return parsed.list;
  if (Array.isArray(parsed?.data)) return parsed.data;
  return [];
}

async function checkDomain(jenniferUrl, jenniferToken, threshold, domain) {
  try {
    const items = await fetchActiveServices(jenniferUrl, jenniferToken, domain.domainId);
    const delayedServices = items
      .map((item) => ({ item, runningTime: extractRunningTime(item) }))
      .filter(({ runningTime }) => runningTime !== null && runningTime > threshold)
      .map(({ item, runningTime }) => ({ ...item, runningTime }));

    return {
      domainId: domain.domainId,
      serviceName: domain.serviceName,
      status: delayedServices.length > 0 ? 'DELAYED' : 'OK',
      activeServiceCount: items.length,
      delayedCount: delayedServices.length,
      delayedServices,
      error: null,
    };
  } catch (e) {
    return {
      domainId: domain.domainId,
      serviceName: domain.serviceName,
      status: 'ERROR',
      activeServiceCount: null,
      delayedCount: null,
      delayedServices: [],
      error: e.message,
    };
  }
}

function printUsage() {
  console.log(`
Kobi kbpay-service-check CLI

Usage:
  node kbpay-service-check.cjs <command> [options]

Commands:
  check          도메인별 액티브 서비스를 조회하여 지연건(runningTime > threshold)을 추려낸
                 전체 도메인 현황 리포트를 반환한다. (정상/지연 여부 판단은 이 리포트를 읽는
                 kobi 에이전트가 직접 수행한다.)
  list-domains   내장된 [도메인ID / 서비스명] 매핑표를 그대로 출력한다. (네트워크 호출 없음)

Options (check):
  --threshold <ms>       지연 판단 기준 (기본값: ${DEFAULT_THRESHOLD_MS}ms)
  --domains <id1,id2,..> 특정 도메인ID만 점검 (기본값: 전체 33개 도메인)
  --concurrency <n>      Jennifer API 동시 호출 개수 (기본값: ${DEFAULT_CONCURRENCY})
  --jennifer-url <url>   Jennifer View Server URL (기본값: ${DEFAULT_JENNIFER_URL})
  --jennifer-token <tk>  Jennifer API Token (기본값: 환경변수 JENNIFER_TOKEN 또는 내장 기본값)
  `);
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('--help') || argv.includes('-h')) {
    printUsage();
    process.exit(0);
  }

  const command = argv[0];
  const opts = parseArgs(argv.slice(1));

  if (command === 'list-domains') {
    return ok({ domainCount: DOMAINS.length, domains: DOMAINS }, `등록된 도메인 ${DOMAINS.length}건 조회 완료`);
  }

  if (command !== 'check') {
    printUsage();
    return fail('UNKNOWN_COMMAND', `알 수 없는 명령입니다: ${command}`, null);
  }

  const threshold = opts.threshold ? Number(opts.threshold) : DEFAULT_THRESHOLD_MS;
  if (!Number.isFinite(threshold) || threshold < 0) {
    return fail('INVALID_ARGUMENT', '--threshold는 0 이상의 숫자여야 합니다.', null);
  }

  const concurrency = opts.concurrency ? Number(opts.concurrency) : DEFAULT_CONCURRENCY;
  const targetDomains = opts.domains
    ? DOMAINS.filter((d) => opts.domains.split(',').map((s) => s.trim()).includes(String(d.domainId)))
    : DOMAINS;

  if (targetDomains.length === 0) {
    return fail('INVALID_ARGUMENT', '--domains에 해당하는 도메인을 찾을 수 없습니다.', null);
  }

  const jenniferUrl = (opts['jennifer-url'] || DEFAULT_JENNIFER_URL).replace(/\/$/, '');
  const jenniferToken = opts['jennifer-token'] || DEFAULT_JENNIFER_TOKEN;

  let domains;
  try {
    domains = await mapWithConcurrency(targetDomains, concurrency, (domain) =>
      checkDomain(jenniferUrl, jenniferToken, threshold, domain)
    );
  } catch (e) {
    return fail('JENNIFER_REQUEST_FAILED', 'Jennifer APM 조회 중 오류가 발생했습니다.', e.message);
  }

  // service_name.csv 를 사전 조인: 각 지연 서비스에 mappedServiceName(한글 서비스명 또는 null)을 붙인다.
  const serviceNameRows = loadServiceNameRows();
  for (const d of domains) {
    for (const s of d.delayedServices || []) {
      s.mappedServiceName = mapServiceName(pickApplication(s), serviceNameRows);
    }
  }

  const delayedDomainCount = domains.filter((d) => d.status === 'DELAYED').length;
  const errorDomainCount = domains.filter((d) => d.status === 'ERROR').length;

  const report = {
    checkedAt: nowKstIso(),
    thresholdMs: threshold,
    domainCount: domains.length,
    delayedDomainCount,
    errorDomainCount,
    domains,
  };

  return ok(
    report,
    delayedDomainCount > 0 ? `지연 도메인 ${delayedDomainCount}건 발견` : '전체 정상'
  );
}

main().catch((e) => fail('SYSTEM_ERROR', e.message, e.stack));
