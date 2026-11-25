// Kobi intranet-web skill — 페이지 내부에서 실행되는 고정 추출 스크립트.
// intranet-web.cjs 가 CDP Runtime.evaluate 로 이 함수 하나만 실행하며, 인자(mode/opts)는 JSON 으로만 전달된다.
// DOM 을 읽기만 하고 클릭/입력/폼 제출/쿠키 접근은 하지 않는다.
// 레거시 사내 화면은 frameset/iframe 구성이 많으므로 같은 출처(same-origin) 프레임까지 재귀 탐색한다.
(function (mode, opts) {
  'use strict';
  opts = opts || {};

  function clean(s) {
    return String(s || '')
      .replace(/ /g, ' ')
      .replace(/[ \t]+/g, ' ')
      .replace(/ *\n */g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  // 최상위 문서 + 접근 가능한 하위 프레임 문서 목록 (cross-origin 프레임은 건너뜀)
  function collectDocs(doc, label, out, depth) {
    out.push({ doc: doc, frame: label });
    if (depth > 5) return out;
    var frames = doc.querySelectorAll('frame, iframe');
    for (var i = 0; i < frames.length; i++) {
      var f = frames[i];
      try {
        var d = f.contentDocument;
        if (d && d.body) collectDocs(d, (label ? label + ' > ' : '') + (f.name || f.id || 'frame' + i), out, depth + 1);
      } catch (e) {
        /* cross-origin: 접근 불가 */
      }
    }
    return out;
  }

  var docs = collectDocs(document, '', [], 0);
  var base = { url: location.href, title: document.title, frameCount: docs.length - 1 };

  if (mode === 'status') {
    return base;
  }

  if (mode === 'text') {
    var parts = [];
    docs.forEach(function (d) {
      if (!d.doc.body) return;
      var t = clean(d.doc.body.innerText);
      if (t) parts.push(d.frame ? '[프레임: ' + d.frame + ']\n' + t : t);
    });
    var text = parts.join('\n\n');
    var max = opts.maxChars || 20000;
    base.length = text.length;
    base.truncated = text.length > max;
    base.text = base.truncated ? text.slice(0, max) : text;
    return base;
  }

  if (mode === 'tables') {
    var tables = [];
    docs.forEach(function (d) {
      var list = d.doc.querySelectorAll('table');
      for (var i = 0; i < list.length; i++) {
        var tbl = list[i];
        // 표 안에 표가 중첩된 레이아웃용 바깥 표는 건너뛰고 실제 데이터 표(가장 안쪽)만 취한다
        if (tbl.querySelector('table')) continue;
        var rows = [];
        var headers = null;
        var trs = tbl.rows;
        for (var r = 0; r < trs.length; r++) {
          var cells = [];
          var allTh = trs[r].cells.length > 0;
          for (var c = 0; c < trs[r].cells.length; c++) {
            var cell = trs[r].cells[c];
            if (cell.tagName !== 'TH') allTh = false;
            cells.push(clean(cell.innerText));
          }
          if (headers === null && rows.length === 0 && allTh) headers = cells;
          else rows.push(cells);
        }
        if (rows.length === 0 && !headers) continue;
        var cap = tbl.caption ? clean(tbl.caption.innerText) : null;
        tables.push({ frame: d.frame || null, caption: cap, headers: headers, rows: rows });
      }
    });
    tables.forEach(function (t, i) { t.index = i; });
    var maxRows = opts.maxRows || 200;
    if (typeof opts.index === 'number') {
      var one = tables[opts.index];
      base.tableCount = tables.length;
      base.table = one || null;
      return base;
    }
    base.tableCount = tables.length;
    base.tables = tables.map(function (t) {
      var copy = { index: t.index, frame: t.frame, caption: t.caption, headers: t.headers, rowCount: t.rows.length };
      copy.truncated = t.rows.length > maxRows;
      copy.rows = copy.truncated ? t.rows.slice(0, maxRows) : t.rows;
      return copy;
    });
    return base;
  }

  if (mode === 'links') {
    var seen = {};
    var links = [];
    var filter = opts.filter ? String(opts.filter).toLowerCase() : null;
    docs.forEach(function (d) {
      var as = d.doc.querySelectorAll('a[href]');
      for (var i = 0; i < as.length; i++) {
        var href = as[i].href;
        var text = clean(as[i].innerText || as[i].title || '');
        if (filter && text.toLowerCase().indexOf(filter) < 0 && href.toLowerCase().indexOf(filter) < 0) continue;
        var key = text + '|' + href;
        if (seen[key]) continue;
        seen[key] = true;
        links.push({ text: text, href: href, frame: d.frame || null });
      }
    });
    base.links = links;
    return base;
  }

  // 로그인된 세션(쿠키)으로 같은 출처의 API 를 GET 호출한다. 메서드는 GET 으로 고정되며 본문 전송 경로는 없다.
  // 레거시 API 가 EUC-KR 로 응답할 수 있으므로 Content-Type 의 charset 으로 직접 디코딩한다.
  if (mode === 'fetch') {
    return fetch(opts.url, {
      method: 'GET',
      credentials: 'include',
      redirect: 'follow',
      headers: { Accept: 'application/json, text/plain, */*', 'X-Requested-With': 'XMLHttpRequest' },
    }).then(function (res) {
      var ct = res.headers.get('content-type') || '';
      var m = /charset=([^;]+)/i.exec(ct);
      return res.arrayBuffer().then(function (buf) {
        var text;
        try {
          text = new TextDecoder(m ? m[1].trim() : 'utf-8').decode(buf);
        } catch (e) {
          text = new TextDecoder('utf-8').decode(buf);
        }
        var max = opts.maxChars || 100000;
        return {
          pageUrl: location.href,
          status: res.status,
          finalUrl: res.url,
          redirected: res.redirected,
          contentType: ct,
          length: text.length,
          truncated: text.length > max,
          body: text.length > max ? text.slice(0, max) : text,
        };
      });
    });
  }

  return { error: 'unknown mode: ' + mode };
})
