# 七期：斷鏈行動｜新內容第八輪

VERIFIED｜0.22.0，main。依 R7 Muse 的五項清單實作，並修正 GPT／Claude 指出的預覽、代號、狀態與選取色問題。本報告的最終驗證數字以 [verification.json](content/r8/verification.json) 與 [final-tests.json](content/r8/final-tests.json) 為準；外部複審不由本機測試代替。

三案共同入口：「暫停 → 查證 → 街坊查證簿・三宗新案」，再選案件。先在街區靠近來源、點互動留存原文，證物齊全後進入推論。已封存案件可從同一清單進入「封存結論／證據鏈／曾選錯」，只供回看。

- **第二次求助，第二次收費**：三個行動皆為 13 字，同句式，分別在付款及留存範圍上作選擇。玩家須讀甲乙原件並親手標出兩句收費原文；錯選不封存，直接逐句引用兩處黃標，說明矛盾為何仍未解決。保留的歷史包含實際選項與當時回饋，重載後可讀回。
- **晚班之前的收據**：三格本身同步顯示插入後的原件名稱與引用句，放下結果與預覽一致。半透明浮件含名稱、引用句與遮時欄，不遮排序格；淡字虛線來源記號留在排序區上方。放入零至三張時，只顯示一種待放／全放入狀態。甲全程稱「車店收據」。甲乙、乙丙關係進度同屏，未選齊時揭時維持灰色並指出缺段；已選採紙白外框，主行動採黃色。核對後仍須貼回收據才封存。
- **三張嘴，一句真話**：全程使用「首筆／林秀蘭」「末筆／陳奕廷」「索引／吳安琪」，玩家合看不再掛吳的書寫者標籤。判定頁顯示「依據 → 完整主張」，紀錄帶用向下箭頭連接；錯釘當下指出哪釘錯及應核對的主張，拔釘修正不影響另外兩釘。支持「前後都有」仍須分別引用 17：50、18：10；18：00 不算任一側。

## Muse 五項驗收與原尺寸證據

原圖均在 `docs/content/r8/`。精選集在 [review-set](content/r8/review-set/)，僅 15 張 390×844 原圖複本，按 01～15 排序，第一案五張、第二案六張、第三案四張。三案都有進行中的操作；第二案多分配一張，用來對照懸停與實際落下。沒有縮圖、拼貼或補畫；逐檔來源、尺寸與 SHA-256 見 [review-set.json](content/r8/review-set.json)。

| Muse 驗收項 | 原尺寸截圖（以下相對 `docs/content/r8/`） |
| --- | --- |
| ①第一案選項去提示化，錯選引用原句 | `phone-second_help-action-options.png`、`-action-payment-retry.png`、`-action-latest-only-retry.png`。精選 03、04。三句等長；錯選兩種留證方式都有各自回饋。 |
| ②雙關係進度、缺段灰鈕、齊備黃鈕 | `phone-before_night-relations-empty.png`、`-relations-one.png`、`-relations-a-options.png`、`-relations-chosen.png`。精選 10、11 同屏保留兩段狀態，甲乙選項另有完整原圖。 |
| ③依據箭頭與錯釘局部修正 | `phone-three_voices-wrong-pin.png`、`-judgment-chosen.png`、`-player-results.png`；精選 12、15 可見錯釘原因與三筆完整主張。`-support-one-side.png`、`-support-both-sides.png` 為精選 13、14，補足先前單側不足的缺證。 |
| ④完整浮件、三格預覽與落下相符 | `phone-before_night-drag-preview-1.png`～`-3.png` 與 `-actual-drop-1.png`～`-3.png`，每個落點各有懸停／結果。精選 06～08 為連續三個落點，09 為第三落點的實際放下結果。引用句、遮時欄與格內排列均可讀。 |
| ⑤重開後回看自己的證據鏈及錯選 | 三案 `phone-<案件>-sealed-reloaded.png`、`-chain-reloaded.png`、`-history-reloaded.png`。精選 05、15 顯示「你當時的選擇」與封存結論；三案完整回顧頁均另留原圖。沒有可重新解案的亮色行動鈕。 |

補足 GPT／Claude 的缺證：`phone-second_help-field-0.png`（精選 01）與各案 `-field-<序號>.png` 呈現來源附近的現場；`phone-second_help-paper-b-unmarked.png` → `-paper-b-marked.png`（精選 02）保留乙原件的實際標記。`phone-before_night-placed-0.png`～`-placed-3.png` 各只有一種狀態句；`-drag-cancelled.png`、`-undo.png`、`-tap-alternative.png` 證明取消、撤回及點選補回。`-relation-retry.png` 留存錯選重試；原「指控」選項已移除，改成只留最新乙件，截圖亦按實際決策命名。

封存頁從上方排列，三案使用相同回顧導覽。一般直式推論頁使用「證物／推論／放大」三分頁，關係及釘選頁正確反白推論；矮橫向雙欄依既有策略保留操作區。已選答案採外框，已引用證據保留黃標，主要行動與停用狀態有文字區分。

## 驗證方法與邊界

VERIFIED｜Godot 無頭匯入／解析、主線整合、全部既有測試及新增 `content_r8.gd`，共 **38 套、94,552 項檢查，零失敗**。新增測試逐一比對實際格序、落下結果、雙關係停用、雙引用不足、錯釘修正與歷史存檔。既有測試只更新介面名稱及浮件幾何公式，沒有刪除或放寬斷言。禁則排字、顯示字元、44px 命中、按鈕邊界與重疊守門保留。

VERIFIED｜Web 四種直式尺寸：390×844、320×568、1290×2796、2064×2752，共 **125 張原圖**。手機橫向、矮筆電與平板橫向另由 Godot 九視口矩陣驗證。每個 Web 視口實際觸控完成三案、存檔並冷重載；最後對照原選擇、黃標、關係、引用、釘選與封存狀態完全相同。瀏覽器錯誤、外站請求皆為零，391 個實際顯示字元通過字型覆蓋檢查。瀏覽器紀錄、原尺寸 PNG、來源指紋與雜湊見 [manifest.json](content/r8/manifest.json)、[export.json](content/r8/export.json)。測試與匯出使用相同受管來源快照。

測試隔離於本 repo 的 `.audit-tmp/content-r8/`。原有未提交的 export、touch 等受保護檔，快照使用 HEAD 版本；不納入他人的草稿。街區擷取使用實際 Godot 無頭世界產生的近來源未完成存檔，省略長距離旅行；玩家仍透過畫面互動收件及解案，沒有注入目標案件的完成狀態。最終回歸重新產生的 11 份存檔須與擷取來源雜湊相同，見 [fixture-generation.json](content/r8/fixture-generation.json)。

全程使用工作單指定的 Godot 4.7.stable 與 headless Chromium，無編輯器或可見視窗。Chromium 使用 `--use-angle=d3d11 --enable-gpu --ignore-gpu-blocklist --force_high_performance_gpu`，實際硬體 renderer 記入 manifest。瀏覽器與單一 loopback server 結束後關閉。

新增生成美術 **0 張**，沿用既有案卷、人物、街景及原素材授權；沒有將 UI 排版或浮件冒充新生成美術。人物、地圖、技能及骨架動作本輪未新增，保留既有整合與美術回歸。新增商店原圖 **4 張**：`docs/store/screenshots/{1290x2796,2064x2752}-content-r8-{before_night-relations-chosen,three_voices-support-both-sides}.png`，為同尺寸實拍複本，既有商店圖保留，見 [CONTENT_R8_STATUS.json](store/screenshots/CONTENT_R8_STATUS.json)。

**Apple 4.3 風險：中，產品自評。** 依 2026-10-19 查閱的 [Apple 官方 4.3](https://developer.apple.com/app-store/review/guidelines/#spam)，重複 Bundle ID 及難以區分既有產品都是風險。本作以都市走訪、紙本矛盾、遮時文件關係與雙引用判定形成區隔；仍偏重文字閱讀，也未取得本輪外部複審，不代表商店核准。

**BLOCKED｜Muse ≥8 複審、實體 iPhone／iPad／Android、真人／親子試玩。** 需要實際審查員、裝置與測試者。並發主機量測 3×180 幀，p95 中位數 **16.8ms**，低於 18ms 參考值；這是瀏覽器 RAF 呈現間隔，乾淨機況與實機效能仍待驗證。沒有捏造評分、動作演出、實機或真人結果。

只做本機 commit，不 push、不部署、不操作商店、不派工或傳訊。沒有新增外連、SDK、帳號、廣告、付費或線上功能。秘密掃描與 242 個原有檔案雜湊以最終 verification 為準。

speak-human-tw mode 2：原「直接指控並刪原件」過於送分，改為「暫停付款，留存最新乙件原件」；原「推翻林／陳」容易被讀成人格評價，改為完整主張；原「暫放導引」不清楚，改為「取消街區導引」。原收費引句、虛構姓名機構、時刻與推論界限保持原意。
