# 七期：斷鏈行動｜新內容第九輪

VERIFIED｜0.23.0｜main｜本機修正與驗證完成。最終驗證結果以 `content/r9/verification.json`、`final-tests.json` 與 `manifest.json` 為準。外部 Muse 尚未複審，不自行填入 8 分。

三案共同入口：「暫停 → 查證 → 街坊查證簿・三宗新案」。先按街區導引到來源、互動留存原文，再開始推論。封存後仍能回看證據鏈與錯選；返回街區會導引到來源，看角色處置與原件物件。全程離線，沒有加入廣告、內購、帳號、網路功能或第三方遊戲 SDK。

- 第二次求助，第二次收費：甲乙都要親手標出收費原句，才能比較並封存。乙件標明最新補充，卻沒有撤回甲的承諾，也要求一併核對；付款、只留乙有不同錯因。回美晴車店可見付款狀態、角色回應與兩份原件。封存頁的「付款回放」「單件回放」分別顯示付款未解矛盾、只剩乙件的差異，標明回放且不改封存紀錄。錯選當下也能回街區看尚待修正的處置。
- 晚班之前的收據：先拖原件、再核對兩段具名箭頭、最後揭時並把收據貼回輪值單旁。兩段各顯示原文，錯選直接指出讀反的「附件」或「接班依據」；修正一段保留另一段。浮件完整顯示文件名、引用句、鎖圖示及時間遮蔽標籤。回美晴車店，收據、摘要與輪值三份留存件出現，角色撤回「一定是晚班開的」猜測。
- 三張嘴，一句真話：先配對原話與證物，再判定並釘入紀錄帶。按鈕、時間軸及封存頁使用林秀蘭、陳奕廷、吳安琪全名；玩家合看用雙圈連結，與兩個原始紀錄的單圈區分。只引 17：50 就指出缺末筆 18：10，反之亦然。引用未齊時判定停用；撤回引用只重開合看那一釘，其他釘保留。返回橘盒取件站有吳安琪的更正說法與首末兩份原件。

## Muse 唯一五項驗收

以下全部是 `content/r9/` 下的原尺寸 PNG。手機主圖為 390×844；沒有縮圖、拼貼或後製補字。

| 項目 | 實作與證據 |
|---|---|
| 1 圖形化引用關係 | 具名箭頭和兩份原文同屏。`phone-before_night-relations-a-options.png`、`-relation-retry.png`、`-relations-chosen.png`；揭時印證與貼回：`-revealed.png`、`-attachment-picked.png`、`-sealed.png` |
| 2 完整浮件與三落點 | `phone-before_night-drag-preview-1.png`、`-2.png`、`-3.png`；接續的 `-actual-drop-1.png`～`-3.png` 證明落下與預覽一致，文件文字完整、浮件不蓋排序格 |
| 3 封存後街區結果 | `phone-second_help-street-actual.png`、`-street-payment-replay.png`、`-street-latest-replay.png`。實際封存是暫停付款、留甲乙；另外兩個畫面明標分支行動回放，分別為付款／兩件、暫停／一件，不能當作另兩個正確封存分支。未封存處置另有 `-street-payment-provisional.png`、`-street-latest-provisional.png` |
| 4 全名及合看節點 | 判定：`phone-three_voices-support-both-sides.png`；時間軸：`-wrong-pin-with-two-preserved.png`、`-local-pin-repaired.png`；封存：`-chain-reloaded.png`。合看為雙圈，首末筆為單圈 |
| 5 當前步驟聚焦與真放大 | 第一案標句／決策：`phone-second_help-paper-a-marked.png`、`-action-options.png`；真放大：`-paper-a-magnified.png`。第二案排序／引用／貼回：上述對應圖。第三案單側／雙側／釘入：`phone-three_voices-support-one-side.png`、`-support-last-only.png`、`-support-both-sides.png`、`-player-results.png`。當前決策不超過三個；返回與分頁另列為導覽 |

五項直接開圖：①[箭頭與被讀反的原文](content/r9/phone-before_night-relation-retry.png)；②[落點一](content/r9/phone-before_night-drag-preview-1.png)、[落點二](content/r9/phone-before_night-drag-preview-2.png)、[落點三](content/r9/phone-before_night-drag-preview-3.png)；③[實際處置](content/r9/phone-second_help-street-actual.png)、[付款回放](content/r9/phone-second_help-street-payment-replay.png)、[單件回放](content/r9/phone-second_help-street-latest-replay.png)；④[完整姓名與雙圈合看](content/r9/phone-three_voices-chain-reloaded.png)；⑤[放大原件](content/r9/phone-second_help-paper-a-magnified.png)、[雙側引用階段](content/r9/phone-three_voices-support-both-sides.png)。

`content/r9/review-set/` 固定 15 張手機原圖複本，三案各五張；第二案連續三張拖曳落點，每案都有操作進行中畫面。來源與 SHA-256 在 `review-set.json`，供審查員直接核對。

## 補上上一輪未見證據

| 未見項目 | 手機原圖（相對 `content/r9/`） |
|---|---|
| 甲原件標記、只留乙的專屬錯因 | `phone-second_help-paper-a-marked.png`、`phone-second_help-action-latest-only-retry.png` |
| 第一案付款錯因 | `phone-second_help-action-payment-retry.png` |
| 第二案零至三張、取消、撤回與點選補回 | `phone-before_night-placed-0.png`～`-placed-3.png`、`-drag-cancelled.png`、`-undo.png`、`-tap-alternative.png` |
| 第二案關係錯選重試、貼回才封存 | `phone-before_night-relation-retry.png`、`-relations-chosen.png`、`-attachment-picked.png`、`-sealed.png` |
| 第二、三案來源現場及各自街區收尾 | `phone-before_night-field-0.png`～`-field-2.png`、`-street-result.png`；`phone-three_voices-field-0.png`～`-field-2.png`、`-street-result.png` |
| 局部拔釘不影響另外兩釘 | `phone-three_voices-local-pin-unpinned.png`、`-wrong-pin-with-two-preserved.png`、`-local-pin-repaired.png` |
| 三案完整封存、證據鏈、錯選頁 | 每案的 `phone-<案名>-sealed-reloaded.png`、`-chain-reloaded.png`、`-history-reloaded.png` |
| 真正放大 | `phone-second_help-paper-a-marked.png` 對照 `-paper-a-magnified.png`，原件字級提高 |

十五張精選無法收納所有輔助狀態；完整圖集保留以上操作與重載證據。測試數字由機器報告提供，截圖只能證明畫面狀態，不能代替測試輸出。

## 驗證方法與邊界

`tools/test_game.py` 在排除他人草稿的來源快照執行全部既有測試及新增 `content_r9`；既有斷言未刪除或放寬。`content_r1` 只更新實際改名的箭頭／全名按鈕，仍逐顆點選並檢查完成和存檔。新增測試涵蓋三案完成、磁碟一致性、回放不修改封存、單側缺件、局部修復，以及手機／橫式／平板版面。

Web 由 Godot 無頭匯出，再由 headless Chromium（每次僅一個，依序執行並關閉）使用 NVIDIA ANGLE D3D11 實際觸控操作；測試期間沒有可見視窗。六種原尺寸為 320×568、390×844、1290×2796、2064×2752、844×390、1024×768，已全部通過，共 155 張原尺寸截圖。離線路由守門、44px 命中、文字／按鈕邊界、按鈕互不重疊、拖曳落點及 IndexedDB 冷重載都由腳本檢查。

遠距離移動使用無頭世界產生的來源附近存檔；每個目標案件仍未完成，由瀏覽器實際取證、排序、判定和封存。街區收尾只搬移角色與鏡頭到來源，沿用該瀏覽器剛完成的同一份紀錄。這不是全程連續步行或實體裝置測試。原始方法、來源雜湊與逐張狀態保留於 `manifest.json`。橫式導覽曾誤找收起的放大分頁，已改走實際可見的案件清單／證物入口並重測；彙整只保留相同 PCK 的成功尺寸，`capture_runs` 留存各批狀態與雜湊，所有觸控、文字、完成及重載斷言仍啟用。

商店新增 `docs/store/screenshots/1290x2796-content-r9-before_night-relations-chosen.png`、`2064x2752-content-r9-before_night-relations-chosen.png`，均為 Web 實際操作原圖，未刪除舊圖。本輪新增生成美術為 0，沿用原有美術；紙張物件、箭頭、鎖與雙圈是遊戲資訊與既有材質的應用，不宣稱新角色或新動畫。沿用素材雜湊見 `art-reuse.json`。

效能為併發負載下的三跑 RAF p95 中位數，僅供參考，不冒充原生 GPU 或乾淨機況出貨數據。三跑 p95 中位數為 16.8ms，低於本輪 18ms 參考值；確切數字見 `verification.json`。

## 文案修訂摘要

依 speak-human-tw mode 2 直接修訂，虛構原文的收費句、案號、時間及推論界線保留。

| 原句／問題 | 原因 | 改成 |
|---|---|---|
| 摘要引用收據／收據引用摘要 | 需要比語序，負擔高 | 車店收據 → 交接摘要，對照實際引用詞組 |
| 分界整點不能證明前後都有 | 與玩家只選 17：50 不符 | 已引用 17：50，只有分界前；還缺末筆 18：10；反向另有提示 |
| 你當時的選擇出現兩次 | 最後結果與錯選混淆 | 最後封存選擇／這次錯選 |
| 反駁林／陳、支持吳 | 名稱不完整 | 全名加主張，時間軸與回顧一致 |
| 中性指引、浮件、封存標題也用紅 | 錯誤失去辨識度 | 改為炭墨；逐句紅字清單見 `red-text.json` |

## 未完成與風險

BLOCKED：實體 iPhone／iPad／Android 與真人試玩需要裝置及測試者；乾淨機況效能需要獨立量測時段；Muse 8 分以上需要外部複審。未進行原生包驗收、商店操作、部署、push 或對外傳訊。

Apple 4.3 風險：中。三案已用文件矛盾、引用排序和雙側紀錄區分操作，並加入街區結果，但仍共享查證簿框架，實際節奏與可讀性需要真人試玩及商店審查判斷。本機不將此評估當作上架核准。

第一案另兩個錯誤行動仍不能封存；封存後提供的是清楚標示的分支回放，不把錯選改成正確結局。255 個既有修改／未追蹤檔以雜湊核對，保持原樣；只提交本輪明確檔案，不讀取秘密目錄。
