# 七期：斷鏈行動｜新內容第三輪

2026-10-19 執行 10/18 工作單，main，版本 **0.17.0**。本輪修整原有三案，依 `docs/content/CONTENT_REVIEW_R2_MUSE.md` 的五項清單驗收。Muse 新分數為 **BLOCKED，待複審**；沒有自行宣稱已達 8 分。

共同入口：**暫停 → 查證 → 街坊查證簿 → 案名**。不必先完成主線；到指定現場、下車並靠近三公尺內才能互動留證。正常流程有待訪來源、街區導引、原件、推論及封存；不能從案件清單直接領取證物。進度自動保存。

| 三項內容 | 這輪做了什麼、怎麼玩 |
| --- | --- |
| 第二次求助，第二次收費 | 比對甲、乙同案文件，再從三個相同長度、相同語氣的行動中選擇保住原文的做法。錯選指出甲／乙依據；第一層只保存判斷，第二層正確才封存。 |
| 晚班之前的收據 | 先讀「收據供摘要引用、摘要簽收時晚班尚未開始、晚班沿用摘要」的關係，牌面先不顯示時間。確認才揭時；錯排可以撤回，正排後還要判斷時間線能證明什麼。選擇「已確定經手人」會被拒絕，不能跳過推論界限。 |
| 三張嘴，一句真話 | 親訪林秀蘭、陳奕廷、吳安琪，原文可逐張重讀。選取索引時直接列出三筆時間；核對後明寫所用文件與支持／推翻。封存逐人列出實際配對，保留記憶不符不能推定犯罪的界限。 |

## 五項驗收及原尺寸證據

全部原圖在 `docs/content/r3/`。[完整手機圖集](content/r3/REVIEW_GALLERY.md)把第一層、錯選、撤回、原件、重載與資料替換也逐張嵌入，避免只有檔名而漏看核心玩法。PNG 尺寸、狀態與 SHA-256 見 [manifest.json](content/r3/manifest.json)。

修改前的 0.16.0 原圖保留：[現場文字重疊](content/r2/phone-three_voices-field-0.png)、[320×568 時間線](content/r2/phone-before_night-arranged-320x568.png)、[320×568 行動頁](content/r2/phone-second_help-action-320x568.png)。以下均為本輪修改後畫面，沒有改寫歷史證據。

### 1．時間線不能只看數字｜VERIFIED

六種排列都測試過：只點三張牌不能封存；錯排確認後揭時但不完成，撤回可重排；正排揭時仍不完成，還要確認有界結論。十次可見 UI 開案均保留遮時、非正序的牌面。三張主證據如下，另有 `phone-before_night-wrong.png`、`phone-before_night-undo.png`、`phone-before_night-revealed.png`、`phone-before_night-conclusion-retry.png`。

![未排序，牌面遮時](content/r3/phone-before_night-unsorted.png)
![排序中，依事件判斷](content/r3/phone-before_night-sorting.png)
![封存後才寫出完整有界結論](content/r3/phone-before_night-sealed.png)

### 2．320×568 保留資訊｜VERIFIED

三行事件與時間不再因 compact 模式消失；目前順序、撤回／確認、案件清單／返回街區同時可見。第一案回饋採獨立段落，下方保留 8px 空隙。版面守門逐一檢查正文與控制均在視口內、控制至少 44px、互不重疊。

![320×568，三行時間事件與全部操作](content/r3/phone-before_night-arranged-320x568.png)
![320×568，第二步](content/r3/phone-second_help-action-320x568.png)
![320×568，指名文件的回饋全文](content/r3/phone-second_help-action-retry-320x568.png)

### 3．現場方框與壓字｜VERIFIED

左上原本的五個空心矩形是繪製進度，本輪改為圓點。地點、人物與證物名稱移至固定 HUD，取證期間隱去重疊的浮動來源及街坊名牌。字型子集按新文案重建，另逐字核對實拍 UI 的字元覆蓋。

![晨光市場，林秀蘭](content/r3/phone-three_voices-field-0.png)
![便利店，陳奕廷](content/r3/phone-three_voices-field-1.png)
![橘盒站，吳安琪](content/r3/phone-three_voices-field-2.png)

另有一次連續觸控走近的三格：`phone-second_help-walking-1.png`、`phone-second_help-walking-2.png`、`phone-second_help-walking-3.png`，接著按留證取得原件 `phone-second_help-walk-collected.png`。這段有實際位置變化及三公尺範圍檢查。其餘遠距來源由真實無頭世界產生的近來源存檔接續，再按可見互動取得；沒有宣稱以輸入走完全部長距離路線。

### 4．第一案去除選項洩題｜VERIFIED

三項都是 12 字，同以「暫停付款」開頭，分別是留存甲乙、依乙撤下甲、等身分查明才留證。沒有一項包辦「停止付款＋保存＋求助」三件套。錯選分別指出乙未撤回甲，以及甲乙已在手、留證不必等待查明身分。

![三個等長行動](content/r3/phone-second_help-action.png)
![錯選指出乙未撤回甲](content/r3/phone-second_help-action-retry.png)
![第一層比對](content/r3/phone-second_help-compare.png)
![第一案封存](content/r3/phone-second_help-sealed.png)

第一層錯選 `phone-second_help-retry.png`；另一行動錯選 `phone-second_help-action-retry-identity.png`；中途冷重載仍停在第二層 `phone-second_help-action-reloaded.png`。可替換案件資料另以隔離匯出只換 JSON 的虛構機構與案號，原文與推論各一張，來源與匯出指紋見 [data-swap.json](content/r3/data-swap.json)。正式資料已還原。

![替換後的原文](content/r3/phone-second_help-data-swap-original.png)
![替換後的推論](content/r3/phone-second_help-data-swap.png)

### 5．第三案核心六張齊備｜VERIFIED

選用索引時可直接讀出 17：50／18：00／18：10；兩種有效反證都明寫「丙 三筆索引 → 推翻此句」。之後可改配首筆或末筆，不扣分。封存依最後實際配對列出說法、文件、支持／推翻。

![林秀蘭說法](content/r3/phone-three_voices-statement-0.png)
![陳奕廷說法](content/r3/phone-three_voices-statement-1.png)
![吳安琪說法](content/r3/phone-three_voices-statement-2.png)
![索引反證一](content/r3/phone-three_voices-index-accepted-0.png)
![索引反證二](content/r3/phone-three_voices-index-accepted-1.png)
![封存逐人對照](content/r3/phone-three_voices-sealed.png)

角色沿用既有 Blender／GLB、真骨架與材質貼圖，降低衣物及皮膚的鏡面反射，保留暖光與接觸陰影；沒有把它算成新角色，也沒有宣稱 3D 精度已與紙頁插圖相同。本輪新增生成美術 **0 張**，沿用 content-r2 的三張專屬圖；其實際工具仍為 `image_gen.imagegen`，來源與共同風格前綴沿用既有 manifest／PROMPTS。

## 驗證與保留範圍

**VERIFIED：Godot 全套 33 套、28,610 項，零失敗。** 包含全部既有回歸、主線整合、逐步保存、磁碟重讀、舊檔相容、六種時間排列、錯選重試、近場互動、十種無頭版面與新增 R3 測試。[完整原始結果](content/r3/final-tests.json)。既有斷言保留；第一輪排序測試加上「揭時仍未完成、確認結論才封存」，第二輪沿新步驟完成案件。

**VERIFIED：九種 Web 視口逐案完成、保存及冷重載。** Web 與來源匯出詳情以 [verification.json](content/r3/verification.json)、[export.json](content/r3/export.json)為準；正式原圖 304 張，加上兩張純 JSON 替換圖共 306 張。實拍一律是 headless Chromium、指定 ANGLE D3D11 四旗標、NVIDIA 硬體 renderer；單一 browser／server，逐個 context 關閉。原尺寸 PNG 不拼貼、不裁切、不縮放成商店尺寸。九種視口含手機直橫、320×568、iPad 尺寸及矮桌機；每案用可見按鈕完成、讀磁碟，最後再做 IndexedDB 冷重載。

Godot 指定執行檔實際回報 **4.7.stable.official.5b4e0cb0f**；只有 `--headless` 匯入、解析、測試及匯出，沒有開編輯器視窗。測試與 Web 使用同一份來源指紋；匯出僅在隔離來源暫換已安裝的 Web 模板及排除歷史美術，之後還原設定。沒有借用他人的 export／touch 修補。

230 個原有未提交檔案逐一以雜湊保護，包括 `.gitignore`、`export_presets.cfg`、`touch_controls.gd`、qa、native 與原有未追蹤檔。只 stage 本輪明確路徑。秘密掃描器修正「完整 Godot 快取欄位」的誤判，另有 10 項回歸驗證，包含真正金鑰附在快取行後仍必須命中。沒有讀取憑證目錄、寫入金鑰、派工、push、部署、操作商店或傳訊。

案件、人物與機構全部虛構，文案只說如何核對矛盾。沒有新增廣告、付費、外部連結、SDK、帳號或線上功能；未增加每日任務、抽卡、技能樹或同款換皮系統。既有離線流程與授權不變。

新增商店圖 **6 張**，保留全部舊圖。`docs/store/screenshots/{1290x2796,2064x2752}-content-r3-{three_voices-field-0,before_night-revealed,three_voices-sealed}.png` 為直接原尺寸截圖；清單與 SHA-256 見 [CONTENT_R3_STATUS.json](store/screenshots/CONTENT_R3_STATUS.json)。PCK 為 **26,192,032 bytes**，保留既有 25 MiB 上限。

並發參考效能為三跑、每跑 180 個瀏覽器 RAF 間隔的 p95 中位數：

| 原尺寸視口 | p95 中位 | 18ms 參考線 |
| --- | ---: | --- |
| 390x844 | 16.7ms | VERIFIED |
| 1290x2796 | 16.8ms | VERIFIED |
| 2064x2752 | 66.7ms | BLOCKED |
| 1366x768 | 50.1ms | BLOCKED |

手機兩個尺寸在參考線內；iPad 與桌機參考值超標，不能宣稱效能驗收通過。406 次主機採樣涵蓋背景負載與本輪無頭回歸，CPU 15.2–92.5%、GPU 3–100%；保留其他工作，沒有用並發資料推定乾淨機況。原始負載見 [host-load.json](content/r3/host-load.json)，逐跑數據見 manifest.json。

## 未完成與風險

**BLOCKED：Muse ≥8 的獨立複審、iPhone／iPad／Android 原生實機、真人試玩與乾淨機況 p95。** 需要審查員、相應裝置／測試者及獨占效能時段。並發量測只供參考；不停止其他線路、不把桌面瀏覽器當原生裝置。本輪只提供可供複審的實作與原圖，不能以自審代替 Muse 分數或 Apple 核准。詳細條件見 [limitations.json](content/r3/limitations.json)。

**Apple 4.3 風險：中，屬本輪產品判斷。** 街區取證、遮時因果重建、完整索引反證與推論界限有本作的辨識度；介面仍有紙面問答的成分，且原生實機與外部複審未完成。Apple 4.3 著重相同應用的重複提交及欠缺有意義差異的體驗，免費與 MIT 不等於通過。[Apple 官方審查準則 4.3](https://developer.apple.com/app-store/review/guidelines/#spam)（2026-10-19 讀取）。

speak-human-tw mode 2 校對摘要：原「停止付款，保存兩份文件並尋求協助」太像標準答案，改為三個等長第一步；原「比較每張原件時間」會鼓勵只排數字，改為指出摘要引用收據與晚班接在摘要後；原籠統「此句已核對」補上所用文件與支持／推翻，避免結果不明。原件的虛構事實、時間與推論界限保留。
