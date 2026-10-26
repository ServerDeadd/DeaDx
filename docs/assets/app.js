(function () {
  "use strict";

  var KEYWORDS = {
    and: 1, back: 0, "break": 1, "do": 1, "else": 1, elseif: 1, end: 1, "for": 1,
    "function": 1, "if": 1, "in": 1, local: 1, not: 1, or: 1, repeat: 1,
    "return": 1, then: 1, until: 1, "while": 1, "continue": 1, export: 1, type: 1
  };

  var LITERALS = { "true": 1, "false": 1, nil: 1, self: 1 };

  var LIBS = {
    game: 1, workspace: 1, script: 1, shared: 1, task: 1, math: 1, table: 1,
    string: 1, os: 1, coroutine: 1, debug: 1, utf8: 1, bit32: 1, buffer: 1,
    Instance: 1, Enum: 1, UDim: 1, UDim2: 1, Vector2: 1, Vector3: 1, Color3: 1,
    ColorSequence: 1, NumberSequence: 1, CFrame: 1, TweenInfo: 1, Rect: 1, Font: 1,
    print: 1, warn: 1, error: 1, assert: 1, pcall: 1, xpcall: 1, require: 1,
    tostring: 1, tonumber: 1, typeof: 1, next: 1, pairs: 1, ipairs: 1, select: 1,
    unpack: 1, setmetatable: 1, getmetatable: 1, rawget: 1, rawset: 1, loadstring: 1,
    getgenv: 1, gethui: 1, getcustomasset: 1, writefile: 1, readfile: 1, isfile: 1,
    isfolder: 1, makefolder: 1, delfile: 1, listfiles: 1, request: 1, syn: 1,
    identifyexecutor: 1, setclipboard: 1, cloneref: 1, hookfunction: 1, DeaDx: 1
  };

  var RE = new RegExp(
    "(--\\[\\[[\\s\\S]*?\\]\\]|--[^\\n]*)" +
    "|(\\[\\[[\\s\\S]*?\\]\\]|\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*')" +
    "|(0[xX][0-9a-fA-F]+|\\d+\\.?\\d*(?:[eE][+-]?\\d+)?)" +
    "|([A-Za-z_][A-Za-z0-9_]*)" +
    "|([+\\-*/%^#=~<>]+)",
    "g"
  );

  function esc(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function highlight(src) {
    var out = "";
    var last = 0;
    var match;
    RE.lastIndex = 0;
    while ((match = RE.exec(src)) !== null) {
      if (match.index > last) out += esc(src.slice(last, match.index));
      last = match.index + match[0].length;

      if (match[1]) {
        out += '<span class="tok-com">' + esc(match[1]) + "</span>";
      } else if (match[2]) {
        out += '<span class="tok-str">' + esc(match[2]) + "</span>";
      } else if (match[3]) {
        out += '<span class="tok-num">' + esc(match[3]) + "</span>";
      } else if (match[4]) {
        var word = match[4];
        var after = src.slice(last);
        var cls = null;
        if (KEYWORDS[word] === 1) cls = "tok-kw";
        else if (LITERALS[word] === 1) cls = "tok-bool";
        else if (LIBS[word] === 1) cls = "tok-lib";
        else if (/^\s*\(/.test(after) || /^\s*["'{]/.test(after)) cls = "tok-fn";
        out += cls ? '<span class="' + cls + '">' + esc(word) + "</span>" : esc(word);
      } else if (match[5]) {
        out += '<span class="tok-op">' + esc(match[5]) + "</span>";
      }
    }
    if (last < src.length) out += esc(src.slice(last));
    return out;
  }

  function paintCode() {
    var blocks = document.querySelectorAll("pre > code");
    for (var i = 0; i < blocks.length; i++) {
      var code = blocks[i];
      if (code.dataset.lit === "1") continue;
      var raw = code.textContent.replace(/^\n+/, "").replace(/\s+$/, "");
      if (code.dataset.lang === "text") {
        code.textContent = raw;
      } else {
        code.innerHTML = highlight(raw);
      }
      code.dataset.lit = "1";
    }
  }

  var COPY_ICON =
    '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';

  function addCopy() {
    var wraps = document.querySelectorAll(".code");
    for (var i = 0; i < wraps.length; i++) {
      (function (wrap) {
        if (wrap.querySelector(".copy")) return;
        var pre = wrap.querySelector("pre");
        if (!pre) return;
        var btn = document.createElement("button");
        btn.className = "copy";
        btn.type = "button";
        btn.innerHTML = COPY_ICON + "<span>copy</span>";
        btn.addEventListener("click", function () {
          var text = pre.innerText;
          var done = function () {
            btn.classList.add("done");
            btn.querySelector("span").textContent = "copied";
            setTimeout(function () {
              btn.classList.remove("done");
              btn.querySelector("span").textContent = "copy";
            }, 1400);
          };
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(done, function () {
              fallbackCopy(text);
              done();
            });
          } else {
            fallbackCopy(text);
            done();
          }
        });
        wrap.appendChild(btn);
      })(wraps[i]);
    }
  }

  function fallbackCopy(text) {
    var area = document.createElement("textarea");
    area.value = text;
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(area);
  }

  function revealOnScroll() {
    var items = document.querySelectorAll(".reveal");
    if (!("IntersectionObserver" in window)) {
      for (var i = 0; i < items.length; i++) items[i].classList.add("in");
      return;
    }
    var seen = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var el = entry.target;
        var delay = parseInt(el.dataset.delay || "0", 10);
        setTimeout(function () { el.classList.add("in"); }, delay);
        seen.unobserve(el);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.04 });
    for (var j = 0; j < items.length; j++) seen.observe(items[j]);
  }

  function stagger() {
    var groups = document.querySelectorAll("[data-stagger]");
    for (var i = 0; i < groups.length; i++) {
      var kids = groups[i].children;
      var step = parseInt(groups[i].dataset.stagger, 10) || 60;
      for (var j = 0; j < kids.length; j++) {
        kids[j].classList.add("reveal");
        kids[j].dataset.delay = String(j * step);
      }
    }
  }

  function anchors() {
    var heads = document.querySelectorAll(".content h2[id], .content h3[id]");
    for (var i = 0; i < heads.length; i++) {
      var h = heads[i];
      if (h.querySelector(".anchor")) continue;
      var a = document.createElement("a");
      a.className = "anchor";
      a.href = "#" + h.id;
      a.textContent = "#";
      a.setAttribute("aria-label", "link to this section");
      h.appendChild(a);
    }
  }

  function jumpLinks() {
    var links = document.querySelectorAll(".side-group a[href^='#'], .content a[href^='#'], .topnav a[href^='#']");
    for (var i = 0; i < links.length; i++) {
      links[i].addEventListener("click", function (event) {
        var id = this.getAttribute("href").slice(1);
        var target = document.getElementById(id);
        if (!target) return;
        event.preventDefault();
        var top = Math.max(target.getBoundingClientRect().top + window.scrollY - 92, 0);
        var far = Math.abs(top - window.scrollY) > 2400;
        var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        window.scrollTo({ top: top, behavior: far || reduced ? "auto" : "smooth" });
        if (history.replaceState) history.replaceState(null, "", "#" + id);
        else location.hash = id;
      });
    }
  }

  function landOnHash() {
    if (!location.hash || location.hash.length < 2) return;
    var target = document.getElementById(location.hash.slice(1));
    if (!target) return;
    var settle = function () {
      window.scrollTo({
        top: Math.max(target.getBoundingClientRect().top + window.scrollY - 92, 0),
        behavior: "auto"
      });
    };
    settle();
    setTimeout(settle, 60);
    window.addEventListener("load", function () { setTimeout(settle, 40); });
  }

  function scrollspy() {
    var links = Array.prototype.slice.call(document.querySelectorAll(".side-group a[href^='#']"));
    if (!links.length) return;
    var targets = links
      .map(function (link) {
        var el = document.getElementById(link.getAttribute("href").slice(1));
        return el ? { link: link, el: el } : null;
      })
      .filter(Boolean);
    if (!targets.length) return;

    var current = null;
    var queued = false;

    function sync() {
      queued = false;
      var line = window.scrollY + 120;
      var pick = targets[0];
      for (var i = 0; i < targets.length; i++) {
        if (targets[i].el.offsetTop <= line) pick = targets[i];
      }
      if (window.innerHeight + window.scrollY >= document.body.scrollHeight - 4) {
        pick = targets[targets.length - 1];
      }
      if (pick.link === current) return;
      if (current) current.classList.remove("active");
      pick.link.classList.add("active");
      current = pick.link;
    }

    window.addEventListener("scroll", function () {
      if (queued) return;
      queued = true;
      requestAnimationFrame(sync);
    }, { passive: true });

    window.addEventListener("resize", sync);
    sync();
  }

  function sideSearch() {
    var box = document.getElementById("side-filter");
    if (!box) return;
    var links = Array.prototype.slice.call(document.querySelectorAll(".side-group a"));
    var groups = Array.prototype.slice.call(document.querySelectorAll(".side-group"));
    box.addEventListener("input", function () {
      var q = box.value.trim().toLowerCase();
      links.forEach(function (link) {
        var hit = q === "" || link.textContent.toLowerCase().indexOf(q) !== -1;
        link.classList.toggle("hidden", !hit);
      });
      groups.forEach(function (group) {
        var any = group.querySelector("a:not(.hidden)");
        group.style.display = any ? "" : "none";
      });
    });
  }

  function mobileNav() {
    var btn = document.getElementById("menu-btn");
    var side = document.querySelector(".sidebar");
    if (!btn || !side) return;
    var scrim = document.createElement("div");
    scrim.className = "scrim";
    document.body.appendChild(scrim);

    function close() {
      side.classList.remove("open");
      scrim.classList.remove("show");
    }
    btn.addEventListener("click", function () {
      var open = side.classList.toggle("open");
      scrim.classList.toggle("show", open);
    });
    scrim.addEventListener("click", close);
    side.addEventListener("click", function (event) {
      if (event.target.tagName === "A") close();
    });
    window.addEventListener("keydown", function (event) {
      if (event.key === "Escape") close();
    });
  }

  function toTop() {
    var btn = document.createElement("button");
    btn.className = "to-top";
    btn.type = "button";
    btn.setAttribute("aria-label", "back to top");
    btn.innerHTML =
      '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m18 15-6-6-6 6"/></svg>';
    btn.addEventListener("click", function () {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
    document.body.appendChild(btn);
    var queued = false;
    window.addEventListener("scroll", function () {
      if (queued) return;
      queued = true;
      requestAnimationFrame(function () {
        queued = false;
        btn.classList.toggle("show", window.scrollY > 520);
      });
    }, { passive: true });
  }

  function countUp() {
    var nodes = document.querySelectorAll("[data-count]");
    if (!nodes.length || !("IntersectionObserver" in window)) return;
    var watcher = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var el = entry.target;
        watcher.unobserve(el);
        var target = parseFloat(el.dataset.count);
        var suffix = el.dataset.suffix || "";
        var started = null;
        var span = 900;
        function tick(now) {
          if (started === null) started = now;
          var pass = Math.min((now - started) / span, 1);
          var eased = 1 - Math.pow(1 - pass, 3);
          var value = target * eased;
          el.textContent = (target % 1 === 0 ? Math.round(value) : value.toFixed(1)) + suffix;
          if (pass < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
      });
    }, { threshold: 0.4 });
    for (var i = 0; i < nodes.length; i++) watcher.observe(nodes[i]);
  }

  function boot() {
    paintCode();
    addCopy();
    stagger();
    anchors();
    revealOnScroll();
    jumpLinks();
    landOnHash();
    scrollspy();
    sideSearch();
    mobileNav();
    toTop();
    countUp();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.DeaDxSite = { highlight: highlight, paint: paintCode, copy: addCopy, reveal: revealOnScroll };
})();
