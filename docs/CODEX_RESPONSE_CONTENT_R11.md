# 七期：斷鏈行動｜新內容第十一輪

VERIFIED｜0.25.0｜main。41 套、127,916 項檢查全綠；六個 Web 視口皆實際完成三案並通過冷重載。163 張原尺寸截圖、15 張精選、2 張商店圖；秘密掃描零命中，261 個既存未提交檔案雜湊未變。依本線最後指定，本輪只修四項嚴重問題，沒有新增案件、角色、骨架動作或美術。數字與來源見 `content/r11/verification.json`、`final-tests.json`、`manifest.json`。

共同入口：「暫停 → 查證 → 街坊查證簿・三宗新案」。三案仍接在既有走訪取證流程，離線自動保存。只做本機提交，沒有推送、部署、操作商店後台或對外派工。

| 案件 | 做了什麼、怎麼玩 |
|---|---|
| 第二次求助，第二次收費 | 入口選同名案。走訪留存甲乙、親手標出收費句後決定處置。兩種錯選各以「你選的」及朱紅框標出對應按鈕，與錯因直條同色；從已保存的選擇歷史還原標記。保留兩份、暫停付款才封存。 |
| 晚班之前的收據 | 入口選同名案。拖曳三份遮時原件、選引用方向、揭時印證，再拿起收據貼回。拿起後甲卡改為「已拿起・點右側貼入」，不再同時要求拿起；步驟二保留證物／推論／放大，三步從同一頂端排版。小尺寸收緊留白，保留 44px 點擊區，保護「摘要」「反查依據」詞組。 |
| 三張嘴，一句真話 | 入口選同名案。配對原話後，引用首末兩份原件、判定並釘入紀錄帶。索引、欄位、判定與結論一致標示 17：50／18：10 是原件、18：00 是分界；吳安琪提供的索引只供定位，判定仍須首末原件。沒有把索引當作第三份原始紀錄。 |

## 四項驗收與原尺寸截圖

以下路徑以 `docs/content/r11/` 為基準，未註尺寸者皆為 390×844 原圖。

| 指定問題 | 原圖與驗收 |
|---|---|
| 拿起前後文字衝突 | `phone-before_night-revealed.png`、`phone-before_night-attachment-picked.png`、`phone-before_night-sealed.png`：未拿／已拿／已貼回。拿起不封存，貼回才完成。精選 08～10。 |
| 錯選處置沒有選取標記 | `phone-second_help-action-payment-retry.png`、`phone-second_help-action-latest-only-retry.png`：分別標出不同按鈕，未選鈕維持原樣；各有對應錯因。精選 02、03。 |
| 索引與「沒有第三筆原件」矛盾 | `phone-three_voices-support-one-side.png`、`phone-three_voices-support-both-sides.png`、`phone-three_voices-chain-reloaded.png`：索引提供者、定位用途、非原件的分界，與封存鏈一致。精選 11、12、14。 |
| 第二案分頁消失、版面跳動 | 390×844：`phone-before_night-shuffled.png`、`phone-before_night-relation-retry.png`、`phone-before_night-attachment-picked.png`。320×568：`phone-before_night-shuffled-320x568.png`、`phone-before_night-relation-retry-320x568.png`、`phone-before_night-attachment-picked-320x568.png`。兩尺寸三步標題與三分頁的 y 差實測均為 **0px**，數字在 `r11-acceptance.json`。精選 06、08、09 顯示一致分頁。 |

歷史 R10 修正前原圖留在 `before/`，來源及雜湊寫於該目錄 manifest；這些明確是舊版對照，不列為本輪重拍。

## R9／R10 回歸與未見證據補圖

| 回歸項目 | 本輪原圖，仍以 `docs/content/r11/` 為基準 |
|---|---|
| 甲件未標、親手標記、實際放大 | `phone-second_help-paper-a-unmarked.png`、`paper-a-marked.png`、`paper-a-magnified.png`（後兩檔同樣有 `phone-second_help-` 前綴）；精選 01 放已標原件。 |
| 兩種錯因、兩件並存及回放識別 | 精選 02～05；`phone-second_help-street-latest-replay.png`、`phone-second_help-sealed-reloaded.png`。回放持續褐色罩及蓋章，實際處置恢復原色，退出不改封存。 |
| 三落點、實際落下、取消、撤回與補放 | `phone-before_night-drag-preview-1.png` 至 `drag-preview-3.png`、`actual-drop-1.png` 至 `actual-drop-3.png`、`drag-cancelled.png`、`undo.png`、`tap-alternative.png`（皆有 `phone-before_night-` 前綴）；320×568 另有三落點圖。 |
| 三文件連線、錯段無勾、兩段專屬錯因、局部修復 | 精選 06；`phone-before_night-relation-b-retry.png`、`phone-before_night-relations-chosen.png`。揭時在兩段正確後才開放，修一段保留另一段。 |
| 真正逐張揭時、貼回才完成、街區收尾 | `phone-before_night-revealing-1.png`、`revealing-2.png`、`revealed.png`、`attachment-picked.png`、`sealed.png`、`street-result.png`（皆有 `phone-before_night-` 前綴）。精選 07、08 為兩格連續揭時，08～10 為拿起前後及封存；三格揭時完整序列及街區收尾另列補充。 |
| 單側兩種缺件、雙側、全名及原始紀錄／推論分層 | 精選 11、12、14；`phone-three_voices-support-last-only.png`、`phone-three_voices-judgment-before-pin.png`。 |
| 局部拔釘、另兩釘保留、修復與更正說法 | 精選 13 為重釘錯誤時另兩釘保留的同框圖，15 為橘盒站收尾；`phone-three_voices-local-pin-unpinned.png`、`phone-three_voices-local-pin-repaired.png` 補完整前後狀態。拔釘判定頁本身仍沿用既有版型，沒有冒稱已新增同框紀錄帶。 |
| 完成與冷重載 | 三案各自 `phone-<案號>-sealed-reloaded.png`、`chain-reloaded.png`、`history-reloaded.png`，以及 `phone-case-list-reloaded.png`。自動比對三案完整結果、錯選歷史與引用，不只確認完成旗標。 |

精選集嚴守十五張、每案五張，圖檔與來源雜湊在 `review-set.json`。十五張無法同時容納全部補充證據；沒有把上表補充圖冒稱審查員已看到。既有角色姿勢、紙張數量與文字回應不算新演出。

## 測試、商店與保留範圍

VERIFIED：40 套 Godot 無頭檢查及 1 套既有 JS 檢查，共 127,916 項、零失敗；既有測試未刪除或放寬。含九視口排版與新增三案存檔／狀態測試。Web 六視口為 390×844、320×568、1290×2796、2064×2752、844×390、1024×768，皆通過實際操作、錯選重試、完成、冷重載、44px 命中、界內／不交疊、中文排字及禁止遠端請求守門。結果寫於 `verification.json`、`final-tests.json`、`manifest.json` 與 `secrets-scan.json`。

揭時另用同一 PCK 做第二案單獨補拍，以實際已揭張數 1／2／3 作為截圖時機，取代最初以固定延遲取樣的三格。只替換這三張原尺寸 PNG，來源雜湊、相同目標進度與方法列在 manifest 的 `reveal_recapture`；原六視口完成／重載證據與並發效能數據保留，不把單案補拍說成三案重測。

測試／匯出取用同一隔離快照；受保護的設定與觸控腳本採 HEAD，沒有借用或改寫其他線路草稿。Web 沿用從真實無頭世界產生的未完成、來源附近存檔，目標案以可見觸控控件完成；沒有灌入目標完成狀態，也不宣稱連續徒步走完整個街區。截圖使用 headless Chromium 及工單 GPU 旗標，僅為本機 Web 證據。

新增商店原圖為 `docs/store/screenshots/1290x2796-content-r11-before_night-relations-chosen.png` 及 `2064x2752-content-r11-before_night-relations-chosen.png`，已逐檔核對尺寸與原圖雜湊。既有商店圖不刪。新增生成美術 **0**，沿用既有合法紙材、人物、場景與骨架。

並發載下三次各 180 幀的瀏覽器 RAF 呈現間隔，p95 中位為 **16.8ms**；這是參考數據，不代替實體裝置或乾淨機況的 GPU 出貨效能。四個目前版本識別一致為 0.25.0；測試、匯出及截圖 PCK 的來源綁定已核對。

## 文案修改

| 原句 | 原因 | 改成什麼 |
|---|---|---|
| 拿起後仍顯示「點選拿起收據」 | 同屏狀態不一致。 | 拿起後顯示「已拿起・點右側貼入」。 |
| 三個處置鈕沒有選取文字 | 無法對應玩家的錯選。 | 只在實際錯選鈕前加「你選的｜」，以朱紅框連回錯因。 |
| 「17：50／18：00／18：10」「中筆：18：00」 | 把分界寫成第三筆原件。 | 原件：17：50、18：10；分界：18：00（非原件）。 |
| 「索引支持」「與三筆時間相符」 | 來源與證據層級混淆。 | 吳安琪提供的索引只供定位；合看首末兩份原件才支持主張。 |

## 未完成與風險

Apple 4.3 風險自評 **中**：三案有不同操作，但共用查證簿與文字判定的節奏仍相近；這是本輪風險判斷，不是 Apple 審核結果。

BLOCKED：實體 iPhone／iPad／Android、真人試玩需設備、原生包與測試者；乾淨機況效能需排除其他線路負載，並發載三跑 p95 僅參考。Muse 真正複評需審查員看精選集，本輪禁止對外派工，不能自行宣稱 8 分。

依本線「只修四項」限制，R10 Muse 五項延伸建議（新增街區處置演出、決策頁重開完整原件、放大引用圖、改寫第三案按鈕層級、錯選後強制回看）未納入；Claude 第五項的判定頁同框紀錄帶及菱形減號也沒有改動。這些既有品質缺口仍保留，不以補截圖冒充已實作。
