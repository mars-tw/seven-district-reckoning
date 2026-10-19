# R1 好玩與美觀優化報告

- 日期：2026-10-15
- 版本：0.4.0 → **0.5.0**（本地 commit，未 push、未部署、未碰商店）
- 計畫：`docs/OPTIM_PLAN_R1.md`
- 執行者：Claude（本輪未使用 Codex、未使用 Blender MCP、未新增 AI 生成 2D 原畫）

## 1．這輪改了什麼、為什麼比較好玩

| # | 改動 | 為什麼更好玩／更好看 | 驗證 |
|---|---|---|---|
| 1 | **開場 60 秒**：標題畫面改成街景背景（鏡頭慢速環繞）＋「斷鏈」圖形標誌＋「被騙走的，一環一環討回來。」＋橘色主按鈕「開始行動」。按下後播四張可點擊、可跳過的故事卡：虛構「恆曜投資教育」群組用 12% 獲利拉人、要求「解凍保證金」、阿遠三十八萬存款歸零、美晴說「扳手借你，但只砸該砸的」，最後一張提醒現實遇到投資詐騙撥 165。 | 原本按「開始新遊戲」就直接站在灰色廣場上，玩家不知道自己為什麼要去砸玻璃辦公室。現在 15 秒內交代動機與在地題材，這是本作和其他城市沙盒最不一樣的地方（Apple 4.3 換皮疑慮的主要回應）。 | `r1_fun_polish`：故事 4 張、結束後解除暫停、接上 MAIN-001 橫幅與台詞 |
| 2 | **目標導引**：當前目標上方有光柱、地面脈衝圈、旋轉箭頭；任務卡顯示「▶ 目標 N 公尺」；靠近時光柱淡出。 | 原本只有右上 132×94 小地圖上的一個方點，第一個任務就容易迷路。 | 測試確認光柱跟著 `missions.get_target_key()` 換位置 |
| 3 | **任務節奏**：每個主線開場有大標題橫幅＋該任務角色台詞（原本只藏在 Tab 手機裡）；完成目標跳「✓ 目標完成」＋提示音；完成任務跳「✓ 任務完成｜+N 零件券」＋斷鏈音效。 | 核心循環有清楚的開始、進度與獎勵回饋。 | 測試確認目標完成提示、任務完成提示、下一任務橫幅 |
| 4 | **招牌玩法「斷鏈」**：任務卡右上五節鎖鏈，每完成一個主線斷一節（斷開時閃白）。 | 片名就是斷鏈；玩家每推進一步都在「拆詐騙鏈」，進度一眼可見。 | 測試確認斷鏈數＝完成的主線數，讀檔時同步 |
| 5 | **打擊感**：命中時火花粒子、浮動傷害數字、受擊白閃、鏡頭震動、70 ms 骨架停頓、連擊 ×N、命中音隨機音高；揮空有破風聲。全部只做表現層：不改傷害、不改判定窗、不改 `Engine.time_scale`。 | 原本命中只有一聲 0.18 秒合成音與物件傾斜 0.06 rad，幾乎感覺不到有打到。 | 測試確認只有實際扣血才觸發、傷害數值不變；`release_regressions` 判定窗 37 項仍綠 |
| 6 | **重玩理由**：章節結算顯示 S／A／B／C 大字評價（證據、街坊信任、救出人數、用時、警戒），破壞／蒐證／救援各自記最佳評價，畫面寫「解法完成 1／3」並建議下一局試哪一條。紀錄存在獨立的 `user://seven-district-records-v1.cfg`，不進存檔。 | 原本結算只有分數與「重新開始」。三種解法本來就是這款遊戲的設計核心，現在有明確的收集目標。 | 測試確認評分邊界、紀錄只升不降、非持久模式不落盤、持久模式可讀回 |
| 7 | **光影與色調**：環境光改用天空色並混暖色補光、ACES 曝光 1.08、輕度 glow、飽和 1.14／對比 1.05；車店前廣場改暖紅磚鋪面（台灣騎樓人行道常見色），大面積地面加世界座標細紋；鏡頭附掛無陰影補光燈，角色材質加邊緣光。 | 原本整片灰色廣場、主角深藍衣服幾乎是黑塊。 | 下方色調量測 |
| 8 | **修正標題背景 bug**：選單暫停時 `SpringArm3D` 也跟著暫停，標題與暫停畫面其實是從主角頭部內部算圖（before 標題背景一片深藍就是主角的外套）。改成鏡頭臂在暫停時持續運作。 | 標題終於看得到街景。 | 測試確認 `PROCESS_MODE_ALWAYS`；web 截圖對照 |
| 9 | **HUD 重排**：任務卡從全寬改成左上窄卡（桌機 ≤ 470 px）、加安全值條；證據／信任分數列移出常駐 HUD（仍在暫停與手機選單）；底部提示改成置中膠囊；操作說明 45 秒後收起。 | 遊戲畫面從約 42% 被面板蓋住降到 18%。 | `R1_HUD_COVERAGE {"coverage":0.18,"viewport":"1280x720"}`；before 由截圖面板邊界量得約 42% |
| 10 | **觸控介面**：六顆指令鈕從畫面正中央移到直式頂端一列／橫式右上 3×2；按鈕改半透明圓角，攻擊鈕橘、互動鈕綠；直式提示不再蓋住「連跑」；橫式「連跑」移到搖桿右側。 | before 手機直式「連跑」被提示面板壓住，指令鈕擋在角色正前方。 | 測試在 390×844、844×390、826×340 檢查不重疊、≥44 px、畫面中央淨空 |
| 11 | **聲音**：本機 AI 派工器生成兩首 30 秒配樂（標題曲、街區循環），選單時街區音樂自動壓低 9 dB；新增五個原創合成音效（破風、目標完成、任務完成、斷鏈、介面）。 | 原本完全沒有配樂。 | 測試確認兩首曲目存在、標題／遊戲切換、選單壓低與恢復 |

## 2．證據

### 2.1 截圖（全部 headless）

老闆中途指示「不要啟動試玩 僅背景工作」後，本輪所有最終截圖都改用 **headless**：Godot `--headless` 匯出 Web 版到暫存資料夾，以 Playwright 驅動 headless Chromium（SwiftShader 軟體 WebGL）在本機 127.0.0.1:5107 載入，擷取遊戲 canvas。before 用 `git worktree` 的 `905e123` 原版同法匯出，條件一致。

| 畫面 | before | after |
|---|---|---|
| 桌機標題（canvas 1214×513） | `docs/evidence/r1/web-before/desktop_1280x720_title.png` | `docs/evidence/r1/web-after/desktop_1280x720_title.png` |
| 桌機開場故事卡 | （原版無故事卡，同一時點畫面）`web-before/desktop_1280x720_story.png` | `web-after/desktop_1280x720_story.png` |
| 桌機遊戲中 | `web-before/desktop_1280x720_gameplay_late.png` | `web-after/desktop_1280x720_gameplay_late.png` |
| 手機直式 390×844 | `web-before/phone_portrait_390x844_gameplay_late.png` | `web-after/phone_portrait_390x844_gameplay_late.png` |
| 手機橫式 844×390 | `web-before/phone_landscape_844x390_gameplay_late.png` | `web-after/phone_landscape_844x390_gameplay_late.png` |

每組另有 `_title`、`_story`、`_gameplay`（剛開始，含任務橫幅）。

`docs/evidence/r1/native-window-before/` 是收到「不開視窗」指示**之前**，用非 headless Godot 視窗拍的原版截圖（桌機標題／起始／戰鬥、手機直橫式），保留作原生版 before 參考。收到指示後沒有再開任何視窗；當時開過的 Godot 視窗都已結束（查無殘留程序）。原生版 after 沒有算圖截圖。

### 2.2 色調量測（`tools/r1_visual_metrics.py`，`docs/evidence/r1/tone-metrics.jsonl`）

桌機遊戲中畫面，同一鏡位：

| 區域 | 指標 | before | after | 閘門 |
|---|---|---|---|---|
| 主角裁切（582,230–630,350，含少量背景） | 平均亮度 | 0.321 | 0.382 | 0.30–0.75 ✓ |
| | 近黑像素 | **45.8%** | **26.3%** | < 35% ✓（before 不合格） |
| | 平均飽和 | 0.453 | 0.525 | ≥ 0.32 ✓ |
| | 低飽和像素 | **44.9%** | **12.8%** | < 20% ✓（before 不合格） |
| 街景帶（0,215–1214,370） | 平均飽和 | 0.119 | 0.231 | — |
| | 低飽和像素 | 88.7% | 50.2% | — |

### 2.3 測試

- before：17 suites／8,561 checks／0 failures（`docs/evidence/r1/before-engine-checks-summary.txt`）
- after：**18 suites／8,641 checks／0 failures**（`docs/evidence/r1/after-engine-checks-summary.txt`），指令 `python tools/test_game.py --godot <Godot 4.7.2 console>`，全程 headless。
- 新增 `tests/r1_fun_polish.gd`（80 checks）並加入 `tools/test_game.py` 的 suite 清單。
- 過程中修掉的問題：音效在 headless dummy 音訊驅動下播放會留下未釋放的 playback 物件，讓 v02／v03／district_life 在結束時報「resources still in use」。改成 dummy 驅動不實際播放（模式切換、壓低仍可測）；命中白閃改由 `_process` 計時，不再用 `SceneTreeTimer`。
- repo 的 `.github/workflows`（未提交、屬原生匯出工作）只有手動觸發的 Android／iOS 無簽章匯出，需要 Linux／macOS runner 與 SDK，本機沒有跑。
- `qa/engine-checks*.json` 每次跑測都會被覆寫；因為工作樹裡已有他人未提交的版本，本輪每次跑完都還原原檔，本輪結果另存在 `docs/evidence/r1/`。

### 2.4 效能

- **沒有算圖 p95**：GPU（RTX 2060）一直被其他工作占用到 99%，之後又收到不開視窗的指示，所以沒有量渲染影格時間，也沒有手機實機數字。
- 只做了 headless CPU 影格間隔對照（`--profile=`，dummy 算圖，三跑）：原版 p95 14.874／14.898／15.045 ms（中位 14.898），本版 14.835／14.885／14.914 ms（中位 14.885）。看得出新的回饋層沒有增加 CPU 負擔，但**不能**當成出貨效能閘門的證據。原始 JSON 在 `docs/evidence/r1/perf/`。
- Web 套件 `game.pck` 從 10,974,752 增加到 11,889,036 bytes（兩首 Vorbis 配樂約 0.8 MB、字型子集 266,184 → 277,324 bytes、五個 WAV）。

### 2.5 其他閘門

- 秘密掃描 `grep -rniE "sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}"`（排除 .git／node_modules）：0 命中。
- 版本：`project.godot`、標題、`export_presets.cfg` Windows 檔案版本、`web/shell.html` 都改成 0.5.0／Alpha 0.5；執行期設定 grep `0.4.0|Alpha 0.4` 為 0。網頁下載連結改指向 releases 頁（v0.5.0 release 尚不存在）。`native/build-config.json` 還寫 0.4.0，但它屬於他人未提交的原生匯出工作，本輪沒動。
- 字型：新文字有 31 個字不在舊子集裡，已用 `tools/subset_game_font.py` 重建（並讓工具略過 `.godot`、`_checks`、`android` 產生目錄）。重建後 scripts 內所有字元都在子集內。

## 3．配樂來源

| 檔案 | 派工器 task ID | 實際 worker | 提示詞 |
|---|---|---|---|
| `godot/assets/audio/music_street.ogg` | `29941126-2f69-4a05-b10d-aac9673fdb6c` | `ace_step_turbo` | instrumental urban lo-fi hip hop loop, Taiwanese city night street vibe, warm electric piano, soft erhu-like lead melody, punchy boom bap drums, deep bass, scooter city energy, seamless loop, no vocals, 92 bpm |
| `godot/assets/audio/music_title.ogg` | `247a5ca6-354f-49f4-914c-5d2a19ff1d58`（第一次 `95767a0f…` 因 GPU 排隊逾時失敗後重派） | `ace_step_base_backup` | instrumental cinematic tense synthwave theme, determined hero, dark city neon, pulsing bass arpeggio, taiko-like percussion hits, rising strings, hopeful minor-key melody, no vocals, 100 bpm |

FFmpeg 處理：頭 0.4 s 淡入、尾 1.2 s 淡出，44.1 kHz 立體聲 Vorbis q3，各 30 秒。響度檢查：mean −14.2／−15.3 dB。**我沒有實際聽過這兩首**（只做響度檢查），曲風是否合適、有沒有怪音，需要人工試聽。CREDITS 已記錄來源。

## 4．未完成、缺件與風險

1. **美術模型沒動**：本輪禁止用 Blender MCP，練習目標（灰藍塊）、桌子（米色方塊）、招牌柱等低模道具外觀仍舊；角色臉部表情、三視圖重工、新動作片段也沒做。可替換架構不變：`_model(key)` 讀 `res://assets/models/<key>.glb`，換檔即生效。
2. **原生版沒有 after 算圖截圖**；手機實機 FPS、發熱、長時間遊玩都沒量。
3. **配樂未經人耳確認**（見第 3 節）。
4. **既有問題（非本輪造成）**：Web 版載入畫面 `startup_progress.gd` 讀 `NotoSansTC-Regular.otf`，但 Web 匯出排除該字型，console 出現 `No loader found ... NotoSansTC-Regular.otf`，載入階段文字沒有中文字型。我沒有改，因為該行是 `6aefbaa` 刻意的設定，要改需確認原生版需求。
5. **他人未提交的 `tests/native_touch.gd`**（不在 CI 清單）：我用 headless 跑了一次，十分鐘內沒有輸出結果、結束時有引擎清理錯誤。我沒有查是不是本輪造成的，建議原生匯出工作接手時再跑一次確認。
6. 暫停選單仍是長清單（需捲動），留待下輪分頁化。
7. 評分門檻（S ≥ 58、A ≥ 46、B ≥ 34）是依任務資料推算的最大值訂的，還沒有真人試玩校正。
8. 工作樹裡他人未提交的改動（`.gitignore`、`export_presets.cfg` 的 Android／iOS 區段、`touch_controls.gd` 的 `NOTIFICATION_APPLICATION_PAUSED`、`qa/*.json`、`native/`、`tools/export_mobile.py`、`tools/install_native_toolchain.py`、`.github/workflows/`）都保留在工作樹，沒有放進本輪 commit。
9. **合併風險**：本機另有 worktree 分支 `codex/seven-phone-hud-20261014`、`codex/seven-native-build14-20261014`、`fix/android-build8-startup` 正在改原生／手機介面。本輪改了 `game_hud.gd`、`touch_controls.gd` 的版面，之後合併時可能衝突，需要人工對照。
