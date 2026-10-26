(function () {
  "use strict";

  var CDN = "https://unpkg.com/lucide-static@0.544.0/icons/";
  var PAGE = 320;

  var grid = document.getElementById("icon-grid");
  var search = document.getElementById("icon-filter");
  var counter = document.getElementById("icon-count");
  var more = document.getElementById("icon-more");
  var modes = document.getElementById("icon-modes");
  if (!grid) return;

  var all = [];
  var raw = window.DEADX_ICONS || "";
  raw.split(";").forEach(function (pair) {
    var cut = pair.indexOf("=");
    if (cut <= 0) return;
    all.push({ name: pair.slice(0, cut), id: pair.slice(cut + 1) });
  });

  var view = all;
  var shown = 0;
  var mode = "name";

  function payload(icon) {
    if (mode === "asset") return "rbxassetid://" + icon.id;
    if (mode === "lua") return 'Icon = "' + icon.name + '",';
    return icon.name;
  }

  function flash(tile, label) {
    var text = tile.querySelector("span");
    var was = text.textContent;
    tile.classList.add("copied");
    text.textContent = label;
    setTimeout(function () {
      tile.classList.remove("copied");
      text.textContent = was;
    }, 1100);
  }

  function copy(text, tile) {
    var done = function () { flash(tile, "copied"); };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () {
        legacy(text);
        done();
      });
    } else {
      legacy(text);
      done();
    }
  }

  function legacy(text) {
    var area = document.createElement("textarea");
    area.value = text;
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(area);
  }

  function tile(icon, index) {
    var node = document.createElement("button");
    node.type = "button";
    node.className = "icon-tile";
    node.title = icon.name + "  ·  rbxassetid://" + icon.id;
    node.style.animationDelay = Math.min(index, 26) * 11 + "ms";

    var img = document.createElement("img");
    img.loading = "lazy";
    img.decoding = "async";
    img.alt = "";
    img.src = CDN + icon.name + ".svg";
    img.addEventListener("error", function () {
      img.style.visibility = "hidden";
    });

    var label = document.createElement("span");
    label.textContent = icon.name;

    node.appendChild(img);
    node.appendChild(label);
    node.addEventListener("click", function () {
      copy(payload(icon), node);
    });
    return node;
  }

  function paint(reset) {
    if (reset) {
      grid.innerHTML = "";
      shown = 0;
    }
    var slice = view.slice(shown, shown + PAGE);
    var batch = document.createDocumentFragment();
    for (var i = 0; i < slice.length; i++) batch.appendChild(tile(slice[i], i));
    grid.appendChild(batch);
    shown += slice.length;
    if (more) {
      more.style.display = shown < view.length ? "" : "none";
      var left = view.length - shown;
      var btn = more.querySelector("button");
      if (btn) btn.textContent = "Show " + Math.min(left, PAGE) + " more";
    }
    if (counter) {
      counter.textContent = view.length === all.length
        ? all.length + " icons"
        : view.length + " of " + all.length;
    }
  }

  function filter() {
    var q = (search ? search.value : "").trim().toLowerCase().replace(/\s+/g, "-");
    view = q === "" ? all : all.filter(function (icon) {
      return icon.name.indexOf(q) !== -1 || icon.id.indexOf(q) === 0;
    });
    paint(true);
  }

  if (search) {
    var wait;
    search.addEventListener("input", function () {
      clearTimeout(wait);
      wait = setTimeout(filter, 130);
    });
  }

  if (more) {
    var btn = more.querySelector("button");
    if (btn) btn.addEventListener("click", function () { paint(false); });
  }

  if (modes) {
    modes.addEventListener("click", function (event) {
      var hit = event.target.closest("[data-mode]");
      if (!hit) return;
      mode = hit.dataset.mode;
      var all = modes.querySelectorAll("[data-mode]");
      for (var i = 0; i < all.length; i++) all[i].classList.toggle("on", all[i] === hit);
    });
  }

  paint(true);
})();
