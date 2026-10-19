# 七期：斷鏈行動｜新內容第二輪計畫

2026-10-19，main，基準 d3a753b／0.15.0，目標 0.16.0。原始計畫 PREPARED；實作 EXECUTED，定稿驗證見 `docs/content/r2/verification.json`。
唯一驗收來源：`docs/content/CONTENT_REVIEW_R1_MUSE.md`「下一輪最該做的 5 件事」。本次任務覆寫技能的一般派工、推送及全面美術重製要求：只在本 repo 背景執行、只本機 commit，不派工、不操作商店。沿用既有角色、骨架與 R10 美術。

## 三項設計與檔案

| 內容 | 設計與驗收 | 預定檔案 |
| --- | --- | --- |
| 第二次求助，第二次收費 | 比對同案文件後才解鎖安全行動判斷；兩步都通過才封存，第一步與中途保存。干擾選項採證據不足的推論。專屬雙文件圖、岸七案號與兩份原文真文字並列。 | `godot/data/fraud_cases.json`、`godot/scripts/content/content_investigations.gd`、`godot/scripts/ui/investigation_panel.gd`、`tests/content_r1.gd`、`tests/content_r2.gd` |
| 晚班之前的收據 | 固定打亂為丙、甲、乙，10 次新開均不得從左至右完成。時間牌保留時間並顯示來源、事件；已排順序及撤回清楚。封存顯示三個時間點及不能推定經手人的界限。 | 同上；三張收據專屬生成圖 |
| 三張嘴，一句真話 | 三人來源、原文及三份文件可重讀；索引作額外有效反證保留。封存以三行顯示說法、實際選用證物、支持／推翻，再列界限。 | 同上；收件簿與三原件專屬生成圖 |

## 五項驗收對照

1. 效能：依本輪明示不追並發桌機 83.4ms；保留舊實測參照與不可上架判定。乾淨機況及 Android、iPhone／iPad 實機 BLOCKED，需要可用裝置與獨占測試時段，不能用 RAF 代替原生。截圖不能證明 p95。
2. 現場流程：畫面持續標示「待訪來源 → 到現場 → 取得證物 → 推論」。三案各拍真實街區位置、來源及靠近互動，取證前／現場／取得後連續截圖；測試從正常案件入口開始、實際世界互動。真人口述驗收 BLOCKED，需未參與開發玩家；自動操作只證明流程可達。
3. 時間排序：10 次新開測試初始牌面，0 次正序；自動實玩錯排、撤回、正排及封存，附原尺寸手機圖。
4. 版面與案件識別：390×844、1290×2796 逐案證物／推論／封存，三案專屬圖及來源摘要，空間隨內容收合；矮橫向仍可返回、44px 以上、不溢出。遮題口述仍需真人，BLOCKED。
5. 深度與可讀性：第一案兩層判斷及中途冷重載；第三案三行對照及索引替代反證圖。10 秒辨識、正確複述兩組結果屬真人試玩，BLOCKED。

## 證據與品質閘

- `docs/content/r2/phone-<內容>-<狀態>.png`：原尺寸手機直式實際 Web 畫面；兩種商店圖 1290×2796、2064×2752 新增到 `docs/store/screenshots/`，保留舊圖。
- Godot 僅 `--headless`；Web 僅 headless Chromium，指定 ANGLE D3D11 四旗標，單一 server／browser，結束關閉。取證 fixture 必須由實際世界產生，禁止注入完成狀態；解題均按可見按鈕。
- 完整既有套件與新 R2 測試全綠；不刪測試、不放寬斷言。存檔含逐步保存、磁碟／IndexedDB 冷重載及舊版相容。RWD 含直橫手機、iPad、矮桌機，正文與控制不越界。
- 美術用 `image_gen.imagegen`，共同前綴取 `docs/art/PROMPTS.json`，保留母圖、prompt、真實工具名及 SHA-256；不加新 3D 模型或程序佔位。
- 受保護檔案先雜湊；測試／匯出隔離快照採其 HEAD 版本，不借用他人未提交修補。明確路徑 stage，秘密掃描，繁中 commit。版本更新現行 README、Godot、Web shell；歷史證據版本不改。
- 收尾 `docs/CODEX_RESPONSE_CONTENT_R2.md`：五項狀態及逐項原圖、三項入口、測試、素材、Apple 4.3 風險、真人／實機／Muse 複審缺件。不得自評為 Muse 8 分。

執行增補檔案：`godot/scripts/main.gd`、`godot/scripts/ui/game_hud.gd`、`godot/scripts/content/investigation_field.gd`、`tools/content_r2_*.py`、`tools/content_r2_evidence.mjs`、`assets/art/content-r2/`、`godot/assets/art/content-r2/`、字型子集、專案／Web 版本及 README／CREDITS。第一案另以純 JSON 替換的隔離匯出提供兩張原尺寸圖，正式資料與原匯出指紋在驗證後讀回。

執行結果：VERIFIED，32 套／28,371 項、九種 Web 視口、264 張正式資料原圖、兩張純 JSON 替換圖、八張新增商店圖。效能／實機／真人試玩／獨立 Muse 複審為 BLOCKED，維持出貨限制；逐項證據與需補條件見交付報告及 `limitations.json`。
