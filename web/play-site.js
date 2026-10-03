/* Official Godot Engine startup, read-only state display and the game's fixed UI command whitelist. */
(() => {
  "use strict";

  const canvas = document.getElementById("canvas");
  const frame = document.getElementById("game-frame");
  const overlay = document.getElementById("launch-overlay");
  const startButton = document.getElementById("start-button");
  const focusButton = document.getElementById("focus-button");
  const fullscreenButton = document.getElementById("fullscreen-button");
  const loadingPanel = document.getElementById("loading-panel");
  const progress = document.getElementById("load-progress");
  const progressLabel = document.getElementById("progress-label");
  const progressValue = document.getElementById("progress-value");
  const launchTitle = document.getElementById("launch-title");
  const launchDescription = document.getElementById("launch-description");
  const launchNote = document.getElementById("launch-note");
  const statusMessage = document.getElementById("status-message");
  const inputHint = document.getElementById("input-hint");
  const touchHint = document.getElementById("touch-hint");
  const failureDetails = document.getElementById("failure-details");
  const failureText = document.getElementById("failure-text");
  const gameToolbar = document.getElementById("game-toolbar");
  const gameObjective = document.getElementById("game-objective");
  const gameRecord = document.getElementById("game-record");
  const commandButtons = {
    new_game: document.getElementById("command-start"),
    pause: document.getElementById("command-pause"),
    phone: document.getElementById("command-phone"),
    resume: document.getElementById("command-resume"),
    save: document.getElementById("command-save"),
    load: document.getElementById("command-load"),
    touch_toggle: document.getElementById("command-touch"),
  };
  const touchDevice = window.matchMedia("(pointer: coarse)").matches || navigator.maxTouchPoints > 0;
  let engine = null;
  let phase = "ready";
  let loaded = 0;
  let total = 0;
  let message = "等待進入街區";
  let resizeQueued = false;
  let config = null;
  let reportedProgressBucket = -1;
  let lastGameState = null;
  let expandedFallback = false;
  let previousOverflow = "";

  // Diagnostics are snapshots only. No callable methods or engine internals are exposed.
  Object.defineProperty(window, "sevenDistrictStatus", {
    configurable: false,
    enumerable: true,
    get: () => Object.freeze({ phase, loaded, total, message }),
  });

  function setStatus(nextPhase, nextMessage) {
    phase = nextPhase;
    message = nextMessage;
    statusMessage.replaceChildren();
    const dot = document.createElement("span");
    dot.className = "status-dot";
    dot.setAttribute("aria-hidden", "true");
    statusMessage.append(dot, document.createTextNode(nextMessage));
  }

  function focusCanvas() {
    canvas.focus({ preventScroll: true });
  }

  function issueGameCommand(command) {
    // The game publishes a fixed command whitelist. This page has no general action/eval API.
    if (phase !== "running" || !Object.hasOwn(commandButtons, command)) return false;
    if (typeof window.sevenDistrictCommand !== "function") {
      inputHint.textContent = "遊戲操作列還沒準備好，請直接使用畫面內的遊戲選單。";
      return false;
    }
    try {
      window.sevenDistrictCommand(command);
      if (command === "new_game" || command === "resume") overlay.hidden = true;
      focusCanvas();
      return true;
    } catch (error) {
      console.error("Game command failed:", error);
      inputHint.textContent = "這個按鈕未完成操作，請直接使用畫面內的遊戲選單。";
      return false;
    }
  }

  function updateGameState(state) {
    if (!state || typeof state !== "object") return;
    if (!["title", "playing", "menu"].includes(state.phase)) return;
    const previousGamePhase = lastGameState ? lastGameState.phase : null;
    lastGameState = state;
    const ready = phase === "running" && typeof window.sevenDistrictCommand === "function";
    gameToolbar.hidden = !ready;
    if (ready && state.phase === "playing") overlay.hidden = true;
    if (phase === "running" && previousGamePhase !== state.phase) {
      setStatus("running", state.phase === "playing" ? "遊戲進行中" : state.phase === "menu" ? "遊戲選單開啟" : "遊戲已載入，等待開始");
    }
    commandButtons.new_game.hidden = state.phase !== "title";
    commandButtons.pause.hidden = state.phase !== "playing";
    commandButtons.phone.hidden = state.phase !== "playing";
    commandButtons.resume.hidden = state.phase !== "menu";
    commandButtons.save.hidden = state.phase !== "menu";
    const title = typeof state.main_title === "string" ? state.main_title.trim().slice(0, 100) : "";
    const objective = typeof state.objective === "string" ? state.objective.trim().slice(0, 220) : "";
    gameObjective.textContent = [title, objective].filter(Boolean).join("｜");
    gameObjective.hidden = !gameObjective.textContent || state.phase === "title";
    const sides = Number.isFinite(state.completed_sides) ? Math.max(0, Math.trunc(state.completed_sides)) : 0;
    const activities = Number.isFinite(state.completed_activities) ? Math.max(0, Math.trunc(state.completed_activities)) : 0;
    gameRecord.textContent = `街區紀錄：委託 ${sides}・活動 ${activities}`;
    gameRecord.hidden = state.phase === "title";
    commandButtons.touch_toggle.setAttribute("aria-pressed", String(state.touch === true));
    // Coordinates are machine-readable for UI verification, never presented as player content.
    if (Number.isFinite(state.player_x)) canvas.dataset.playerX = state.player_x.toFixed(3);
    if (Number.isFinite(state.player_z)) canvas.dataset.playerZ = state.player_z.toFixed(3);
  }

  function resizeCanvas() {
    resizeQueued = false;
    const rect = frame.getBoundingClientRect();
    const availableWidth = Math.max(1, frame.clientWidth || rect.width);
    const availableHeight = Math.max(1, frame.clientHeight || rect.height);
    // The game's responsive HUD follows the actual frame, including portrait phones.
    const cssWidth = availableWidth;
    const cssHeight = availableHeight;
    // Policy 0 leaves backing dimensions to the shell. Never allocate above 2x CSS size.
    const pixelRatio = Math.min(2, Math.max(1, window.devicePixelRatio || 1));
    const width = Math.max(1, Math.round(cssWidth * pixelRatio));
    const height = Math.max(1, Math.round(cssHeight * pixelRatio));
    canvas.style.width = `${cssWidth}px`;
    canvas.style.height = `${cssHeight}px`;
    if (canvas.width !== width) canvas.width = width;
    if (canvas.height !== height) canvas.height = height;
  }

  function queueResize() {
    if (!resizeQueued) {
      resizeQueued = true;
      window.requestAnimationFrame(resizeCanvas);
    }
  }

  function formatBytes(value) {
    return `${(value / (1024 * 1024)).toFixed(1)} MB`;
  }

  function displayFailure(error, explanation = "遊戲資料未載入完成。可重新載入遊戲，或改用 Windows 版。") {
    const detail = error instanceof Error ? error.message : String(error || "Unknown error");
    console.error("Seven District could not start:", error);
    frame.setAttribute("aria-busy", "false");
    overlay.hidden = false;
    loadingPanel.hidden = true;
    startButton.hidden = false;
    startButton.disabled = false;
    startButton.textContent = "重新載入遊戲 ↻";
    focusButton.disabled = true;
    gameToolbar.hidden = true;
    launchTitle.textContent = "這次沒能進入街區。";
    launchDescription.textContent = explanation;
    launchNote.textContent = "下方保留操作說明與 Windows 下載入口。";
    failureDetails.hidden = false;
    failureText.textContent = detail;
    setStatus("failed", "載入失敗，可重試");
    queueResize();
  }

  function onProgress(current, expected) {
    if (phase !== "loading") return;
    loaded = Number.isFinite(current) ? Math.max(0, current) : 0;
    total = Number.isFinite(expected) ? Math.max(0, expected) : 0;
    if (loaded > 0 && total > 0) {
      progress.max = total;
      progress.value = Math.min(loaded, total);
      const percent = Math.min(100, Math.floor((loaded / total) * 100));
      progressValue.textContent = `${percent}%`;
      progressLabel.textContent = percent === 100 ? "正在準備街區" : "正在下載遊戲";
      const bucket = Math.floor(percent / 10);
      if (bucket !== reportedProgressBucket) {
        reportedProgressBucket = bucket;
        setStatus("loading", percent === 100 ? "下載完成，正在啟動" : `正在下載遊戲 ${percent}%`);
      }
    } else {
      progress.removeAttribute("value");
      progress.removeAttribute("max");
      progressValue.textContent = loaded > 0 ? formatBytes(loaded) : "連線中";
      progressLabel.textContent = "正在下載遊戲";
    }
  }

  function onExit(exitCode) {
    overlay.hidden = false;
    frame.setAttribute("aria-busy", "false");
    focusButton.disabled = true;
    gameToolbar.hidden = true;
    loadingPanel.hidden = true;
    startButton.hidden = false;
    startButton.disabled = false;
    startButton.textContent = "重新進入街區 →";
    launchTitle.textContent = "行動暫告一段落。";
    launchDescription.textContent = "重新載入即可回到遊戲選單。存檔會保留在這個瀏覽器。";
    launchNote.textContent = "可以從遊戲選單讀取存檔。";
    setStatus("exited", "遊戲已結束");
    if (exitCode !== 0) displayFailure(`Godot exited with status ${exitCode}`);
    queueResize();
  }

  function startGame() {
    // Engine init has shared promise state; a whole-page retry avoids a half-initialized runtime.
    if (phase === "failed" || phase === "exited") {
      window.location.reload();
      return;
    }
    if (phase === "running") {
      if (!issueGameCommand("new_game")) {
        overlay.hidden = true;
        focusCanvas();
      }
      return;
    }
    if (phase !== "ready") return;
    if (typeof Engine === "undefined" || !config) {
      displayFailure("The exported engine script or configuration is unavailable.");
      return;
    }
    const missing = Engine.getMissingFeatures({ threads: document.body.dataset.godotThreads === "true" });
    if (missing.length > 0) {
      displayFailure(missing.join("\n"), "瀏覽器缺少遊戲需要的功能。請使用支援 WebGL 2、開啟硬體加速的瀏覽器，並從 HTTPS 網址開啟。");
      return;
    }
    frame.setAttribute("aria-busy", "true");
    startButton.disabled = true;
    startButton.hidden = true;
    loadingPanel.hidden = false;
    launchTitle.textContent = "正在接上街區。";
    launchDescription.textContent = "首次載入需要下載遊戲資料。完成後會進入遊戲選單。";
    launchNote.textContent = "載入期間請保持這個分頁開啟。";
    setStatus("loading", "正在載入遊戲");
    resizeCanvas();
    focusCanvas();
    try {
      const runtimeConfig = { ...config, canvas, canvasResizePolicy: 0, focusCanvas: true, locale: "zh_TW" };
      engine = new Engine(runtimeConfig);
      engine.startGame({ onProgress, onExit }).then(() => {
        if (phase !== "loading") return;
        overlay.hidden = true;
        loadingPanel.hidden = true;
        frame.setAttribute("aria-busy", "false");
        focusButton.disabled = false;
        setStatus("running", "遊戲已載入，等待開始");
        if (typeof window.sevenDistrictCommand === "function") {
          // A second real click begins play and activates audio.
          overlay.hidden = false;
          launchTitle.textContent = "街區已接上。";
          launchDescription.textContent = "從最後一則訊息開始，追查假客服留下的線索。";
          launchNote.textContent = "按下後開始新遊戲。已有進度可用下方的「讀取存檔」。";
          startButton.textContent = "進入街區 →";
          startButton.hidden = false;
          startButton.disabled = false;
          gameToolbar.hidden = false;
        }
        if (lastGameState) updateGameState(lastGameState);
        inputHint.textContent = touchDevice
          ? "觸控請橫向並開啟全螢幕；用「觸控按鈕」開啟畫面操作。"
          : "WASD 移動，按住右鍵拖曳調整視角。按 Esc 暫停。";
        resizeCanvas();
        focusCanvas();
      }).catch(displayFailure);
    } catch (error) {
      displayFailure(error);
    }
  }

  function toggleFullscreen() {
    if (expandedFallback) {
      setExpandedFallback(false);
      return;
    }
    // Fullscreen is requested directly inside the click gesture, before any await.
    const action = document.fullscreenElement === frame
      ? document.exitFullscreen()
      : frame.requestFullscreen();
    Promise.resolve(action).then(() => {
      queueResize();
      if (phase === "running") focusCanvas();
    }).catch(() => {
      setExpandedFallback(true);
    });
  }

  function setExpandedFallback(active) {
    expandedFallback = active;
    if (active) {
      previousOverflow = document.body.style.overflow;
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = previousOverflow;
    }
    frame.classList.toggle("expanded-play", active);
    fullscreenButton.classList.toggle("expanded-exit", active);
    fullscreenButton.textContent = active ? "返回頁面 ⛶" : "全螢幕 ⛶";
    fullscreenButton.setAttribute("aria-pressed", String(active));
    queueResize();
    focusCanvas();
  }

  try {
    config = JSON.parse(document.getElementById("godot-config").textContent);
  } catch (error) {
    displayFailure(error, "網頁內的遊戲設定不完整。請重新載入；若持續失敗，可先使用 Windows 版。");
  }
  if (typeof Engine === "undefined" && phase !== "failed") {
    displayFailure("The exported Godot engine script did not load.");
  }

  startButton.addEventListener("click", startGame);
  Object.entries(commandButtons).forEach(([command, button]) => {
    button.addEventListener("click", () => issueGameCommand(command));
  });
  window.addEventListener("seven-district-state", (event) => updateGameState(event.detail));
  focusButton.addEventListener("click", focusCanvas);
  canvas.addEventListener("pointerdown", focusCanvas);
  // Web camera orbit uses right-button drag without pointer lock.
  canvas.addEventListener("contextmenu", (event) => event.preventDefault());
  canvas.addEventListener("webglcontextlost", () => {
    displayFailure("WebGL context was lost.", "瀏覽器失去圖形連線。請關閉其他耗用圖形的分頁後，重新載入遊戲。");
  });
  if (typeof frame.requestFullscreen === "function" && typeof document.exitFullscreen === "function") {
    fullscreenButton.addEventListener("click", toggleFullscreen);
  } else {
    fullscreenButton.disabled = true;
    fullscreenButton.title = "這個瀏覽器未提供網頁全螢幕";
  }
  document.addEventListener("fullscreenchange", () => {
    if (expandedFallback) return;
    const active = document.fullscreenElement === frame;
    fullscreenButton.setAttribute("aria-pressed", String(active));
    fullscreenButton.textContent = active ? "離開全螢幕 ⛶" : "全螢幕 ⛶";
    queueResize();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && expandedFallback) setExpandedFallback(false);
  });
  window.addEventListener("resize", queueResize, { passive: true });
  window.addEventListener("orientationchange", queueResize, { passive: true });
  if (window.visualViewport) window.visualViewport.addEventListener("resize", queueResize, { passive: true });
  if (typeof ResizeObserver !== "undefined") new ResizeObserver(queueResize).observe(frame);
  if (touchDevice) {
    touchHint.hidden = false;
    inputHint.textContent = "觸控請橫向遊玩。手機操作與效能仍在測試中。";
  }
  resizeCanvas();
})();
