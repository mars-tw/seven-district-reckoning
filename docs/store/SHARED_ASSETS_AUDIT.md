# 共用素材與模板殘留稽核

狀態：VERIFIED（限定範圍的檔案比對），不是二進位相似度或全市場抄襲鑑定。

工具：`python tools/audit_store.py shared`。結果：`docs/evidence/r3-store/shared-assets.json`、`runtime-asset-inventory.json`。唯讀掃描明確列出的 13 個同機遊戲資料夾；只寫本 repo。比較 godot／web 的執行程式、UI、圖示、字型、音訊與模型。排除第三方程式套件、引擎快取、產物、歷史報告與私人目錄；先比大小再計算 SHA-256，大小不同必不可能是同一份檔案。

| 本作檔案／項目 | 與哪款重複 | 處理方式 |
|---|---|---|
| `godot/assets/fonts/NotoSansTC-Regular.otf` | Rift Forge 3D：`Assets/_Project/Resources/Fonts/NotoSansTC-Regular.otf`，SHA-256 `5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537` | 標準 OFL 第三方字型，保留授權。實際 UI 使用本作重命名的文字子集 `SevenDistrictSansTC-Regular.otf`；本輪補齊案卷字元，字型屬標準元件，不以它作原創證明 |
| `godot/scripts/ui/game_hud.gd`、`story_intro.gd`、`web/shell.html`、`web/play-site.css` | 未見逐位元重複 | 保留既有本作風格；開場改為原創留證任務，移除玩家畫面的英文章節代號與開發版字樣 |
| `godot/scripts/ui/fraud_case_panel.gd`、`content/fraud_case.gd` | 新增本作專用；未見逐位元重複 | 紙色案卷、紅色核對標記、甲乙證物與「說詞→紀錄→判斷」三步，與既有深色暫停頁區分 |
| `godot/assets/icon.svg` | 未見逐位元重複 | 既有斷鏈造形，非 Godot 預設機器人圖示，保留 |
| `godot/assets/audio/*` | 未見逐位元重複 | 沿用既有音效與音樂；未生成新音訊，沒有新增人耳試聽驗收 |
| `godot/assets/models/*` 等實際 3D 資源 | 未見逐位元重複 | 沿用具授權／來源記錄的 Blender／GLB；未用方塊冒充本輪新模型 |
| Godot 執行框架、匯出載入器、WebGL／WASM | 引擎為標準第三方；其他 Godot 遊戲也會含引擎 | 照實揭露 Godot 4.7.2／MIT。不得聲稱本帳號唯一本作用 Godot；hash 掃描沒有涵蓋引擎二進位或證明完全不共用演算法 |
| Noto／OFL、Kenney CC0、MakeHuman 來源 | 標準第三方素材庫，可能由其他遊戲各自使用 | 依 `CREDITS.md`、`LICENSE-ASSETS.md` 與 provenance 保留授權；不同模型的 hash 不等於素材庫獨家 |

全部逐檔 SHA-256 在 JSON，沒有隱藏其他命中。對 UI 通用形式的人工程式檢查包含深色選單、圓角按鈕、金色強調：這些常見設計仍存在。本輪把招牌調查頁改為紙色留證簿，沒有將「改配色」說成核心差異。主要差異仍須由可玩的街區調查支持。

覆蓋限制：夜行列車比對的是目前的重製企劃資料夾（13 個符合類型的檔案），未涵蓋舊送審包；其餘結果也限列出的來源樹，沒有全面比對 native-kit 的歷史打包副本或已上傳商店的二進位。商店問題第七題仍須補最終成品元件盤點，不能用此掃描回答「完全沒有共用」。

玩家執行路徑未新增 Lorem、TODO、Sample、敬請期待、空頁或開發者面板。原始碼註解、測試／工具中的工程詞不會顯示給玩家，不為消除搜尋命中而刪除必要測試。保留英文專有名詞與鍵盤識別。

本輪沒有新增點陣美術；`image_model_slug` 為 null。未呼叫 gpt-image-2，也沒有程序圖冒充生成插畫。獨立商店主視覺、角色表情與完整三視圖仍列素材缺件。
