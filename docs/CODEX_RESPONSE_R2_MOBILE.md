# R2 手機優先內容優化報告

- 日期：2026-10-15。版本：**0.6.0**。狀態：**VERIFIED**（內容／控制／正式回歸）；實機與出貨效能為 **BLOCKED**。
- 範圍：只修改本 repo，只用無頭 Godot／Chromium，只做本機 commit；未 push、部署、操作商店或傳訊息。
- 計畫：[OPTIM_PLAN_R2.md](OPTIM_PLAN_R2.md)。沒有本 repo 的 `CLAUDE.md` 或 `AUDIT_full.md` 可讀；以現有 R1 報告接續。

## 三項主要成果

1. **三份可玩的章節回訪**：從暫停「行動 → 章節回訪」或「委託 → 章節回訪／人物後記」接下。每份走三站，先取得現場線索、到第二站核對二選一，再親自回集合點。只有步行靠近站點才能推進；錯答可重選，取消會恢復主線導引。
2. **收集與重玩**：依序完成才解鎖下一份，收錄美晴、予安、周成的三頁後記；各自保存完成次數與最佳用時，依本機日期輪替推薦已解鎖路線。沒有額外金錢獎勵，避免讀舊存檔刷錢。收藏存在獨立的 `user://seven-district-revisits-v1.cfg`，與既有章節存檔分開。
3. **手機移動與互動**：左下搖桿、右下動作鍵保留雙拇指配置；互動鍵依現場顯示「交談／記錄／核對」。按下變色、拖離取消，同一手指取消後不會變成鏡頭拖曳。失焦、轉向、暫停、背景通知都釋放輸入。短教學在移動及互動後收起；暫停改為行動／進度／其他三頁，返回與繼續固定在內容區外。

回訪為第一章的補充事件，沒有新增完整第二章、敵人或戰鬥動畫。新導航沿用光柱、距離與地圖；角色、模型與音效使用既有素材。

## 驗證與證據

| 項目 | 狀態／證據 |
|---|---|
| 最終完整回歸 | **19 組／9,923 項／0 失敗**；R2 新增 1,280 項。見 [final-source-checks-summary.txt](evidence/r2-mobile/final-source-checks-summary.txt) 與 [逐 suite 結果及來源指紋](evidence/r2-mobile/final-source-checks.json) |
| 新內容與觸控 | `tests/r2_mobile.gd` 已納入正式 runner；實際 Root／物理互動、三路線九站、錯答與重試、後記讀回、解鎖、重玩、存取及損壞資料、暫停計時、多指與鏡頭取消、背景釋放、手機動詞提示 |
| 站點可達 | 真實場景碰撞膠囊從出生點建立連通步行網格；九站均有連通且可站立的互動位置。整合流程會擺位到已驗證位置，並非真人全程步行試玩 |
| 控制可達 | 390×844、844×390、1366×600、1280×640；暫停三頁、回訪頁按鈕 ≥44px、在畫面內且無重疊，暫停頁無須捲動；其他主要選單的固定返回列可見。既有地圖／文化活動可操作區斷言維持不變 |
| 啟動與取消 | [supplemental-tests.json](evidence/r2-mobile/supplemental-tests.json)：responsive startup、mid-cancel gap、startup streaming 三組通過 |
| 字型／素材 | [font-and-assets.json](evidence/r2-mobile/font-and-assets.json)：新字零缺漏，OFL 子集 279,588 bytes；未生成新 2D／3D／音訊，`image_model_slug` 為 null |
| 版本 | [version-audit.json](evidence/r2-mobile/version-audit.json)：活躍 Godot／Web 設定均為 0.6.0；舊版只留歷史報告、before 證據與素材署名 |
| 秘密與原有工作 | [secret-scan.json](evidence/r2-mobile/secret-scan.json) 零命中；[publication-scan.json](evidence/r2-mobile/publication-scan.json) 零發現；[original-worktree-integrity.json](evidence/r2-mobile/original-worktree-integrity.json) 核對原有檔案保留。匯出設定只提交本輪版本兩行 |

完整 runner 指令：`python tools/test_game.py --godot <Godot 4.7.2 console>`。全程 `--headless`，測試資料隔離，不使用玩家存檔。最終來源快照移除他人未提交的原生匯出區段、恢復原本觸控檔案，再加入本輪變更，因此本輪的背景釋放不依賴他人的 patch。

Web 驗證另修正載入介面引用了匯出排除的完整字型，改用隨包子集；允許引擎產生的 blob 圖片，修正實際瀏覽器 CSP 錯誤。after 的三個視口均檢查 console／pageerror。

## 無頭實際算圖證據

| 視口／畫面 | before | after |
|---|---|---|
| 390×844 遊戲中 | [before](evidence/r2-mobile/before/390x844-gameplay.png) | [after](evidence/r2-mobile/after/390x844-gameplay.png) |
| 844×390 遊戲中 | [before](evidence/r2-mobile/before/844x390-gameplay.png) | [after](evidence/r2-mobile/after/844x390-gameplay.png) |
| 390×844 暫停 | [before](evidence/r2-mobile/before/390x844-pause.png) | [after](evidence/r2-mobile/after/390x844-pause.png) |
| 844×390 暫停 | [before](evidence/r2-mobile/before/844x390-pause.png) | [after](evidence/r2-mobile/after/844x390-pause.png) |
| 1366×600 暫停 | [before](evidence/r2-mobile/before/1366x600-pause.png) | [after](evidence/r2-mobile/after/1366x600-pause.png) |
| 手機回訪入口 | 原版無此內容 | [直向](evidence/r2-mobile/after/390x844-revisits.png)／[橫向](evidence/r2-mobile/after/844x390-revisits.png) |

重現工具：`node tools/r2_mobile_evidence.mjs --web-dir <local-export> --phase after --playwright-module <installed-module>`。只啟動無頭 Chromium、本機 HTTP 與實際 Godot WebGL canvas，沒有繪製替代畫面。

**並發載量測，僅供參考。** 每個視口暖機後三跑、每跑 90 個有實際 WebGL draw 的影格間隔；原始區間、p50／p95／p99、draw calls、renderer 見 [rendered-evidence.json](evidence/r2-mobile/after/rendered-evidence.json)。這是 SwiftShader 軟體 WebGL 的畫面影格間隔，包含瀏覽器排程與呈現，並非硬體 GPU query，也不是手機實機。數值不能用來宣稱通過 p95 ≤18ms 的出貨閘。

| 視口 | 三跑 p95（ms） | p95 中位（ms） |
|---|---|---|
| 390×844 | 83.30／100.00／100.00 | 100.00 |
| 844×390 | 83.40／116.70／100.00 | 100.00 |
| 1366×600 | 416.60／266.70／200.10 | 266.70 |

三個視口各 270 個有算圖影格間隔，共 810 個。after 的 console／pageerror 皆為零。來源與打包雜湊見 [build-provenance.json](evidence/r2-mobile/build-provenance.json)；37 個產物以 [packaged-output-check.json](evidence/r2-mobile/packaged-output-check.json) 核對 manifest 雜湊。

## 未完成、缺件與風險

- **BLOCKED：實機與出貨效能**。沒有 Android／iOS 實機、原生有畫面、發熱、耗電、長時間遊玩或乾淨機況量測。本輪量得的軟體 WebGL 數字不達出貨標準。
- **BLOCKED：原有未追蹤的 native fixture**。`tests/native_touch.gd` 在 before／after 都於第 23 行對尚未建立的 `device_profiles` 呼叫 `initialize`，15 秒未能自行結束；它假設兩影格就完成啟動。檔案原封保留且未提交；[實證](evidence/r2-mobile/preexisting-native-fixture.json)。正式控制／裝置／R2 測試採實際啟動完成條件。
- 目前回訪的進行中站點不跨關閉保存；已完成後記、次數與最佳用時會保存。重新啟動可從第一站重玩，沒有期限或錯過懲罰。
- 主操作為雙拇指；連跑與視角步進能減少持續按壓，沒有宣稱完成單手或輔具驗收。
- 配送、設定等既有資料選單仍可捲動；本輪完成暫停分頁與固定返回，未把全部子選單改成無捲動頁面。
- 素材缺件：新人物表情／三視圖、騎乘 IK、破損模型、新插畫、新可授權音樂與音效；本輪未製作，也未以方塊或程序圖冒充。既有配樂仍沒有新增人耳試聽紀錄。
- 角色外觀雙閘門與新動畫三段沒有重做；沿用既有資產並跑命中窗／揮空／受擊回歸，不把 R1 圖當本輪新美術驗收。

## 繁中文案調整

| 原句 | 原因 | 本輪改法 |
|---|---|---|
| 「靠近標示物件，按 E 互動。」 | 手機沒有 E 鍵 | 「沿光柱前往目標，靠近後點右下綠鍵互動。」 |
| 「到車店找美晴，按 E 交談。」 | 主線任務卡也需要手機用語 | 手機改為「到車店找美晴，點互動交談。」；分支提示改為「點委託」 |
| 「使用左鍵攻擊這個物件」 | 觸控玩家找不到滑鼠按鍵 | 手機顯示「點右下『攻擊』敲擊這個物件」，桌機保留鍵盤滑鼠說明 |

八大面向做／不做的理由與未達成閘門，均保留在 R2 計畫中。所有未完成項均未計為 VERIFIED。
