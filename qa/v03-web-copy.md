# Alpha 0.3 網頁與文件交接

狀態：EXECUTED。`node --check web/play-site.js` 通過；隔離 DOM／Engine 合約檢查 **59 項通過、零失敗**。這些是網頁外殼檢查，不代表 Godot WASM 實際啟動、手機效能或公開部署已驗證。

## 交付範圍

- `web/shell.html`、`web/play-site.js`、`web/play-site.css`。
- `README.md`、`CHANGELOG.md`、`docs/web-play.md`、`docs/build-from-source.md`、`docs/release-notes-0.3.0.md`。
- 本交接檔。未修改 Godot 程式、模型、製作工具、部署設定或憑證；沒有部署或提交 Git。

## 介面契約

新增 DOM 按鈕 `command-map`、`command-supplies`、`command-settings`，命令為 `map`、`supplies`、`settings`。頁面仍只呼叫固定 UI 白名單，不接受位置、任務 ID、任意程式或事件參數。

遊戲以 `seven-district-state` 發送 `title`／`playing`／`menu`，並提供 `play_started` 布林值。`map` 與 `supplies` 需已開局；`settings` 在引擎完成啟動後可於標題開啟。標題設定選單不顯示繼續、存檔或進度列，設定命令會移除外層啟動遮罩，讓玩家看到真正的 Godot 選單。舊版沒有 `play_started` 時，以 `title`／`playing` 推定並在 `menu` 保留前值。

`game-resources` 只顯示體力、補給金、街區階段、時間與導航名稱。`window.sevenDistrictStatus` 保留載入狀態，新增 `stamina`、`max_stamina`、`credits`、`rank`、`time`、`navigation` 的唯讀值；回傳物件為 frozen，不含引擎實例或可呼叫功能。數值須有限，字串最多 80 字，導航物件不會被接受。現有座標只保留於 canvas 的數值資料屬性，用於 UI 驗證。

全螢幕按鈕在缺少 `requestFullscreen`／`exitFullscreen` 時，仍可啟用既有頁內放大。API 被停用、原生請求拒絕或同步擲錯也走同一處理；返回按鈕與 Esc 可縮回，並還原原本的 body overflow。這是針對 API 邊界的修復，不宣稱 iPhone 實機已通過。

手機操作列採自適應網格，按鈕最小高 44px；保留右鍵拖曳、onProgress 的 running 防回退、官方 Godot 五種 placeholder 與 CSP。只有 WebAssembly 編譯使用 `wasm-unsafe-eval`，沒有一般 `unsafe-eval`、inline 執行程式或 `innerHTML` 注入。

## 已執行的 59 項隔離檢查

涵蓋唯一 DOM ID、單一真實 canvas、五種官方 placeholder、CSP、引擎 canvas／resize policy、DPR 上限、真正的 progress callback、延遲 progress 防回退、唯讀 frozen getter、開局前後與標題設定的按鈕狀態、固定 map／supplies／settings 命令、純文字內容、座標資料、有限數值過濾、手機全螢幕缺失／拒絕／同步錯誤／停用回退，以及原生成功與退出。引擎與 DOM 在這份合約測試中是隔離替身，沒有將其當作實際遊戲。

主管仍需重建 Web 套件，確認內容雜湊版本、實際遊戲選單、公開網址啟動、存讀檔及截圖。文件暫標 **Alpha 0.3 尚未部署**，待公開驗證完成後更新；Alpha 0.2 的 775 項結果明列為歷史證據，0.2 截圖也只以歷史連結保留。

## 繁中文案覆核：mode 2

依共用核心規則的常駐 mode 2，直接套用並留下事後摘要。既有對外繁中文案修改 14 處如下；新增的功能說明以已提供的介面與資料定義為依據，未杜撰地圖精度、寫實水準、手機效能或本版測試總數。

| 原句或位置 | 原因 | 改成什麼 |
| --- | --- | --- |
| README：「Alpha 0.2.0：網頁單人遊玩、六個支線與四個活動。」 | 新版重點已轉為人物、街景與系統。 | 「Alpha 0.3.0：人物比例、商辦街景、街區挑戰與補給系統。」 |
| README：「線上版已發布。」 | 尚未進行新版部署，避免沿用舊版狀態。 | 明列 0.3 待驗證、公開網址目前為 0.2。 |
| README：將 0.2 截圖放在新版介紹首圖。 | 歷史圖不能當成新版美術證據。 | 改成明確標示版本的歷史連結，新圖待公開驗證。 |
| README：「25 個實際 GLB、25 份 Blender 源檔」。 | 新版新增六個人物與六個城市資產。 | 保留原 25 個模型的版本，另列本版新增資產。 |
| README：操作列只列任務、暫停、繼續與存讀檔。 | 玩家需要找到新增功能與手機放大入口。 | 列入地圖、補給、設定及無原生全螢幕時的返回方式。 |
| README：驗證段落直接列 775 項通過。 | 這是 Alpha 0.2 證據，不能當作 0.3 的結果。 | 舊數字明列歷史，本版最後數字待補。 |
| README：公開資源與 Chrome 啟動等驗證不標版本。 | 讀者可能以為新版已完成公開試玩。 | 明列已驗證的是 Alpha 0.2。 |
| README：限制仍寫「畫質選單仍需擴充」。 | 新版已有畫質選項。 | 刪除過時項目，保留交通、導航避障與 LOD 等限制。 |
| README：「25 個 Alpha 模型不能當作 70 項資產全數完成」。 | 模型數已改變，舊數字不再適合。 | 說明本版新增仍未完成全部資產或完整 MVP。 |
| 網頁：「ALPHA 0.2」。 | 輸出外殼將對應新版。 | 「ALPHA 0.3」。 |
| 網頁：「人物、企業與街區皆為虛構。這是持續開發的單人 Alpha。」 | 新增功能需要簡短說明。 | 保留虛構設定，補人物比例、商辦街景、補給與挑戰。 |
| 網頁：操作註記只提醒存檔、F5 與右鍵。 | 需要協助玩家調整新增設定。 | 保留瀏覽器按鍵提醒，補畫質、難度、視角、音效及手機效能模式。 |
| 操作文件：全螢幕註記只寫「拒絕時」回退。 | 缺少原生 API 的手機也必須能用。 | 明列缺少功能或拒絕請求皆可頁內放大。 |
| 操作文件：歷史 Windows 版只寫缺少 0.2 街區。 | 同一下載也沒有本版的新系統。 | 明列 0.2／0.3 街區、可選內容與系統不在該桌面包。 |

遊戲名稱、公共網址、歷史 Windows 版本、挑戰目標與補給數字均已保真回讀。人物與地圖的提升使用「人體比例」、「商辦街景」、「虛構街區」等可核對描述，未寫成 GIS 重建或寫實大作。
