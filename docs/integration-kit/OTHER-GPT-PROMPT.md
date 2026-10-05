# 可直接貼給另一台 GPT 的入庫工單

你正在處理我另一個 GPT 製作的自製遊戲。請把它與《七期：斷鏈行動》整合，做到可檢查、可套用的入庫成果。接收端是 https://github.com/mars-tw/seven-district-reckoning ，Godot 4.7.2／Blender 5.2.0／Alpha 0.4.0。來源包內的 `INTEGRATION_KIT.json` 提供確切基準和來源 commit。

請先讀接收端 `AGENTS.md`、`docs/integration-kit/README.md`、`contracts.md`、`module-contracts.json` 與 `plan/process-alternate-game-integration-1.md`。以我提供的另一版原始工作目錄作 `alternate_source_root`；保留它的原始檔與 Git 歷史。在獨立 checkout 的 `import/alternate-game` 分支工作。

先盤點另一版的引擎／版本、入口、地圖、人物、載具、戰鬥、任務、存檔、手機操作、素材來源與驗證結果。將比較寫入 `docs/integration-kit/alternate-comparison.md`，列出實際可移用的內容、必要轉接及仍缺的檔案。沒有看到的原始碼、素材或測試結果不得宣稱存在。

將選定的新模組逐一接入。模型和可編輯源檔保留來源授權；任務和世界物件保持既有 ID 的名稱與意義，新 ID 採 `EXT-` 命名空間，模型名稱採 `ext_` 前綴。需要更動既有 ID、獎勵或步驟時，提供可測試的存檔遷移與原檔備份。同用 Godot 可整合場景與 GDScript；不同引擎先移植資料和資產，再實作 Godot 轉接。

維持目前主線、41 條生活路線、四種文化活動、32 站可達性、手機／平板／電腦預設與舊存檔支援。新增內容須擴充載入器、驗證器與真實操作測試，保留原有覆蓋，不能刪除斷言或只填完成旗標。源碼內 64 個接點是觀察所得；底線方法不是通用外掛介面。

使用 `tools/test_game.py` 的隔離環境測試，不覆寫玩家存檔。匯出後檢查網頁資源、三種操作版型與素材呈現，記錄實際執行的命令、結果、來源版本與未解問題。不得把 Alpha 0.4 的歷史 8,561 項結果當成這次整合已通過。

完成後交付：

1. `docs/integration-kit/alternate-comparison.md`。
2. `integration-result.json`，符合 `docs/integration-kit/integration-result.schema.json`。
3. `qa/alternate-version-review.md`，包含真實驗收與限制。
4. 整合分支的 PR 網址；若沒有儲存庫寫入權，提供 Git patch、基準 commit 與可套用的來源包。

帳密、API 金鑰、私人存檔、快取及未取得再散布權的素材不得入庫。驗收失敗保留可檢查的結果與具體問題；在分支完成整合，不直接替換 main 或公開部署。發布由接收端依完成的差異與驗收接手。
