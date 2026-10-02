---
title: "七期：斷鏈行動｜遊戲系統與資料契約"
version: "1.0"
date_created: "2026-10-02"
last_updated: "2026-10-02"
owner: "專案製作人與技術負責人"
tags: [design, open-world, blender, godot, planning]
---

# Introduction

本文件把《七期：斷鏈行動》的創作方向轉成可驗收的系統需求。這是規劃版；本次沒有建立 Blender 模型、Godot 遊戲或可執行遊戲檔。所有速度、數量、時間與效能數字均為設計目標，開發工單必須留下實測證據。

## 1. Purpose & Scope

原創第三人稱沙盒動作遊戲。玩家遭虛構虛擬貨幣平臺詐騙後，追查包裝成高級商辦的詐騙組織；可以破壞其展示設備、擊倒守衛、蒐集證據、救出受困者，並駕車或騎自行車撤離。任務設計讓這些做法產生不同後果。

| 項目 | Slice 可玩切片 | MVP 最小可行版本 | Future 擴充研究 |
|---|---|---|---|
| 地圖 | 300×300 公尺、兩街廓 | 800×800 公尺、六區 | 更大城市，另行估算 |
| 任務 | MAIN-001～005；20～30 分鐘 | 合計 12 主線、12 支線、8 活動 | 新篇章 |
| 任務線 | 展示破壞、蒐證、救援的選法 | 五條線，共用任務引用 | 追加故事線 |
| 載具 | 1 款汽車＋1 款自行車 | 合計 3 款汽車＋1 款自行車 | 機車、更多載具 |
| 武器 | 3 款遊戲器具 | 合計 6 款 | 新器具 |
| 室內 | 1 棟核心商辦的指定空間 | 合計 3 棟的關鍵樓層 | 擴充室內 |
| 破壞 | 至少 6 類物件、三狀態 | 變體及更多配置 | 大型破壞研究 |
| 平臺 | Windows 單機 | Windows 主驗收、Linux 相容驗證 | 連線合作研究 |

MVP 的總數包含 Slice，不能把同一任務重算一次。切片 MAIN-005 為前站章節收束，完整戰役在 MAIN-012 結算。城市各區採七期的高樓、公園、寬街與停車空間作視覺靈感；遊戲路網、企業、園區及室內均為虛構設計。

## 2. Definitions

| 名稱 | 定義 |
|---|---|
| Slice | 可從開場玩到章節收束的垂直切片，用來驗證整套體驗 |
| MVP | 能完成單機戰役且包含所有指定核心系統的第一個完整版本 |
| GLB | 封裝模型、材質及動畫資料的 glTF 2.0 二進位檔 |
| LOD | 依距離切換不同細節模型 |
| 灰盒 | 測量路線與碰撞的暫時佔位場景；正式美術工單需替換 |
| 人日 | 8 小時工作的估算單位，不能直接當成日曆天數 |
| Heat | 遊戲警戒等級，0～5 |
| P0／P1 缺陷 | 阻止啟動／造成崩潰、存檔損毀、任務無法通關，或核心功能失效 |

## 3. Requirements, Constraints & Guidelines

- **REQ-001**：玩家可走、跑、跳、互動，鏡頭具有牆面碰撞。
- **REQ-002**：Slice 同時包含可駕駛汽車和可騎乘自行車，並可上下車、煞車與重置。
- **REQ-003**：Slice 三款武器為球棒、扳手與虛構脈衝器具；傷害判定防重複，玩家可撿取及換武器。
- **REQ-004**：初始布局及基礎補給更新後，室外每個可達導航取樣點沿行走路徑 40 公尺內至少有一個可用基礎武器；高階能量不能無限刷新。
- **REQ-005**：六類指定破壞物使用 intact、damaged、broken 三狀態；損壞影響碰撞、聲音及外觀。
- **REQ-006**：守衛有巡邏、調查、追擊、失去目標、擊倒等行為；受困者採跟隨／等待／安全抵達。
- **REQ-007**：Heat 0～5 可升降；任務最低警戒與自由活動警戒分開記錄。
- **REQ-008**：任務由資料定義，包含依賴、目標、觸發、失敗、重試、檢查點與獎勵。
- **REQ-009**：證據毀損、任務車丟失、救援者卡路都有替代推進方式。
- **REQ-010**：存讀檔包含任務、持有物、世界狀態、載具及分支分數，不能重複發獎。
- **REQ-011**：MVP 包含唯一的 12 主線、12 支線、8 活動，並讓五任務線引用這些任務。
- **REQ-012**：三結局只有 MAIN-012 能觸發，採創作書明定的優先序與閾值。
- **REQ-013**：繁中字幕、鍵位重設、鏡頭效果切換及至少低／中畫質設定可用。
- **REQ-014**：保留 Blender 源檔、GLB、貼圖與可重建的 Godot 原始碼，提供來源登記。
- **REQ-015**：所有 AI、拾取、載具、碎片及分區生成使用穩定 ID 和數量上限。
- **CON-001**：本次只完成企劃、創作內容、資產清冊、工單與規格；所有開發工單保持 Planned。
- **CON-002**：單機離線為第一版核心；遊戲內貨幣與平臺均為虛構，不連真實錢包。
- **CON-003**：正式模型須經 Blender 美術處理，灰盒不能當最終美術交付。
- **CON-004**：切片採固定傍晚時段與局部物件破壞，整棟建築倒塌列 Future 研究。
- **CON-005**：使用原創名稱、角色、地圖、音樂與 UI；GTA 只用來說明類型參考。
- **GUD-001**：程式採 MIT、原創素材採 CC BY 4.0 為授權提案；第三方依實際來源登記保留原授權。
- **GUD-002**：英雄、守衛、受困者與證據物有不同剪影、圖示及文字標記；不以單一顏色傳達關鍵資訊。
- **PAT-001**：控制器、資料、匯入模型與關卡場景分離；重新匯入 GLB 不覆寫程式與任務。

## 4. Interfaces & Data Contracts

專案根為 `.`。下列路徑均相對於此根；它們是未來實作位置，本次只建立 planning、spec 及 docs 文件。

```text
assets/source/blender/       Blender 原始模型，放在引擎根外
godot/                      Godot 專案及 project.godot
godot/assets/models/        可重複匯出的 GLB
godot/assets/audio/         聲音及音樂原始檔的遊戲副本
godot/data/                 任務、武器、載具、字幕、生成點資料
godot/scenes/               角色、載具、關卡、UI 與任務場景
godot/scripts/              各系統程式
tools/                      匯出、資料檢查及封裝工具
qa/                         開發後的測試證據
deliverables/               開發後的離線交付包
```

| 介面 | 呼叫／事件 | 契約 |
|---|---|---|
| Interactable | `interact(actor_id)` | 玩家在距離與視線內，成功僅一次；失敗回傳原因 |
| Damageable | `apply_hit(hit_id, source_id, damage)` | 同一 hit_id 同一目標只命中一次；救援者免傷 |
| VehicleControl | `enter(actor_id)`、`exit()`、`reset()` | 占用互斥，出口必須安全，角色和載具關係雙向一致 |
| Destructible | `set_damage_state(state)` | 唯一 object_id，碎片不持久化，碰撞隨狀態改變 |
| MissionManager | `emit_objective(event_id, target_id, value)` | event_id 去重，只有 ACTIVE 任務累計 |
| SaveManager | `save(slot)`、`load(slot)` | schema_version 檢查、原子替換、備份及錯誤回報 |
| ZoneStreamer | `activate(zone_id)`、`deactivate(zone_id)` | 先載入碰撞再允許進入；重訪使用持久化世界狀態 |

任務製作來源為 `docs/missions.json`，投產副本為 `godot/data/missions.json`。兩檔須通過 ID、依賴及數量檢查；工單驗收時不得只改一份。製作來源的描述型 objectives 要由 TASK-018 轉成帶穩定 objective_id 的執行條件，然後保留來源對照，不能直接當任意腳本執行。

持久化欄位至少包含：

```json
{
  "schema_version": 1,
  "checkpoint_id": "CP-MAIN-003-ENTRY",
  "player": {"position": [0, 0, 0], "health": 100, "vehicle_id": null},
  "scores": {"evidence_score": 0, "community_trust": 50, "rescued_count": 0, "heat_level": 0},
  "missions": {},
  "rewarded_mission_ids": [],
  "consumed_event_ids": [],
  "ending_snapshot": null,
  "inventory": {"melee": [], "ranged": [], "quest": []},
  "world": {"pickups": {}, "destructibles": {}, "rescues": {}, "vehicles": {}}
}
```

evidence_score 與 community_trust 限 0～100；rescued_count 為非負整數；heat_level 限 0～5。預設 evidence_score＝0、community_trust＝50、rescued_count＝0、heat_level＝0。分數變更必須來自有 ID 的事件，讀檔不能再次累計。檢查點 ID、position 與載具位置均為格式示例，不代表已建場景或實際地理坐標。

武器刷新以（spawn_id，generation）識別實例。基礎補給每 180 秒可產生新 generation；玩家 15 公尺內或正在任務目標區時延後。存檔保存 generation、已拾取旗標及遊戲時間，讀檔沿用同一代，不能靠重讀洗出物品。高階器具與能量採任務獎勵或固定有限補給。40 公尺是布局與補給更新時點的可達性檢查，不承諾玩家拿光後每一刻都有新道具。

每個 spawn_id 同時最多一個活躍拾取實例。舊代未消費時保留當代；只有舊代已消費且刷新條件成立才建立新代。離區重訪按持久化 registry 重建，不能疊放不同代實例。

MAIN-012 首次成功時建立 ending_snapshot，包含 ending_id、完成事件 ID、當時 scores 與已救 npc_id 清單；寫入後不重算。結局後可做支線，但只更新自由探索狀態；讀檔與重播使用既有快照。新遊戲的快照為 null，不能把 null 視為第三結局。

Blender 採 1 unit＝1 公尺。美術模型朝前與鏡頭朝前不同：遵守 Blender 製作文件的模型＋Z 前向匯入契約；人物與載具控制器以明確 adapter 轉換。禁止把攝影機的－Z 直接套在所有模型上。所有 source_path／export_path／pivot／動畫名稱以資產清冊為準。

## 5. Acceptance Criteria

- **AC-001**：玩家從安全屋開始，依序完成 MAIN-001～005，能抵達切片片尾並繼續自由活動。
- **AC-002**：同一角色能上下汽車及自行車，各完成完整街廓一圈；出口受阻時改用安全側。
- **AC-003**：任一基礎武器被撿起後可使用；滿格有替換提示；任務道具保持獨立。
- **AC-004**：任一破壞物進入 broken 後，外觀、碰撞、音效與存檔狀態一致。
- **AC-005**：玩家毀掉關鍵證據或丟失任務車，仍能透過替代目標通關。
- **AC-006**：儲存 ACTIVE、FAILED、SUCCEEDED 狀態後重載，各自不重複給獎勵或救援計數。
- **AC-007**：第一次玩家測試至少 5 人，4 人能在沒有口頭提示下完成切片；記錄時間而非宣稱保證 20～30 分鐘。
- **AC-008**：MVP 任務檢查得到 MAIN＝12、SIDE＝12、ACT＝8，依賴無循環。
- **AC-009**：MAIN-012 在所有分數邊界組合都只產生一個結局；MAIN-005 不呼叫完整結局。
- **AC-010**：參考機、畫質、解析度與測試路線有記錄；效能目標達成須附原始量測，不用主觀畫面感受代替。
- **AC-011**：乾淨目錄可從來源及源模型重建，匯入與匯出不依賴未記錄的個人設定。
- **AC-012**：發行清冊中沒有來源不明的模型、音效、字型或授權空白項。

## 6. Test Automation Strategy

這是未來遊戲的測試策略，本次僅執行企劃資料與文件的靜態檢查。

- **Test Levels**：資料檢查、核心狀態機單元測試、場景整合、人工操作流程、效能量測。
- **Frameworks**：Python 標準函式庫檢查 JSON；Godot headless 場景測試及 exit code；是否加入第三方測試插件由 TASK-002 留下相容證據後決定。
- **Test Data Management**：固定 seed、任務檢查點、三分支與結局邊界 fixture；測試存檔和正式存檔分開。
- **CI/CD Integration**：未來開源倉庫可在 CI 做 JSON、匯入與 headless smoke；平臺遊玩及效能需參考機驗證。
- **Coverage Requirements**：覆蓋獎勵去重、任務失敗重試、分數邊界、載具占用與存檔備份；不以沒有意義的行數百分比代替。
- **Performance Testing**：固定近景車≤12、行人≤24、敵人≤16、動態碎片≤60。Slice 20 分鐘，MVP 60 分鐘壓力流程；至少三次量測。1080p Medium 目標 p95≤20ms、p99≤33.3ms、VRAM≤3GB、遊戲 RAM≤4GB。這些上限必須經 TASK-031／046 校準。
- **Frame Definition**：Godot 60Hz physics；不將兩個 p95 指標相加推算總幀率。記錄 frame time 原始序列、載入尖峰與版本。

## 7. Rationale & Context

Blender 負責角色、城市、載具、道具、材質與動畫；Godot 負責輸入、碰撞、AI、任務、存檔及執行遊戲。Godot 為 MIT 授權開源引擎，遊戲內容可另選授權。[Godot 官方授權](https://godotengine.org/license/)

引擎輸入使用 GLB。官方文件推薦 glTF 2.0，並說明直接導入 .blend 需要呼叫本機 Blender；分離源檔與執行資產方便協作及重新匯入。[Godot 3D 匯入格式](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)

汽車使用自訂控制，優先確保低速操作、街道轉彎和撞擊回饋。Godot 官方對 VehicleBody3D 列有已知限制，因此本案不把它視為無需調整的 GTA 載具系統；自行車也以街機穩定車身降低平衡模擬成本。[Godot VehicleBody3D](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html)

七期氛圍參考高樓與公園相鄰的城市空間，公園可提供步行和自行車路線；這是由官方景觀資料推導的創作選擇。[臺中市政府秋紅谷景觀資料](https://www.taichung.gov.tw/media/271038/721316281471.pdf)

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**：Blender 編輯及匯出系統；必須保留原始檔、可重複匯出與版本紀錄。

### Third-Party Services

- **SVC-001**：執行遊戲無外部服務必要性；不要求 API key、登入或網路才能通關。

### Infrastructure Dependencies

- **INF-001**：Windows 開發與主驗收機；GPU、RAM、驅動與畫質設定於 TASK-002 實測記錄。
- **INF-002**：Git/LFS 源檔管理與本機備份；離線源碼包必須包含 LFS 實檔。

### Data Dependencies

- **DAT-001**：missions.json、asset-register.json、tickets.json 及各版資料契約；ID 必須唯一。
- **DAT-002**：美術參考只記公開來源，未取得可用素材權利證據前不納入遊戲交付包。

### Technology Platform Dependencies

- **PLT-001**：Godot 4 系列穩定版本與相容的 Blender 穩定版本；由 TASK-002 及 TASK-004 選定、記錄及驗證，不假稱已安裝最新版。

### Compliance Dependencies

- **COM-001**：程式、原創素材與第三方元件分別列授權；CC BY 4.0 素材須署名、連結與修改說明。[CC BY 4.0 官方條款摘要](https://creativecommons.org/licenses/by/4.0/)

## 9. Examples & Edge Cases

| 情況 | 必要回應 |
|---|---|
| 關鍵機櫃被砸，原線索不可取 | 語音或任務提示告知替代證據；降低證據分數，不阻止通關 |
| 玩家在救援過程離區 | 已救者保留狀態，未到安全點者回可靠的導航點並提供提示 |
| 載具出口被牆堵住 | 試另一側，無安全點則禁止退出並提示移車 |
| 翻覆／掉出地圖 | 回最近安全路點，不將玩家送進任務未解鎖區 |
| 序列化中斷或存檔不合法 | 保留原檔，從 backup 恢復；無可用 backup 才回報失敗 |
| 完成事件傳入兩次 | 回第二次已消費狀態，不再加分或給道具 |
| 熱度為 5 而主線需對話 | 對話安全點／暫緩條件由任務指定，不讓敵人無限刷新卡死 |
| 尚未完成支線就進入終章 | 主線仍可通關，三結局依當前分數確定 |
| 素材路徑存在但授權不明 | 工具判為不可發行，不以檔案存在當作權利取得 |
| 切片五主線通關 | 只顯示章節收束與分支預覽，完整結局留給MAIN-012 |

## 10. Validation Criteria

規劃驗證要求：三份 JSON 可解析，50 個工單 ID、任務 ID 及資產 ID 唯一；工單依賴無循環且不得依賴未來階段；檔案路徑留在專案根；工單數量和人日合計與導覽一致；全部開發工單為 Planned。

遊戲驗證要求：AC-001～012、切片及 MVP 對應工單的驗收全部完成，才可以稱遊戲已完成。規劃靜態檢查通過不能替代模型、遊玩或效能實測。

## 11. Related Specifications / Further Reading

- [創作內容](../docs/creative-bible.md)
- [Blender 製作規範](../docs/blender-production.md)
- [工單與開發計畫](../plan/design-game-production-1.md)
- [Godot 授權](https://godotengine.org/license/)
- [Godot glTF／Blender 匯入](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)

官方資料存取日期：2026-10-02。

