# R5 美術第二輪回覆

2026-10-16，版本 **0.9.0**，main。本輪只作本機提交；沒有 push、部署、商店操作、發訊息或外部派工。整體 8 分尚未驗證，新 3D 美術與原生實機仍有缺件。

## MUSE「下一輪五件事」逐項回應

| 項目 | 狀態與結果 | 未完成與理由 |
|---|---|---|
| 1．街區場景優先 | EXECUTED：既有車店與大樓接入磁磚；車店有工作室玻璃、鐵捲門及「美晴車店」招牌。二樓使用較淡的街景反射，避免上下兩層複製維修店。地面降明度，外圍改柏油，使用 mipmap／anisotropic 過濾；暖側光、環境填光、遠霧與色調同步調整。 | 部分完成。騎樓／雨棚沿用舊模型；機車、電線桿與電線、店面立體支架及生活道具沒有新做，不能把背景畫中的物件算成已完成的 3D 街景。手機預設仍按效能配置關閉動態陰影，保留接觸陰影。 |
| 2．街區人物識別 | EXECUTED：阿遠的既有骨架網格加入黃袖標、橘包與白鞋；材質座標綁在 bind pose，原 walk／attack／hurt clip 保留。美晴移至櫃檯側邊，不再只露一小截頭部。390px 畫面投影高度約為阿遠 196px、美晴 85px。 | 部分完成。沒有把包體加大 20%，也沒有新增服裝幾何。美晴舊模型的臉、服裝與女性立繪仍不一致，沒有扳手修理動畫；這些由 Blender 另線處理。 |
| 3．街區 HUD 收斂 | EXECUTED：六枚專屬手繪工具列圖示＋短標籤；配送、錢包與等級等常駐文字移出一般觸控 HUD，活動進行時仍顯示相關資訊；保留任務、目標與健康／體力。五枚細碎圖樣換成可讀的 1–5 案件格。開場任務卡預設 2.8 秒後淡出，遠處小黃字靠近才顯示。 | 手機橫向仍依原可達性配置使用 3×2 工具區；六個操作功能與原 hit region 均保留。方向與移動的受保護基底檔未改。 |
| 4．證據頁色彩／排版 | EXECUTED：非警告說明改墨色或深棕，小字備註不再把句號擠成獨行；公司專戶／個人戶名以黃色對照條呈現；未選說詞時停用底部繼續，選取後啟用。固定捲軸預留與原版面收斂修正完整保留。 | 證物圖仍是既有靜物插畫，真實可讀資料由 UI 文字提供，沒有冒稱插畫上的空白欄位就是可點選收據。 |
| 5．封存儀式與跨頁風格 | EXECUTED：加入 120–144px 封存圓印、黃黑封條、顯影及 0.30 秒落印回彈；保留唯一黃色前進鍵與返回。背景換為同系手繪黃昏車店，沿用已有角色、Logo、紙紋與 App 圖示提案。 | 跨頁色溫已收斂，但舊 3D 人物／街景輪廓仍未達立繪完成度。沒有獨立重評，不能自稱已達 8 分。 |

## 新素材、來源與授權

**7 組生成母版、12 張遊戲用圖**。實際工具為 **image_gen.imagegen**，工具未揭露模型 slug，manifest 明確記為 null，沒有推定為 gpt-image-2。共用風格前綴、每張原始 prompt 與工具列去背編輯 prompt 均在 [PROMPTS.json](art/PROMPTS.json) 的 round5。

| 母版 | 遊戲用途 |
|---|---|
| ceramic-tile | 既有牆柱與立面材質 |
| rolling-shutter | 車店既有立面上的鐵捲門貼花 |
| workshop-window | 一樓維修店玻璃與二樓低調反射 |
| shop-sign | 「美晴車店」專屬招牌 |
| title-street | 標題與開場對話的同系背景 |
| archive-seal | 真 alpha 封存章及封條 |
| toolbar-atlas | 六枚圖示切成 toolbar-0～5 |

母圖與來源 PNG 雜湊在 [assets/art/r5/manifest.json](../assets/art/r5/manifest.json)，遊戲導出清單在 [runtime manifest](../godot/assets/art/r5/manifest.json)。工具回傳的 RGBA 在透明區殘留背景 RGB，數值讀回確認 alpha=0；後製清零透明區 RGB、保留抗鋸齒、切圖與 LANCZOS 縮圖，沒有把底色當透明。工具列原圖與編輯圖均保留。所有 runtime cutout 已核對透明四角、alpha occupancy 與零 RGB；未套用不相關的 PBR 法線／ORM。

新增壓縮圖片 **1,286,718 bytes（約 1.23 MiB）**；全部以 RGBA 解碼約 **18.09 MiB**。無損來源與遮罩約 **12.82 MiB**，放在 godot/ 外；遮罩雜湊在 [alpha-masks.json](../assets/art/r5/alpha-masks.json)。實際 Web PCK 差額見 [package-budget.json](evidence/r5-art/package-budget.json)，約增加 **4.96 MiB**；此為 Web 封包，不是原生 IPA／APK。CREDITS 新增 R5 列，R4 與所有第三方授權完整保留。

## 驗證與前後對照

- VERIFIED：Git 暫存來源隔離副本的完整回歸為 **25 組、14,154 項、零失敗**，含匯入／解析與新增 40 項 R5 檢查。見 [final-tests.json](evidence/r5-art/final-tests.json)。既有測試未刪除或放寬斷言。
- 改前先重跑 native_touch：**12 項、零失敗**，上一輪 fixture 的 BLOCKED 已不再存在；這不是原生實機驗收。
- 指定執行檔回報 **Godot 4.7 stable／5b4e0cb0f**。全程 Godot --headless 與 headless Chromium；沒有開編輯器視窗。
- 截圖與交付測試均使用 Git 暫存區建立的隔離副本，排除他人未提交修改；來源逐檔 blob／SHA-256 見 [candidate-source.json](evidence/r5-art/candidate-source.json)。正式回歸另以隔離 user-data 執行，沒有讀玩家存檔。
- 主要 Web 畫面共 **7 視口、49 張**：1290×2796、2064×2752、430×932、390×844、1376×1032、844×390、1366×600。每個視口實際完成標題、雙人物對話、街景、選證、配對與封存，並重開案卷三次檢查重排上限與閒置穩定；所有檔案皆未合成或縮放。
- [r5-before](art/compare/r5-before/) 有本次 0.8.1 的 390px 七張實拍；商店 before 圖沿用並核對 d1e7fae 的 0.8.1 真實截圖，來源另列 historical-store-baseline.json。[r5-after](art/compare/r5-after/) 為本次最終畫面。[商店圖](store/screenshots/) 重拍兩種尺寸各七張，共 **14 張**。
- 街景另等待 7 秒讓任務卡自然收合，再以同一 PCK 重拍，沒有強制隱藏 UI；逐視口讀回在 r5-after/street-readback.json。64px 阿遠 QA 為這張真實街景的角色裁切，未混入商店圖。
- 落印初驗發現容器重設 scale，使動畫只剩顯影；已指定補間起始縮放，補上會抓到容器重設的回歸斷言。縮放讀回及瀏覽器連續 PNG 證據見 stamp-scale-probe.json、seal-motion.json；CDP 原始動態記錄與正式商店 PNG 分開標示，不能混作商店尺寸截圖。
- 2D 立繪雙閘重新量測通過：阿遠 V 0.349／近黑 25.3%／S 0.478／低飽和 3.8%；美晴 V 0.487／近黑 6.3%／S 0.594／低飽和 2.2%。數據在 retained-portrait-gates.json。3D 三視圖與角色遮罩雙閘仍未驗收。
- 效能只提供並發載參考：390px 瀏覽器 requestAnimationFrame 三跑、各 180 個間隔，p95 中位約 **16.7ms**。這是瀏覽器呈現間隔，不能當作原生 GPU timer，也不代表乾淨機況的手機出貨效能通過。

## 交付邊界

**Apple 4.3 風險：高。** 案卷與街區識別已加強，但舊模型、平面店內貼圖、內容量及同帳號整體區隔仍需獨立／真人審查。沒有聲稱 Apple 已認可或風險已解除。

BLOCKED：新 3D 角色、修理表演、正式立面／騎樓／機車／電線道具、完整 PBR、3D 三視圖與雙閘、五人盲測、原生實機及乾淨機況 GPU 效能。逐項入口與驗收契約在 [R5_MISSING_3D.md](art/R5_MISSING_3D.md)。App 圖示、Logo 與兩名角色立繪沿用 R4，不冒充本輪新增。

受保護的 .gitignore、export_presets.cfg、touch_controls.gd、qa、native 及原有工具等 **292 個檔案**逐一核對雜湊，原樣保留且未提交；新美術適配放在獨立檔案／既有 mobile 子類別。原生匯出設定版本也依本次限制保留。初始未追蹤檔沒有刪除。版本更新範圍為專案、Web shell 與 README，歷史報告／素材 manifest 保留原版本證據。

VERIFIED：素材與商店圖尺寸／SHA-256、來源與測試指紋、PCK 綁定、受保護檔案及 Git 暫存區秘密掃描均通過，秘密零命中；見 [artifact-verification.json](evidence/r5-art/artifact-verification.json)。瀏覽器與本次 HTTP 伺服器全部關閉。本機 Web 成品已同步至 deliverables/web；不屬發布。本輪中間預覽移至被忽略的本機稽核目錄，沒有刪檔。

繁中文案依說人話 mode 2 直接處理。可見用語僅將「說詞→哪項紀錄與它矛盾」拆為「核對說詞」與黃色對照條，避免長題目擠行；警示／數字／戶名／故事事實保留。其餘是樣式、字級與資訊顯隱調整。
