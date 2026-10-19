# 七期：斷鏈行動｜新內容第七輪交付

VERIFIED｜0.21.0，main。本輪依 R6 Muse 五項完成本機驗收，並處理 GPT／Claude 的證據邏輯與排版問題。只做本機 commit；外部複審與實機邊界另列。

三案入口：「暫停 → 查證 → 街坊查證簿・三宗新案」。仍須在街區靠近來源、實際互動留存原文，再回案卷判斷。

- **第二次求助，第二次收費**：甲乙收費句都標黃、完成比較後，玩家親自選照乙付款、暫停付款留存甲乙、或直接指控。錯選會解釋原文足以與不足以證明什麼，不封存；正確行動需雙黃標。原件保留機構、案號與乙「未撤回原承諾」備註。清單結果為「已暫停付款」。這案練習辨認求助過程中的二次收費矛盾。
- **晚班之前的收據**：浮動原件改為半透明、移到排序格上方；原位完全隱去原按鈕文字，只畫虛線。落點格的原件名稱與關係句保留，顯示插入後整體順序。排序後還須選出甲乙、乙丙兩條文件關係；錯序或錯引保留排列供局部修改。時間只在核對後輔助，封存同屏黃標三件的時間／引用依據，明寫 18：00 是晚班開始。清單結果為「已推翻晚班說法」。這案練習不憑時間或第一印象指控經手人。
- **三張嘴，一句真話**：18：00 明定為分界整點，既非以前也非以後。支持吳改成「前後合看」，玩家須分別引用首筆 17：50 與末筆 18：10，單筆與只有一側都不能成立。判定頁同屏顯示原文；紀錄帶分列書寫者、判定與對象，錯釘可拔釘重選。清單結果為「已核對前後紀錄」。這案練習區分記憶、單一紀錄與整組證據，不將說詞不合直接當成犯罪。

## Muse 五項驗收與原尺寸證據

精選集限 [15 張手機直式原圖](content/r7/review-set/)，以 01～15 排序。第一案四張、第二及第三案各五張，另有一張全案結果清單；每案都有進行中的操作。全部為 390×844 原圖的位元組相同複本，沒有縮圖、拼貼或補畫。來源與 SHA-256 見 [索引](content/r7/review-set.json)。

| 驗收 | 原尺寸截圖（相對 `docs/content/r7/`） |
| --- | --- |
| ①拖曳零遮擋、零疊字、結果與預覽一致 | `phone-before_night-drag-preview-1.png`、`phone-before_night-drag-preview-2.png`、`phone-before_night-drag-preview-3.png`，精選 05～07。`phone-before_night-middle-to-left.png` 為落下結果；`phone-before_night-arranged.png`、`phone-before_night-undo.png`、`phone-before_night-tap-alternative.png` 證明改排、撤回及點選補回。 |
| ②分界、來源、判定與對象清楚 | `phone-three_voices-wrong-pin.png`、`-support-insufficient.png`、`-support-one-side.png`、`-support-both-sides.png`、`-player-results.png`、`-sealed.png`；精選 10～14 包含錯釘後重選、原文、單筆不足、合看與結果。 |
| ③行動由玩家決定且須雙原文 | `phone-second_help-action-options.png`、`-action-payment-retry.png`、`-action-accusation-retry.png`、`-sealed.png`；精選 02～04 包含選項、錯選與正確封存。 |
| ④無時間仍能依關係排序，三原件都有依據 | `phone-before_night-relations-chosen.png`、`-relation-retry.png`、`-sealed.png`；精選 08、09。三張拖曳圖亦保持遮時。 |
| ⑤統一封存風格、三種清單結果 | 三案 `phone-<案件>-sealed.png`（精選 04、09、14）皆採既有案卷紙面，主視覺分別為雙頁黃標、三件引用、首末紀錄；`phone-case-list-reloaded.png`（精選 15）顯示不同結果。 |

三案另有 `phone-<案件>-reopened.png` 與 `-sealed-reloaded.png`，比對清單重開、冷重載後的原選擇與封存結果。第一案 `-paper-a-marked.png` → `-paper-a-reloaded.png` 保留黃標中途讀回證據。第二案 `-middle-to-left.png` → `-drag-cancelled.png` 保留拖出排序格取消後的相同排列。現場接觸與角色來源見三案 `-field-<序號>.png`；不把單張圖當成整段走訪或動畫的證明。沒有新增人物動畫、物理或劇情分支演出宣稱。

## 驗證與限制

VERIFIED｜Godot 無頭測試及既有 Web 裝置守門共 **37 套、83,834 項檢查，零失敗**，另外通過 Godot 匯入解析，含主線整合及全部既有回歸。Web 六視口（390×844、320×568、844×390、1024×768、1290×2796、2064×2752）均實際觸控完成三案及 IndexedDB 冷重載，共 **115 張原圖**；瀏覽器錯誤與外站請求零筆，讀回 **387 個顯示字元**的字型覆蓋。以 [總驗證](content/r7/verification.json)、[測試](content/r7/final-tests.json)、[Web 操作](content/r7/manifest.json) 為準。所有既有測試斷言保留；有新增步驟的操作路徑改為先提供引用、再做原本的完成／存檔斷言。R6 跟手測試保留，另加浮動牌不得碰到排序區的斷言。測試與 Web 匯出來源指紋相同，236 個受保護檔案的內容保持不變。

VERIFIED｜待提交索引共 4,333 個檔案，既有秘密掃描器與工作單指定金鑰模式均零命中；未讀取憑證目錄。使用明確路徑加入索引，未納入他人草稿，既有商店圖及未追蹤檔案均保留。

禁則排字涵蓋說明文字、證物標題與紙上可點選原文；依實際字型寬度換行，保留原文識別與每個字元。`rendered_text` 記錄真正顯示的換行，Godot 與瀏覽器均檢查行首標點，並保留原本的 44px、控制邊界與重疊斷言。這也修正了 320×568 原件收費句及第三張封存證物的落單句號。

全程 Godot `--headless`、headless Chromium，沒有開編輯器或可見視窗。實際引擎為工作單指定的 **4.7.stable.official.5b4e0cb0f**。Web 使用工作單指定 ANGLE D3D11／GPU 四旗標。受保護草稿以開始時雜湊核對；匯出與測試使用獨立來源快照，受保護的 export、touch 等檔採 HEAD 版本，不納入他人草稿。瀏覽器使用實際原生無頭世界產生的近來源未完成快照省略長距離旅行，再用可見觸控收件及解案；沒有注入目標案完成狀態。擷取用的 11 份快照亦與最後完整回歸重新產生的檔案逐位元組一致。[快照來源](content/r7/fixture-generation.json)。

新增生成美術 **0 張**；沿用 ART_DIRECTION、既有紙張、人物、街景與真骨架動畫。新增的是 UI 排版與操作回饋，不冒稱新美術。新增商店原圖 **4 張**：`docs/store/screenshots/{1290x2796,2064x2752}-content-r7-{before_night-relations-chosen,three_voices-support-both-sides}.png`。都是同尺寸 Web 實拍複本，既有商店圖保留。[商店讀回](store/screenshots/CONTENT_R7_STATUS.json)。

**Apple 4.3 風險：中，屬產品評估。** 三案保留都市走訪、比較矛盾原文與有界推論的差異；本輪將閱讀後的行動、文件引用與雙證據判斷做成實際決策。依 [Apple 官方 4.3](https://developer.apple.com/app-store/review/guidelines/#spam) 關於重複 App 與難以區分既有產品的規範評估，2026-10-19 查閱。仍有閱讀比重高的限制，沒有取得本輪外部複審或實機驗證，不代表商店核准。商店草稿已說明三案和反詐的關係。

**BLOCKED：Muse ≥8 複審、實體 iPhone／iPad／Android、真人試玩。** 需要審查員、裝置與測試者；未捏造評分或裝置結果。效能依本線指示另案處理，本輪不宣稱 p95 ≤18ms。沒有 push、部署、操作商店後台、派工、傳訊、新增外連、SDK、帳號、廣告、內購或線上功能。

speak-human-tw mode 2：原「核對兩個標欄」不自然，改成「核對兩處黃標」；原已留存來源前的勾號易被誤讀為解題完成，改成「已留存甲／乙」；原「18：00 支持吳」把整組結論掛在單筆上，改成「前後合看」，並保留實際引用；原「推論有界」改成各案具體結果。虛構姓名、機構、案號、收費原句及推論界限保留。
