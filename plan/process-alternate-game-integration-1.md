---
goal: 將另一台主機的自製遊戲逐模組接入七期專案
version: 1
date_created: 2026-10-05
last_updated: 2026-10-05
owner: Seven District contributors
status: Planned
tags: [integration, handoff, assets, migration]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

本工單執行在另一台 GPT 的主機。`alternate_source_root` 定義為使用者指定的另一版原始工作目錄；`kit_root` 定義為解壓後包含 `INTEGRATION_KIT.json` 的目錄；`target_root` 定義為獨立的 `seven-district-integration` checkout。接收端網址是 `https://github.com/mars-tw/seven-district-reckoning`，基準 commit 是 `f296dbdbee6696778891b7f471665db2a8bdba24`。這是待執行的版本整合工單；入庫來源包的製作與驗證另行記錄。

## 1. Requirements & Constraints

- **REQ-001**: 先讀 `docs/integration-kit/module-contracts.json`，盤點另一版可用的原始碼、資產、引擎版本及驗證證據。
- **REQ-002**: 保留現有主線、生活任務／活動、操作預設與存檔；新增 ID 使用 `EXT-`，新模型檔名使用 `ext_`。
- **SEC-001**: 所有入庫檔案須有來源與散布權；秘密、使用者存檔及依賴快取不加入 Git。原始提供的腳本先讀後執行。
- **CON-001**: 僅在 `target_root` 的 `import/alternate-game` 分支修改；不覆寫 `alternate_source_root`，不自動部署。
- **GUD-001**: Godot 使用 `godot/project.godot`，模型 GLB 保留公尺、Godot +Y 上／+Z 模型正面；人物插槽與八段動畫按契約驗證。
- **PAT-001**: 資料／素材與引擎相依程式分開移用。每個模組做有界轉接，在 `godot/scripts/main.gd` 接入實際訊號及管理器。

## 2. Implementation Steps

### Implementation Phase 1

- **GOAL-001**: 確認來源、建立保留基準的整合分支，取得可重現的比較。

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | 在 `kit_root` 讀取來源包 `INTEGRATION_KIT.json`，使用 `python tools/integration_kit.py verify --directory .` 驗證；有 Git 歷史時核對 `source_snapshot_commit`。來源不完整時停止該缺檔的移植並寫明問題。 | 否 | 尚未執行 |
| TASK-002 | 檢查兩個工作目錄的 Git 狀態並保存現有修改；從來源包 commit 建立或接續 `import/alternate-game`，不使用 hard reset。 | 否 | 尚未執行 |
| TASK-003 | 讀另一版 `project.godot`、`package.json`／lock 或 `ProjectSettings/ProjectVersion.txt` 及實際入口；寫 `docs/integration-kit/alternate-comparison.md`，包含模組、ID、模型、授權、建置命令與真實證據。 | 否 | 尚未執行 |

### Implementation Phase 2

- **GOAL-002**: 依 TASK-003 的引擎分類接入選定模組，保留既有功能與可回復來源。

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | 將選定 Blender 源檔放 `assets/source/blender/`、執行 GLB 放 `godot/assets/models/`，新名 `ext_`；保留相對貼圖、比例、骨架／插槽與 provenance，在適用模型清冊記錄 SHA-256／授權。 | 否 | 尚未執行 |
| TASK-005 | 轉換選定任務／站點資料為 `godot/data/` 接收格式，建立 `EXT-` ID 對應。新增活動同時調整 `TaiwanActivities.load_definition()`、`from_dict()` 及測試；保持舊項目可讀。 | 否 | 尚未執行 |
| TASK-006 | Godot 來源用契約接入場景／控制器；其他引擎重新實作對應 GDScript 轉接，再由 `main.gd::_ready()` 建立管理器與訊號，按內容路徑、UI 回呼及交通代碼執行整合。 | 否 | 尚未執行 |
| TASK-007 | 更動已保存的 ID／規則時，新增明確存檔版本／轉換與原檔備份，通過 `_valid_world_save()` 及子管理器 `from_dict()`；裝置偏好仍留 `user://device-preferences-v1.cfg`。 | 否 | 尚未執行 |

### Implementation Phase 3

- **GOAL-003**: 完成可入庫的實測結果、差異與回交資料。

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-008 | 執行 `python tools/validate_taiwan_life.py`、`python tools/test_game.py --godot godot --node node`；新增內容擴充對應案例和基準集合包含檢查，不削減舊覆蓋。 | 否 | 尚未執行 |
| TASK-009 | 執行 `python tools/build_web.py --godot godot --node node`，在本機 preview 以 `tools/verify_web.mjs` 驗 hash／MIME／入口，實際檢查三版操作、場景、載具、背包與存讀檔；範圍未測就明示。 | 否 | 尚未執行 |
| TASK-010 | 執行 `python tools/scan_publication.py`，交回符合 `docs/integration-kit/integration-result.schema.json` 的 `integration-result.json`、`qa/alternate-version-review.md` 與 PR／Git patch；驗收失敗狀態寫 `needs_work`，不可寫 completed。 | 否 | 尚未執行 |

## 3. Alternatives

- **ALT-001**: 同 Godot 引擎逐模組整合，適用於可滿足現有生命週期與資料契約的來源。
- **ALT-002**: 不同引擎先移用已授權的 GLB、Blender、貼圖與資料，再重新實作引擎相依部分。
- **ALT-003**: 維持獨立遊戲，適用於只有可執行檔、缺乏原始碼／授權，或不能完成轉接驗收的模組；記錄原因，保留已可工作的部分。

## 4. Dependencies

- **DEP-001**: `alternate_source_root` 必須是使用者指定且可讀的另一版完整原始目錄；現有接收端未取得它。
- **DEP-002**: `target_root` 需要 Git、Python 3.12、Node.js 與 Godot 4.7.2；重製美術另需 Blender 5.2.0 及該工具宣告的 Python 套件。
- **DEP-003**: TASK-004 至 TASK-007 依賴 TASK-003 的來源分類；TASK-008／TASK-009 依賴完成的選定模組；TASK-010 依賴實際測試結果。

## 5. Files

- **FILE-001**: `docs/integration-kit/alternate-comparison.md`、`integration-result.json`：接收端產生的比較與可讀結果。
- **FILE-002**: `godot/scripts/main.gd` 與選定管理器／UI：有界接線，不替換整個入口。
- **FILE-003**: `godot/data/`、`godot/assets/models/`、`assets/source/blender/`、`assets/provenance/`：資料、來源、匯出與授權同步。
- **FILE-004**: 對應 `tests/` 與 `qa/alternate-version-review.md`：新增測試與真實驗收。

## 6. Testing

- **TEST-001**: 驗來源包 CRC、SHA-256、路徑與基準；這與外來遊戲的功能驗收分開。
- **TEST-002**: 完整 import／17 組現有案例保持通過，新增操作與舊存檔遷移有真實失敗／成功分支。
- **TEST-003**: 32 舊站仍可達、41 舊路線保持可完成、四舊活動可操作，新增內容另有對應操作與可達性結果。
- **TEST-004**: 手機／平板／電腦的版型、3D 預算、輸入、儲存與偏好保留；未驗實機效能不得由桌機模擬代稱。

## 7. Risks & Assumptions

- **RISK-001**: 既有任務獎勵、步驟與 ID 被更動會使舊存檔驗證失敗，必須先完成 TASK-007。
- **RISK-002**: 外來材質、骨架、碰撞或三角形數量可能超出手機預算；保留原始來源，輸出受預算約束的可測版本。
- **ASSUMPTION-001**: 另一版是使用者自己的自製專案；具體引擎和再散布權仍由 TASK-003 的實際來源確認。

## 8. Related Specifications / Further Reading

[入庫整合包說明](../docs/integration-kit/README.md) · [現行介面契約](../docs/integration-kit/contracts.md) · [建置工具](../tools/test_game.py) · [資產授權](../LICENSE-ASSETS.md) · [現有版本驗收](../qa/v04-release.md)
