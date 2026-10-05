# Alpha 0.4 手機、平板與電腦入口

Alpha 0.4 已上線。手機、平板與電腦入口都有真正公開 WebGL 啟動、模式設定與選單操作證據；驗證是在桌面 Chromium／IAB 的不同 viewport 執行，不是手機硬體幀率測試。

## 進入遊戲

首頁自動判斷裝置。三個專用入口也各自產生 HTML，先選好操作、畫面與說明，再啟動同一份遊戲。

| 入口 | 預設操作與用途 |
| --- | --- |
| [首頁](https://seven-district-reckoning.digimkt.workers.dev/) | 自動選擇；有精細滑鼠指標的觸控筆電維持電腦模式。 |
| [手機 `/phone/`](https://seven-district-reckoning.digimkt.workers.dev/phone/) | 手機模式；浮動搖桿、分指動作／視角、省電畫面與單欄任務。 |
| [平板 `/tablet/`](https://seven-district-reckoning.digimkt.workers.dev/tablet/) | 平板模式；較大的觸控鍵、雙欄生活任務與較大地圖。 |
| [電腦 `/desktop/`](https://seven-district-reckoning.digimkt.workers.dev/desktop/) | 電腦模式；鍵盤滑鼠、快捷鍵、較遠街景與完整 HUD。 |

三個專用入口共用同一份遊戲資料與這個瀏覽器的存檔，各自帶入真正不同的模式。[Windows Alpha 0.4](https://github.com/mars-tw/seven-district-reckoning/releases/tag/v0.4.0)也提供 x64 下載包。

先按「開始線上遊玩」，下載完成再按「進入街區」。已有進度可用「讀取存檔」。頁面「操作與畫面」可以切換模式；網址加 `?profile=auto` 或 `?profile=phone|tablet|desktop` 也可明確指定。指定模式優先於該裝置先前的手動選擇。

手機與平板左下拖曳移動，右側點動作，另用一根手指拖曳右半邊看四周。「連跑」切換持續跑步，方向與視角可各用自己的手指。開選單、切換方向、離開分頁或中止觸控時會放開動作。直向可用，橫向與「全螢幕」適合看路；瀏覽器不提供原生全螢幕時，會改成頁內放大，按「返回頁面」縮回。

電腦用 WASD 移動、Shift 衝刺、右鍵拖曳視角、左鍵攻擊、E 互動、F 上下車、Space 跳／煞車。J 開外送與取貨、M 開地圖、Tab 開委託。存讀檔請用網頁或遊戲選單；瀏覽器可能將 F5 當成重新整理。

「外送與取貨」可查看街坊故事與生活工作。從市場或夜市領餐、到便利商店取物、到橘盒站核碼領件，再帶著貨物去指定收件點。橘盒站參考台灣店到店流程，使用虛構商店與模擬代碼，沒有真實蝦皮帳號、訂單、交易或個資連線。

新增生活區是晨光市場、星燈夜市、日常便利街、橘盒物流街、青蔭里民綠廊、澄川河岸、犁光騎樓老街與紙光文創聚落。到對應站點可玩陀螺節奏體驗、木屐協調練習、街坊手作配色與街坊集章健走；活動結果、徽章、最佳成績與生活相簿會存檔。

## 真正不同的預算

下表取自 `godot/data/device_profiles.json`。Godot 管理器另把設定套用到 3D viewport、鏡頭、陰影、幾何顯示距離、音效與背景人車更新；選單的欄數與觸控佈局也各自不同。

| 項目 | 手機 | 平板 | 電腦 |
| --- | --- | --- | --- |
| 3D 解析度倍率 | 0.70 | 0.85 | 1.00 |
| canvas 像素倍率上限 | 1.50 | 1.75 | 2.00 |
| 道具／建築視距 | 70／190 m | 110／280 m | 180／440 m |
| 鏡頭最遠距離 | 240 m | 360 m | 560 m |
| 背景行人／車流上限 | 6／2 | 12／4 | 24／8 |
| 音效聲部上限 | 4 | 8 | 16 |
| 生活任務欄數 | 1 | 2 | 2 |
| 觸控動作鍵／間距 | 54／8 px | 64／12 px | 可選觸控，54／6 px |

canvas 依**實際 DPR 和該端上限的較小值**分配，並先扣掉全螢幕安全邊界。例如 DPR 1.25 的手機仍用 1.25，不會強制放大到 1.50。Godot UI 座標除以同一個實際倍率，3D 的內部解析度另由 0.70／0.85／1.00 控制。

人物、任務物件、碰撞與大片地面不因普通道具視距而移除。裝置設定留在獨立偏好檔，與戰役／街區存檔分開；讀取電腦遊戲進度不會覆蓋手機操作模式。四個入口同屬一個網站來源，共用該瀏覽器的遊戲存檔，不需要三份遊戲或三個帳號。

網頁存檔仍是同一瀏覽器、同一網站的 IndexedDB。換瀏覽器、換裝置或清除網站資料會影響存檔，沒有跨裝置雲端同步。

## 建置與檢查

以 Godot 4.7.2 官方單執行緒 Web template 匯出；不需要 COOP／COEP 才能啟動這份單執行緒遊戲。執行：

```powershell
python tools/build_web.py --godot godot
node tests/device_web.mjs
python tools/serve_web.py --port 8766
```

另開終端檢查真實 HTTP 包：

```powershell
node tools/verify_web.mjs http://127.0.0.1:8766 qa/local/v04-final-http.json
```

`prepare_web_assets.mjs` 從真正 `godot/project.godot` 讀版本，生成 `index.html` 與三個目錄的 `index.html`，所有入口配置都指向 `/game`、`/game.pck`、`/game.wasm`。引擎腳本、圖示、CSS 與 shell JS 都從網站根目錄載入，CSS／JS／engine script 帶實際 SHA-256 前 12 碼的查詢版本。遊戲包與 HTML 需重新驗證快取，避免新版入口讀到舊包。

原始 WASM 先確認 magic 再 Brotli 壓縮，儲存為 `game.wasm.br`。正式 Worker 僅在 `/game.wasm` 傳回一次壓縮的實際位元組與 `Content-Encoding: br`；其他入口與檔案由正常靜態資產服務處理，可由服務自行協商壓縮。素材、Godot、字型與角色底模的授權副本隨包保留，新增台灣原創資產亦附 CC0 告知。

`_redirects` 將 `/index.html`、`/game.html` 與 `/phone`／`/tablet`／`/desktop` 等別名導到正規入口；每頁有自己的 canonical、預設模式、標題與操作說明。錯誤路徑保留真正 404，不回傳成功狀態的首頁冒充引擎。

`verify_web.mjs` 逐檔比對 hash、必要 MIME 與解碼後 WASM，逐入口檢查配置、負載大小、專用內容與資源路徑，再檢查 redirects。三個裝置目錄下的錯誤引擎路徑 `/phone/game.wasm`、`/tablet/game.pck`、`/desktop/game.js` 必須回傳真正 HTML 404，不能把它當成引擎成功載入。HTTP 位元組檢查與真正 WebGL／操作驗證分開記錄。

## 發布與驗證證據

- `tests/device_web.mjs`：99 項 PASS，包含原有 54 項與 45 項新增入口／DPR／Engine API／錯誤拒絕條件。
- 公開 Alpha 0.4 包：96 項 HTTP／資源檢查 PASS，涵蓋四個真入口、解碼後 WASM、配置、檔案雜湊、必要 MIME、redirects 與 404。[公開結果](../qa/web-live-check.json)
- 最終凍結來源：17 組、8,561 項檢查 PASS，含 2,698 項 Root／UI 整合檢查、245 項文化活動檢查。41 條完整人物／配送／分支路線透過 321 次實際站點操作完成。[完整範圍](../qa/v04-integration-review.md)
- JS syntax 與 Python preview syntax 通過。[完整範圍](../qa/v04-entry-check.md)
- Windows x64：embedded PCK、PE 0.4.0.0、授權副本、ZIP CRC 與安靜五 frame 原標題啟動驗證通過。[原生包報告](../qa/v04-windows-export.md)

真正公開 IAB／Chromium 啟動後，電腦模式套用 1.00 的 3D 解析度、560 m 鏡頭距離與鍵鼠操作；手機套用 0.70、240 m 與觸控；平板套用 0.85、360 m 與觸控。手機畫布中的配送按鈕可開生活選單，平板操作列可開雙欄生活選單，電腦按 M 可開 800 公尺地圖。先在電腦模式存檔，再從同一瀏覽器的手機／平板入口讀檔，位置保持一致，裝置模式未被存檔覆蓋。[實際三端操作紀錄](../qa/browser/v04/public-browser-check.json)

[公開手機遊戲畫面](../qa/browser/v04/phone-play-public.png) · [手機生活選單](../qa/browser/v04/phone-jobs-public.png) · [平板雙欄選單](../qa/browser/v04/tablet-jobs-public.png) · [電腦大地圖](../qa/browser/v04/desktop-map-public.png)

這些瀏覽器結果是在桌面主機以三種 profile／viewport 執行，並非實際手機或平板硬體。Safari／Android 實機的幀率、溫度、記憶體壓力、音效與長時間遊玩仍需另以硬體測試記錄。遊戲是持續開發的單人 Alpha，沒有跨裝置雲端存檔或多人伺服器。
