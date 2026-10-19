# 第五輪美術交付（repo R8）

2026-10-18；main；版本 **0.12.0**。依 ART_RESCORE4_MUSE 唯一五項驗收清單收尾，並對照第三輪未解問題。只本機提交；獨立 8 分以上仍待複審，不自行填分。

製作為 EXECUTED。最終原尺寸、來源、測試、所有權與秘密掃描以 `docs/evidence/r8-art/artifact-verification.json` 為準；完整出貨狀態仍為 BLOCKED，原生實機、乾淨機況 GPU 計時與獨立複審尚未完成。

## Muse 五項逐項交付

| 驗收 | 改了什麼、如何驗證 | 改後原尺寸截圖 |
|---|---|---|
| 1．重做標記對齊 | 換掉烘有空紅圈與格線的底圖。標記寬度由實際字框決定，只比文字多 18px 內距；客服頁沒有紅圈，收據只有「林○翔（個人）」一圈。每張放大頁保留字框與標記座標，另有回歸檢查。 | `docs/store/screenshots/1290x2796-message-inspection.png`、`1290x2796-receipt-inspection.png`、`2064x2752-message-inspection.png`、`2064x2752-receipt-inspection.png`。 |
| 2．安全區與裁切 | 裝訂孔、紅繩移到獨立左側 40px 裝訂區，正文、選項及頁腳另有內距。放大頁用乾淨紙，不放孔洞、虛線或橫線裝飾；底部「保存說詞，再與轉帳收據核對；不要繼續付款。」完整顯示。矮橫向降低非關鍵資訊密度，返回鈕保持可達。 | 上述四張證物圖；`docs/store/screenshots/1290x2796-evidence.png`、`1290x2796-link.png`、`1290x2796-sealed.png`，以及同名 `2064x2752-*`。 |
| 3．封存動作與結果 | 新木柄印章在固定印章槽內壓下、抬起，完成後只剩朱紅印與完成封條；返回動作保留原文字與功能，但所有焦點狀態都維持次要深色。移除整張紙的旋轉疊層。補 45 項動作邊界檢查，抓住並修正起落時遮標題／左側裁切的錯誤。 | `docs/store/screenshots/1290x2796-seal-action.png` 對照 `1290x2796-sealed.png`；`2064x2752-seal-action.png` 對照 `2064x2752-sealed.png`。50／130／320ms 原始三連幀在 `docs/evidence/r8-art/clock-phone/`、`clock-tablet/`。 |
| 4．讓證物像證物 | 甲有客服抬頭、上週五時間欄、對話底與訊息氣泡；乙有收據外框、交易明細、留存編號、分隔線及戶名／時間／金額欄。黃線按字寬收縮，不再整頁同寬。原戶名、三十八萬元、14：32、四萬八千元及推論均保留；新留存編號明確屬虛構文件，不冒充銀行文件。 | 與第 1 項相同的四張原尺寸證物圖；不看下方提示亦可由文件結構區分。 |
| 5．街區收尾 | 新暖雲天空映射在真實 3D 世界；Blender 補波浪屋簷、圓形雨槽與落水管、垂掛電線、彎頸燈、輪胎、盆栽與油壺。機車改低彩度橄欖灰；人物補接觸陰影。美晴視覺放大 1.1 倍、扳手放大，保留原交談點與開場朝向；指引三角固定朝玩家，避免轉成細線。3D 人臉及握持近景精度仍有限，未稱全街重製。 | `docs/store/screenshots/1290x2796-street.png`、`2064x2752-street.png`；`docs/art/compare/r8-after/390x844-street.png`、三張 `390x844-street-angle-*.png`；商店列表縮圖 `docs/evidence/r8-art/street-list-thumbnail.png`。 |

## 新美術、模型與授權

新增 **3 張生成母圖、3 張 runtime 圖、1 組 GLB／Blender 原檔**：乾淨案卷紙、黃昏天空環境、透明木柄印章、車店生活物件組。實際圖片工具為 **image_gen.imagegen**；工具未揭露模型 slug，manifest 記 null，不推測為特定 gpt-image 版本。共同風格前綴、完整提示詞、母圖及雜湊見 `assets/art/r8/`、`docs/art/PROMPTS.json` round8。

紙與天空採 WebP Q86；印章保留工具實際提供的透明 alpha，裁切後加透明邊距、透明 RGB 歸零，PNG 壓縮。母圖以無損 WebP 留存；未捏造 normal／ORM。新增 runtime 圖共 **238,362 bytes**，解碼 RGBA 預算 **12,189,696 bytes**。新 GLB **379,528 bytes、6,038 三角形、5 材質批次**；Blender 5.2 背景製作，來源讀回與 GLB 雜湊／面數／相對依賴等 8 項檢查通過。圖依既有 CC BY 4.0 政策，原創幾何 CC0-1.0，已補 CREDITS；原授權未刪。

R7 的角色三視圖、阿遠／美晴膝上立繪、手機／收據／斷鏈圖示、標題 Logo 與 App 圖提案沿用，不為增加素材數量重畫已成立的身份。既有三視圖在 `docs/art/character-sheets/r7-cast-turnaround.png`。2D 立繪以實際 alpha 重測亮度／飽和雙閘；3D 人物沒有逐物件遮罩量測，不能冒充同項全過。兩人真實街區裁圖以 64px 另列於 `docs/evidence/r8-art/`。

## 前後對照與測試

改前：`docs/art/compare/r8-before/`，含從 0.11.0 Web 包重拍的 390×844 流程與原商店原尺寸圖，保留各自 manifest。改後：`docs/art/compare/r8-after/`；最終商店圖：`docs/store/screenshots/`。1290×2796、2064×2752 各 10 張，共 20 張。所有商店圖來自實際 Godot Web 原尺寸輸出，沒有拼貼遊戲場景、縮圖放大或以插畫代替 3D 街區；標題／對話背景仍明確為插畫。

使用指定 Godot **4.7 stable／5b4e0cb0f** console，全程 headless；沒有開編輯器視窗。Chromium 使用四個指定 GPU 旗標，實際 NVIDIA ANGLE D3D11；十視口涵蓋窄手機、390 直向、手機橫向、iPad 直橫、矮桌機與 1920×1080。每個視口實際走向美晴、交談、開甲乙證物、返回、選證據、封存並重開案卷三次；原固定捲軸寬度契約保留。動作三幀由瀏覽器時鐘步進並暫停真實遊戲，未寫入解題狀態或後製圖像。

完整 **28 套、16,434 項，0 失敗**，另含匯入／解析通過；原測試與斷言全保留。R8 新增 352 項，含文字／標記對齊、文件邊界、返回不重疊、裝訂區及移動印章不遮標題。native_touch 基準與最終各 12 項通過，上一輪 BLOCKED 未重現。最終候選使用 HEAD 的受保護設定與 touch_controls.gd，再獨立匯出及測試，不依賴他人未提交修補。

最終 Web PCK **24,480,432 bytes（約 23.35 MiB）**，較基準增加 **1,641,552 bytes（約 1.57 MiB、7.19%）**。隔離匯出排除已被替代的歷史圖片與本輪開始前就存在的未追蹤草稿；原檔全部留在工作區，未刪除。這是 Web 包體，沒有建立 IPA／APK。

手機與桌機各採三跑 RAF p95，中位為 **手機 33.3 ms、桌機 33.4 ms**，均超過 18ms，效能為 **BLOCKED**。這是並發載量測，僅供參考；完整三跑數據見 `docs/evidence/r8-art/performance.json`，不是原生 GPU 計時或乾淨機況驗收，未停掉其他線路製造低負載結果。

## 風險與保留

**Apple 4.3 風險：中。** 案卷、聊天／收據查證與黃昏車店已有不同於同帳號其他題材的識別；街區人物五官、部分遠景與既有物件仍簡化。獨立 8 分、原生實機與乾淨機況 GPU 效能尚缺，詳見 `docs/art/R8_MISSING_3D.md`；不以本機回歸通過宣告商店審查通過。

基準 331 個檔案維持雜湊一致：330 個既有工作檔及本輪先建立的盤點工具。原修改與初始未追蹤檔保留；.gitignore、export_presets.cfg、touch_controls.gd、qa、native 與 workflow 沒有納入本次提交。版本稽核只更新現行專案、Web shell、README；歷史報告、素材來源版本與他人原生設定保留。未 push、部署、改商店後台、發訊息或派工。

繁中依 speak-human-tw mode 2 直接校對。實際更正：「美晴走到店外查案位置」／原交談點須保留，不能如此描述／「放大美晴的紅圍裙與扳手辨識」。
