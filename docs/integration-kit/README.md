# 給另一台 GPT 的入庫整合包

這個包包含目前《七期：斷鏈行動》Alpha 0.4.0 的完整可編輯原始碼、Blender 源檔、執行用模型、素材授權與測試，以及接收另一個自製遊戲版本的工單。另一版的原始碼尚未取得；本包已備妥整合入口，沒有宣稱兩個版本已合併。

先讀 [可直接貼給 GPT 的工單](OTHER-GPT-PROMPT.md)、[程式與資料契約](contracts.md)、[機器可讀模組清冊](module-contracts.json)，再執行 [入庫流程](../../plan/process-alternate-game-integration-1.md)。

## 交付內容

- `godot/`：Godot 4.7.2 遊戲、場景、資料、61 份執行用 GLB、貼圖、音效和字型。
- `assets/source/blender/`：可編輯 Blender 模型；`assets/provenance/` 與授權文件保留來源。
- `tests/`、`tools/`、`web/`：原有驗收、建置工具及手機／平板／電腦網頁入口。
- `docs/integration-kit/`：接收規則、工單、實際介面清冊與回交結果格式。
- `INTEGRATION_KIT.json`：ZIP 專用的基準、來源 commit、數量與驗證範圍。
- `FILES.sha256.json`：ZIP 內全部負載檔案的大小和 SHA-256，明確排除該清單本身。

ZIP 來自已提交的 Git 來源，不含 `.git`、`.godot`、私人存檔、依賴快取或憑證。來源包保留 `.gd.uid`、資產 `.import`、原始字型與第三方授權；它們與執行時快取不同。下載 ZIP 後會在單一 `SevenDistrict-integration-kit/` 目錄內解壓。

歷史基準有一份 `godot/_checks/v04_rendered_capture.gd` 本機副本，內容與 `tests/v04_rendered_capture.gd` 相同。本包僅排除副本，保留正式測試檔；`INTEGRATION_KIT.json` 明確記錄這項來源排除，其餘基準檔案依固定 LF Git 匯出規則逐位元組保留，跨作業系統可用同一個 SHA 核對。既有 `v0.4.0` 標籤不移動。

## 在另一台主機開始

1. 解壓縮來源包，保留另一個遊戲的原始工作目錄。
2. 在解壓根目錄執行來源包驗證。該目錄沒有 Git 歷史，先用下方兩種方式之一建立整合 checkout。
3. 將 `OTHER-GPT-PROMPT.md` 貼給另一台 GPT，指定另一版的本機來源目錄；先交回引擎／功能／素材比較，再在 `import/alternate-game` 分支做選定模組的轉接。
4. 交回 PR 網址或可套用的 Git patch，加上 [結果格式](integration-result.schema.json) 規定的 `integration-result.json`。

優先使用 Git clone，在解壓來源包的根目錄執行：

```powershell
$kitMetadata = Get-Content -LiteralPath INTEGRATION_KIT.json -Raw | ConvertFrom-Json
git clone https://github.com/mars-tw/seven-district-reckoning.git seven-district-integration
cd seven-district-integration
git switch -c import/alternate-game $kitMetadata.source_snapshot_commit
```

分支若已存在，先檢查其工作內容，再接續該分支。ZIP 的 `INTEGRATION_KIT.json` 記錄確切來源 commit；需要完全重現來源包時，從該 commit 建立整合分支。不要重設有未提交修改的工作目錄。

不能 clone 時，在已驗證的解壓根目錄建立本機歷史，再切整合分支：

```powershell
git init
git add .
git commit -m "Import verified Seven District source kit baseline"
git switch -c import/alternate-game
```

本機初始 commit 會與上游不同。保留它作為 patch 的父 commit，同時記錄來源包 `source_snapshot_commit`；回交 patch 時附這兩個識別。這個離線方式的未改動檔案仍可由檔案 SHA 核對。來源包目錄驗證在 Git 初始化或 Godot 匯入前執行，否則新增的 `.git`／`.godot` 檔案會使完整目錄清單不同。

同用 Godot 的版本可以逐模組轉接。Three.js、Unity 或其他引擎版本先取出可用模型、貼圖及任務資料，再移植控制、物理與介面。存檔需另外轉換，裝置偏好維持獨立。

## 驗收與來源包驗證

在解壓根目錄執行：

```powershell
python tools/integration_kit.py verify --directory .
```

在 Git checkout 內驗證收到的 ZIP：

```powershell
python tools/integration_kit.py verify --archive deliverables/SevenDistrict-0.4.0-integration-kit-20261005.zip --git-compare
```

這會驗證 ZIP CRC、路徑、SHA-256、數量及基準來源；檔案完整性不等於另一版本的功能相容性。

整合分支的遊戲驗收：

```powershell
python tools/validate_taiwan_life.py
python tools/test_game.py --godot godot --node node
python tools/build_web.py --godot godot --node node
python tools/scan_publication.py
```

`godot` 與 `node` 代表該主機上已安裝的執行檔；可改成其實際路徑。Blender 源檔使用 5.2.0；美術重製的工具可能另外使用 NumPy、Pillow、fontTools。新增內容須增加對應驗收與存檔遷移，保留既有任務 ID、授權和回復路徑。

目前 17 組／8,561 項通過是 Alpha 0.4 的既有驗收結果。本包另行驗證來源與交接檔；尚未驗證另一個遊戲，也未將它部署到公開站點。完整測試、原始證據與實機範圍見 [版本報告](../../qa/v04-release.md)。

## 回交資料

依 [integration-result.schema.json](integration-result.schema.json) 交回引擎版本、來源 commit、已匯入模組／檔案、ID 對應、素材授權、存檔遷移、實測結果與未解問題。實際比較檔放在 `docs/integration-kit/alternate-comparison.md`，驗收報告放在 `qa/alternate-version-review.md`。這兩份是接收端後續產物，不是本包已完成的結果。
