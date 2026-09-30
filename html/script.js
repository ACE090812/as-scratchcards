(function () {
  'use strict';

  // This file never shows #app on its own. The ONLY thing that removes the 'hidden' class is the
  // 'open' NUI message below - there is no default/idle mode, no query-string branch, nothing that
  // runs on load besides wiring up listeners. That's deliberate: as-betting's ui_page used to
  // default itself visible when no query string was present, which rendered it full-screen for
  // every player from the moment the resource started. This page starts, and stays, inert until
  // told otherwise.

  function resourceName() {
    return (window.GetParentResourceName && GetParentResourceName()) || 'as-scratchcard';
  }

  function nuiPost(name, body) {
    return fetch('https://' + resourceName() + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {}),
    }).then(function (r) { return r.json().catch(function () { return null; }); });
  }

  var els = {
    app: document.getElementById('app'),
    card: document.getElementById('card'),
    cardStrap: document.getElementById('card-strap'),
    cardTitle: document.getElementById('card-title'),
    cardPrice: document.getElementById('card-price'),
    cardTop: document.getElementById('card-top'),
    game1Area: document.getElementById('game1-area'),
    game1Label: document.getElementById('game1-label'),
    cardRules: document.getElementById('card-rules'),
    bonusGrid: document.getElementById('bonus-grid'),
    bonusResult: document.getElementById('bonus-result'),
    chancesRibbon: document.getElementById('chances-ribbon'),
    resultBar: document.getElementById('result-bar'),
    revealBtn: document.getElementById('reveal-btn'),
    closeBtn: document.getElementById('close-btn'),
    coin: document.getElementById('scratch-coin'),
  };

  var state = null; // built fresh every time an 'open' message arrives
  var scratchSoundEnabled = true;

  function fmt(tier, n) { return tier.symbol + Number(n || 0).toLocaleString('en-GB'); }

  // ---- Scratch coin: follows the cursor while a drag is active, like scratching with a real coin.
  var coinWobble = 0;
  function coinShow(clientX, clientY) {
    document.body.classList.add('coin-active');
    els.coin.classList.remove('hidden');
    coinMove(clientX, clientY);
  }
  function coinMove(clientX, clientY) {
    els.coin.style.left = clientX + 'px';
    els.coin.style.top = clientY + 'px';
    // A little wobble so it feels dragged, not glued flat to the cursor.
    coinWobble = (coinWobble + 7) % 360;
    var tilt = -18 + Math.sin(coinWobble * Math.PI / 180) * 10;
    els.coin.style.transform = 'translate(-50%,-50%) rotate(' + tilt.toFixed(1) + 'deg)';
  }
  function coinHide() {
    document.body.classList.remove('coin-active');
    els.coin.classList.add('hidden');
  }

  // ---- Synthesized scratch sound (Web Audio noise burst through a bandpass filter) -------------
  // No audio file is loaded here on purpose - nothing to ship, nothing that can go missing or fail
  // to fetch. A short burst of filtered noise plays on each scratch stroke, throttled so it doesn't
  // spam while dragging.
  var audioCtx = null;
  var lastScratchSoundAt = 0;
  function ensureAudioCtx() {
    if (audioCtx) return audioCtx;
    var Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    audioCtx = new Ctx();
    return audioCtx;
  }
  function playScratchTick() {
    if (!scratchSoundEnabled) return;
    var now = performance.now();
    if (now - lastScratchSoundAt < 70) return;
    lastScratchSoundAt = now;

    var ctx = ensureAudioCtx();
    if (!ctx) return;
    if (ctx.state === 'suspended') ctx.resume();

    var dur = 0.06;
    var bufferSize = Math.floor(ctx.sampleRate * dur);
    var buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    var data = buffer.getChannelData(0);
    for (var i = 0; i < bufferSize; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / bufferSize);

    var src = ctx.createBufferSource();
    src.buffer = buffer;

    var filter = ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.value = 1800 + Math.random() * 800;
    filter.Q.value = 0.7;

    var gain = ctx.createGain();
    gain.gain.value = 0.18;

    src.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    src.start();
  }

  function scratchCanvas(cellEl) {
    var canvas = document.createElement('canvas');
    // Append BEFORE measuring, and measure the canvas itself (not cellEl) via
    // getBoundingClientRect. Reading cellEl.clientWidth here, before this canvas (or anything) had
    // been attached under it, could return 0 depending on exactly when the browser had last
    // resolved this cell's layout - and size silently fell back to a hardcoded 100. That 100 then
    // became the canvas' internal coordinate space (canvas.width/height), while the canvas was
    // still visually stretched to fit the cell's REAL size via the `width:100%;height:100%` CSS
    // rule (often much smaller, e.g. 49px). Every pointer coordinate is computed in real on-screen
    // CSS pixels (getBoundingClientRect), so a drag across the entire visible cell could only ever
    // reach roughly half of the canvas' actual logical area - the rest was physically unreachable,
    // which is exactly "only lets me scratch a corner and won't take the rest off". Measuring the
    // canvas after it's attached and styled removes the guesswork entirely.
    cellEl.appendChild(canvas);
    var dpr = window.devicePixelRatio || 1;
    var rect = canvas.getBoundingClientRect();
    var size = rect.width || cellEl.clientWidth || 100;
    canvas.width = size * dpr; canvas.height = size * dpr;
    var ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);

    // Foil-style coating instead of a flat grey fill: a soft metallic gradient plus a fine diagonal
    // hatch, so it actually looks like something worth scratching off rather than a plain block.
    var sheen = ctx.createLinearGradient(0, 0, size, size);
    sheen.addColorStop(0, '#c4cdc9');
    sheen.addColorStop(0.45, '#8f9a96');
    sheen.addColorStop(0.55, '#a7b2ae');
    sheen.addColorStop(1, '#7c8985');
    ctx.fillStyle = sheen;
    ctx.fillRect(0, 0, size, size);

    ctx.strokeStyle = 'rgba(255,255,255,.16)';
    ctx.lineWidth = Math.max(1, size * 0.012);
    for (var i = -size; i < size * 2; i += size * 0.09) {
      ctx.beginPath();
      ctx.moveTo(i, 0);
      ctx.lineTo(i + size, size);
      ctx.stroke();
    }
    ctx.fillStyle = 'rgba(255,255,255,.12)';
    for (var j = 0; j < 16; j++) {
      ctx.beginPath();
      ctx.arc(Math.random() * size, Math.random() * size, Math.random() * 6 + 1, 0, Math.PI * 2);
      ctx.fill();
    }

    var lastPt = null;
    var brush = size * 0.15;
    var done = false;

    function posFromClient(clientX, clientY) {
      // Map by FRACTION of the canvas' current on-screen box, not raw pixel offset, then scale into
      // this canvas' own logical drawing size (`size`). If `size` was ever measured wrong (e.g. this
      // whole card is built while its container is still `display:none`, which is exactly what
      // happens here - #app is hidden until just after buildUi() runs, so every cell reads as 0x0 at
      // creation time and `size` falls back to a guess), a raw-pixel mapping would only ever be able
      // to reach whatever fraction of the canvas its guessed size overshot the real display size by -
      // which looked exactly like "only lets me scratch a corner, won't take the rest off". A
      // fraction-based mapping always covers the full logical canvas regardless of any mismatch
      // between the size it was drawn at and the size it's actually displayed at.
      var r = canvas.getBoundingClientRect();
      var fx = r.width ? (clientX - r.left) / r.width : 0;
      var fy = r.height ? (clientY - r.top) / r.height : 0;
      return [fx * size, fy * size];
    }
    function dab(x, y) {
      // In 'destination-out' mode the erase strength is the ALPHA of what you draw, not its color -
      // without setting this explicitly here, fillStyle stayed whatever the foil texture drawing
      // above last left it at (a translucent white, alpha ~0.12), so every scratch stroke only ever
      // erased ~12% of the coating per pass instead of fully clearing it. That's what made
      // scratching feel like it "wouldn't take the rest off" - it technically was, just at ~1/8th
      // strength, so it looked like almost nothing happened even while dragging normally.
      ctx.fillStyle = '#000';
      ctx.beginPath();
      ctx.arc(x, y, brush, 0, Math.PI * 2);
      ctx.fill();
    }
    // Erases a full stroke from the last point to this one (not just a dot at each sampled point),
    // so a fast drag clears a continuous line instead of a trail of gaps the player has to go back
    // and fill in - that gap-leaving was the main thing making scratching feel bad/incomplete.
    function scratchTo(x, y) {
      ctx.globalCompositeOperation = 'destination-out';
      if (lastPt) {
        var dx = x - lastPt[0], dy = y - lastPt[1];
        var dist = Math.sqrt(dx * dx + dy * dy);
        var steps = Math.max(1, Math.ceil(dist / (brush * 0.4)));
        for (var i = 0; i <= steps; i++) {
          dab(lastPt[0] + (dx * i) / steps, lastPt[1] + (dy * i) / steps);
        }
      } else {
        dab(x, y);
      }
      lastPt = [x, y];
    }
    function checkCleared() {
      if (done) return;
      var data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      var total = data.length / 4, clearN = 0;
      for (var i = 3; i < data.length; i += 4 * 7) { if (data[i] < 40) clearN++; }
      var ratio = clearN / (total / 7);
      if (ratio > 0.45) { done = true; canvas.onRevealed && canvas.onRevealed(); }
    }

    // A real scratchcard doesn't limit your nail to one panel at a time, so a single drag needs to
    // be able to sweep across several cells' canvases in a row rather than being pinned to whichever
    // one first received the pointerdown (which is what per-canvas pointer capture used to force).
    // That cross-cell handoff is handled by one shared, document-level drag controller (see
    // activateGlobalScratchDrag below, wired up once for the whole page) which looks up whatever
    // canvas is actually under the pointer on every move and calls straight into this cell's own
    // dab/checkCleared - each cell still owns its own ink and its own "done" state, only the
    // pointer-tracking and the coin cursor are shared across all of them.
    canvas.__scratch = {
      isDone: function () { return done; },
      resetStroke: function () { lastPt = null; },
      dabAt: function (cx, cy) {
        var p = posFromClient(cx, cy);
        scratchTo(p[0], p[1]);
        playScratchTick();
      },
      check: checkCleared,
      markDone: function () { done = true; }, // used by the "Reveal all" button, which reveals
                                              // instantly without actually scratching the canvas.
    };
    activateGlobalScratchDrag();

    return canvas;
  }

  // ---- shared cross-cell drag controller (wired up once, lazily, on the first scratchCanvas call) --
  var globalScratchDragActive = false;
  function activateGlobalScratchDrag() {
    if (globalScratchDragActive) return;
    globalScratchDragActive = true;

    var dragging = false;
    var activeCanvas = null;

    function pointFromEvent(e) {
      if (e.touches && e.touches.length) return [e.touches[0].clientX, e.touches[0].clientY];
      if (e.changedTouches && e.changedTouches.length) return [e.changedTouches[0].clientX, e.changedTouches[0].clientY];
      return [e.clientX, e.clientY];
    }
    function scratchableAt(cx, cy) {
      var el = document.elementFromPoint(cx, cy);
      return (el && el.tagName === 'CANVAS' && el.__scratch) ? el : null;
    }
    function onDown(e) {
      var p = pointFromEvent(e);
      var el = scratchableAt(p[0], p[1]) || (e.target && e.target.__scratch ? e.target : null);
      if (!el || el.__scratch.isDone()) return;
      dragging = true; activeCanvas = el;
      el.__scratch.resetStroke();
      el.__scratch.dabAt(p[0], p[1]);
      el.__scratch.check();
      coinShow(p[0], p[1]);
      e.preventDefault();
    }
    function onMove(e) {
      if (!dragging) return;
      var p = pointFromEvent(e);
      var el = scratchableAt(p[0], p[1]);
      if (el && !el.__scratch.isDone()) {
        if (el !== activeCanvas) { activeCanvas = el; el.__scratch.resetStroke(); }
        el.__scratch.dabAt(p[0], p[1]);
        el.__scratch.check();
      } else {
        // Pointer is over a gap or an already-revealed cell - drop stroke continuity so the next
        // scratchable cell it lands on starts with a fresh dab instead of a long streak from afar.
        activeCanvas = null;
      }
      coinMove(p[0], p[1]);
      e.preventDefault();
    }
    function onUp() {
      dragging = false; activeCanvas = null;
      coinHide();
    }

    document.addEventListener('pointerdown', onDown);
    document.addEventListener('pointermove', onMove, { passive: false });
    document.addEventListener('pointerup', onUp);
    document.addEventListener('pointercancel', onUp);
    document.addEventListener('touchstart', onDown, { passive: false });
    document.addEventListener('touchmove', onMove, { passive: false });
    document.addEventListener('touchend', onUp);
    document.addEventListener('touchcancel', onUp);
  }

  function maybeFinish() {
    var g2Done = state.bonusObjs.every(function (c) { return c.el.classList.contains('done'); });
    if (!state.game1Done || !g2Done) return;
    els.revealBtn.disabled = true;
    els.closeBtn.disabled = false;

    var total = (state.result.win || 0) + ((state.result.bonusWin && state.result.bonusPrize) || 0);
    if (total > 0) {
      els.resultBar.className = 'result-bar win';
      els.resultBar.innerHTML = '<div class="line1">Total win</div><div class="line2">' + fmt(state.tier, total) + '</div>';
    } else {
      els.resultBar.className = 'result-bar lose';
      els.resultBar.innerHTML = '<div class="line1">Card complete</div><div class="line2">No win</div>';
    }
  }

  function fadeOutCanvas(cellObj) {
    var canvas = cellObj.el.querySelector('canvas');
    if (canvas) {
      canvas.classList.add('clearing');
      if (canvas.__scratch) canvas.__scratch.markDone();
    }
  }

  // ---- generic cell helper used by every Game 1 renderer below --------------------------------
  function mkCell(innerHtml, extraClass) {
    var el = document.createElement('div');
    el.className = extraClass ? ('cell ' + extraClass) : 'cell';
    var v = document.createElement('div');
    v.className = 'value';
    v.innerHTML = innerHtml;
    el.appendChild(v);
    var canvas = scratchCanvas(el); // appends itself to el
    return { el: el, canvas: canvas };
  }

  function finishGame1() {
    state.game1Done = true;
    maybeFinish();
  }

  // Each renderer below owns exactly one `game`'s worth of Game 1 layout/logic: it builds the DOM
  // into `area`, wires every cell's reveal into its own `objs` list, and calls `finishGame1()` once
  // every cell it created is done - applying whatever "matched" highlighting makes sense for that
  // game first. The server has already decided the win amount for all of them; these renderers only
  // ever decide how to VISUALLY highlight what already won, never whether anything won.
  var GAME1_RENDERERS = {
    classic: function (tier, result, area) {
      area.innerHTML = '<div class="grid" id="g1-grid"></div>';
      var gridEl = area.querySelector('#g1-grid');
      var objs = [];
      result.game1.cells.forEach(function (value) {
        var cell = mkCell(fmt(tier, value));
        gridEl.appendChild(cell.el);
        var o = { el: cell.el, value: value };
        objs.push(o);
        cell.canvas.onRevealed = function () { reveal(o); };
      });
      function reveal(o) {
        if (o.el.classList.contains('done')) return;
        fadeOutCanvas(o);
        o.el.classList.add('done');
        var win = result.win || 0;
        if (win > 0) {
          var winners = objs.filter(function (c) { return c.value === win; });
          if (winners.filter(function (c) { return c.el.classList.contains('done'); }).length === 3) {
            winners.forEach(function (c) { c.el.classList.add('matched'); });
          }
        }
        if (objs.every(function (c) { return c.el.classList.contains('done'); })) finishGame1();
      }
      state.game1Objs = objs;
      state.game1Reveal = reveal;
    },

    star: function (tier, result, area) {
      area.innerHTML = '<div class="grid4" id="g1-grid"></div>';
      var gridEl = area.querySelector('#g1-grid');
      var objs = [];
      result.game1.panels.forEach(function (icon, i) {
        var cell = mkCell('<span style="font-size:20px;">' + icon + '</span>');
        gridEl.appendChild(cell.el);
        var o = { el: cell.el, icon: icon, index: i + 1 };
        objs.push(o);
        cell.canvas.onRevealed = function () { reveal(o); };
      });
      function reveal(o) {
        if (o.el.classList.contains('done')) return;
        fadeOutCanvas(o);
        o.el.classList.add('done');
        if (result.game1.starIndex === o.index && o.el.classList.contains('done')) {
          o.el.classList.add('matched');
        }
        if (objs.every(function (c) { return c.el.classList.contains('done'); })) finishGame1();
      }
      state.game1Objs = objs;
      state.game1Reveal = reveal;
    },

    banker: function (tier, result, area) {
      area.innerHTML =
        '<div class="row-vs">' +
        '<div class="subgroup"><div class="subgroup-label">Your numbers</div><div class="grid3" id="g1-yours"></div></div>' +
        '<div class="vs-label">VS</div>' +
        '<div class="subgroup"><div class="subgroup-label">The banker</div><div class="grid3" id="g1-banker"></div></div>' +
        '</div>';
      var yoursEl = area.querySelector('#g1-yours'), bankerEl = area.querySelector('#g1-banker');
      var objs = [];
      var bankerObj;
      result.game1.yourNumbers.forEach(function (value) {
        var cell = mkCell(String(value));
        yoursEl.appendChild(cell.el);
        var o = { el: cell.el, value: value, kind: 'yours' };
        objs.push(o);
        cell.canvas.onRevealed = function () { reveal(o); };
      });
      (function () {
        var cell = mkCell(String(result.game1.bankerNumber));
        bankerEl.appendChild(cell.el);
        bankerObj = { el: cell.el, value: result.game1.bankerNumber, kind: 'banker' };
        objs.push(bankerObj);
        cell.canvas.onRevealed = function () { reveal(bankerObj); };
      })();
      function reveal(o) {
        if (o.el.classList.contains('done')) return;
        fadeOutCanvas(o);
        o.el.classList.add('done');
        if (objs.every(function (c) { return c.el.classList.contains('done'); })) {
          if (result.win > 0) {
            objs.forEach(function (c) {
              if (c.kind === 'yours' && c.value > bankerObj.value) c.el.classList.add('matched');
              if (c.kind === 'banker') c.el.classList.add('matched');
            });
          }
          finishGame1();
        }
      }
      state.game1Objs = objs;
      state.game1Reveal = reveal;
    },

    multiplier: function (tier, result, area) {
      area.innerHTML = '<div class="grid" id="g1-grid"></div><div class="mult-badge">Multiplier</div><div class="mult-cell" id="g1-mult"></div>';
      var gridEl = area.querySelector('#g1-grid'), multEl = area.querySelector('#g1-mult');
      var objs = [];
      result.game1.cells.forEach(function (value) {
        var cell = mkCell(fmt(tier, value));
        gridEl.appendChild(cell.el);
        var o = { el: cell.el, value: value, kind: 'cell' };
        objs.push(o);
        cell.canvas.onRevealed = function () { reveal(o); };
      });
      var multCell = mkCell('x' + result.game1.multiplier);
      multEl.appendChild(multCell.el);
      var multObj = { el: multCell.el, kind: 'mult' };
      objs.push(multObj);
      multCell.canvas.onRevealed = function () { reveal(multObj); };

      function reveal(o) {
        if (o.el.classList.contains('done')) return;
        fadeOutCanvas(o);
        o.el.classList.add('done');
        if (objs.every(function (c) { return c.el.classList.contains('done'); })) {
          if (result.win > 0) {
            var baseWinValue = objs.filter(function (c) { return c.kind === 'cell'; })
              .reduce(function (best, c) {
                return objs.filter(function (x) { return x.kind === 'cell' && x.value === c.value; }).length >= 3 ? c.value : best;
              }, 0);
            objs.forEach(function (c) {
              if (c.kind === 'cell' && c.value === baseWinValue) c.el.classList.add('matched');
              if (c.kind === 'mult') c.el.classList.add('matched');
            });
          }
          finishGame1();
        }
      }
      state.game1Objs = objs;
      state.game1Reveal = reveal;
    },

    numbers: function (tier, result, area) {
      area.innerHTML =
        '<div class="subgroup-label">Winning numbers</div><div class="grid5" id="g1-win"></div>' +
        '<div class="subgroup-label" style="margin-top:8px;">Your numbers</div><div class="grid5" id="g1-your"></div>';
      var winEl = area.querySelector('#g1-win'), yourEl = area.querySelector('#g1-your');
      var objs = [], winningObjs = [], yourObjs = [];
      result.game1.winningNumbers.forEach(function (value) {
        var cell = mkCell(String(value));
        winEl.appendChild(cell.el);
        var o = { el: cell.el, value: value };
        objs.push(o); winningObjs.push(o);
        cell.canvas.onRevealed = function () { reveal(o); };
      });
      result.game1.yourNumbers.forEach(function (value) {
        var cell = mkCell(String(value));
        yourEl.appendChild(cell.el);
        var o = { el: cell.el, value: value };
        objs.push(o); yourObjs.push(o);
        cell.canvas.onRevealed = function () { reveal(o); };
      });
      function reveal(o) {
        if (o.el.classList.contains('done')) return;
        fadeOutCanvas(o);
        o.el.classList.add('done');
        if (objs.every(function (c) { return c.el.classList.contains('done'); })) {
          var calledSet = {};
          winningObjs.forEach(function (c) { calledSet[c.value] = true; });
          yourObjs.forEach(function (c) { if (calledSet[c.value]) c.el.classList.add('matched'); });
          finishGame1();
        }
      }
      state.game1Objs = objs;
      state.game1Reveal = reveal;
    },

    bingo: function (tier, result, area) {
      var rowLabels = ['ROW1 = £2', 'ROW2 = £5', 'ROW3 = £10', 'ROW4 = £20', 'ROW5 = £50'];
      area.innerHTML =
        '<div class="game-label" style="margin-bottom:5px;">Scratch here first - Caller\'s numbers</div><div class="grid5 caller-row" id="g1-caller"></div>' +
        '<div class="gem-banner">Lines with a &#9830; pay double!</div>' +
        '<div class="game-label">Your Bingo Card</div><div class="bingo-wrap" id="g1-grid"></div>';
      var callerEl = area.querySelector('#g1-caller'), gridEl = area.querySelector('#g1-grid');
      var objs = [], callerObjs = [], gridObjs = [];

      result.game1.caller.forEach(function (value) {
        var cell = mkCell(String(value), 'ball');
        callerEl.appendChild(cell.el);
        var o = { el: cell.el, value: value };
        objs.push(o); callerObjs.push(o);
        cell.canvas.onRevealed = function () { reveal(o); };
      });

      for (var row = 0; row < 5; row++) {
        var rowEl = document.createElement('div');
        rowEl.className = 'bingo-row';
        var label = document.createElement('div');
        label.className = 'row-label';
        label.textContent = rowLabels[row];
        rowEl.appendChild(label);
        var cellsWrap = document.createElement('div');
        cellsWrap.className = 'bingo-cells';
        for (var col = 0; col < 5; col++) {
          var idx = row * 5 + col + 1; // 1-indexed to match server/main.lua's grid layout
          var isGem = idx === result.game1.gemIndex;
          if (result.game1.grid[idx] === 'FREE') {
            var freeCell = mkCell('<span class="gem">&#9830;</span>', 'free');
            freeCell.el.classList.add('done', 'matched');
            if (freeCell.canvas.__scratch) freeCell.canvas.__scratch.markDone();
            cellsWrap.appendChild(freeCell.el);
          } else {
            var value = result.game1.grid[idx];
            var cell = mkCell(isGem ? (String(value) + '<span class="gem-mark">&#9830;</span>') : String(value));
            cellsWrap.appendChild(cell.el);
            var o = { el: cell.el, value: value };
            objs.push(o); gridObjs.push(o);
            (function (o) { cell.canvas.onRevealed = function () { reveal(o); }; })(o);
          }
        }
        rowEl.appendChild(cellsWrap);
        gridEl.appendChild(rowEl);
      }

      function reveal(o) {
        if (o.el.classList.contains('done')) return;
        fadeOutCanvas(o);
        o.el.classList.add('done');
        if (objs.every(function (c) { return c.el.classList.contains('done'); })) {
          var calledSet = {};
          callerObjs.forEach(function (c) { calledSet[c.value] = true; });
          gridObjs.forEach(function (c) { if (calledSet[c.value]) c.el.classList.add('matched'); });
          finishGame1();
        }
      }
      state.game1Objs = objs;
      state.game1Reveal = reveal;
    },
  };

  var GAME1_LABELS = {
    classic: 'Game 1 &middot; Match 3',
    star: 'Game 1 &middot; Find The Star',
    banker: 'Game 1 &middot; Beat The Banker',
    multiplier: 'Game 1 &middot; Cash Multiplier',
    numbers: 'Game 1 &middot; Match Your Numbers',
    bingo: 'Game 1 &middot; Jewel Bingo',
  };
  var GAME1_RULES = {
    classic: 'Match 3 identical amounts in GAME 1 to win that PRIZE. Match 4 identical symbols in GAME 2 to win the BONUS shown. Top prize <b id="card-top"></b>.',
    star: 'Find the single &#11088; among the 8 panels in GAME 1 to win the prize it\'s hiding. Match 4 identical symbols in GAME 2 to win the BONUS shown. Top prize <b id="card-top"></b>.',
    banker: 'Beat the banker\'s number with any of your 3 numbers in GAME 1 to win. Match 4 identical symbols in GAME 2 to win the BONUS shown. Top prize <b id="card-top"></b>.',
    multiplier: 'Match 3 identical amounts in GAME 1, then multiply it by whatever the multiplier panel reveals. Match 4 identical symbols in GAME 2 to win the BONUS shown. Top prize <b id="card-top"></b>.',
    numbers: 'Scratch your 20 numbers against the 10 winning numbers in GAME 1 - the more matches, the bigger the prize. Match 4 identical symbols in GAME 2 to win the BONUS shown. Top prize <b id="card-top"></b>.',
    bingo: 'Scratch the caller\'s numbers, then your Bingo Card in GAME 1 - complete a row, column or diagonal for the prize alongside it (lines through the &#9830; pay double). Match 4 identical symbols in GAME 2 to win the BONUS shown. Top prize <b id="card-top"></b>.',
  };

  function revealBonus(cellObj) {
    if (cellObj.el.classList.contains('done')) return;
    fadeOutCanvas(cellObj);
    cellObj.el.classList.add('done');

    var doneCount = state.bonusObjs.filter(function (c) { return c.el.classList.contains('done'); }).length;
    if (doneCount === 4) {
      if (state.result.bonusWin) {
        state.bonusObjs.forEach(function (c) { c.el.classList.add('matched'); });
        els.bonusResult.className = 'bonus-result win';
        els.bonusResult.textContent = 'Bonus won: ' + fmt(state.tier, state.result.bonusPrize);
      } else {
        els.bonusResult.className = 'bonus-result lose';
        els.bonusResult.textContent = 'No bonus this time';
      }
    }
    maybeFinish();
  }

  function buildUi(tier, result) {
    state = { tier: tier, result: result, game1Done: false, game1Objs: [], game1Reveal: null, bonusObjs: [] };

    var game = result.game || 'classic';

    els.card.setAttribute('data-tier', tier.id);
    els.cardStrap.textContent = tier.strap;
    els.cardTitle.textContent = tier.name;
    els.cardPrice.textContent = tier.symbol + tier.price;
    els.chancesRibbon.textContent = (9 + Math.round(tier.price)) + ' CHANCES TO WIN!';
    els.game1Label.innerHTML = GAME1_LABELS[game] || GAME1_LABELS.classic;
    // Replaces the rules box's whole innerHTML (including the <b id="card-top"> placeholder inside
    // it), so the cached els.cardTop reference from page load now points at a detached node - refetch
    // it before setting the top-prize text or it'd silently write to an element nobody can see.
    els.cardRules.innerHTML = GAME1_RULES[game] || GAME1_RULES.classic;
    els.cardTop = document.getElementById('card-top');
    els.cardTop.textContent = fmt(tier, tier.top);
    document.body.style.setProperty('--tier-color', tier.color);

    els.game1Area.innerHTML = '';
    var renderer = GAME1_RENDERERS[game] || GAME1_RENDERERS.classic;
    renderer(tier, result, els.game1Area);

    els.bonusGrid.innerHTML = '';
    els.bonusResult.className = 'bonus-result';
    els.bonusResult.textContent = 'Scratch to reveal';
    result.bonusIcons.forEach(function (icon) {
      var cell = document.createElement('div');
      cell.className = 'bonus-cell';
      var iconEl = document.createElement('span');
      iconEl.className = 'bicon';
      iconEl.textContent = icon;
      cell.appendChild(iconEl);
      els.bonusGrid.appendChild(cell);
      var cellObj = { el: cell, icon: icon };
      var canvas = scratchCanvas(cell); // appends itself to cell
      canvas.onRevealed = function () { revealBonus(cellObj); };
      state.bonusObjs.push(cellObj);
    });

    els.resultBar.className = 'result-bar';
    els.resultBar.innerHTML = '<div class="line1">Scratch Game 1 to reveal</div><div class="line2">&mdash;</div>';
    els.revealBtn.disabled = false;
    els.closeBtn.disabled = true;
  }

  els.revealBtn.addEventListener('click', function () {
    if (!state) return;
    (state.game1Objs || []).forEach(function (o) { if (state.game1Reveal) state.game1Reveal(o); });
    state.bonusObjs.forEach(revealBonus);
  });

  els.closeBtn.addEventListener('click', function () {
    if (els.closeBtn.disabled) return;
    nuiPost('claim').then(function () {
      els.app.classList.add('hidden');
      nuiPost('close');
    });
  });

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape' || els.app.classList.contains('hidden')) return;
    // Leaving before both games are fully scratched forfeits the card - the server already
    // generated (and will discard) the result, nothing is re-rolled if they use another one.
    var finished = els.closeBtn && !els.closeBtn.disabled;
    els.app.classList.add('hidden');
    nuiPost(finished ? 'close' : 'cancel');
  });

  window.addEventListener('message', function (event) {
    var data = event.data;
    if (typeof data === 'string') { try { data = JSON.parse(data); } catch (e) { return; } }
    if (!data || !data.action) return;

    if (data.action === 'open') {
      scratchSoundEnabled = data.scratchSound !== false;
      // Unhide BEFORE building: #app is `display:none` while hidden, which means every cell has a
      // 0x0 layout box for as long as buildUi() runs underneath it - canvas sizing falls back to a
      // guess instead of measuring anything real. Swapping the order costs nothing visually (this
      // is all synchronous; the browser won't paint a frame until this whole handler returns, so
      // there's no flash of a stale/empty card), but it means buildUi() now runs against a
      // genuinely laid-out page, so every canvas gets sized correctly the first time.
      els.app.classList.remove('hidden');
      buildUi(data.tier, data.result);
    } else if (data.action === 'claimed') {
      // Optional: could show a toast here. The result bar already shows the total.
    }
  });
})();