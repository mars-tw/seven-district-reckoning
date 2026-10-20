# 七期：斷鏈行動｜新內容第十四輪

PREPARED｜main｜0.27.0 → 0.28.0。已讀共用規則、AGENTS、game-optimization-round、token-efficient-ai-dispatch、繁中文案規則、美術方向、R12／R13 三位評審及最近交付。只修原三案，不新增案件；本機提交，不派工、不推送、不開可見視窗。

入口：暫停 → 查證 → 街坊查證簿・三宗新案。

| Muse R13 唯一驗收清單 | 設計與驗收 | 預計檔案／原尺寸證據 |
|---|---|---|
| 1．街區短標可讀 | 原件固定貼在展示板，脫離鏡頭追隨；不遮人物。紙上只保留件名／大時間。第三案左 17：50、中 18：00 分界、右 18：10；分界明示非原件。390×844 正常距離讀得出件名與時間。 | investigation_field.gd；phone-*-street-result.png |
| 2．第三案步驟 2 時間軸 | 同框提供橫向原件時間／18：00 分界與三人原話；各原件分開說明誰記錄、記錄誰的話。判定成功後才解釋時間如何反證「全部」，候選不預配正確時間。選項墨字淺紙，對比 ≥4.5:1；只有缺條件的釘上鍵停用。 | investigation_panel.gd、content_investigations.gd；phone-three_voices-*.png |
| 3．第二案真拖放 | 拿起後拖收據到丙件框，錯位退回並提示「位置不對」；點按落點不能完成。三張全揭前連線只寫待核對，全揭才顯示相符；封條加紙纖維、撕口、投影與掀角。 | investigation_panel.gd、investigation_time_mask.gd、investigation_links.gd；phone-before_night-attachment-{dragging,rejected,sealed}.png |
| 4．第一案完整原件找句 | 保留完整原件每句與上下文，親手標句；已標 1／2 同框可見，錯句只提示「這句不是收費條件」。原件返回保留紅框、黃標，第二錯選顯示完整對照。 | investigation_panel.gd、content_investigations.gd；phone-second_help-{marked,returned-error,second-error}.png |
| 5．街區下一步與證據補齊 | 街區直接可見目前案件與下一步；列表同框三案、完成狀態與入口。既有底部插畫加入隨案件揭時／標記／封存改變的實際標記，避免重複摘要。補乙丙揭時、錯釘／局部修復及冷重載。 | game_hud.gd、investigation_panel.gd；phone-*-progress.png、phone-case-list.png |

介面收斂：刪除候選上的預配答案與重複摘要，保留原件、判定與結果的層級；不縮小必要正文。44px 觸控、直橫手機與平板、紙卡下緣安全區、全名、狀態色與封存分頁維持回歸。既有美術沿用；必要封條紋理由 image_gen.imagegen 產生並記錄實際工具與提示。

測試：新增 tests/content_r14.gd；既有測試隨真拖放更新輸入步驟，保留原完成／存檔／版面斷言。隔離快照只取他人已修改追蹤檔的 HEAD；全 Godot 無頭匯入／解析、整合、歷史回歸。Web 單一 headless Chromium，指定 D3D11 旗標，六視口實玩、完成／存檔與冷重載；三跑 p95 ≤18ms 僅並發參考。保留 owner 草稿 SHA-256。

證據：docs/content/r14/ 原尺寸 PNG，review-set 精選 15 張、每案 5 張且有遊玩中畫面；新增 1290×2796、2064×2752 商店圖，不刪舊商店圖。逐一對照唯一清單與精選圖號。舊證據只刪已追蹤且未改動、已被取代又不被驗證器讀取的檔案；先建立清單、參照與雜湊收據，再刪，列檔案數與 bytes，之後重跑全部測試。所有舊 Markdown、評審、既存未追蹤檔與必要輸入保留。

BLOCKED：實體手機／iPad、真人試玩、乾淨機況原生效能與 Muse 實際複評需設備／測試者／審查員；320×568 街區互動缺鍵涉及明確禁止修改的 touch_controls.gd，保留並如實報告。不得宣稱達成外部 8 分。秘密掃描零命中、版本更新、保護檔不變後，每批最多十個明確路徑加入本機繁中 commit。

EXECUTED：補入 `CREDITS.md`、`LICENSE-ASSETS.md` 的新封條來源／授權；小手機放大頁把原件切換併入頁籤列，窄橫向把較長的版次與發文說明放在紙面全寬，保留原句與 44px 操作。時間線按各張封條的實際步數揭露，先揭乙件也不會露出甲件時間。灰階證據由 Chromium 視覺模擬直接擷取。

VERIFIED：最終 44 套、143,008 項檢查零失敗；六視口完成並冷重載。完整來源雜湊、精選原圖與保留／刪除收據以 `docs/content/r14/verification.json`、`acceptance.json`、`cleanup.json` 為準。外部與保護檔造成的 BLOCKED 維持如上。
