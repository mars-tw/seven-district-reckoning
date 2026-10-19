# R4.1 美術重做後修正回覆

日期：2026-10-16。版本：**0.8.1**。崩潰修正、介面調整、實際截圖與回歸驗證均已完成；3D 美術仍有缺件。本輪只建立本機 commit，沒有 push、部署、商店操作、發訊息或外部派工。

## 崩潰根因與修法

已在硬體 NVIDIA WebGL、430×932 CSS／DPR 1 重現。R4 加入證物插畫後，案卷內容落在捲動區的高度臨界點：`ScrollContainer` 的自動捲軸反覆顯示、隱藏，文字區寬度在 **358／366px** 間切換，延後更新的文字最小高度則在 **522／582px** 間切換，跨過 530px 的捲動區高度。

同一影格內記錄超過 **23,000 次容器重排**，隨後出現 `Message queue out of memory`。這段期間 `_resize_modal` 累計一直停在 11 次，因此根因是捲軸寬度與自動換行造成的容器循環，並非 `fraud_case_panel.gd` 那一次 `call_deferred()` 自己遞迴呼叫。

修正位於 `godot/scripts/ui/game_hud.gd`：在建立案卷內容前，改用 `SCROLL_MODE_SHOW_ALWAYS` 保留固定捲軸空間，使溢出與未溢出內容具有相同換行寬度。保留原有 deferred 版面更新，沒有提高記憶體上限或用計時器掩蓋循環。只套用捲軸修正的對照版本即能完成證物、連結、封存，每頁只重排兩次。原始觀測與對照 PCK 雜湊見 [root-cause.json](evidence/r4-1/root-cause.json)。

## 各項結果

| 項目 | 結果 |
|---|---|
| Logo | 粗黑 Logo 下加入真實案卷紙底板。已查看實際畫面裁出的 64px 寬縮圖，可辨識「七期」主識別；細小英文副標不宣稱在 64px 下全文可讀。取樣墨色／淺紙底的中位對比為 13.31：1，此值不是整張圖的無障礙認證。見 [縮圖](evidence/r4-1/logo-64px.png) 與 [計算來源](evidence/r4-1/logo-review.json)。 |
| iPad 案卷 | 使用約 88% 視窗寬、上限 1180px，依高度調整插畫、字級及可用高度。實拍直向寬 908.16／1032px，橫向寬 1180／1376px，所有按鈕保留可達性。 |
| iPad 對話 | 對話卡改為 84% 視窗寬，同步放大肖像與文字；直、橫向四張開場卡均有幾何驗證。 |
| 街景任務橫幅 | 改為下方實色任務卡，避開中央 3D 互動標籤，縮小標題及描邊干擾；手機實拍可同時辨識美晴、車店互動與台詞。 |
| 街景材質／光線 | 降低地面貼圖重複率，減輕遠處密集紋理；降低日間環境填光與飽和度、調整霧密度。仍是既有 alpha 模型，沒有以調色宣稱新 3D 模型完成。 |
| 匯入中繼檔 | 使用指定 Godot `--headless --editor --import --quit` 產生並納入 13 個 R4 圖檔 `.import`、`art_theme.gd.uid`。未納入 `.godot` 快取。 |
| 狀態 | `docs/store/screenshots/R4_STATUS.json` 已改為 0.8.1 的實拍驗證狀態，並明列尚缺的 3D 美術。 |

既有案卷金額、戶名、推論與故事台詞均未改寫。本輪繁中報告依共用規則的 mode 2 直接撰寫；沒有既有對外文案需要替換。

## 測試與真實截圖

指定執行檔實際回報 **Godot 4.7 stable／5b4e0cb0f**，沒有寫成 4.7.2。全程只用 Godot 無頭模式及無頭 Chromium。

- 工作區完整回歸：**24 組、14,210 項、0 失敗**；另有匯入／解析檢查。見 [工作區結果](evidence/r4-1/working-tree-tests.json)。
- 從 Git 暫存區建立副本，排除他人未提交修改後再跑完整回歸：**同為 24 組、14,210 項、0 失敗**。交付截圖也來自這個副本；來源指紋、逐檔比對與 PCK 雜湊見 [final-tests.json](evidence/r4-1/final-tests.json) 及 [build-provenance.json](evidence/r4-1/build-provenance.json)。
- 新增 `tests/r4_1_resize.gd`，納入正式 runner，提供 **902 項**檢查：九次視窗／旋轉配置、五個案卷階段、每階段三次開啟，檢查 explicit resize 上限、每影格容器重排上限、閒置收斂、溢出前後換行寬度不變及平板版面。隔離副本只撤回固定捲軸修正，新測試出現 **135 項失敗**，確認能抓到回歸。既有斷言未刪除或放寬。
- `tools/r4_1_store_evidence.mjs` 使用實際開場、走向美晴、按 E 交談、選證物與封存流程；每種尺寸再重開案卷三次，檢查 resize／sort 次數與閒置穩定。430×932 的 DPR 1／3 均通過，最終五種視窗的案卷每影格最多 **2～3 次重排**。
- `docs/store/screenshots/` 重拍 **1290×2796、2064×2752 各 7 張，共 14 張**：標題、阿遠對話、美晴對話、街景、證物、連結、結案。`docs/art/compare/after/` 另含 430×932、390×844、1376×1032，共 **35 張**，manifest 均記錄遊戲狀態、CSS／DPR、NVIDIA ANGLE D3D11 renderer 與雜湊。

交付截圖未合成或縮放，標題插畫就是遊戲當下使用的背景；64px Logo 檢查圖另列為衍生 QA 圖，未混入商店圖。這些是實際 Web 匯出的瀏覽器畫面，不是原生 iOS 實機畫面。PNG 尺寸／雜湊、案卷進度、兩目錄一致性與匯入檔由 `python tools/verify_r4_1.py` 再次核對，結果見 [artifact-verification.json](evidence/r4-1/artifact-verification.json)。

## 保留與未完成

受保護的 `.gitignore`、`export_presets.cfg`、`touch_controls.gd`、`qa/*.json`、`native/`、既有原生工具及 workflow，共 290 個現存檔案均逐一核對原始 SHA-256，沒有修改、還原或納入本次 commit。原先已修改的截圖先留本機備份，再按本次明確要求重拍；其餘未追蹤審查文件、歷史 before 圖及崩潰最後一幀均保留。秘密掃描與保留證據見 `docs/evidence/r4-1/`。根目錄沒有 `CLAUDE.md`，已讀 `AGENTS.md` 及指定的兩份 R4 審查文件。

版本已更新於專案、Web shell 與 README；受保護的原生匯出版本設定原樣保留，本輪沒有建立原生安裝包。瀏覽器與本次本機 HTTP 伺服器均已關閉。

尚未完成：新版角色服裝／表情、車店立面與維修道具、街景細節、騎乘接合等 3D 美術，逐項列於 [R4_1_MISSING_3D.md](art/R4_1_MISSING_3D.md)。原生實機、五人盲測及正式 GPU 效能驗收也不在本次完成範圍；不能以本輪修正宣稱整體美術或商店審查已通過。
