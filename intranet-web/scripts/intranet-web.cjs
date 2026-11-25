#!/usr/bin/env node

/**
 * Kobi intranet-web skill CLI
 * 사용자가 SSO 로그인 버튼을 눌러 로그인한 Edge 창(전용 프로필 + 로컬 디버깅 포트)의 화면 내용을
 * Chrome DevTools Protocol(CDP)로 읽기 전용 조회한다. Kobi 는 ID/PW·쿠키·토큰을 다루지 않는다.
 * SKILL_GUIDE.md 법칙 1에 따라 항상 단일 JSON 한 줄만 stdout에 출력한다.
 *
 * 보안 게이트(법칙 2, 스킬 코어 내부):
 *  - 사용하는 CDP 메서드는 Runtime.evaluate(고정 extract.js 만), Page.enable/Page.navigate 뿐이다.
 *    Input.*(클릭·입력), Network/Storage(쿠키) 등은 구현하지 않는다.
 *  - api-get 은 extract.js 의 fetch 모드로 같은 출처 API 를 GET 으로만 호출한다(POST 등 본문 전송 경로 없음).
 *  - 이동(goto/open)·읽기 대상 URL 은 config.json 의 allowedHosts 에 있어야 하며, 이동 후 최종 URL 도 재검사한다.
 *  - logout/delete/approve/save 등 상태 변경이 의심되는 URL 로의 이동은 SECURITY_BLOCK 으로 차단한다.
 *  - 디버깅 포트는 127.0.0.1 에만 바인딩하고, 사용자의 기본 Edge 프로필이 아닌 전용 프로필을 쓴다.
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const SKILL_ROOT = path.join(__dirname, '..');
const CONFIG_PATH = path.join(SKILL_ROOT, 'config.json');
const EXTRACT_SRC = fs.readFileSync(path.join(__dirname, 'extract.js'), 'utf8')
  .replace(/^\s*\/\/.*$/gm, '')
  .trim();

// GET 요청이 상태를 바꾸는 레거시 화면을 막기 위한 차단 단어 (URL 경로·쿼리 기준, 대소문자 무시)
const DENY_URL_WORDS = ['logout', 'logoff', 'signout', 'delete', 'remove', 'approve', 'save'];

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

function loadConfig() {
  let cfg;
  try {
    cfg = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch (e) {
    fail('CONFIG_ERROR', `config.json 을 읽을 수 없습니다: ${CONFIG_PATH}`, e.message);
  }
  return {
    allowedHosts: (cfg.allowedHosts || []).map((h) => String(h).toLowerCase().trim()).filter(Boolean),
    startUrl: cfg.startUrl || '',
    loginUrlPatterns: (cfg.loginUrlPatterns || []).map((p) => String(p).toLowerCase()),
    debugPort: Number(cfg.debugPort) || 9333,
    maxChars: Number(cfg.maxChars) || 20000,
    maxRows: Number(cfg.maxRows) || 200,
    navigateTimeoutSec: Number(cfg.navigateTimeoutSec) || 30,
    afterLoginUrl: cfg.afterLoginUrl || '',
    loginWaitSec: Number(cfg.loginWaitSec) || 180,
    pollIntervalSec: Number(cfg.pollIntervalSec) || 2,
    apiMaxChars: Number(cfg.apiMaxChars) || 100000,
    apis: Array.isArray(cfg.apis) ? cfg.apis : [],
  };
}

// --- URL 보안 검사 ---

// allowedHosts 항목은 정확한 호스트명 또는 '*.example.local' 형태의 하위 도메인 와일드카드
function isAllowedHost(cfg, urlStr) {
  let u;
  try {
    u = new URL(urlStr);
  } catch (e) {
    return false;
  }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') return false;
  const host = u.hostname.toLowerCase();
  return cfg.allowedHosts.some((h) =>
    h.startsWith('*.') ? host === h.slice(2) || host.endsWith(h.slice(1)) : host === h
  );
}

function deniedWord(urlStr) {
  const u = new URL(urlStr);
  const target = decodeURIComponent(u.pathname + u.search).toLowerCase();
  return DENY_URL_WORDS.find((w) => target.includes(w)) || null;
}

// 이동 대상 URL 검사: 형식 → 스킴 → 허용 호스트 → 차단 단어 순
function assertNavigable(cfg, urlStr) {
  if (cfg.allowedHosts.length === 0) {
    fail('CONFIG_REQUIRED', 'config.json 의 allowedHosts 가 비어 있습니다. 조회할 사내 웹서비스 호스트를 등록해 주세요.', CONFIG_PATH);
  }
  let u;
  try {
    u = new URL(urlStr);
  } catch (e) {
    fail('INVALID_ARGUMENT', `올바른 URL 이 아닙니다: ${urlStr}`, null);
  }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') {
    fail('SECURITY_BLOCK', `http/https 이외의 주소는 열 수 없습니다: ${u.protocol}`, null);
  }
  if (!isAllowedHost(cfg, urlStr)) {
    fail('SECURITY_BLOCK', `허용되지 않은 호스트입니다: ${u.hostname}`, `allowedHosts: ${cfg.allowedHosts.join(', ')}`);
  }
  const w = deniedWord(urlStr);
  if (w) {
    fail('SECURITY_BLOCK', `상태 변경이 의심되는 주소('${w}' 포함)에는 접근할 수 없습니다.`, urlStr);
  }
}

function isLoginPage(cfg, url, title) {
  const s = `${url || ''} ${title || ''}`.toLowerCase();
  return cfg.loginUrlPatterns.some((p) => s.includes(p));
}

// --- CDP (DevTools HTTP 엔드포인트 + WebSocket) ---

async function listTabs(cfg) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 3000);
  try {
    const res = await fetch(`http://127.0.0.1:${cfg.debugPort}/json/list`, { signal: ctrl.signal });
    const list = await res.json();
    return list.filter((t) => t.type === 'page');
  } finally {
    clearTimeout(timer);
  }
}

async function browserRunning(cfg) {
  try {
    await listTabs(cfg);
    return true;
  } catch (e) {
    return false;
  }
}

function connect(wsUrl) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    let seq = 0;
    const pending = new Map();
    const listeners = [];
    ws.onopen = () =>
      resolve({
        send(method, params) {
          const id = ++seq;
          ws.send(JSON.stringify({ id, method, params: params || {} }));
          return new Promise((res, rej) => pending.set(id, { res, rej }));
        },
        waitEvent(method, timeoutMs) {
          return new Promise((res, rej) => {
            const timer = setTimeout(() => rej(new Error(`${method} 대기 시간 초과`)), timeoutMs);
            listeners.push({ method, fn: (p) => { clearTimeout(timer); res(p); } });
          });
        },
        close() {
          ws.close();
        },
      });
    ws.onerror = () => reject(new Error(`DevTools 연결 실패: ${wsUrl}`));
    ws.onmessage = (ev) => {
      const msg = JSON.parse(typeof ev.data === 'string' ? ev.data : ev.data.toString());
      if (msg.id && pending.has(msg.id)) {
        const p = pending.get(msg.id);
        pending.delete(msg.id);
        if (msg.error) p.rej(new Error(msg.error.message));
        else p.res(msg.result);
      } else if (msg.method) {
        for (let i = listeners.length - 1; i >= 0; i--) {
          if (listeners[i].method === msg.method) {
            listeners[i].fn(msg.params);
            listeners.splice(i, 1);
          }
        }
      }
    };
  });
}

async function runExtract(session, mode, extractOpts) {
  const expression = `(${EXTRACT_SRC})(${JSON.stringify(mode)}, ${JSON.stringify(extractOpts || {})})`;
  const r = await session.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) {
    throw new Error(r.exceptionDetails.exception ? r.exceptionDetails.exception.description : r.exceptionDetails.text);
  }
  return r.result.value;
}

// --tab 지정 시 그 탭, 아니면 허용 호스트에 있는 첫 번째 탭(DevTools 목록은 최근 활성 순)
async function pickTab(cfg, tabId) {
  let tabs;
  try {
    tabs = await listTabs(cfg);
  } catch (e) {
    fail('BROWSER_NOT_RUNNING', 'Kobi 전용 Edge 창이 실행 중이 아닙니다. 먼저 open 명령으로 Edge 를 열고 SSO 로그인해 주세요.', e.message);
  }
  if (tabId) {
    const t = tabs.find((x) => x.id === tabId);
    if (!t) fail('TAB_NOT_FOUND', `탭을 찾을 수 없습니다: ${tabId}`, null);
    if (!isAllowedHost(cfg, t.url)) {
      fail('SECURITY_BLOCK', '허용되지 않은 호스트의 탭은 읽을 수 없습니다.', null);
    }
    return t;
  }
  const t = tabs.find((x) => isAllowedHost(cfg, x.url));
  if (!t) {
    if (tabs.some((x) => isLoginPage(cfg, x.url, x.title))) {
      fail('LOGIN_REQUIRED', 'SSO 로그인이 필요합니다. Edge 창에서 SSO 로그인 버튼을 눌러 로그인한 뒤 다시 요청해 주세요.', null);
    }
    fail('TAB_NOT_FOUND', '허용된 사내 웹서비스 화면이 열려 있는 탭이 없습니다. goto 명령으로 화면을 열어 주세요.', null);
  }
  return t;
}

function summarizeTabs(cfg, tabs) {
  return tabs.map((t) => {
    const allowed = isAllowedHost(cfg, t.url);
    const loginPage = isLoginPage(cfg, t.url, t.title);
    // 허용 호스트가 아닌 탭(SSO 인증 서버 등)은 주소·제목을 노출하지 않는다
    return allowed ? { id: t.id, allowed, loginPage, url: t.url, title: t.title } : { id: t.id, allowed, loginPage };
  });
}

function overallStatus(tabSummaries) {
  if (tabSummaries.some((t) => t.allowed && !t.loginPage)) return 'READY';
  if (tabSummaries.some((t) => t.loginPage)) return 'LOGIN_REQUIRED';
  return 'NO_SERVICE_TAB';
}

async function cmdStatus(cfg) {
  let tabs;
  try {
    tabs = await listTabs(cfg);
  } catch (e) {
    return ok({ status: 'BROWSER_NOT_RUNNING', tabs: [] }, 'Kobi 전용 Edge 창이 실행 중이 아닙니다. open 명령으로 실행해 주세요.');
  }
  const summaries = summarizeTabs(cfg, tabs);
  const status = overallStatus(summaries);
  const msg = {
    READY: '사내 웹서비스 화면을 읽을 수 있습니다.',
    LOGIN_REQUIRED: 'SSO 로그인이 필요합니다. Edge 창에서 SSO 로그인 버튼을 눌러 주세요.',
    NO_SERVICE_TAB: '허용된 사내 웹서비스 화면이 열려 있지 않습니다.',
  }[status];
  return ok({ status, tabs: summaries }, msg);
}

function findEdge() {
  const candidates = [
    process.env['ProgramFiles(x86)'] && path.join(process.env['ProgramFiles(x86)'], 'Microsoft', 'Edge', 'Application', 'msedge.exe'),
    process.env.ProgramFiles && path.join(process.env.ProgramFiles, 'Microsoft', 'Edge', 'Application', 'msedge.exe'),
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'Microsoft', 'Edge', 'Application', 'msedge.exe'),
  ].filter(Boolean);
  return candidates.find((p) => fs.existsSync(p)) || null;
}

async function cmdOpen(cfg, opts) {
  if (process.platform !== 'win32') {
    return fail('UNSUPPORTED_PLATFORM', 'open 명령은 Windows(Microsoft Edge)에서만 지원합니다.', process.platform);
  }
  const url = typeof opts.url === 'string' ? opts.url : cfg.startUrl;
  if (!url) {
    return fail('INVALID_ARGUMENT', '--url 을 지정하거나 config.json 의 startUrl 을 설정해 주세요.', CONFIG_PATH);
  }
  assertNavigable(cfg, url);

  if (await browserRunning(cfg)) {
    // 이미 실행 중이면 새로 띄우지 않고 기존 창에서 이동한다
    if (opts.wait) {
      await navigate(cfg, url, null);
      return cmdWaitLogin(cfg, opts);
    }
    return cmdGoto(cfg, { url });
  }

  const edge = findEdge();
  if (!edge) return fail('EDGE_NOT_FOUND', 'Microsoft Edge(msedge.exe)를 찾을 수 없습니다.', null);
  const profileDir = path.join(process.env.LOCALAPPDATA || os.homedir(), 'Kobi', 'edge-profile');
  fs.mkdirSync(profileDir, { recursive: true });
  const child = spawn(
    edge,
    [
      `--remote-debugging-port=${cfg.debugPort}`,
      '--remote-debugging-address=127.0.0.1',
      `--user-data-dir=${profileDir}`,
      '--no-first-run',
      '--no-default-browser-check',
      url,
    ],
    { detached: true, stdio: 'ignore', windowsHide: false }
  );
  child.unref();

  // 디버깅 포트가 열릴 때까지 최대 15초 대기
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    if (await browserRunning(cfg)) break;
    await new Promise((r) => setTimeout(r, 500));
  }
  if (!(await browserRunning(cfg))) {
    return fail(
      'DEBUG_PORT_UNAVAILABLE',
      'Edge 는 실행했지만 디버깅 포트에 연결할 수 없습니다. 회사 정책(RemoteDebuggingAllowed)으로 막혀 있을 수 있습니다.',
      `port ${cfg.debugPort}`
    );
  }
  // 첫 페이지(SSO 리다이렉트 포함)가 그려질 시간을 조금 둔 뒤 상태를 반환한다
  await new Promise((r) => setTimeout(r, 2000));
  if (opts.wait) return cmdWaitLogin(cfg, opts);
  return cmdStatus(cfg);
}

async function cmdGoto(cfg, opts) {
  if (typeof opts.url !== 'string') return fail('INVALID_ARGUMENT', '--url 이 필요합니다.', null);
  const r = await navigate(cfg, opts.url, typeof opts.tab === 'string' ? opts.tab : null);
  if (r.status === 'LOGIN_REQUIRED') {
    return ok(r, 'SSO 로그인이 필요합니다. Edge 창에서 SSO 로그인 버튼을 눌러 로그인한 뒤 다시 요청해 주세요.');
  }
  return ok(r, `이동 완료: ${r.title}`);
}

// 허용 호스트 URL 로 이동하고 { status: READY|LOGIN_REQUIRED, tab, url, title } 를 반환한다(검사 실패 시 fail 로 종료)
async function navigate(cfg, url, tabId) {
  assertNavigable(cfg, url);

  let tabs;
  try {
    tabs = await listTabs(cfg);
  } catch (e) {
    return fail('BROWSER_NOT_RUNNING', 'Kobi 전용 Edge 창이 실행 중이 아닙니다. 먼저 open 명령으로 실행해 주세요.', e.message);
  }
  // goto 는 허용 호스트 탭 또는 로그인/빈 탭에서만 이동한다(다른 사이트 탭은 건드리지 않음)
  let tab = tabId ? tabs.find((t) => t.id === tabId) : null;
  if (!tab) tab = tabs.find((t) => isAllowedHost(cfg, t.url)) || tabs.find((t) => isLoginPage(cfg, t.url, t.title) || t.url.startsWith('edge://') || t.url === 'about:blank');
  if (!tab) return fail('TAB_NOT_FOUND', '이동에 사용할 탭을 찾을 수 없습니다.', null);

  const session = await connect(tab.webSocketDebuggerUrl);
  try {
    await session.send('Page.enable');
    const loaded = session.waitEvent('Page.loadEventFired', cfg.navigateTimeoutSec * 1000);
    let info;
    try {
      const nav = await session.send('Page.navigate', { url });
      if (nav.errorText) throw new Error(nav.errorText);
      await loaded;
      info = await runExtract(session, 'status');
    } catch (e) {
      return fail('NAVIGATE_FAILED', '페이지 이동 중 오류가 발생했습니다.', e.message);
    }
    const allowed = isAllowedHost(cfg, info.url);
    const loginPage = isLoginPage(cfg, info.url, info.title);
    if (!allowed && !loginPage) {
      return fail('SECURITY_BLOCK', '이동 후 허용되지 않은 호스트로 리다이렉트되었습니다.', null);
    }
    if (loginPage) return { status: 'LOGIN_REQUIRED', tab: tab.id };
    return { status: 'READY', tab: tab.id, url: info.url, title: info.title };
  } finally {
    session.close();
  }
}

// 탭의 본문 텍스트와 표를 함께 읽는다(로그인 직후 목표 페이지 요약용)
async function snapshotTab(cfg, tabId, maxChars) {
  const tabs = await listTabs(cfg);
  const tab = tabs.find((t) => t.id === tabId);
  if (!tab || !isAllowedHost(cfg, tab.url)) {
    return fail('SECURITY_BLOCK', '허용되지 않은 호스트의 화면은 읽을 수 없습니다.', null);
  }
  const session = await connect(tab.webSocketDebuggerUrl);
  try {
    const text = await runExtract(session, 'text', { maxChars: maxChars || cfg.maxChars });
    const tables = await runExtract(session, 'tables', { maxRows: cfg.maxRows });
    if (!isAllowedHost(cfg, text.url)) {
      return fail('SECURITY_BLOCK', '허용되지 않은 호스트의 화면은 읽을 수 없습니다.', null);
    }
    return { tab: tab.id, url: text.url, title: text.title, text: text.text, truncated: text.truncated, tableCount: tables.tableCount, tables: tables.tables };
  } catch (e) {
    return fail('EXTRACT_FAILED', '화면 내용을 읽는 중 오류가 발생했습니다.', e.message);
  } finally {
    session.close();
  }
}

// 사용자가 Edge 창에서 SSO 로그인을 마칠 때까지 기다린 뒤, 지정한 페이지(--then / afterLoginUrl)로 이동해 내용을 반환한다
async function cmdWaitLogin(cfg, opts) {
  const then = typeof opts.then === 'string' ? opts.then : cfg.afterLoginUrl;
  if (then) assertNavigable(cfg, then);
  const timeoutSec = Number(opts.timeout) || cfg.loginWaitSec;

  const deadline = Date.now() + timeoutSec * 1000;
  let ready = null;
  while (Date.now() < deadline) {
    let tabs = null;
    try {
      tabs = await listTabs(cfg);
    } catch (e) {
      return fail('BROWSER_NOT_RUNNING', 'Kobi 전용 Edge 창이 실행 중이 아닙니다. 먼저 open 명령으로 실행해 주세요.', e.message);
    }
    const summaries = summarizeTabs(cfg, tabs);
    if (overallStatus(summaries) === 'READY') {
      ready = summaries.find((t) => t.allowed && !t.loginPage);
      break;
    }
    await new Promise((r) => setTimeout(r, cfg.pollIntervalSec * 1000));
  }
  if (!ready) {
    return fail('LOGIN_TIMEOUT', `${timeoutSec}초 동안 SSO 로그인이 완료되지 않았습니다. Edge 창에서 로그인한 뒤 다시 요청해 주세요.`, null);
  }
  if (!then) {
    return ok({ status: 'READY', tab: ready.id, url: ready.url, title: ready.title }, 'SSO 로그인이 확인되었습니다.');
  }
  const nav = await navigate(cfg, then, ready.id);
  if (nav.status !== 'READY') {
    return ok(nav, '로그인 후 이동한 페이지에서 다시 SSO 로그인이 요구됩니다. Edge 창을 확인해 주세요.');
  }
  const page = await snapshotTab(cfg, nav.tab, Number(opts['max-chars']) || cfg.maxChars);
  return ok({ status: 'READY', page }, `로그인 확인 후 이동 완료: ${page.title}`);
}

// 로그인된 탭의 세션(쿠키)으로 같은 출처 API 를 GET 호출해 JSON(또는 텍스트)을 반환한다
async function cmdApiGet(cfg, opts) {
  if (typeof opts.url !== 'string') return fail('INVALID_ARGUMENT', '--url 이 필요합니다.', null);
  let tabs;
  try {
    tabs = await listTabs(cfg);
  } catch (e) {
    return fail('BROWSER_NOT_RUNNING', 'Kobi 전용 Edge 창이 실행 중이 아닙니다. 먼저 open 명령으로 Edge 를 열고 SSO 로그인해 주세요.', e.message);
  }
  const serviceTabs = tabs.filter((t) => isAllowedHost(cfg, t.url) && !isLoginPage(cfg, t.url, t.title));
  if (typeof opts.tab === 'string') {
    const t = serviceTabs.find((x) => x.id === opts.tab);
    if (!t) return fail('TAB_NOT_FOUND', `로그인된 허용 호스트 탭을 찾을 수 없습니다: ${opts.tab}`, null);
    serviceTabs.splice(0, serviceTabs.length, t);
  }
  if (serviceTabs.length === 0) {
    if (tabs.some((x) => isLoginPage(cfg, x.url, x.title))) {
      return fail('LOGIN_REQUIRED', 'SSO 로그인이 필요합니다. Edge 창에서 SSO 로그인 버튼을 눌러 로그인한 뒤 다시 요청해 주세요.', null);
    }
    return fail('TAB_NOT_FOUND', '로그인된 사내 웹서비스 화면이 열려 있어야 API 를 호출할 수 있습니다.', null);
  }

  // '/api/list?x=1' 같은 상대 경로는 첫 서비스 탭 기준으로 해석한다
  let url;
  try {
    url = new URL(opts.url, serviceTabs[0].url).href;
  } catch (e) {
    return fail('INVALID_ARGUMENT', `올바른 URL 이 아닙니다: ${opts.url}`, null);
  }
  assertNavigable(cfg, url);
  // 브라우저 CORS 정책상 세션 쿠키가 붙는 호출은 같은 출처에서만 가능하므로, 같은 출처의 탭에서 실행한다
  const origin = new URL(url).origin;
  const tab = serviceTabs.find((t) => new URL(t.url).origin === origin);
  if (!tab) {
    return fail('TAB_NOT_FOUND', `API 와 같은 출처(${origin})의 화면이 열려 있지 않습니다. goto 로 해당 서비스 화면을 먼저 열어 주세요.`, null);
  }

  const session = await connect(tab.webSocketDebuggerUrl);
  let r;
  try {
    r = await runExtract(session, 'fetch', { url, maxChars: Number(opts['max-chars']) || cfg.apiMaxChars });
  } catch (e) {
    return fail('API_REQUEST_FAILED', 'API 호출 중 오류가 발생했습니다.', e.message);
  } finally {
    session.close();
  }
  if (!isAllowedHost(cfg, r.pageUrl)) {
    return fail('SECURITY_BLOCK', '허용되지 않은 호스트의 화면에서는 API 를 호출할 수 없습니다.', null);
  }
  // 세션 만료 시 SSO 로그인 화면으로 리다이렉트되거나 401/403 이 온다
  if (r.redirected && (!isAllowedHost(cfg, r.finalUrl) || isLoginPage(cfg, r.finalUrl, ''))) {
    return fail('LOGIN_REQUIRED', 'SSO 세션이 만료된 것 같습니다. Edge 창에서 다시 로그인한 뒤 요청해 주세요.', null);
  }
  if (r.status === 401 || r.status === 403) {
    return fail('API_AUTH_FAILED', `API 접근 권한이 없거나 세션이 만료되었습니다(HTTP ${r.status}).`, null);
  }

  const data = { tab: tab.id, url, status: r.status, contentType: r.contentType, length: r.length, truncated: r.truncated };
  let parsed = false;
  if (!r.truncated) {
    try {
      data.json = JSON.parse(r.body);
      parsed = true;
    } catch (e) {
      /* JSON 이 아니면 텍스트로 반환 */
    }
  }
  if (!parsed) data.text = r.body;
  if (r.status >= 400) {
    return fail('API_HTTP_ERROR', `API 가 HTTP ${r.status} 를 반환했습니다.`, r.body.slice(0, 500));
  }
  const kind = parsed ? 'JSON' : r.truncated ? `텍스트(${r.length}자 중 일부)` : '텍스트';
  return ok(data, `API 호출 완료: HTTP ${r.status}, ${kind}`);
}

async function cmdRead(cfg, opts, mode) {
  const tab = await pickTab(cfg, typeof opts.tab === 'string' ? opts.tab : null);
  if (isLoginPage(cfg, tab.url, tab.title)) {
    return fail('LOGIN_REQUIRED', 'SSO 로그인이 필요합니다. Edge 창에서 SSO 로그인 버튼을 눌러 로그인한 뒤 다시 요청해 주세요.', null);
  }
  const extractOpts = { maxChars: Number(opts['max-chars']) || cfg.maxChars, maxRows: cfg.maxRows };
  if (mode === 'tables' && opts.index !== undefined) extractOpts.index = Number(opts.index);
  if (mode === 'links' && typeof opts.filter === 'string') extractOpts.filter = opts.filter;

  const session = await connect(tab.webSocketDebuggerUrl);
  let data;
  try {
    data = await runExtract(session, mode, extractOpts);
  } catch (e) {
    return fail('EXTRACT_FAILED', '화면 내용을 읽는 중 오류가 발생했습니다.', e.message);
  } finally {
    session.close();
  }
  // 읽는 사이 다른 호스트로 이동했을 수 있으므로 실제 문서 URL 을 다시 검사한다
  if (!isAllowedHost(cfg, data.url)) {
    return fail('SECURITY_BLOCK', '허용되지 않은 호스트의 화면은 읽을 수 없습니다.', null);
  }
  data.tab = tab.id;
  if (mode === 'links') {
    const before = data.links.length;
    data.links = data.links.filter((l) => isAllowedHost(cfg, l.href));
    data.excludedLinkCount = before - data.links.length;
    return ok(data, `링크 ${data.links.length}건 조회 완료`);
  }
  if (mode === 'tables') {
    return ok(data, `표 ${data.tableCount}개 조회 완료`);
  }
  return ok(data, `화면 텍스트 ${data.text.length}자 조회 완료${data.truncated ? '(일부 생략)' : ''}`);
}

function printUsage() {
  console.log(`
Kobi intranet-web CLI (사내 SSO 웹서비스 화면 읽기 전용 조회)

Usage:
  node intranet-web.cjs <command> [options]

Commands:
  open   [--url <URL>] [--wait] [--then <URL>]
                                      Kobi 전용 프로필로 Edge 를 열고(이미 열려 있으면 이동) 로그인 상태를 반환.
                                      --wait 이면 SSO 로그인 완료까지 기다린 뒤 --then(또는 afterLoginUrl) 페이지 내용 반환
  wait-login [--then <URL>] [--timeout 초]
                                      SSO 로그인 완료를 기다린 뒤 지정 페이지로 이동해 본문·표 반환
  status                              열린 탭과 로그인 상태(READY / LOGIN_REQUIRED / ...) 반환
  goto   --url <URL> [--tab <id>]     허용된 호스트의 주소로 이동
  read   [--tab <id>] [--max-chars N] 화면 본문 텍스트 반환
  tables [--tab <id>] [--index N]     화면의 표를 {headers, rows} JSON 으로 반환
  links  [--tab <id>] [--filter 텍스트] 화면의 링크(허용 호스트만) 반환
  api-get --url <URL|/상대경로> [--tab <id>] [--max-chars N]
                                      로그인 세션으로 같은 출처 API 를 GET 호출해 JSON 반환
  apis                                config.json 에 등록된 자주 쓰는 API 목록 반환

설정: ${CONFIG_PATH}
  `);
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('--help') || argv.includes('-h')) {
    printUsage();
    process.exit(0);
  }
  if (typeof WebSocket === 'undefined' || typeof fetch === 'undefined') {
    return fail('NODE_UNSUPPORTED', 'Node.js 22 이상이 필요합니다(내장 WebSocket/fetch 사용).', process.version);
  }

  const command = argv[0];
  const opts = parseArgs(argv.slice(1));
  const cfg = loadConfig();

  switch (command) {
    case 'open':
      return cmdOpen(cfg, opts);
    case 'status':
      return cmdStatus(cfg);
    case 'goto':
      return cmdGoto(cfg, opts);
    case 'read':
      return cmdRead(cfg, opts, 'text');
    case 'tables':
      return cmdRead(cfg, opts, 'tables');
    case 'links':
      return cmdRead(cfg, opts, 'links');
    case 'wait-login':
      return cmdWaitLogin(cfg, opts);
    case 'api-get':
      return cmdApiGet(cfg, opts);
    case 'apis':
      return ok({ apis: cfg.apis }, `등록된 API ${cfg.apis.length}건`);
    default:
      return fail('UNKNOWN_COMMAND', `알 수 없는 명령입니다: ${command}`, null);
  }
}

main().catch((e) => fail('UNEXPECTED_ERROR', '예상하지 못한 오류가 발생했습니다.', e.message));
