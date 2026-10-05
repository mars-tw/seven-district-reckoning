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
  const gameResources = document.getElementById("game-resources");
  const commandButtons = {
    new_game: document.getElementById("command-start"),
    pause: document.getElementById("command-pause"),
    phone: document.getElementById("command-phone"),
    jobs: document.getElementById("command-jobs"),
    map: document.getElementById("command-map"),
    supplies: document.getElementById("command-supplies"),
    settings: document.getElementById("command-settings"),
    resume: document.getElementById("command-resume"),
    save: document.getElementById("command-save"),
    load: document.getElementById("command-load"),
    touch_toggle: document.getElementById("command-touch"),
  };
  const profileSelector = document.getElementById("device-profile");
  const profileNote = document.getElementById("device-profile-note");
  const entryHint = document.getElementById("device-entry-hint");
  const PROFILE_SETTINGS = Object.freeze({
    phone: Object.freeze({ label: "手機", pixelRatioCap: 1.5, input: "touch" }),
    tablet: Object.freeze({ label: "平板", pixelRatioCap: 1.75, input: "touch" }),
    desktop: Object.freeze({ label: "電腦", pixelRatioCap: 2, input: "keyboard_mouse" }),
  });
  const coarsePointer = window.matchMedia("(pointer: coarse)").matches;
  const agentText = navigator.userAgent || "";
  const mobileHint = /Android|iPhone|iPad|iPod/.test(agentText)
    || (/Macintosh/.test(agentText) && navigator.maxTouchPoints > 1 && coarsePointer);
  // maxTouchPoints alone also matches laptops; those keep desktop controls.
  const hardwareProfile = mobileHint || coarsePointer
    ? (Math.min(window.screen?.width || window.innerWidth, window.screen?.height || window.innerHeight) < 600 ? "phone" : "tablet")
    : "desktop";
  const pathProfile = window.location.pathname.split("/").filter(Boolean)[0];
  const entryProfile = document.body.dataset.entryProfile;
  const queryProfile = new URLSearchParams(window.location.search).get("profile");
  const preferenceKey = `seven-district-device-v1:${hardwareProfile}`;
  let requestedProfile = "auto";
  try {
    const saved = window.localStorage.getItem(preferenceKey);
    if (saved === "auto" || Object.hasOwn(PROFILE_SETTINGS, saved)) requestedProfile = saved;
  } catch (_) { /* Storage can be unavailable in private/restricted browsers. */ }
  if (Object.hasOwn(PROFILE_SETTINGS, entryProfile)) requestedProfile = entryProfile;
  if (Object.hasOwn(PROFILE_SETTINGS, pathProfile)) requestedProfile = pathProfile;
  if (queryProfile === "auto" || Object.hasOwn(PROFILE_SETTINGS, queryProfile)) requestedProfile = queryProfile;
  let deviceProfile = requestedProfile === "auto" ? hardwareProfile : requestedProfile;
  let touchDevice = deviceProfile !== "desktop";
  let engine = null;
  let phase = "ready";
  let loaded = 0;
  let total = 0;
  let message = "等待進入街區";
  let resizeQueued = false;
  let config = null;
  let reportedProgressBucket = -1;
  let lastGameState = null;
  let playStarted = false;
  let expandedFallback = false;
  let previousOverflow = "";

  Object.defineProperty(window, "sevenDistrictDevice", {
    configurable: false,
    enumerable: true,
    get: () => Object.freeze({
      profile: deviceProfile, requested_profile: requestedProfile,
      device_hint: hardwareProfile, pointer_touch: coarsePointer || mobileHint,
      pixel_ratio_cap: PROFILE_SETTINGS[deviceProfile].pixelRatioCap,
      pixel_ratio: Math.min(PROFILE_SETTINGS[deviceProfile].pixelRatioCap, Math.max(1, window.devicePixelRatio || 1)),
    }),
  });

  // Diagnostics are snapshots only. No callable methods or engine internals are exposed.
  Object.defineProperty(window, "sevenDistrictStatus", {
    configurable: false,
    enumerable: true,
    get: () => Object.freeze({ phase, loaded, total, message, ...resourceSnapshot(lastGameState) }),
  });

  function resourceSnapshot(state) {
    const source = state && typeof state === "object" ? state : {};
    const finite = (value) => Number.isFinite(value) ? Math.max(0, value) : null;
    const label = (value) => typeof value === "string" ? value.trim().slice(0, 80) : "";
    return {
      stamina: finite(source.stamina),
      max_stamina: finite(source.max_stamina),
      credits: finite(source.credits),
      rank: typeof source.rank === "string" ? label(source.rank) : finite(source.rank),
      time: label(source.time),
      navigation: label(source.navigation),
    };
  }

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
    const profileCommand = ["profile_auto", "profile_phone", "profile_tablet", "profile_desktop"].includes(command);
    if (phase !== "running" || (!Object.hasOwn(commandButtons, command) && !profileCommand)) return false;
    if (["map", "supplies", "jobs"].includes(command) && !playStarted) return false;
    if (typeof window.sevenDistrictCommand !== "function") {
      inputHint.textContent = "遊戲操作列還沒準備好，請直接使用畫面內的遊戲選單。";
      return false;
    }
    try {
      window.sevenDistrictCommand(command);
      if (command === "new_game" || command === "resume" || command === "settings") overlay.hidden = true;
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
    if (typeof state.play_started === "boolean") playStarted = state.play_started;
    else if (state.phase === "title") playStarted = false;
    else if (state.phase === "playing") playStarted = true;
    const ready = phase === "running" && typeof window.sevenDistrictCommand === "function";
    gameToolbar.hidden = !ready;
    if (ready && state.phase === "playing") overlay.hidden = true;
    if (phase === "running" && previousGamePhase !== state.phase) {
      setStatus("running", state.phase === "playing" ? "遊戲進行中" : state.phase === "menu" ? "遊戲選單開啟" : "遊戲已載入，等待開始");
    }
    if (typeof state.device_profile === "string" && Object.hasOwn(PROFILE_SETTINGS, state.device_profile)) {
      deviceProfile = state.device_profile;
      touchDevice = deviceProfile !== "desktop";
      applyDeviceLayout();
    }
    commandButtons.new_game.hidden = playStarted;
    commandButtons.pause.hidden = state.phase !== "playing";
    commandButtons.phone.hidden = state.phase !== "playing";
    if (commandButtons.jobs) commandButtons.jobs.hidden = !playStarted;
    commandButtons.map.hidden = !playStarted;
    commandButtons.supplies.hidden = !playStarted;
    commandButtons.settings.hidden = false;
    commandButtons.resume.hidden = state.phase !== "menu" || !playStarted;
    commandButtons.save.hidden = state.phase !== "menu" || !playStarted;
    const title = typeof state.main_title === "string" ? state.main_title.trim().slice(0, 100) : "";
    const objective = typeof state.objective === "string" ? state.objective.trim().slice(0, 220) : "";
    gameObjective.textContent = [title, objective].filter(Boolean).join("｜");
    gameObjective.hidden = !playStarted || !gameObjective.textContent;
    const sides = Number.isFinite(state.completed_sides) ? Math.max(0, Math.trunc(state.completed_sides)) : 0;
    const activities = Number.isFinite(state.completed_activities) ? Math.max(0, Math.trunc(state.completed_activities)) : 0;
    gameRecord.textContent = `街區紀錄：委託 ${sides}・活動 ${activities}`;
    gameRecord.hidden = !playStarted;
    const resources = resourceSnapshot(state);
    const resourceLabels = [];
    if (resources.stamina !== null && resources.max_stamina !== null) {
      resourceLabels.push(`體力 ${Math.round(resources.stamina)}／${Math.round(resources.max_stamina)}`);
    }
    if (resources.credits !== null) resourceLabels.push(`補給金 ${Math.trunc(resources.credits)}`);
    if (typeof resources.rank === "string" && resources.rank) resourceLabels.push(resources.rank);
    else if (typeof resources.rank === "number") resourceLabels.push(`街區階段 ${Math.trunc(resources.rank)}`);
    if (resources.time) resourceLabels.push(resources.time);
    if (resources.navigation) resourceLabels.push(`前往 ${resources.navigation}`);
    gameResources.textContent = resourceLabels.join("・");
    gameResources.hidden = !playStarted || !gameResources.textContent;
    commandButtons.touch_toggle.setAttribute("aria-pressed", String(state.touch === true));
    // Coordinates are machine-readable for UI verification, never presented as player content.
    if (Number.isFinite(state.player_x)) canvas.dataset.playerX = state.player_x.toFixed(3);
    if (Number.isFinite(state.player_z)) canvas.dataset.playerZ = state.player_z.toFixed(3);
    // Read-only renderer diagnostics; these never accept gameplay commands.
    if (typeof state.version === "string") canvas.dataset.runtimeVersion = state.version;
    if (typeof state.device_profile === "string") canvas.dataset.runtimeProfile = state.device_profile;
    if (Number.isFinite(state.resolution_scale)) canvas.dataset.renderScale = state.resolution_scale.toFixed(2);
    if (Number.isFinite(state.camera_distance)) canvas.dataset.cameraDistance = String(state.camera_distance);
    if (typeof state.touch_controls === "boolean") canvas.dataset.touchControls = String(state.touch_controls);
    if (Number.isFinite(state.visible_citizens)) canvas.dataset.visibleCitizens = String(state.visible_citizens);
    if (Number.isFinite(state.visible_traffic)) canvas.dataset.visibleTraffic = String(state.visible_traffic);
    if (Number.isFinite(state.draw_calls)) canvas.dataset.drawCalls = String(state.draw_calls);
    if (Number.isFinite(state.frame_fps)) canvas.dataset.frameFps = String(state.frame_fps);
  }

  function resizeCanvas() {
    resizeQueued = false;
    const rect = frame.getBoundingClientRect();
    const style = window.getComputedStyle(frame);
    const availableWidth = Math.max(1, (frame.clientWidth || rect.width) - (parseFloat(style.paddingLeft) || 0) - (parseFloat(style.paddingRight) || 0));
    const availableHeight = Math.max(1, (frame.clientHeight || rect.height) - (parseFloat(style.paddingTop) || 0) - (parseFloat(style.paddingBottom) || 0));
    // The game's responsive HUD follows the actual frame, including portrait phones.
    const cssWidth = availableWidth;
    const cssHeight = availableHeight;
    // Separate device budgets affect real canvas allocation, including manual modes.
    const pixelRatio = Math.min(PROFILE_SETTINGS[deviceProfile].pixelRatioCap, Math.max(1, window.devicePixelRatio || 1));
    const width = Math.max(1, Math.round(cssWidth * pixelRatio));
    const height = Math.max(1, Math.round(cssHeight * pixelRatio));
    canvas.style.width = `${cssWidth}px`;
    canvas.style.height = `${cssHeight}px`;
    if (canvas.width !== width) canvas.width = width;
    if (canvas.height !== height) canvas.height = height;
    canvas.dataset.deviceProfile = deviceProfile;
    canvas.dataset.pixelRatio = String(pixelRatio);
  }

  function applyDeviceLayout() {
    document.body.dataset.deviceProfile = deviceProfile;
    if (profileSelector) profileSelector.value = requestedProfile;
    if (profileNote) profileNote.textContent = deviceProfile === "phone"
      ? "浮動搖桿・省電畫面・直向／橫向"
      : deviceProfile === "tablet" ? "大觸控鍵・雙欄任務・大地圖" : "鍵盤滑鼠・完整街景・快捷鍵";
    if (entryHint) entryHint.textContent = deviceProfile === "phone"
      ? "左下浮動搖桿移動，右側點按動作。直向可玩，橫向放大可看更遠。"
      : deviceProfile === "tablet"
        ? "較大的觸控鍵、雙欄生活任務與大地圖。可直向查看任務，再橫向騎車。"
        : "WASD 移動、右鍵拖曳視角；J 外送與取貨、M 地圖、Tab 委託。";
    touchHint.hidden = deviceProfile === "desktop";
    inputHint.textContent = touchDevice
      ? "左下拖曳移動，右邊點按動作；拖曳右半邊看四周。可按「連跑」切換跑步。"
      : "WASD 移動，右鍵拖曳看四周；M 地圖、Tab 委託、J 外送與取貨、Esc 暫停。";
    queueResize();
  }

  function selectProfile(value) {
    if (value !== "auto" && !Object.hasOwn(PROFILE_SETTINGS, value)) return;
    requestedProfile = value;
    deviceProfile = value === "auto" ? hardwareProfile : value;
    touchDevice = deviceProfile !== "desktop";
    try { window.localStorage.setItem(preferenceKey, value); } catch (_) { /* Optional local preference. */ }
    applyDeviceLayout();
    issueGameCommand(`profile_${value}`);
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
        issueGameCommand(`profile_${requestedProfile}`);
        applyDeviceLayout();
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
    if (typeof frame.requestFullscreen !== "function" || typeof document.exitFullscreen !== "function" || document.fullscreenEnabled === false) {
      setExpandedFallback(true);
      return;
    }
    // Fullscreen is requested directly inside the click gesture, before any await.
    try {
      const action = document.fullscreenElement === frame
        ? document.exitFullscreen()
        : frame.requestFullscreen();
      Promise.resolve(action).then(() => {
        queueResize();
        if (phase === "running") focusCanvas();
      }).catch(() => setExpandedFallback(true));
    } catch (_) {
      setExpandedFallback(true);
    }
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
    if (button) button.addEventListener("click", () => issueGameCommand(command));
  });
  if (profileSelector) profileSelector.addEventListener("change", () => selectProfile(profileSelector.value));
  window.addEventListener("seven-district-state", (event) => updateGameState(event.detail));
  focusButton.addEventListener("click", focusCanvas);
  canvas.addEventListener("pointerdown", focusCanvas);
  // Web camera orbit uses right-button drag without pointer lock.
  canvas.addEventListener("contextmenu", (event) => event.preventDefault());
  canvas.addEventListener("webglcontextlost", () => {
    displayFailure("WebGL context was lost.", "瀏覽器失去圖形連線。請關閉其他耗用圖形的分頁後，重新載入遊戲。");
  });
  fullscreenButton.addEventListener("click", toggleFullscreen);
  if (typeof frame.requestFullscreen !== "function" || typeof document.exitFullscreen !== "function") {
    fullscreenButton.title = "放大遊戲區，填滿這個分頁";
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
  // Leaving a mobile tab cannot leave a movement finger or sprint toggle live.
  window.addEventListener("blur", () => {
    if (lastGameState?.phase === "playing") issueGameCommand("pause");
  });
  document.addEventListener("visibilitychange", () => {
    if (document.hidden && lastGameState?.phase === "playing") issueGameCommand("pause");
  });
  if (window.visualViewport) window.visualViewport.addEventListener("resize", queueResize, { passive: true });
  if (typeof ResizeObserver !== "undefined") new ResizeObserver(queueResize).observe(frame);
  applyDeviceLayout();
  resizeCanvas();
})();
