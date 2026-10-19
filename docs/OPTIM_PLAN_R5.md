# R5｜美術第二輪計畫

日期：2026-10-16。基線：0.8.1／d1e7fae，分支 main。範圍只限本 repo，本機 commit，不發布、不派工。狀態起始為 PREPARED。

已讀核心規則、AGENTS.md、game-optimization-round、token-efficient-ai-dispatch、R4／R4.1 報告、ART_DIRECTION、兩份 MUSE 審查及共用 VISUAL_REFRESH_PLAN。根目錄沒有 CLAUDE.md、AUDIT_full.md。本次指令優先於共用派工與發布流程。保護清單及原始雜湊在 evidence/r5-art/protected-before.json。

## 驗收清單

1. 先重跑 native_touch，確認舊 BLOCKED；先匯出 0.8.1 Web 並用 headless Chromium／硬體 D3D11 拍七個主要畫面，再寫 ART_REVIEW_R5。
2. 美術／地圖：保留紙本案卷、證據黃與黃昏街區識別；生成磁磚、鐵捲門、玻璃店面、車店招牌等真正紋理，接到既有授權模型。只加材質／平面貼花，不以新方塊冒充 Blender 模型。
3. 人物／角色：保留既有真骨架與立繪，改善鏡頭占比與材質可讀性，量 390px 街景主要人物是否 ≥40px；64px 身份、亮度／飽和度與三視圖不足逐項列缺件。
4. 按鈕／選單：保留所有 ≥44px 與關閉／返回的嚴格回歸；收斂街景 HUD、減少競爭資訊；手機無鍵盤教學。受保護 touch_controls.gd 不動。
5. 技能／動作：既有命中、受擊與骨架測試全綠；新增案卷封存蓋印及矛盾標記回饋，以實際連續畫面與時間紀錄驗證。UI 補間不冒稱角色骨架動畫。
6. 重拍手機直橫、iPad、矮桌機；前後放 art/compare/r5-before、r5-after；商店 1290×2796、2064×2752 為未合成實際遊戲畫面。
7. WebP 適當縮圖、來源與 runtime manifest／PROMPTS／CREDITS，核算新增壓縮素材、PCK 與解碼大小。無法取得模型 slug 就記實際 image_gen 工具名。
8. 正式 runner 完整回歸、匯入／解析、GPU Web 操作、秘密掃描、版本 bump、保護檔雜湊 readback。效能量三跑 p95 中位，標示並發載僅參考，不能冒稱乾淨實機通過。

## MUSE 五項對應

街景材質／台灣訊號、角色識別、HUD、證據色彩／排版、封存儀式／跨頁風格，各自在最終 CODEX_RESPONSE_R5_ART 逐項交代已做與缺件。8 分是目標，沒有獨立重評不得自稱已達標。新服裝／表情、店面立體細節、道具／機車／電線等新模型由 Blender 另線，列明可替換介面。

## 收尾判定

VERIFIED：native fixture 12 項通過；最終完整回歸 25 組、14,154 項通過。EXECUTED：7 組新母版／12 張 runtime 圖、街景材質與霧色、人物識別著色、圖示工具列、紙本案卷與落印修正。截圖、雜湊與秘密掃描的最終 readback 見 CODEX_RESPONSE_R5_ART 及 artifact-verification.json。

BLOCKED：新 3D 模型／表演、三視圖、原生實機與乾淨機況 GPU 效能、獨立 ≥8 分評估。具體缺件與替換入口在 art/R5_MISSING_3D.md；不作出貨品質全通過的宣告。
