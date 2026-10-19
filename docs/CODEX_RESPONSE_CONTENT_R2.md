# 七期：斷鏈行動｜新內容第二輪

2026-10-19，main，版本 **0.16.0**。依 `docs/content/CONTENT_REVIEW_R1_MUSE.md` 五項清單修整三案。可執行流程與原尺寸畫面以本輪驗證紀錄為準；原生實機、乾淨機況效能、真人口述與新的 Muse 8 分複審維持 BLOCKED，沒有宣稱可以上架。

## 三案做了什麼、怎麼進入

共同入口：「暫停 → 查證 → 街坊查證簿」。不須主線通關、帳號或等待日期。案卷保留「待訪來源 → 到現場 → 取得證物 → 推論」，街區顯示來源、步數與靠近互動提示。必須下車、三公尺內互動才能留證；清單不能領取文件。暫放導引可回原任務。

| 內容 | 本輪修改與玩法 | 原尺寸手機圖 |
| --- | --- | --- |
| 第二次求助，第二次收費 | 到美晴車店與旁邊留證桌取得岸七同案文件。先比對「不收預付費／先付代辦費」，再選現在的安全行動；第一層答對只保存判斷，不封存。干擾改為後發通知取代承諾、同案號足以證明身分等證據不足的推論。錯選兩層都能重試。封存列出矛盾、停止付款與留證行動、不能確認身分或保證追回的界限。 | `docs/content/r2/phone-second_help-compare.png`、`phone-second_help-action.png`、`phone-second_help-action-retry.png`、`phone-second_help-sealed.png`，均在同目錄。 |
| 晚班之前的收據 | 三張時間牌固定打亂為丙 18：00、甲 17：42、乙 17：55，牌下寫側門晚班單、車店收據、交接摘要。閱讀時間與來源重排；已排區逐行寫事件，可撤回。封存顯示收據早於晚班，不能指認經手人或推定哪班涉案。 | 同目錄 `phone-before_night-unsorted.png`、`phone-before_night-wrong.png`、`phone-before_night-undo.png`、`phone-before_night-arranged.png`、`phone-before_night-sealed.png`。 |
| 三張嘴，一句真話 | 林秀蘭、陳奕廷、吳安琪的原件可逐張重讀，查證點對齊實際角色位置。封存以三行列出證人說法、玩家實際選用的文件、支持／推翻，再列推論界限。完整索引仍可反駁兩句「全部」，畫面直接示範兩種有效反證，不硬判錯。 | 同目錄 `phone-three_voices-statement-0.png`、`phone-three_voices-statement-1.png`、`phone-three_voices-statement-2.png`、`phone-three_voices-index-accepted-0.png`、`phone-three_voices-index-accepted-1.png`、`phone-three_voices-sealed.png`。 |

人物、機構與案件全部虛構；文案只談辨認矛盾，沒有可照做的施詐步驟、真實帳號或付款連結。三案保持離線、免費、無廣告、無內購、無外部連結、無第三方 SDK、無帳號或線上功能；沒有加每日任務、徽章或技能樹。

## 五項驗收與證據界限

1. **效能：BLOCKED。** 依本輪明示不重追並發桌機數字。前輪 Web RAF 手機／桌機 p95 為 16.7／83.4ms，來自 `docs/content/r1/screenshots/manifest.json`，不是本輪新實測；NVIDIA 共享 GPU 的干擾對照在 `docs/evidence/r10-art/performance-investigation.json`。**並發載量測，僅供參考。** 乾淨機況 p95 ≤18ms、Android 與 iPhone／iPad 原生實機仍缺；需要獨占測試時段及裝置。沒有用截圖或瀏覽器數字冒充原生證據，保持不可上架判定。
2. **現場流程：實作與自動操作 VERIFIED；真人口述 BLOCKED。** 第一案 `phone-second_help-pending.png → phone-second_help-field-0.png → phone-second_help-original-0.png`，另有 `field-1／original-1`；第二案 `phone-before_night-pending.png → phone-before_night-field-1.png → phone-before_night-original-1.png`；第三案 `phone-three_voices-pending.png → phone-three_voices-field-0.png → phone-three_voices-original-0.png`。後者另有 `field-1／original-1` 的陳奕廷、`field-2／original-2` 的吳安琪。全部位於 `docs/content/r2/`，都是實際街區、來源與取得後原文。未參與開發者能否說出去處、向誰留證，仍需真人試玩。
3. **時間線：VERIFIED。** Godot 新開十次與手機可見 UI 重新開案十次皆非正序；瀏覽器紀錄含十次實際牌面次序，0 次由早到晚。錯排不完成，撤回後按時間正排才能封存。證據為第 2 案五張直式圖及 `docs/content/r2/manifest.json` 的 `timeline_ten_ui_opens`。
4. **空白與案件識別：畫面與版面 VERIFIED；遮題口述 BLOCKED。** 案卷改為依內容高度置中的紙頁，取消把頁腳推到底的大片空紙。三張專屬圖分別突出雙文件、三收據、收件簿；原文與來源使用真字型排字。390×844 為三張 `phone-*-sealed.png`；1290×2796 為同目錄 `phone-second_help-sealed-1290x2796.png`、`phone-before_night-sealed-1290x2796.png`、`phone-three_voices-sealed-1290x2796.png`。沒有請真人遮住標題辨識，因此不冒稱該口述驗收通過。
5. **第一案深度、第三案可讀性：實作與保存 VERIFIED；完成時間／複述 BLOCKED。** 第一案第一層、錯誤回饋、第二層與錯誤行動均有圖，且第一層 IndexedDB 冷重載後仍未封存。第三案三句頁與結果對照均有圖；索引反證先被接受並保存，再換配首筆／末筆；封存列出最後的配對。十秒內是否能猜完、完成後能否複述兩組結果，需要未參與開發的玩家；目前沒有真人測試資料。

冷重載的可見讀回：同目錄 `phone-second_help-action-reloaded.png`、`phone-case-list-reloaded.png`、`phone-second_help-sealed-reloaded.png`、`phone-before_night-sealed-reloaded.png`、`phone-three_voices-sealed-reloaded.png`。第一張仍停在第二層，後四張顯示封存進度已保留。

第一案的資料替換實證：`phone-second_help-data-swap-original.png` 與 `phone-second_help-data-swap.png`，皆在 `docs/content/r2/`。隔離匯出只把 JSON 的虛構機構「澄岸協助所」換為「晴橋協助所」、案號「岸七」換為「橋七」，不改 UI 或答案程式；從正常案件入口讀到替換原文與推論。來源、PCK、原圖雜湊及正式來源已還原的檢查在 `data-swap.json`。這是開發資料替換驗證，商店圖使用正式資料包。

詳細缺件：`docs/content/r2/limitations.json`。未新增動畫或物理效果，不以靜態插圖宣稱動態效果。

## 測試、畫面與保存

VERIFIED：完整 **32 套、28,371 項、零失敗**，含匯入／解析、主線整合與所有既有回歸。新 R2 測試 4,523 項；第一輪內容測試加強後 6,814 項。定稿讀回在 `docs/content/r2/verification.json`，逐套原始輸出在 `final-tests.json`；來源與 PCK 指紋在 `export.json`，每張原圖、實際狀態、尺寸及 SHA-256 在 `manifest.json`。

Godot 使用指定執行檔，實際為 4.7 stable／5b4e0cb0f。僅 `--headless` 匯入、解析與遊玩；Web 使用 headless Chromium、NVIDIA ANGLE D3D11 及指定四旗標。沿用 repo 的 Playwright 自動操作，單一 browser／server，完成後關閉。沒有開編輯器或可見視窗。

既有斷言保留，第一輪第一案測試加上「第一層未封存、第二層才完成」，沒有刪測試或放寬門檻。新測試涵蓋十次非正序、兩層防跳步、錯誤重試、中途原子存檔、磁碟重讀、舊版已封存進度、無效狀態拒絕、實際世界取證、正常讀檔後來源仍在三公尺內，以及十種 Godot 無頭版面。VERIFIED：九種 Web 視口、264 張正式資料原圖，另有兩張純 JSON 替換圖，共 266 張原尺寸 PNG。Web 多視口逐案實際點按錯選、撤回、配對、封存、磁碟讀回及 IndexedDB 冷重載；正文、返回與 44px 控制守門不變，手機沒有鍵盤提示。

Web 遠距旅行使用無頭世界實際產生的近來源存檔，經公開 `Engine.copyToFS` 放入隔離瀏覽器後正常讀檔；目前要解的案件在每份 fixture 中都尚未完成，取證與解題均用可見按鈕；先前案件可能保留 Godot 測試的已完成進度，沒有把它算作這次按鍵操作。每案在完成當下另驗磁碟讀回，不靠最後一張清單代替三案實玩。每個原始存檔皆記錄雜湊。舊版已封存案件沿用完成狀態；「安全行動」列示案件建議，不追溯宣稱舊玩家點過新步驟。這證明讀檔、來源距離、互動及解題可達，沒有宣稱以輸入走完所有長距離路線，也不是原生 iOS 截圖。

實拍曾抓到 568×320 時間線答錯後提示擠出返回鈕，已讓短橫向提示共用指示列，並新增錯排與撤回版面守門。也抓到留證桌附近的存檔被安全重定位、原鏡頭背對車店，已改為桌前安全位置，並以正常存檔讀回驗證距離。新畫面也抓到冷重載後未恢復全畫布造成捕圖點位錯誤，捕圖器已重回全畫布再按可見按鈕；沒有改遊戲判斷來繞過。

## 美術、商店圖與保留

新增 **3 張生成母圖、3 張 runtime 衍生圖**；實際工具 **image_gen.imagegen**，模型 slug 未揭露，記 null。完整共同前綴、prompt、母圖、尺寸與雜湊在 `assets/art/content-r2/`、`docs/art/PROMPTS.json`。母圖為無損 WebP，runtime 768×512 WebP；只有這三張 UI 圖採 lossy 0.62、無 mipmap。沒有新增 3D 佔位模型或把既有角色算成新美術。Web PCK **26,186,368 bytes**，保留既有 25 MiB 上限；沒有放寬打包守門。

新增商店圖保留所有舊圖：`docs/store/screenshots/{1290x2796,2064x2752}-content-r2-{second_help-field-0,second_help-action,before_night-unsorted,three_voices-sealed}.png`，各為實際 Web 原尺寸，沒有拼貼、縮放或加偽造裝置框。清單與雜湊在 `CONTENT_R2_STATUS.json`。

受保護的 `.gitignore`、`export_presets.cfg`、`touch_controls.gd`、qa、native、workflow 及既有未追蹤檔保留；測試與匯出採隔離來源，保護檔使用 HEAD，沒有借用他人修補。秘密掃描的指定格式命中為 0、實際憑證為 0。既有掃描器另把未變更的 `dusk-sky` Godot 匯入快取參照誤判兩筆；保留原掃描器，逐筆與 HEAD 及完整快取格式比對，結果列在 `verification.json`。共核對 3,296 個 prospective tracked 檔案。只用明確路徑 stage，本機繁中 commit，沒有 push、部署、操作商店、發訊息或派工，未讀取憑證目錄。

**Apple 4.3 風險：中，屬本輪推論。** 本款以街區取證、時序重建、證詞交叉核對與推論界限形成自己的玩法，改善純問答的商店印象；仍需獨立玩家辨識與原生證據。Apple 4.3 要求應用有足以區別既有作品的體驗，免費與 MIT 不等於通過；本輪沒有代替 Apple 作核准判斷。[Apple 官方審查準則 4.3](https://developer.apple.com/app-store/review/guidelines/#spam)

繁中依 speak-human-tw mode 2 校對兩類問題：「紙色不同／有通知就可信」的干擾太弱，改為文件效力與身分推論；「一段塞三組時間」難以回看，改為逐人對照實際選用證物與結果。虛構事實、時間與推論界限保留。
