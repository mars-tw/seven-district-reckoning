# R3 上架可能性優化報告

日期：2026-10-15。版本：**0.7.0**。本輪只修改七期 repo，全程背景／無頭，只做本機提交，未 push、部署、操作商店、讀取秘密目錄或派工。

**VERIFIED：Godot 4.7 與 4.7.2 各 21 組、12,018 項、零失敗；R3 新增 2,095 項。** 最終測試、Git index 來源與 25 張實際算圖截圖的來源指紋／PCK／PNG 核對通過，見 `docs/evidence/r3-store/final-verification.json`。商店素材為 PREPARED；下方缺件維持 BLOCKED。

**Apple 4.3 風險：高。** 新增了可操作的反詐案卷，題材已成為開場玩法；但帳號已有整批 4.3／4.2.6 退件，而且目前仍是一份新案卷與既有第一章。尚缺最新原生成品、實機影片與真人 beta 回饋，不能據此認定達到 Apple 要求的「重大改變」。[Apple 審查準則](https://developer.apple.com/app-store/review/guidelines/)

## 最大改進

1. **前段就能操作反詐調查。** 四張開場訊息卡結束或跳過後，留下客服的公司專戶說詞。玩家親自走到美晴桌邊取得收據，再選說詞、證物及可支持的判斷。錯選會解釋理由，不扣資源，可返回重選；正確完成才封存。案卷納入主線原子存檔，不發可重複刷取的金錢。
2. **本作識別與小螢幕可用性。** 新增紙色留證簿、紅色核對標記、甲乙證物與推論流程，更新標題與開場對話，移除玩家畫面的 MAIN 代號，等級／經驗改為中文。窄直向與極矮橫向使用緊湊排版；保留固定返回／繼續。修正開選單後要等下一影格才釋放觸控的競態，改成同步釋放。不是以換色代替玩法差異。
3. **區隔、隱私與商店證據。** 準備逐款比較、13 個同機 repo 的唯讀資產比對、隱私核對、繁中商店文字、英文審查路徑及兩種尺寸的真實無頭算圖截圖。所有文字均為本機草稿，沒有上傳。

## 驗證與證據

測試與截圖的最後讀回結果，收在 `docs/evidence/r3-store/` 及 `docs/store/screenshots/manifest.json`。測試使用 Git index 的乾淨來源快照，排除原有未提交 native／觸控 patch；實際資料目錄隔離，不讀玩家存檔。不刪除既有測試、不放寬斷言。

| 項目 | 證據／範圍 |
|---|---|
| 完整回歸 | `final-source-tests-47.json`、`final-source-tests-472.json`；兩個實際引擎版本分列，不能把指定的 4.7 執行檔稱為 4.7.2 |
| 審查路徑 | `tests/r3_store.gd`：冷啟動、訊息保留、觸控移動、遠距互動不推進、真實車店互動、第一主線目標、錯選／返回／封存、暫停與背景恢復、非法存檔拒絕、舊存檔相容 |
| 跨程序進度 | `tests/r3_store_restart.gd` 在下一個 Godot OS 程序從冷標題讀回相同隔離存檔，確認案卷封存、第一目標與重讀操作 |
| 版面 | 320×568、568×320、375×667、667×375、430×932、932×430、440×956、956×440、768×1024、1024×768、1032×1376、1376×1032、1366×600、1280×640；案卷各階段／選詞／錯選提示共八種狀態，按鈕雙向 ≥44px、在畫面內、不重疊、不捲動才能操作 |
| 真實算圖 | `screenshots/manifest.json` 與 `rendered-small/manifest.json`，含版本、PCK／PNG 雜湊、實際物理走到車店與封存；無頭 Chromium／SwiftShader，不是手機實機。跨程序讀回由原生 suite 證明，Web 補驗限制另列 |
| 字型 | `font-and-art.json`：補齊案卷字元，OFL 子集、中文字覆蓋；沒有新增點陣插畫，模型 slug 為 null |
| 素材／區隔 | `shared-assets.json`、`runtime-asset-inventory.json`、[DIFFERENTIATION](store/DIFFERENTIATION.md)、[逐項素材稽核](store/SHARED_ASSETS_AUDIT.md) |
| 隱私 | `privacy-source-audit.json`、[隱私核對](store/PRIVACY_AUDIT.md)，區分本機原生遊戲與需下載的 Web 入口、歷史來源與未完成成品 |
| 工作保留 | `preexisting-worktree.json`、`preexisting-integrity.json`、`export-preset-ownership.json`；原有 11 檔保留，匯出設定只 stage 本輪 Windows 版本兩行 |
| 來源／秘密 | `build-provenance.json`、`secret-scan.json`、`publication-scan.json`、`listing-lengths.json`；來源核對、零秘密命中與欄位長度 |
| 證據總驗收 | `python tools/verify_store_evidence.py --candidate <隔離來源目錄>`：比對 staged 來源、完整測試指紋、PNG 尺寸／雜湊、PCK、遊戲封存階段與瀏覽器紀錄，產出 `final-verification.json` |

自動化整合測試會把角色擺到已存在的車店互動點；截圖工具則另用真實 W／E 按鍵走過去，不以擺位時間推算三分鐘可玩性。原生背景驗證是引擎通知模擬，不能當實機切換 App 的證明。

完整基準與版本證明以最終 JSON 為準。`before-evidence.json` 引用既有 R2 0.6.0 的真實 after 圖作歷史基準，沒有把它們說成本輪重拍。Web 匯出缺少全機 4.7.2 模板時，只在本 repo 忽略目錄提取既有 TPZ 的所需檔案，匯出後還原快照設定；未安裝或改寫外部工具。

**並發載量測，僅供參考。** 最終 1290×2796／2064×2752 畫面的無頭操作從開始行動到車店，分別約 15.2／40.7 秒；封存案卷約 22.4／58.9 秒。另有 375×667、667×375、1366×600 的五階段畫面。25 張 PNG 全部實際尺寸／雜湊正確，五個視口的瀏覽器錯誤與非本機來源請求均為零；沒有把這些秒數當真人測試或實機效能。

## 上一輪 native BLOCKED 的原因

`tests/native_touch.gd` 原檔本輪再次實跑：第 23 行在兩個 process frames 後對 null `device_profiles` 呼叫 `initialize`，15 秒逾時，見 `preexisting-native-reproduction.json`。完整世界採分階段非同步啟動，兩影格不是就緒契約；而 fixture 在 add_child 前設定的 is_test_mode 也會被主場景啟動重設。

原檔 hash 保持不變，沒有刪除、偷改或納入本輪提交。新增 R3 fixture 等待 `expansion_complete`，再設定測試模式，實跑原生搖桿、角色物理、背景釋放、恢復與暫停。**原 fixture 仍為 BLOCKED；替代驗證通過不代表修好了原檔。**

## 商店草稿

- [繁中名稱／副標題／說明／關鍵字](store/LISTING_ZH_TW.md)，內含 mode 2「原句／原因／改成什麼」。
- [英文 App Review Notes](store/APP_REVIEW_NOTES_EN.md)，逐字列出三分鐘路徑的中文按鈕與英文解釋。
- [截圖清單](store/SCREENSHOTS.md)；1290×2796 與 2064×2752 的實際畫面在 `docs/store/screenshots/`。
- [隱私政策草稿](store/PRIVACY_POLICY_ZH_TW.md) 仍需擁有者核對開發者聯絡資料與公開網址。

## 未完成與缺件

| 狀態 | 缺件／風險 |
|---|---|
| BLOCKED | 0.7.0 最新簽章 iOS／Android 成品、實機飛航模式與背景切換、錄影、長時間發熱／耗電；沒有商店重送或 App Store Connect／Play Console 宣告讀回 |
| BLOCKED | TestFlight／其他真人 beta、具體回饋與改善紀錄；內容提供者身分與是否替客戶代作仍需擁有者確認，不能編造九題答案 |
| BLOCKED | 乾淨機況的 p95 ≤18ms 出貨閘。所有本輪操作秒數均為「並發載量測，僅供參考」，不是實機幀時間或出貨證明 |
| BLOCKED | 額外 Web 生命週期探測：手機已重載讀回；平板在軟體算圖與並發載下等待外圍建置 240 秒仍未完成，未執行到讀檔。`web-lifecycle-probe.json` 保留當時 PCK／結果，不把它說成資料遺失或平板重開通過。最終截圖不重複這項耗時探測 |
| BLOCKED | 原有 native fixture 的非同步啟動修正；本輪明確保留原檔，以新 fixture 補驗 |
| PREPARED | 商店文字、隱私政策、英文審查備註與截圖；尚未成為已上傳商店素材 |
| BLOCKED | 新插畫、商店主視覺、角色表情與三視圖、騎乘 IK、新可授權音效／音樂；本輪未生成，沒有以程序方塊或舊圖冒充新美術驗收 |
| EXECUTED | 原有大型配送／生活選單仍可捲動，返回固定；本輪只保證新案卷與既有暫停測試的操作可達，沒有把全遊戲選單重做成無捲動 |

八大面向：本輪做介面、按鈕、選單、角色敘事與證物操作；人物／地圖／骨架／戰鬥動畫沿用既有素材並保留回歸，不宣稱新增完整第二章、完成全部資產、重做三視圖或通過新動畫製作品質閘。沒有獨立模型覆核或真人測試的宣稱。
