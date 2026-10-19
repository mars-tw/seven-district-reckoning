# 美術第七輪交付（repo R10）

2026-10-18，main，**0.14.0**。基準 2bd6b2c／0.13.0。只執行 ART_RESCORE6_MUSE §4 的五件事，對照 RESCORE5 收掉重複點名的包袋、工具、接地、引號與返回歧義。修改為 EXECUTED；原尺寸畫面、來源及測試按下列證據核對。**獨立8分以上、乾淨機況效能及原生實機仍為 BLOCKED**，沒有自行填新的 Muse 分數。

## 唯一五項驗收與原尺寸證據

| 項目 | 改後結果 | 原尺寸商店畫面 |
|---|---|---|
| 4.1 街區去原型化 | 背景 Blender 將成排相同扳手改為六件工具、五種輪廓：兩支扳手、鉗、起子、套筒與棘輪；加厚掛鉤，留出間距及貼板陰影。阿遠改柔軟聚褶包體、弧面翻蓋、側袋與連到包體的胯側背帶。人物、工作台、抽屜及店基接觸陰影加強；新增大尺度柏油水漬、斜面路緣與可見排水格柵。原暖光、招牌與屋簷保留。列表縮圖可見黃昏機車行、紅圍裙人物與到店主角；仍是風格化簡化模型，未稱寫實全街完成。 | `docs/store/screenshots/1290x2796-street.png`、`docs/store/screenshots/2064x2752-street.png`。縮圖另見 `docs/evidence/r10-art/street-list-thumbnail.png`。 |
| 4.2 封存一致性 | 按壓顯影到完成共用同一印文資源，取消遮字的木柄；移除淡入空封條與重複封存標題，只留印文及矛盾結果。兩顆同去向返回合併為「回到街區，繼續斷鏈」。動作與完成頁均由真實遊戲取得。 | `docs/store/screenshots/1290x2796-seal-action.png`、`docs/store/screenshots/2064x2752-seal-action.png`；完成為同目錄 `1290x2796-sealed.png`、`2064x2752-sealed.png`。 |
| 4.3 固定狀態編碼 | 已選說詞用證據黃；完成核對用勾選與灰墨／朱紅；焦點改墨色框。三顆未核對「比對」同色，不預先把正確答案塗黃。禁用繼續鍵上方直接顯示「尚缺：選說詞，再比對收據戶名。」選取後以黃底說詞和「比對」按鈕引導，不另佔頁腳高度。 | `docs/store/screenshots/1290x2796-evidence.png`、`2064x2752-evidence.png`；已選 `1290x2796-link.png`、`2064x2752-link.png`；完成 `1290x2796-linked.png`、`2064x2752-linked.png`，均在同目錄。 |
| 4.4 證物閱讀與資訊密度 | 原虛構說詞與數字不變；引號字組及句末標點保護斷行。下半部加入來源、甲方聲稱、乙方收據、帳戶性質核對與推論邊界，沒有裝飾填空。補字型子集消除缺字。矮橫向合併訊息斷行並收起次要長註，返回仍在連續紙面頁腳。 | `docs/store/screenshots/1290x2796-message-inspection.png`、`2064x2752-message-inspection.png`；收據 `1290x2796-receipt-inspection.png`、`2064x2752-receipt-inspection.png`，均在同目錄。 |
| 4.5 街區案卷語言 | 搖桿改雙層裝訂環、穿孔與紅繩；唯一黃色主操作改切角證據標籤。移除頭上三角與光柱，只留較小紙灰腳圈；腳圈抬到新增柏油面上方，避免被地面遮住。體力與搖桿中心退為紙灰，五案改次要五格進度，只留目前目標。 | 同上兩張 `*-street.png`。`docs/evidence/r10-art/street-without-sign-QA.png` 是明示遮招牌的衍生QA，未混入商店圖。 |

封存動作在兩種商店尺寸各留50／130／320ms三幀，路徑為 `docs/art/compare/r10-after/*-seal-controlled-*.png`。以真實瀏覽器時鐘步進並暫停；因一般橋接每350ms才更新，逐幀透過其既有無動作分支讀回當下節點，不改遊戲狀態或動畫時間。商店動作圖取50ms，能看見放大的印文正在顯影，完成頁則為正常大小；三幀都是同一印文。沒有注入解題狀態、合成或放大截圖。

## 新美術、包體與授權

**1張生成母圖、1張runtime貼圖、3組GLB及Blender原檔**。實際圖片工具 **image_gen.imagegen**；工具未揭露模型slug，manifest寫null，不推定特定gpt-image型號。1254×1254 opaque母圖以無損WebP保存；runtime為768×768 WebP Q86，**201,740 bytes**，RGBA解碼約2.25MiB。本輪無新透明cutout；沿用的真alpha立繪及圖示不冒充新增。完整prompt、共同前綴及來源雜湊在 `assets/art/r10/`、`docs/art/PROMPTS.json` round10。

新GLB實際匯出：阿遠9,602三角形／16材質批次／8個真骨架clip，工作台9,144／7批次，路緣排水2,744／2批次。工作台比R9的18,320三角形少，但不把局部面數變化當成整場景GPU成本比例。模型讀回確認內嵌貼圖、源檔相對路徑、雜湊、骨架與八clip；新包袋依既有角色正側背與表情金標製作，CPU背景棚拍在 `docs/art/character-sheets/r10/`，不當商店畫面。

Web PCK為 **25,876,008 bytes**，較0.13.0的25,391,532增加 **484,476 bytes（1.90%）**，仍低於既有25MiB限制。首版超過限制時，將只承載大尺度表面訊號的貼圖縮為768，沒有放寬檔案守門。Blender源檔在godot/之外；包裝只排除被替換的歷史資產及初始未追蹤草稿，原檔未刪。CREDITS及所有原第三方授權保留。

## 效能對照與判讀

VERIFIED：以dc73132的Git archive重新無頭匯出，與本輪改前0.13.0精確PCK比較；每個視口採 **R4→R9→R9→R4** 交錯次序。相同Godot 4.7 stable、headless Chromium、NVIDIA ANGLE D3D11與四個指定GPU旗標；手機390×844／桌機1366×768、DPR1、相同profile與實際開場，世界準備好後三跑各180個RAF間隔，取p95中位。所有跑數、PCK雜湊及每秒CPU／GPU／可用記憶體在 `docs/evidence/r10-art/benchmarks/`。

| 視口 | R4兩次p95中位 | R9兩次p95中位 |
|---|---|---|
| 手機 | 16.7／16.7ms | 16.7／33.3ms |
| 桌機 | 50.1／50.1ms | 50.1／50.1ms |

桌機四次相同，未重現目前版本相對第四輪的退步；同一R9 PCK手機兩次也會變動。各跑GPU中位接近滿載，本線全部瀏覽器／Godot關閉後仍有 **97% GPU、11,440MiB顯存**。這支持共享環境干擾是目前量測的限制，未找到須據此回滾的程式退步。不能把這些證據延伸為歷史83.4ms那一筆的唯一根因；該次沒有同期負載紀錄。摘要在 `performance-investigation.json`，原始A/B方法與負載皆保留。

定稿同法手機／桌機為 **33.3／50.1ms**，各三跑與同期負載見 `final-performance.json`。**並發載量測，僅供參考；乾淨機況 ≤18ms仍為BLOCKED。** RAF不是原生GPU timer，Godot TIME_PROCESS也不是純腳本CPU時間。未中止其他線路；既有渲染解析度比例及畫質profile維持原設定，真骨架動畫保留。

## 驗證與保留

- VERIFIED：指定執行檔實際為 **Godot 4.7 stable／5b4e0cb0f**。全程Godot --headless、Blender -b與headless Chromium，未開可見視窗。
- VERIFIED：改前native_touch **12／12**，上一輪native fixture BLOCKED未重現；定稿完整 **30套、16,790項、零失敗**，另含匯入／解析。測試與匯出來自同一隔離來源指紋，受保護設定使用HEAD版本，不依賴他人未提交修補。既有測試與斷言全數保留，新增133項R10守門抓固定狀態、單一返回、同印文及註記邊界。
- VERIFIED：十視口走完前3分鐘、雙人對話、查證、重開三次、連結與封存。兩種商店原尺寸共 **22張**。來源PNG尺寸、SHA-256、NVIDIA renderer、文字與紙面幾何、角色投影高度均讀回；手機人物高度為 **阿遠247.4px／美晴109.3px**，均大於40px。2D立繪亮度／飽和度雙閘回測通過，64px真實人物裁圖另列QA。
- 首輪實拍抓到新增註記超出紙面、句號孤行與缺字；收緊閱讀版面並補字型。既有版面測試另抓到矮橫向狀態說明擠壓返回，以及訊息固定斷行造成頁腳不足，均修回原斷言；未刪測試或降低門檻。
- VERIFIED：初始 **169個**工作檔雜湊原樣保留。`.gitignore`、`godot/export_presets.cfg`、`godot/scripts/ui/touch_controls.gd`、qa、native、workflow等未動未提交。初始未追蹤檔未刪，只有明確路徑進Git index。秘密掃描 **1066個索引文字檔、零命中**；完整結果在 `docs/evidence/r10-art/artifact-verification.json`。

改前 `docs/art/compare/r10-before/`（含當次實拍live）；改後 `docs/art/compare/r10-after/`；商店 `docs/store/screenshots/`。原圖均為Web實際畫面，不是原生iOS截圖。中間預覽留本機不作定稿。版本更新限現行專案、Web shell及README；歷史證據與他人原生版本設定保留。

**Apple 4.3風險：中。** 案卷玩法與街區操作已呈現同一套識別，仍缺獨立8分重評、原生實機及乾淨機況效能。臉、手指與遠景仍簡化，Godot逐角色遮罩雙閘尚未補齊；詳見 `docs/art/R10_MISSING_3D.md`。VERIFIED只表示來源、畫面與測試核對，不代表美術評分或商店通過。只本機繁中commit，沒有push、部署、操作商店、發訊息或外部派工；本線瀏覽器與HTTP server均於量測／擷取後關閉。

繁中依speak-human-tw mode2直接校對：原「沿光柱找到拿扳手的人」／光柱已移除，指引不符畫面／改「找到紅圍裙、拿扳手的人」；原客服說詞的引號／標點容易孤行／字句與數字不變，只改斷行約束；新增缺步驟說明及同案核對註記，未改金額、戶名與推論邊界。
