/* imjaDNS speed test — client-side, powered by Cloudflare's public speed
   endpoints (speed.cloudflare.com). No backend; only throwaway test bytes
   leave the browser. Results are guidance, not guarantees. */
(function () {
  "use strict";

  var DOWN = "https://speed.cloudflare.com/__down?bytes=";
  var UP = "https://speed.cloudflare.com/__up";
  var META = "https://speed.cloudflare.com/meta";

  // ---- i18n -------------------------------------------------------------
  var I18N = {
    en: {
      title: "Test your connection",
      subtitle: "Measure your real-world speed, then see how it holds up for streaming, gaming, cameras and a full smart home.",
      ready: "Ready", pinging: "Pinging", downloading: "Download", uploading: "Upload", done: "Done",
      start: "Start test", testing: "Testing…", again: "Test again",
      download: "Download", upload: "Upload", ping: "Ping", jitter: "Jitter",
      smooth: "Smooth", tight: "Tight", struggles: "Struggles",
      metaPrefix: "Tested via Cloudflare",
      disclaimer: "Guidance, not a guarantee — real performance depends on your devices, Wi-Fi and the service. Only throwaway test data leaves your browser; imjaDNS stores nothing.",
      scenarios: {
        web: ["Web & social", "Browsing, chat, email"],
        hd: ["HD streaming", "1080p on one screen"],
        uhd: ["Netflix 4K", "Ultra-HD streaming"],
        iptv: ["IPTV", "Live TV over the internet"],
        gaming: ["Cloud gaming", "Latency-sensitive play"],
        cameras: ["Security cameras", "Uploading several feeds"],
        combo1: ["Movie night + gaming", "4K stream while someone games"],
        smarthome: ["Full smart home", "Many 4K screens, cameras & gaming"]
      }
    },
    el: {
      title: "Δοκιμάστε τη σύνδεσή σας",
      subtitle: "Μετρήστε την πραγματική σας ταχύτητα και δείτε πώς ανταποκρίνεται σε streaming, gaming, κάμερες και ένα πλήρες έξυπνο σπίτι.",
      ready: "Έτοιμο", pinging: "Ping", downloading: "Λήψη", uploading: "Αποστολή", done: "Έτοιμο",
      start: "Έναρξη δοκιμής", testing: "Δοκιμή…", again: "Δοκιμή ξανά",
      download: "Λήψη", upload: "Αποστολή", ping: "Ping", jitter: "Διακύμανση",
      smooth: "Ομαλά", tight: "Οριακά", struggles: "Δυσκολεύεται",
      metaPrefix: "Δοκιμή μέσω Cloudflare",
      disclaimer: "Καθοδήγηση, όχι εγγύηση — η πραγματική απόδοση εξαρτάται από τις συσκευές, το Wi-Fi και την υπηρεσία σας. Μόνο προσωρινά δεδομένα δοκιμής φεύγουν από τον browser· το imjaDNS δεν αποθηκεύει τίποτα.",
      scenarios: {
        web: ["Web & κοινωνικά", "Περιήγηση, chat, email"],
        hd: ["HD streaming", "1080p σε μία οθόνη"],
        uhd: ["Netflix 4K", "Streaming Ultra-HD"],
        iptv: ["IPTV", "Ζωντανή TV μέσω διαδικτύου"],
        gaming: ["Cloud gaming", "Παιχνίδι ευαίσθητο στην καθυστέρηση"],
        cameras: ["Κάμερες ασφαλείας", "Ανέβασμα πολλών ροών"],
        combo1: ["Ταινία + gaming", "4K streaming ενώ κάποιος παίζει"],
        smarthome: ["Πλήρες έξυπνο σπίτι", "Πολλές οθόνες 4K, κάμερες & gaming"]
      }
    },
    sq: {
      title: "Testo lidhjen tënde",
      subtitle: "Mat shpejtësinë tënde reale, pastaj shiko si përballon streaming, gaming, kamera dhe një shtëpi të mençur të plotë.",
      ready: "Gati", pinging: "Ping", downloading: "Shkarkim", uploading: "Ngarkim", done: "U krye",
      start: "Nis testin", testing: "Duke testuar…", again: "Testo sërish",
      download: "Shkarkim", upload: "Ngarkim", ping: "Ping", jitter: "Jitter",
      smooth: "Rrjedhshëm", tight: "Në kufi", struggles: "Vështirësi",
      metaPrefix: "Testuar përmes Cloudflare",
      disclaimer: "Udhëzim, jo garanci — performanca reale varet nga pajisjet, Wi-Fi dhe shërbimi yt. Vetëm të dhëna testimi të përkohshme dalin nga shfletuesi; imjaDNS nuk ruan asgjë.",
      scenarios: {
        web: ["Web & sociale", "Shfletim, chat, email"],
        hd: ["Streaming HD", "1080p në një ekran"],
        uhd: ["Netflix 4K", "Streaming Ultra-HD"],
        iptv: ["IPTV", "TV live përmes internetit"],
        gaming: ["Cloud gaming", "Lojë e ndjeshme ndaj vonesës"],
        cameras: ["Kamera sigurie", "Ngarkim i disa transmetimeve"],
        combo1: ["Mbrëmje filmi + gaming", "Streaming 4K ndërsa dikush luan"],
        smarthome: ["Shtëpi e mençur e plotë", "Shumë ekrane 4K, kamera & gaming"]
      }
    }
  };

  // rating: 2 = smooth, 1 = tight, 0 = struggles. (d,u,p,j) in Mbps/ms.
  var SCENARIOS = [
    { id: "web", icon: "🌐", rate: function (d) { return d >= 25 ? 2 : d >= 5 ? 1 : 0; } },
    { id: "hd", icon: "📺", rate: function (d) { return d >= 15 ? 2 : d >= 5 ? 1 : 0; } },
    { id: "uhd", icon: "🎬", rate: function (d) { return d >= 40 ? 2 : d >= 25 ? 1 : 0; } },
    { id: "iptv", icon: "📡", rate: function (d, u, p, j) { return (d >= 25 && j < 30) ? 2 : d >= 15 ? 1 : 0; } },
    { id: "gaming", icon: "🎮", rate: function (d, u, p) { return (p < 40 && d >= 25) ? 2 : (p < 80 && d >= 12) ? 1 : 0; } },
    { id: "cameras", icon: "📷", rate: function (d, u) { return u >= 10 ? 2 : u >= 4 ? 1 : 0; } },
    { id: "combo1", icon: "🍿", rate: function (d, u, p) { return (d >= 80 && p < 50) ? 2 : (d >= 45 && p < 80) ? 1 : 0; } },
    { id: "smarthome", icon: "🏠", rate: function (d, u) { return (d >= 150 && u >= 20) ? 2 : (d >= 80 && u >= 10) ? 1 : 0; } }
  ];

  function t() {
    var lang = (document.documentElement.lang || "en").slice(0, 2);
    return I18N[lang] || I18N.en;
  }

  // ---- measurement ------------------------------------------------------
  function now() { return performance.now(); }

  async function measurePing() {
    var lat = [];
    for (var i = 0; i < 20; i++) {
      var t0 = now();
      try { await fetch(DOWN + "0", { cache: "no-store" }); } catch (e) { continue; }
      var dt = now() - t0;
      if (i >= 3) lat.push(dt); // discard warmup
    }
    if (!lat.length) return { ping: 0, jitter: 0 };
    lat.sort(function (a, b) { return a - b; });
    var use = lat.slice(0, Math.max(1, lat.length - 2)); // drop worst 2
    var ping = use[Math.floor(use.length / 2)];
    var jit = 0;
    for (var k = 1; k < use.length; k++) jit += Math.abs(use[k] - use[k - 1]);
    jit = use.length > 1 ? jit / (use.length - 1) : 0;
    return { ping: ping, jitter: jit };
  }

  async function measureDownload(onProgress) {
    var CAP = 150e6, MAX = 10000, STREAMS = 4, CHUNK = 25e6, WARMUP = 800;
    var total = 0, winStart = null, winBytes = 0, start = now();
    var ctrl = new AbortController();

    function chunk(n) {
      total += n;
      var ts = now();
      if (winStart === null && ts - start > WARMUP) { winStart = ts; winBytes = 0; }
      else if (winStart !== null) { winBytes += n; }
      var live = winStart ? (winBytes * 8) / ((ts - winStart) / 1000) / 1e6
                          : (total * 8) / ((ts - start) / 1000) / 1e6;
      onProgress(live, Math.min(total / CAP, (ts - start) / MAX));
      if (total >= CAP || ts - start > MAX) ctrl.abort();
    }

    async function stream() {
      var res = await fetch(DOWN + CHUNK, { cache: "no-store", signal: ctrl.signal });
      var reader = res.body.getReader();
      while (true) {
        var r = await reader.read();
        if (r.done) break;
        chunk(r.value.length);
      }
    }
    async function worker() { try { while (!ctrl.signal.aborted) await stream(); } catch (e) {} }

    await Promise.all(Array.from({ length: STREAMS }, worker));
    var ts = now();
    return winStart ? (winBytes * 8) / ((ts - winStart) / 1000) / 1e6
                    : (total * 8) / ((ts - start) / 1000) / 1e6;
  }

  async function measureUpload(onProgress) {
    var CAP = 60e6, MAX = 8000, STREAMS = 3, CHUNK = 10e6, WARMUP = 500;
    var payload = new Uint8Array(CHUNK);
    var total = 0, winStart = null, winBytes = 0, start = now();
    var ctrl = new AbortController();

    async function one() {
      await fetch(UP, { method: "POST", body: payload, cache: "no-store", signal: ctrl.signal });
      total += CHUNK;
      var ts = now();
      if (winStart === null && ts - start > WARMUP) { winStart = ts; winBytes = 0; }
      else if (winStart !== null) { winBytes += CHUNK; }
      var live = winStart ? (winBytes * 8) / ((ts - winStart) / 1000) / 1e6
                          : (total * 8) / ((ts - start) / 1000) / 1e6;
      onProgress(live, Math.min(total / CAP, (ts - start) / MAX));
      if (total >= CAP || ts - start > MAX) ctrl.abort();
    }
    async function worker() { try { while (!ctrl.signal.aborted) await one(); } catch (e) {} }

    await Promise.all(Array.from({ length: STREAMS }, worker));
    var ts = now();
    return winStart ? (winBytes * 8) / ((ts - winStart) / 1000) / 1e6
                    : (total * 8) / ((ts - start) / 1000) / 1e6;
  }

  async function fetchMeta() {
    try {
      var res = await fetch(META, { cache: "no-store" });
      var j = await res.json();
      return j;
    } catch (e) { return null; }
  }

  // ---- UI ---------------------------------------------------------------
  var CIRC = 540.35; // 2·π·r, r = 86

  function fmt(n) { return n >= 100 ? String(Math.round(n)) : n >= 10 ? n.toFixed(1) : n.toFixed(2); }
  function ratingClass(r) { return r === 2 ? "smooth" : r === 1 ? "tight" : "struggles"; }
  // Map speed (Mbps) to a 0..1 gauge fill on a log scale (~1 at 1 Gbps).
  function speedToFrac(mbps) { return Math.max(0, Math.min(1, Math.log10(mbps + 1) / 3)); }

  document.addEventListener("DOMContentLoaded", function () {
    var L = t();
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var key = el.getAttribute("data-i18n");
      if (L[key]) el.textContent = L[key];
    });

    var startBtn = document.getElementById("startBtn");
    var live = document.getElementById("live");
    var gauge = document.getElementById("gauge");
    var gaugeFill = document.getElementById("gaugeFill");
    var meta = document.getElementById("meta");
    var steps = {
      ping: document.getElementById("step-ping"),
      download: document.getElementById("step-download"),
      upload: document.getElementById("step-upload")
    };
    var out = { down: document.getElementById("m-down"), up: document.getElementById("m-up"), ping: document.getElementById("m-ping"), jit: document.getElementById("m-jit") };
    var grid = document.getElementById("scenarios");

    SCENARIOS.forEach(function (s) {
      var names = L.scenarios[s.id];
      var card = document.createElement("div");
      card.className = "glass scenario";
      card.setAttribute("data-id", s.id);
      card.innerHTML =
        '<div class="sc-top"><span class="sc-ic">' + s.icon + '</span>' +
        '<span class="sc-status" data-status>–</span></div>' +
        '<div class="sc-name">' + names[0] + '</div>' +
        '<div class="sc-desc">' + names[1] + '</div>';
      grid.appendChild(card);
    });

    function setGauge(frac) { gaugeFill.style.strokeDashoffset = CIRC * (1 - Math.max(0, Math.min(1, frac))); }
    function setStep(name, state) {
      var el = steps[name]; if (!el) return;
      el.classList.remove("active", "done"); if (state) el.classList.add(state);
    }

    // Smooth live-number animation.
    var liveTarget = 0, liveCur = 0, liveRAF = null;
    function animate() { liveCur += (liveTarget - liveCur) * 0.18; live.textContent = fmt(liveCur); liveRAF = requestAnimationFrame(animate); }
    function startAnim() { if (!liveRAF) liveRAF = requestAnimationFrame(animate); }
    function stopAnim(finalVal) { if (liveRAF) { cancelAnimationFrame(liveRAF); liveRAF = null; } if (finalVal != null) { liveCur = finalVal; live.textContent = fmt(finalVal); } }

    function rate(d, u, p, j) {
      SCENARIOS.forEach(function (s) {
        var r = s.rate(d, u, p, j);
        var card = grid.querySelector('[data-id="' + s.id + '"]');
        var badge = card.querySelector("[data-status]");
        card.classList.remove("smooth", "tight", "struggles");
        card.classList.add(ratingClass(r));
        badge.textContent = r === 2 ? L.smooth : r === 1 ? L.tight : L.struggles;
      });
    }

    var running = false;
    async function run() {
      if (running) return;
      running = true;
      startBtn.disabled = true;
      startBtn.textContent = L.testing;
      gauge.classList.add("active");
      out.down.textContent = out.up.textContent = out.ping.textContent = out.jit.textContent = "–";
      setStep("ping", null); setStep("download", null); setStep("upload", null);
      liveCur = 0; liveTarget = 0; setGauge(0); startAnim();

      // ping
      setStep("ping", "active");
      var pj = await measurePing();
      out.ping.textContent = Math.round(pj.ping);
      out.jit.textContent = Math.round(pj.jitter);
      setStep("ping", "done");

      // download
      setStep("download", "active");
      var d = await measureDownload(function (mbps) { liveTarget = mbps; setGauge(speedToFrac(mbps)); });
      out.down.textContent = fmt(d);
      setStep("download", "done");

      // upload
      setStep("upload", "active");
      liveTarget = 0; liveCur = 0;
      var u = await measureUpload(function (mbps) { liveTarget = mbps; setGauge(speedToFrac(mbps)); });
      out.up.textContent = fmt(u);
      setStep("upload", "done");

      // results
      rate(d, u, pj.ping, pj.jitter);
      liveTarget = d; setGauge(speedToFrac(d));
      setTimeout(function () { stopAnim(d); }, 600);
      gauge.classList.remove("active");
      startBtn.disabled = false;
      startBtn.textContent = L.again;
      running = false;

      fetchMeta().then(function (m) {
        if (!m) return;
        var city = typeof m.city === "string" ? m.city : "";
        var colo = typeof m.colo === "string" ? m.colo : "";
        var where = city + (colo ? " (" + colo + ")" : "");
        if (where) meta.textContent = L.metaPrefix + " · " + where;
        else meta.textContent = L.metaPrefix;
      });
    }

    startBtn.addEventListener("click", run);
  });
})();
