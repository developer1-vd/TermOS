// TermOS site: digital rain behind the header, and a small easter egg.
(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Draw falling 0/1 rain on a canvas. Returns a function that stops it.
  function rain(canvas, opts) {
    var ctx = canvas.getContext("2d");
    var size = opts.size || 16;
    var cols = [], w = 0, h = 0, running = true, last = 0;

    function resize() {
      var ratio = window.devicePixelRatio || 1;
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = w * ratio; canvas.height = h * ratio;
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      cols = [];
      for (var i = 0; i < Math.ceil(w / size); i++) cols.push(Math.random() * -h / size);
      ctx.fillStyle = "#000"; ctx.fillRect(0, 0, w, h);
    }

    function frame(t) {
      if (!running) return;
      if (t - last > (opts.interval || 60)) {
        last = t;
        // Fade what's there, so each column leaves a trail.
        ctx.fillStyle = "rgba(0, 0, 0, " + (opts.fade || 0.08) + ")";
        ctx.fillRect(0, 0, w, h);
        ctx.font = "bold " + size + "px ui-monospace, monospace";
        for (var i = 0; i < cols.length; i++) {
          var y = cols[i] * size;
          ctx.fillStyle = Math.random() < 0.1 ? "#d8ffe3" : "#00ff66";
          ctx.fillText(Math.random() < 0.5 ? "0" : "1", i * size, y);
          cols[i] = y > h && Math.random() > 0.975 ? 0 : cols[i] + 1;
        }
      }
      requestAnimationFrame(frame);
    }

    resize();
    window.addEventListener("resize", resize);
    requestAnimationFrame(frame);
    return function stop() { running = false; window.removeEventListener("resize", resize); };
  }

  // Header rain (skipped when the visitor prefers reduced motion).
  var hero = document.getElementById("hero-rain");
  if (hero && !reduceMotion) rain(hero, { size: 16, interval: 70, fade: 0.1 });

  // Easter egg: type "rabbit" anywhere (or click the footer hint).
  var overlay = document.getElementById("rabbit");
  var text = document.getElementById("rabbit-text");
  var stopRain = null, timers = [];
  var lines = ["Wake up, Neo...", "The Matrix has you...", "Follow the white rabbit.", "Knock, knock."];

  function open() {
    if (overlay.classList.contains("on")) return;
    overlay.classList.add("on");
    overlay.setAttribute("aria-hidden", "false");
    if (!reduceMotion) stopRain = rain(overlay.querySelector("canvas"), { size: 18, interval: 45, fade: 0.06 });
    lines.forEach(function (line, i) {
      timers.push(setTimeout(function () { text.textContent = line; }, i * 2200));
    });
  }
  function close() {
    overlay.classList.remove("on");
    overlay.setAttribute("aria-hidden", "true");
    if (stopRain) stopRain();
    stopRain = null;
    timers.forEach(clearTimeout); timers = [];
    text.textContent = "";
  }

  var typed = "";
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") { close(); return; }
    if (e.key.length !== 1) return;
    typed = (typed + e.key.toLowerCase()).slice(-6);
    if (typed === "rabbit") open();
  });
  overlay.addEventListener("click", close);
  var hint = document.querySelector(".hint");
  if (hint) hint.addEventListener("click", open);
})();
