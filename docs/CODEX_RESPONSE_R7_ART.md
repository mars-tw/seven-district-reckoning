# 第四輪美術交付（repo R7）

2026-10-17 工作單，於 2026-10-18 完成本機製作；版本 **0.11.0**、分支 main。只做本機 commit。以下以最新 Muse 五項為驗收；不自評為 8 分，不宣稱已通過 Apple 審查。

**VERIFIED** 代表本輪素材、證據完整性與回歸檢查；完整出貨狀態仍為 **BLOCKED**，桌機效能與落印初段重排未過，獨立美術分數與原生實機尚未取得。

## 最新 Muse 五項

| 驗收 | 修改與驗證 | 改後原尺寸截圖 |
|---|---|---|
| 1 先修人物指引 | 美晴移到原交談點，光柱／箭頭落在本人位置；保留約主角 0.95 倍的實際身高與手持扳手。肩側鏡頭分開兩人剪影；移除浮空扳手及靠近時重複的大字名牌。目標位置、鏡頭與原互動事件均有回歸檢查。 | `docs/store/screenshots/1290x2796-street.png`、`docs/store/screenshots/2064x2752-street.png`；390 寬見 `docs/art/compare/r7-after/390x844-street.png`。 |
| 2 街區去原型 | 新細粒柏油與窄騎樓磚分段、灰黃粉牆取代大面積重複磁磚；新 Blender 工作台有六抽屜、金屬把手、工具板、扳手、虎鉗與油壺；補入可見機車、鐵捲門及單車，修正黃昏太陽方向。三角度核對未見磁磚牆超過畫面三分之一。遠景與其他既有街坊物件仍簡化，不能稱全街區已重製。 | 同上兩張街區商店圖；多角度原圖 `docs/art/compare/r7-after/390x844-street-angle-1.png`、`-2.png`、`-3.png`。 |
| 3 立繪接縫 | 先做正／側／背與表情設定表，再產兩人膝上立繪；保留暖光與乾淨 alpha，下緣僅柔化筆觸，不再有透明小腿。阿遠獨白回歸左對齊、名牌取消薄荷綠。 | `docs/store/screenshots/1290x2796-dialogue.png`、`1290x2796-dialogue-meiqing.png`、`2064x2752-dialogue.png`、`2064x2752-dialogue-meiqing.png`。 |
| 4 證據承擔玩法 | 甲乙圖示可點擊開全屏，直接核對虛構戶名、上週五 14：32、三十八萬元；戶名朱紅圈、欄位證據黃。連結維持左黃選取／右紅結論；未改解題規則。 | `docs/store/screenshots/1290x2796-receipt-inspection.png`、`1290x2796-message-inspection.png`、`1290x2796-link.png`；iPad 為同名 `2064x2752-*`。 |
| 5 彈窗與任務欄雜訊 | 案卷全暗遮罩、隱藏底層 HUD；灰色捲軸隱去但保留穩定寬度，避免 R4.1 重排死循環。紙面補實際留證進度與翻閱提示；任務框使用案卷紋理，只留明寫「體力 n／100」的一條黃條，刪粉紅條。封存保留落印、紙面反應與封條補間，兩個商店尺寸各留動作瞬間。 | `docs/store/screenshots/1290x2796-evidence.png`、`2064x2752-evidence.png`、`1290x2796-seal-action.png`、`2064x2752-seal-action.png`；三連幀在 `docs/art/compare/r7-after/*-seal-sequence-*.png`。 |

## 素材與包體

新增 **8 張生成母圖、11 張 runtime 圖、2 組 GLB／Blender 原檔**。實際工具為 **image_gen.imagegen**，模型 slug 未揭露，manifest 記 null；不推測模型版本。清單為角色三視圖、兩張膝上立繪、黃昏車店背景、案卷面板／斷鏈／手機／收據 atlas、標題 Logo、App 圖示提案、柏油／粉牆 atlas。來源與完整 prompt 在 `assets/art/r7/`、`docs/art/PROMPTS.json` round7；同一風格前綴、左上暖光、細深墨輪廓。新圖與沿用素材授權均保留於 CREDITS。

去背用 CPU isnet-general-use matting，保留母圖、mask、cutout 與 SHA-256；透明 RGB 歸零。PNG 用於透明素材，背景及材質為 Q84 WebP；沒有捏造 normal／ORM。兩張立繪的 alpha 可見區亮度／飽和雙閘通過，這是 2D 圖片檢查，不把它冒充所有 3D 角色已通過相同遮罩量測。64px 實際人物裁圖與 App 圖縮圖在 `docs/evidence/r7-art/`，細小五官仍是缺件。

工作台 27,536 三角形、五個材質批次；阿遠 9,346 三角形、53 根骨骼，保留 idle／walk／run／attack／hit／drive／pedal／knockdown 八種動畫。包袋有實際厚度、翻蓋、雙扣與縫線，不再用平板色塊代替。讀回 Blender 原檔與 GLB 的檢查見 `model-validation.json`。美晴仍沿用原骨架與 idle，沒有把手持扳手說成新修車動畫。

新增 runtime 圖片 **2,362,578 bytes**，解碼 RGBA 預算 **16,637,952 bytes**。最終 Web PCK **22,838,880 bytes（約 21.78 MiB）**，比本輪基準減少 **1,942,936 bytes**。歷史圖片留在原始資料，僅在隔離匯出副本排除已被取代的圖；沒有修改他人的 export_presets.cfg。這是 Web 包體，未產 IPA／APK。

## 證據與測試

改前：`docs/art/compare/r7-before/`，以原 0.10.0 Web 包重新擷取 390×844 七個主要畫面。改後：`docs/art/compare/r7-after/`；商店圖：`docs/store/screenshots/`。所有商店圖都是實際 Godot Web 原尺寸 PNG，1290×2796 與 2064×2752；沒有合成遊戲場景或放大低解析圖。標題與對話的生成背景明確是插畫。

Godot 使用指定 **4.7 stable** console 執行檔，全程 headless；Chromium 全程 headless，使用指定四個 GPU 旗標與 NVIDIA ANGLE D3D11，沒有可見視窗。十種視口涵蓋 320×568、390×844、手機橫向、iPad 直橫、矮桌機與 1920×1080；每個視口測甲乙放大、返回、案卷重開與穩定重排。商店尺寸由 CSS 視口與 DPR 直接輸出，非原生 iOS 裝置截圖。

最終狀態以 `docs/evidence/r7-art/artifact-verification.json` 與 `docs/store/screenshots/R7_STATUS.json` 為準：完整 **27 套、16,088 項**回歸全綠、原斷言保留，含 native_touch 12 項；另有 13 項模型檢查、原尺寸／雜湊、受保護檔與初始未追蹤檔核對、index 秘密掃描。上一輪 native 測試 BLOCKED 未重現；隔離候選使用 HEAD 的 touch_controls.gd，沒有依賴他人未提交修補。

封存動作另以 Playwright 瀏覽器時鐘在 50／130／320 ms 步進並暫停，擷取同一份遊戲包的真實 Godot 畫面；不是合成、不是注入立繪，也沒有改寫解題狀態。原始三幀與 manifest 在 `docs/evidence/r7-art/clock-phone/`、`clock-tablet/`；商店動作圖採 320 ms 封條尚在貼合的第三幀。一般連續擷取的封存三連幀仍保留在 compare 中。初段兩幀仍可見短暫文字與紙緣重排，未把它們當作完成版商店圖，後續應收掉這段動畫雜訊。

效能在手機與桌機各採三跑 RAF p95，中位為 **手機 16.7 ms、桌機 33.4 ms**，完整結果留於 `performance.json`。**並發載量測，僅供參考**。桌機超過 18 ms，這項為 **BLOCKED**，不能宣稱出貨效能全過；目前沒有乾淨機況與原生 GPU 計時，未停掉其他線路來製造低負載結果。

## 未完成與風險

**Apple 4.3 風險：中。** 案卷紋理、查證圖、角色與車店已能與同帳號其他類型區別；3D 遠景、人物五官與部分既有道具仍簡化，主玩法完成度仍低於立繪。8 分以上仍待獨立複審，沒有自行代填分數。原生裝置、乾淨機況 GPU p95、所有路人與修車動作未完成，詳見 `docs/art/R7_MISSING_3D.md`。

語感依 speak-human-tw 的既有 mode 2 校對；修正為具體的製作、證據與限制敘述，未改題材、數值或證物事實。全程未 push、部署、改商店後台、傳訊或派工；既有未提交修改與初始未追蹤檔保留。
