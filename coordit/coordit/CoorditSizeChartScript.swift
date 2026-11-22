import Foundation

/// 상품 페이지에서 사이즈표를 뽑아내는 결과.
struct CoorditWebSizeChart: Equatable, Sendable {
    struct Row: Equatable, Sendable {
        let sizeLabel: String
        let measurements: [CoorditFitLabMeasurementKey: Double]
    }

    let productName: String?
    let brand: String?
    let mallName: String?
    let productURL: URL?
    let rawHeaders: [String]
    let rows: [Row]
    /// 표가 이미지로만 있는 경우 true. 화면 캡처를 Vision OCR로 넘겨야 한다.
    let requiresVisionOCR: Bool
    let sizeChartImageURL: URL?
}

enum CoorditWebSizeChartErrorKind: String, Sendable {
    case sizeTableNotFound
    case loadFailed
    case timedOut
    case blocked
}

struct CoorditWebSizeChartError: Error, Equatable, Sendable {
    let kind: CoorditWebSizeChartErrorKind
    let message: String

    var isRetryable: Bool { kind == .sizeTableNotFound }
}

/// 페이지에 주입되는 추출 스크립트.
///
/// 서버 크롤러(`size-chart-parser` / `product-navigation`)가 하던 일을
/// 웹뷰 안에서 그대로 재현한다. 사이즈 탭이 닫혀 있으면 눌러서 열고,
/// 표가 이미지면 그 사실을 알려 OCR 단계로 넘긴다.
enum CoorditSizeChartScript {
    static let messageHandlerName = "coorditSizeChart"

    /// 페이지 로드 후 한 번 더 밀어줄 때 쓰는 호출문.
    static let retryInvocation = "window.__coorditExtractSizeChart && window.__coorditExtractSizeChart(true);"

    static let source = #"""
(function () {
  if (window.__coorditSizeChartInstalled) { return; }
  window.__coorditSizeChartInstalled = true;
  var hasSent = false;

  function post(payload) {
    try {
      window.webkit.messageHandlers.coorditSizeChart.postMessage(payload);
    } catch (error) { /* handler missing: nothing we can do here */ }
  }

  function norm(text) {
    return String(text == null ? "" : text).replace(/\s+/g, " ").trim();
  }

  // 측정 항목 한글/영문 라벨 -> Coordit 키
  var KEYS = [
    ["shoulder_width", ["어깨", "어깨너비", "어깨단면", "shoulder"]],
    ["chest_width", ["가슴", "가슴단면", "흉상", "흉위", "chest", "bust"]],
    ["total_length", ["총장", "총 길이", "총기장", "body length", "기장"]],
    ["sleeve_length", ["소매", "소매길이", "팔길이", "sleeve"]],
    ["waist_width", ["허리", "허리단면", "waist"]],
    ["hip_width", ["엉덩이", "힙", "hip"]],
    ["rise", ["밑위", "밑아래", "rise"]],
    ["outseam", ["아웃심", "밑기장", "인심", "outseam", "inseam"]]
    // "밑단단면"은 밑단 둘레로 아웃심과 다른 항목이라 매핑하지 않는다.
  ];

  function keyFor(header) {
    var text = norm(header).toLowerCase();
    if (!text) { return null; }
    // "전체소매길이"/"소매길이"가 "길이" 계열 총장으로 새지 않도록 소매를 먼저 판정한다.
    // 소매 폭 계열(소매단면·소매통·소매부리)은 소매 길이가 아니다.
    if (/소매\s*(단면|통|밑단|부리)|sleeve\s*(width|opening)/.test(text)) { return null; }
    if (/소매|sleeve/.test(text)) { return "sleeve_length"; }
    for (var i = 0; i < KEYS.length; i += 1) {
      var names = KEYS[i][1];
      for (var j = 0; j < names.length; j += 1) {
        if (text.indexOf(names[j].toLowerCase()) !== -1) { return KEYS[i][0]; }
      }
    }
    return null;
  }

  function cellsOf(row) {
    return Array.prototype.slice.call(row.querySelectorAll("th, td"));
  }

  // 단위가 cm가 아닌 표는 여기서 걸러낸다(인치 표기는 오차가 커진다).
  function unitIsCm(table) {
    var text = norm(table.textContent || "");
    if (/\(inch\)|인치|\bin\b/i.test(text)) { return false; }
    return true;
  }

  function looksLikeSizeLabel(text) {
    if (!text) { return false; }
    // S/M/L, FREE 같은 토큰.
    if (/^(free|one size|f|xs|s|m|l|xl|xxl|xxxl|2xl|3xl)$/i.test(text)) { return true; }
    // 지그재그식 "S(090)", "XL(105)" 표기.
    if (/^(xxs|xs|s|m|l|xl|xxl|xxxl|2xl|3xl)\s*[（(]\s*\d{2,3}\s*[)）]$/i.test(text)) { return true; }
    // "95", "100" 같은 숫자 사이즈(소수점 없음).
    if (/^\d{2,3}$/.test(text)) { return true; }
    // "S/M", "F(프리)" 같은 변형.
    if (/^(free|one size)\s*[（(][^)）]*[)）]$/i.test(text)) { return true; }
    return false;
  }

  function isMeasurementCell(text) {
    return /^-?\d+(\.\d+)?$/.test(norm(text));
  }

  // 표에 사이즈 라벨 열이 없는 경우(단일 사이즈 상품)를 감지한다.
  function tableHasLabelColumn(rows, headerKeys) {
    for (var r = 0; r < rows.length; r += 1) {
      var cells = cellsOf(rows[r]).map(function (cell) { return norm(cell.textContent); });
      for (var i = 0; i < cells.length; i += 1) {
        if (!headerKeys[i] && looksLikeSizeLabel(cells[i]) && !isMeasurementCell(cells[i])) { return true; }
        if (!headerKeys[i] && /^(free|one size)$/i.test(cells[i])) { return true; }
      }
    }
    return false;
  }

  function parseTable(table) {
    if (!unitIsCm(table)) { return null; }
    var rows = Array.prototype.slice.call(table.querySelectorAll("tr"));
    if (rows.length < 2) { return null; }

    var headerCells = cellsOf(rows[0]).map(function (cell) { return norm(cell.textContent); });
    var headerKeys = headerCells.map(keyFor);
    var matched = headerKeys.filter(Boolean).length;
    if (matched === 0 && rows.length > 1) {
      // 헤더가 첫 행이 아닐 수 있어 다른 행으로 재시도한다.
      for (var r = 1; r < Math.min(rows.length, 3); r += 1) {
        var altKeys = cellsOf(rows[r]).map(function (cell) { return keyFor(norm(cell.textContent)); });
        if (altKeys.filter(Boolean).length > matched) {
          headerCells = cellsOf(rows[r]).map(function (cell) { return norm(cell.textContent); });
          headerKeys = altKeys;
          rows = rows.slice(r + 1);
          matched = headerKeys.filter(Boolean).length;
          break;
        }
      }
    }
    if (matched === 0) { return null; }

    var hasLabelColumn = tableHasLabelColumn(rows.slice(1), headerKeys);
    // 사이즈 라벨 열이 없으면 각 행은 별도 사이즈가 아니라
    // 한 상품의 측정값 나열일 수 있다. 이 경우 행마다 라벨을 붙이지 않고
    // 첫 행만 쓰거나(단일) 라벨을 비워 두고 상위에서 판단한다.
    var rowsWithoutLabel = !hasLabelColumn;
    var out = [];
    rows.forEach(function (row) {
      var cells = cellsOf(row).map(function (cell) { return norm(cell.textContent); });
      if (!cells.length) { return; }
      // 헤더 행 자체(예: "1총장 2어깨너비 ...")는 데이터가 아니다.
      var headerLike = cells.filter(function (text) { return keyFor(text); }).length;
      if (headerLike >= 2) { return; }
      var measurements = {};
      var filled = 0;
      var label = null;
      cells.forEach(function (text, index) {
        var key = headerKeys[index];
        if (!key) {
          // 헤더 없는 다른 열은 사이즈 라벨 후보. 측정값 형태면 라벨이 아니다.
          if (!isMeasurementCell(text) && looksLikeSizeLabel(text)) { label = text; }
          return;
        }
        var value = parseFloat(String(text).replace(/[^0-9.]/g, ""));
        if (isFinite(value) && value > 0) {
          measurements[key] = value;
          filled += 1;
        }
      });
      // 라벨만 있고 값이 빈 "내 사이즈" 도우미 행은 버린다.
      if (filled === 0) { return; }
      // 라벨이 없으면 이 표는 사이즈별 실측표가 아니다(단일 상품 측정 나열).
      // 첫 행만 채택하고 나머지는 버린다. 잘못된 라벨을 지어내지 않는다.
      if (!label && rowsWithoutLabel && out.length > 0) { return; }
      var sizeLabel = label || (rowsWithoutLabel ? "FREE" : null);
      if (!sizeLabel) { return; }
      out.push({ sizeLabel: sizeLabel, measurements: measurements });
    });

    if (!out.length) { return null; }
    return { rawHeaders: headerCells, rows: out };
  }

  function findSizeTable() {
    var tables = Array.prototype.slice.call(document.querySelectorAll("table"));
    var best = null;
    tables.forEach(function (table) {
      var parsed = parseTable(table);
      if (!parsed) { return; }
      if (!best || parsed.rows.length > best.rows.length) { best = parsed; }
    });
    return best;
  }

  // 사이즈 탭이 닫혀 있으면 연다. 서버 크롤러와 달리 "사이즈"라는 글자를 우선한다.
  function openSizeTab() {
    var candidates = Array.prototype.slice.call(
      document.querySelectorAll("button, [role='tab'], [role='button'], a")
    );
    var target = null;
    candidates.forEach(function (element) {
      if (target) { return; }
      var text = norm(element.textContent).toLowerCase();
      if (/^사이즈$|사이즈\s*정보|^size$|size\s*guide|실측/.test(text)) { target = element; }
    });
    if (target) {
      try { target.click(); } catch (error) { /* ignore */ }
    }
    return Boolean(target);
  }

  function findSizeChartImage() {
    var images = Array.prototype.slice.call(document.querySelectorAll("img"));
    for (var i = 0; i < images.length; i += 1) {
      var image = images[i];
      var hint = norm((image.getAttribute("alt") || "") + " " + (image.getAttribute("src") || "")).toLowerCase();
      if (/size|사이즈|실측/.test(hint) && image.naturalWidth > 200) {
        return image.currentSrc || image.src || null;
      }
    }
    return null;
  }

  function metaContent(selector) {
    var element = document.querySelector(selector);
    return element ? norm(element.getAttribute("content") || "") : "";
  }

  // 상품명과 브랜드를 가른다.
  // h1은 사이트 로고인 경우가 있어(무신사 모바일) og:title을 기준으로 삼는다.
  function productInfo() {
    var heading = document.querySelector("h1");
    var headingText = heading ? norm(heading.textContent) : "";
    var raw = metaContent('meta[property="og:title"]') || norm(document.title) || headingText;
    // "상품명 - 부가설명 | 사이트" 형태에서 상품명만 남긴다.
    var cleaned = norm(norm(raw.split("|")[0]).split(" - ")[0]);
    if (!cleaned) { return { name: headingText, brand: null }; }
    // 지그재그: 제목이 "브랜드 + h1 상품명"이다.
    if (headingText && cleaned.length > headingText.length &&
        cleaned.slice(-headingText.length) === headingText) {
      return { name: headingText, brand: norm(cleaned.slice(0, -headingText.length)) || null };
    }
    // 무신사: "브랜드(TENBLADE) 상품명"
    var paren = cleaned.match(/^(.+?\s*\([^)]+\))\s+(.+)$/);
    if (paren) { return { name: paren[2], brand: paren[1] }; }
    // 그 외에는 브랜드를 추측하지 않는다. 상품명 첫 단어를 쓰면 틀리는 경우가 더 많다.
    return { name: cleaned, brand: null };
  }

  var retryCount = 0;
  var tabOpened = false;

  window.__coorditExtractSizeChart = function (isRetry) {
    if (hasSent) { return; }
    if (isRetry) { retryCount += 1; }
    var found = findSizeTable();
    // 탭은 한 번만 연다. 다시 누르면 닫히는 사이트가 있다.
    if (!found && !tabOpened) { tabOpened = openSizeTab(); }

    // 표가 늦게 그려지는 페이지에서 성급히 이미지로 넘어가지 않도록 몇 번 기다린다.
    var chartImage = (!found && retryCount >= 3) ? findSizeChartImage() : null;
    if (!found && !chartImage) {
      // 확정 실패가 아니다. 네이티브 쪽이 타임아웃까지 다시 부른다.
      if (isRetry) { post({ ok: false, kind: "sizeTableNotFound", message: "사이즈표를 찾지 못했어요." }); }
      return;
    }

    hasSent = true;
    var info = productInfo();
    post({
      ok: true,
      productName: info.name,
      brand: info.brand,
      mallName: document.querySelector('meta[property="og:site_name"]') ? metaContent('meta[property="og:site_name"]') : location.hostname,
      productURL: location.href,
      rawHeaders: found ? found.rawHeaders : [],
      rows: found ? found.rows : [],
      requiresVisionOCR: !found,
      sizeChartImageURL: chartImage
    });
  };

  window.__coorditExtractSizeChart(false);
})();
"""#
}

/// 웹뷰가 넘긴 JSON을 Swift 타입으로 변환한다.
extension CoorditSizeChartScript {
    static func decode(_ body: Any) -> Result<CoorditWebSizeChart, CoorditWebSizeChartError>? {
        guard let data = try? JSONSerialization.data(withJSONObject: body),
              let payload = try? JSONDecoder().decode(CoorditSizeChartScriptDecoder.Payload.self, from: data) else {
            return nil
        }
        if payload.ok == false {
            let kind = CoorditWebSizeChartErrorKind(rawValue: payload.kind ?? "") ?? .sizeTableNotFound
            return .failure(.init(kind: kind, message: payload.message ?? "사이즈표를 찾지 못했어요."))
        }
        let rows = (payload.rows ?? []).compactMap { row -> CoorditWebSizeChart.Row? in
            var measurements: [CoorditFitLabMeasurementKey: Double] = [:]
            for (rawKey, value) in row.measurements {
                if let key = CoorditFitLabMeasurementKey(rawValue: rawKey) { measurements[key] = value }
            }
            guard !measurements.isEmpty else { return nil }
            return .init(sizeLabel: row.sizeLabel, measurements: measurements)
        }
        if rows.isEmpty && payload.requiresVisionOCR != true {
            return .failure(.init(kind: .sizeTableNotFound, message: "사이즈표를 읽지 못했어요."))
        }
        return .success(.init(
            productName: payload.productName,
            brand: payload.brand,
            mallName: payload.mallName,
            productURL: payload.productURL.flatMap(URL.init(string:)),
            rawHeaders: payload.rawHeaders ?? [],
            rows: rows,
            requiresVisionOCR: payload.requiresVisionOCR ?? false,
            sizeChartImageURL: payload.sizeChartImageURL.flatMap(URL.init(string:))
        ))
    }
}

enum CoorditSizeChartScriptDecoder {
    struct Payload: Decodable {
        struct Row: Decodable {
            let sizeLabel: String
            let measurements: [String: Double]
        }

        let ok: Bool
        let kind: String?
        let message: String?
        let productName: String?
        let brand: String?
        let mallName: String?
        let productURL: String?
        let rawHeaders: [String]?
        let rows: [Row]?
        let requiresVisionOCR: Bool?
        let sizeChartImageURL: String?
    }
}
