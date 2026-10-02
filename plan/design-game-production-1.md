---
goal: "七期：斷鏈行動｜Blender與Godot遊戲製作工單"
version: "1.0"
date_created: "2026-10-02"
last_updated: "2026-10-02"
owner: "專案製作人"
status: "Planned"
tags: [design, game, blender, godot, open-source]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

本計畫含50張開發工單。此次規劃文件已完成，遊戲實作尚未開始；所有工單保持Planned。每張工單的負責角色、相對輸出路徑、依賴、人日與驗收原文存於[工單資料](../planning/tickets.json)，本文依同一資料生成。

專案根為 `.`；表中所有輸出路徑以此根為起點。每張工單只修改所列輸出及必要的相依資料；任何新版本必須同步資料和本文。

## 1. Requirements & Constraints

- **REQ-001**：Slice 必須包含 MAIN-001～005、汽車、自行車、3武器、6類打砸物件及存檔。
- **REQ-002**：MVP 合計12主線、12支線、8活動；五任務線共享引用，不重復計數。
- **REQ-003**：Blender源檔與GLB分開保存，所有素材可追溯來源、作者與授權。
- **REQ-004**：每張工單通過指定驗收並留下證據，才能改成完成。
- **CON-001**：單機離線Windows優先；連線、全城、大型建築倒塌屬Future。
- **CON-002**：不修改旁邊既有Unity或其他遊戲專案；未實作路徑由工單建置。
- **CON-003**：P0是切片／整合關鍵優先級，不等於所有票必須串行；實際先後按depends_on。
- **GUD-001**：美術角色、環境、載具、道具與工程可平行；不得先整合未驗收模型。
- **PAT-001**：每張工單先讀創作書、系統規格、相關資產契約；先驗證依賴再執行。

## 2. Implementation Steps

估算以1人日＝8小時，每階段另留25%整合與修正緩衝，不包含尚未定義的大型追加需求。緩衝人日先對各階段向上取整，再相加，所以Slice＋MVP的上限為227＋177＝404人日。人工估算不是AI加速承諾，需於Slice完成後重新估算。

| 階段 | 工單 | 工作人日 | 加25%緩衝 | 3～4人團隊暫估 |
|---|---:|---:|---:|---|
| Slice | 33 | 120～181 | 150～227 | 10～16週 |
| MVP追加 | 14 | 93～141 | 117～177 | 再8～12週 |
| Slice＋MVP | 47 | 213～322 | 267～404 | 合計約5～8個月 |
| Future研究 | 3 | 52～105 | 65～132 | 完整原型後另排 |

一人完成Slice估7～11個月，完整MVP估12～19個月；角色技能、素材取得與關卡返工會明顯影響日歷。團隊配置建議為工程1～2人、Blender美術1人、關卡／敘事1人；QA及製作人角色可兼任。工期按實際依賴與可用人力排，不把人日直接換成日曆天。

### Implementation Phase 1

- **GOAL-001**：可玩切片。先完成20～30分鐘的完整任務體驗，驗證步行、汽車、自行車、戰鬥、破壞、救援、分支與存檔。

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | **規格與範圍定稿**。角色：製作人／遊戲設計；P0；1～2人日。依賴：無。輸出：`docs/creative-bible.md`、`spec/spec-design-game-systems.md`。執行：固定 300×300m、MAIN-001~005、1車＋1自行車、3武器與六類破壞物；將所有設計值及未做項目註明。驗收：機器檢查範圍與兩份JSON一致；不得加入全城、連線或整棟坍塌承諾。 | 未開始 | 尚未執行 |
| TASK-002 | **工具與硬體基準鎖定**。角色：技術負責人；P0；1～2人日。依賴：TASK-001。輸出：`tools/toolchain.json`、`qa/reference-machine.json`。執行：記錄實際 Blender、Godot 4穩定版、Git/LFS、GPU、RAM；做空專案開啟與Windows離線匯出。驗收：版本與雜湊可讀；離線EXE能啟動；reference-machine不是假定的硬體。 | 未開始 | 尚未執行 |
| TASK-003 | **開源倉庫與來源登記**。角色：工程／素材管理；P0；2～3人日。依賴：TASK-001。輸出：`.gitignore`、`.gitattributes`、`LICENSE`、`LICENSE-ASSETS.md`、`CREDITS.md`。執行：程式採MIT提案、原創資產CC BY 4.0提案；建立來源與權利證據；.blend等二進位使用LFS並忽略快取、憑證、.audit-tmp。驗收：每個納入素材都有來源、作者、license、證據；完整原始碼包能離線重建，LFS內容不是只有pointer。 | 未開始 | 尚未執行 |
| TASK-004 | **Blender→GLB→Godot管線試作**。角色：技術美術；P0；3～5人日。依賴：TASK-002、TASK-003。輸出：`tools/blender/export_assets.py`、`godot/assets/models/pipeline_test.glb`、`qa/import-proof.md`。執行：用手工角色比例模型及一個街道模組驗證1m尺度、朝向、PBR、rig與動畫；.blend放在引擎根外。驗收：重新匯出後無手工補救仍能導入；scale=1且輪pivot與角色腳底符合契約；保存截圖及匯出紀錄。 | 未開始 | 尚未執行 |
| TASK-005 | **第三人稱移動與鏡頭**。角色：遊戲工程；P0；4～6人日。依賴：TASK-002。輸出：`godot/scenes/player/player.tscn`、`godot/scripts/player/player_controller.gd`、`godot/scripts/player/camera_rig.gd`。執行：實作CharacterBody3D行走、跑、跳、地面坡度、鏡頭碰撞與camera-relative方向。驗收：連續穿越路面、坡道與樓梯10分鐘不穿牆；60/30fps下位移差≤5%；鏡頭不穿入牆內。 | 未開始 | 尚未執行 |
| TASK-006 | **輸入重設與基本無障礙**。角色：遊戲工程／介面；P0；2～3人日。依賴：TASK-005。輸出：`godot/scripts/ui/input_settings.gd`、`godot/data/input_defaults.json`。執行：WASD移動、滑鼠視角、E互動、F上下車、Q換武器、Esc暫停；鍵位可改、靈敏度與震動可調、手把對應。驗收：改鍵後重啟保留；重複鍵位有提示；主選單與暫停可用鍵盤／手把完成。 | 未開始 | 尚未執行 |
| TASK-007 | **互動、背包與撿取**。角色：遊戲工程；P0；3～4人日。依賴：TASK-005、TASK-006。輸出：`godot/scripts/interaction/interactable.gd`、`godot/scripts/inventory/inventory.gd`。執行：以interact(actor)共同介面支援道具、門、線索；近戰2格＋遠程1格＋任務道具獨立；武器已有時補耐久／能量。驗收：同時按互動不重複領取；任務道具不可丟棄；車內不能隔牆撿；滿格有替換提示。 | 未開始 | 尚未執行 |
| TASK-008 | **兩街廓灰盒與路線試走**。角色：關卡設計；P0；3～5人日。依賴：TASK-001、TASK-005。輸出：`godot/scenes/world/slice_world.tscn`、`godot/data/maps/slice_layout.json`。執行：只在灰盒階段用佔位形狀；安排生活區、商辦前廣場、園區前站及兩條繞行道路、起點安全屋。驗收：可步行跑完整圈；路寬、轉彎半徑與坡度按載具尺寸probe檢查；地圖外有可見邊界；起點到任務區正常步行≤2分鐘。實際駕車與騎車回歸留TASK-015／016／031。 | 未開始 | 尚未執行 |
| TASK-009 | **道路、碰撞與導航**。角色：關卡／工程；P0；3～4人日。依賴：TASK-008、TASK-004。輸出：`godot/scripts/world/navigation_builder.gd`、`godot/scenes/world/navigation_region.tscn`。執行：靜態場景collision分層、NavigationRegion3D烘焙；人行道／可駕道路分開；出口與門口保留尺寸。驗收：12個敵人同時尋路到各測點不永久卡住；以輪徑與自行車尺寸probe檢查碰撞、離地距離及窄路；導航不跨封閉牆；實際載具回歸於TASK-031。 | 未開始 | 尚未執行 |
| TASK-010 | **守衛與受困者AI**。角色：遊戲工程；P0；4～6人日。依賴：TASK-009。輸出：`godot/scripts/ai/guard_ai.gd`、`godot/scripts/ai/rescue_ai.gd`。執行：守衛巡邏、調查、追擊、失去目標、擊倒；受困者以跟隨／等待／到安全點狀態運作。驗收：守衛不穿牆感知；失去視線有明確退出；救援路線卡住可重新尋路；擊倒敵人不再攻擊。 | 未開始 | 尚未執行 |
| TASK-011 | **近戰與幻想遠程器具**。角色：遊戲工程；P0；4～6人日。依賴：TASK-007、TASK-010。輸出：`godot/scripts/combat/weapon_controller.gd`、`godot/scripts/combat/damageable.gd`。執行：球棒、扳手、虛構脈衝器具；近戰判定只在動畫命中窗；對同一攻擊的同一目標只算一次。驗收：三武器可撿／換／使用；友善受困者免傷；hit_id防重複；牆後無命中；hitstop與鏡頭震動可關。 | 未開始 | 尚未執行 |
| TASK-012 | **全街區武器分布與刷新**。角色：關卡／工程；P0；2～3人日。依賴：TASK-011、TASK-008。輸出：`godot/data/weapons.json`、`godot/data/spawns/slice_pickups.json`、`godot/scripts/world/pickup_spawner.gd`。執行：工具箱、車庫、維修架與掉落物提供武器；初始及基礎補給更新后，每個室外可達點沿行走路徑≤40m到基礎武器；高階能量受限。驗收：導航取樣驗證布局可達；基礎補給可用每180秒的新generation更新，玩家15m內或正在任務目標區延後；用(spawn_id,generation)去重；讀檔保持generation與消費狀態，不刷新高階能量。每spawn_id同時最多1個活躍實例；舊代未消費不換代，離區重訪按registry重建。 | 未開始 | 尚未執行 |
| TASK-013 | **六類預製打砸物件**。角色：遊戲工程／技術美術；P0；4～6人日。依賴：TASK-011、TASK-004。輸出：`godot/scripts/world/destructible.gd`、`godot/data/destructibles.json`。執行：招牌、玻璃隔屏、辦公桌、展示機臺、機櫃外殼、路障使用intact/damaged/broken三狀態；任務證據獨立標記。驗收：六類均有聲音與碎片反應；碰撞隨狀態更新；實體碎片池≤60、壽命≤6秒；證據被砸有fallback。 | 未開始 | 尚未執行 |
| TASK-014 | **城市警戒與增援**。角色：遊戲工程；P0；3～4人日。依賴：TASK-010、TASK-013。輸出：`godot/scripts/world/heat_manager.gd`、`godot/data/heat_rules.json`。執行：heat_level 0~5；可見違規與園區增援升級、離開感知後衰減；城市行人撤離，敵我類型明示。驗收：視野外增援且不在玩家鏡頭內憑空出現；警戒0與5可達；讀檔不清除任務既定警戒。 | 未開始 | 尚未執行 |
| TASK-015 | **汽車街機駕駛**。角色：遊戲工程；P0；5～8人日。依賴：TASK-005、TASK-009。輸出：`godot/scenes/vehicles/car.tscn`、`godot/scripts/vehicles/car_controller.gd`。執行：自訂RigidBody3D射線懸吊控制油門、煞車、轉向、倒車；model朝向經adapter處理；設計限速60km/h。驗收：駕駛、倒車、碰撞、坡道、上下車完整；10圈無失控穿透；翻覆3秒後可重置到最近安全路點。 | 未開始 | 尚未執行 |
| TASK-016 | **自行車街機騎乘**。角色：遊戲工程／動畫；P0；4～6人日。依賴：TASK-005、TASK-009。輸出：`godot/scenes/vehicles/bicycle.tscn`、`godot/scripts/vehicles/bicycle_controller.gd`。執行：CharacterBody3D穩定車身＋視覺側傾、輪旋轉與pedal循環；切片不做真實平衡／車鏈模擬；限速25km/h。驗收：上下車、轉彎、煞車、人行道與窄路可用；騎乘手腳連接正確；停車不倒地；存讀後占用狀態一致。 | 未開始 | 尚未執行 |
| TASK-017 | **載具占用、生成與取回**。角色：遊戲工程；P0；3～4人日。依賴：TASK-015、TASK-016、TASK-007。輸出：`godot/scripts/vehicles/vehicle_registry.gd`、`godot/data/vehicles.json`。執行：統一VehicleControl enter/exit/reset介面；占用互斥、阻擋出口找另一安全側、任務車失落可取回。驗收：同時上車只有一人成功；任務車摧毀／離區不軟鎖；退出不塞進牆；玩家只能同時占一輛。 | 未開始 | 尚未執行 |
| TASK-018 | **資料任務狀態機與分支**。角色：遊戲工程；P0；4～6人日。依賴：TASK-007、TASK-014。輸出：`godot/scripts/missions/mission_manager.gd`、`godot/scripts/data/game_data.gd`、`godot/data/missions.json`。執行：載入docs/missions.json的投產副本；AVAILABLE/ACTIVE/SUCCEEDED/FAILED；唯一objective事件與checkpoint；線索缺失提供替代。驗收：5主線能依依賴解鎖；失敗可重試；objective事件只累計一次；循環依賴／未知ID資料拒載並定位。 | 未開始 | 尚未執行 |
| TASK-019 | **切片任務MAIN-001**。角色：關卡／敘事工程；P0；2～3人日。依賴：TASK-018、TASK-012。輸出：`godot/scenes/missions/main_001.tscn`。執行：依創作書實作受騙開場、手機訊息、互動與第一個工具撿取；只使用虛構平臺畫面。驗收：任務觸發、目標、檢查點、獎勵及失敗重試符合missions.json；新手無外部解說可完成。 | 未開始 | 尚未執行 |
| TASK-020 | **切片任務MAIN-002：假客服的門面**。角色：關卡／敘事工程；P0；2～3人日。依賴：TASK-019、TASK-013。輸出：`godot/scenes/missions/main_002.tscn`。執行：依創作書處理2名安保或替代互動，關閉或破壞假客服招牌；保存可選紀錄，取得前站通行物。驗收：破壞／替代互動兩種方式可通關；紀錄未保存或被毀不軟鎖；通行物可取回；獎勵與重試不重複結算。 | 未開始 | 尚未執行 |
| TASK-021 | **切片任務MAIN-003：兩個輪子的捷徑**。角色：關卡／敘事工程；P0；3～4人日。依賴：TASK-020、TASK-017。輸出：`godot/scenes/missions/main_003.tscn`。執行：依創作書騎任務自行車通過3個街廓節點，把通行物送回車店並取得共用小客車；設定可步行取回與窄巷提示。驗收：騎車完成路線、轉彎與檢查點；失車可取回而不軟鎖；送達後汽車可用；任務物及獎勵不因重試重複領取。 | 未開始 | 尚未執行 |
| TASK-022 | **切片任務MAIN-004**。角色：關卡／敘事工程；P0；3～4人日。依賴：TASK-021、TASK-010、TASK-017。輸出：`godot/scenes/missions/main_004.tscn`。執行：實作救援受困者、可選證據與車輛撤離；NPC明確免傷。驗收：救援者能跟隨到安全區；車不在也有步行替代；每人rescued_count只增加一次。 | 未開始 | 尚未執行 |
| TASK-023 | **切片任務MAIN-005與灰盒整合**。角色：關卡／敘事工程；P0；4～6人日。依賴：TASK-022。輸出：`godot/scenes/missions/main_005.tscn`。執行：園區前站收束；破壞／蒐證／救援三種選法給不同回應並預告MAIN-006；先以灰盒驗證任務串接，不結算全戰役結局。驗收：三選法可分別完成與重試；MAIN-001～005能串接到切片片尾；遊玩時間與正式成品由TASK-031～033驗收。 | 未開始 | 尚未執行 |
| TASK-024 | **角色、骨架與動畫成品**。角色：角色美術／動畫；P0；8～12人日。依賴：TASK-004。輸出：`assets/source/blender/characters/`、`godot/assets/models/characters/`、`godot/assets/animations/`、`assets/source/blender/animations/`、`godot/assets/models/animations/`、`assets/source/blender/textures/`、`godot/assets/textures/textures/`。資產：ASSET-001、ASSET-002、ASSET-003、ASSET-004、ASSET-005、ASSET-006、ASSET-007、ASSET-008、ASSET-009、ASSET-010、ASSET-011、ASSET-012、ASSET-013、ASSET-014、ASSET-062。執行：主角、守衛、受困者與市民共用human骨架；Idle/Walk/Run/Jump/Hit/Melee/Use/Drive/Pedal/Knockdown。驗收：模型與64px剪影可讀；至少10動作導入；腳底、手握、骨架mapping符合Blender文件；不交灰盒人。 | 未開始 | 尚未執行 |
| TASK-025 | **商辦、街道與室內模組成品**。角色：環境美術；P0；10～15人日。依賴：TASK-004、TASK-008。輸出：`assets/source/blender/environment/`、`godot/assets/models/environment/`、`assets/source/blender/world/`、`godot/assets/models/world/`、`assets/source/blender/street/`、`godot/assets/models/street/`、`assets/source/blender/buildings/`、`godot/assets/models/buildings/`、`assets/source/blender/interiors/`、`godot/assets/models/interiors/`、`assets/source/blender/proxies/`、`godot/assets/models/proxies/`、`assets/source/blender/branding/`、`godot/assets/textures/branding/`、`assets/source/blender/textures/`、`godot/assets/textures/textures/`。資產：ASSET-024、ASSET-025、ASSET-026、ASSET-027、ASSET-028、ASSET-029、ASSET-030、ASSET-031、ASSET-032、ASSET-033、ASSET-034、ASSET-035、ASSET-036、ASSET-037、ASSET-038、ASSET-039、ASSET-040、ASSET-041、ASSET-042、ASSET-053、ASSET-060、ASSET-061、ASSET-063。執行：手工模組化外牆、入口、騎樓、道路與大廳／辦公層／機房／屋頂；視覺輪廓有臺中高級商辦感。驗收：材質在遊戲光線下可讀；collision／LOD分離；匯出無丟材質；任務重要物不與環境混色。 | 未開始 | 尚未執行 |
| TASK-026 | **汽車、自行車成品資產**。角色：載具美術／動畫；P0；5～8人日。依賴：TASK-004。輸出：`assets/source/blender/vehicles/`、`godot/assets/models/vehicles/`。資產：ASSET-015、ASSET-016、ASSET-017。執行：一款虛構四輪汽車與一款自行車，獨立輪pivot、方向盤、坐墊、grip／foot marker。驗收：車輪轉向與旋轉正確；騎姿不穿模；上下車定位正確；無真實車廠標誌。 | 未開始 | 尚未執行 |
| TASK-027 | **武器與破壞物成品資產**。角色：道具美術；P0；5～8人日。依賴：TASK-004。輸出：`assets/source/blender/props/`、`godot/assets/models/props/`、`assets/source/blender/weapons/`、`godot/assets/models/weapons/`、`assets/source/blender/destructibles/`、`godot/assets/models/destructibles/`、`assets/source/blender/vfx/`、`godot/assets/models/vfx/`。資產：ASSET-019、ASSET-020、ASSET-021、ASSET-022、ASSET-023、ASSET-043、ASSET-044、ASSET-045、ASSET-048、ASSET-049、ASSET-050、ASSET-051、ASSET-052、ASSET-064。執行：三款武器與六類破壞物全部做成美術資產；破損states與碎片預烘焙，證據色標另層。驗收：每類有破壞前後剪影；手持大小與socket正確；碰撞不過密；達到asset-register驗收。 | 未開始 | 尚未執行 |
| TASK-028 | **手機、HUD、地圖與提示**。角色：介面／工程；P0；4～6人日。依賴：TASK-006、TASK-018。輸出：`godot/scenes/ui/hud.tscn`、`godot/scripts/ui/mission_phone.gd`、`godot/scripts/ui/minimap.gd`。執行：HUD顯示武器、健康、警戒、任務；手機接單與辨別證據／救援；小地圖標示目標／車／安全屋。驗收：1080p與720p不截字；圖示與文字能補充色彩；任務marker不洩漏未解鎖支線；暫停存檔按鈕建立介面，於TASK-031接線後驗收。 | 未開始 | 尚未執行 |
| TASK-029 | **環境、武器、載具與任務聲音**。角色：音效設計；P0；4～6人日。依賴：TASK-011、TASK-013、TASK-017。輸出：`godot/assets/audio/`、`godot/data/audio_events.json`、`CREDITS.md`。執行：原創／權利可用的道路、空調、玻璃、腳步、車聲、自行車鏈聲；繁中字幕配少量原創對白。驗收：聲音位置與類別正確；主音量／對白／效果分別調；所有音源有來源證據；字幕與聲音觸發一致。 | 未開始 | 尚未執行 |
| TASK-030 | **存讀檔與檢查點一致性**。角色：遊戲工程；P0；4～6人日。依賴：TASK-018、TASK-017、TASK-013。輸出：`godot/scripts/save/save_manager.gd`、`godot/data/save_schema.json`。執行：schema_version=1；原子替換＋backup；持久化任務、inventory、評分、車、pickup、破壞與檢查點；不序列化碎片。MAIN-012首次完成的結局ID與分數／救援清單以快照保存。驗收：存讀3個分支各5次無重復獎勵；斷寫用backup可恢復；不合法版本有提示且不覆寫原檔。 | 未開始 | 尚未執行 |
| TASK-031 | **成品整合、光照與效能基準**。角色：技術美術／工程；P0；4～6人日。依賴：TASK-023、TASK-024、TASK-025、TASK-026、TASK-027、TASK-028、TASK-029、TASK-030、TASK-013。輸出：`godot/scenes/world/slice_world.tscn`、`godot/scenes/player/player.tscn`、`godot/data/quality_profiles.json`、`qa/slice-performance.csv`、`qa/slice-build-manifest.json`。執行：替換全部灰盒為驗收後正式資產，接上動畫、HUD、聲音與存檔；固定傍晚光照，建立LOD、occlusion、instancing及低／中畫質；記錄同一build供後續測試。驗收：以同一build完成五主線和三選法；暫停可存檔；參考機1080p Medium目標p95≤20ms、p99≤33.3ms、VRAM≤3GB；20分鐘壓力實測保留CSV及build雜湊。 | 未開始 | 尚未執行 |
| TASK-032 | **新手、字幕與分支可讀性驗收**。角色：QA／設計；P0；3～5人日。依賴：TASK-031。輸出：`qa/slice-playtest.md`、`qa/accessibility-checklist.md`。執行：用TASK-031完成的同一build，至少5名首次體驗者跑完整片；記錄完成時間、迷路、武器取得、任務分支理解與暈眩；修正後需重驗受影響證據。驗收：4/5不口頭提示能完成；3種路線有各1次驗證；字幕尺寸、控制重設及鏡頭效果切換有效。 | 未開始 | 尚未執行 |
| TASK-033 | **可玩切片整合與離線交付**。角色：QA／工程；P0；4～6人日。依賴：TASK-031、TASK-032。輸出：`qa/slice-acceptance.md`、`deliverables/slice-windows/`。執行：依已驗證build封裝源碼、全部.blend與GLB、建置步驟、Windows遊戲、credits及操作說明；五主線完整串接，任何封裝前改動須重驗受影響內容。驗收：運行30分鐘無崩潰／軟鎖；MAIN-001~005全部過關；錯誤率與效能證據達門檻，所有P0/P1缺陷清零。 | 未開始 | 尚未執行 |

### Implementation Phase 2

- **GOAL-002**：完整單機MVP。完成六區地圖、12主線12支線8活動、五任務線及三結局，準備可重建的開源發行包。

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-034 | **六區地圖與分區載入**。角色：工程／關卡；P1；8～12人日。依賴：TASK-033。輸出：`godot/scenes/world/mvp_world.tscn`、`godot/scripts/world/zone_streamer.gd`、`godot/data/maps/mvp_layout.json`。執行：拓展到800×800m六區；100m網格分塊、預載相鄰區、內外場分離；世界坐標與拾取ID固定。驗收：沿主環連續運行20分鐘無掉出地圖；加載前有碰撞就緒；重訪不重復人物／車／獎勵。 | 未開始 | 尚未執行 |
| TASK-035 | **敵人分工與戰鬥節奏擴充**。角色：工程／設計；P1；5～8人日。依賴：TASK-034、TASK-010。輸出：`godot/data/enemy_archetypes.json`、`godot/scripts/ai/squad_coordinator.gd`。執行：巡邏守衛、重型保全、帶隊者不同剪影與行為；同時進攻配額避免圍毆。驗收：三類可讀可反制；同時追擊≤16；高警戒有可撤退路徑；救援者不會被編入敵對組。 | 未開始 | 尚未執行 |
| TASK-036 | **追加七個主線任務**。角色：關卡／敘事；P1；12～18人日。依賴：TASK-034、TASK-035、TASK-023。輸出：`godot/scenes/missions/main_006.tscn`、`godot/scenes/missions/main_012.tscn`、`godot/data/missions.json`。執行：逐一實作MAIN-006~012，按創作書呼叫共用巡邏、破壞、追車、救援與證據目標組件。驗收：12主線合計且不重複切片任務；每任務有重試／checkpoint；MAIN-012發出結局觸發事件，分數可達性與三結局由TASK-039／046驗收。 | 未開始 | 尚未執行 |
| TASK-037 | **十二個支線任務**。角色：關卡／敘事；P1；8～12人日。依賴：TASK-034、TASK-018。輸出：`godot/scenes/missions/side/`、`godot/data/missions.json`。執行：SIDE-001~012全部按創作書，融入受害者互助、街頭破壞、證據、載具與救援線。驗收：12個唯一ID；不完成任何支線仍可主線通關；獎勵、重播與存檔可驗。 | 未開始 | 尚未執行 |
| TASK-038 | **八個沙盒活動**。角色：關卡／工程；P1；6～9人日。依賴：TASK-034、TASK-017、TASK-013。輸出：`godot/scripts/activities/activity_manager.gd`、`godot/data/activities.json`。執行：ACT-001~008計時、技巧、快遞、破壞挑戰等按內容冊實施；每區至少1個活動marker。驗收：8活動唯一ID且重復游玩規則明確；排行榜僅本機；活動不重復計作支線數。 | 未開始 | 尚未執行 |
| TASK-039 | **五任務線與三結局結算**。角色：敘事／工程；P1；5～8人日。依賴：TASK-036、TASK-037。輸出：`godot/scripts/missions/ending_resolver.gd`、`godot/data/endings.json`。執行：五線共享任務引用；MAIN-012按evidence_score、community_trust、rescued_count固定優先序結算三結局。驗收：所有邊界值與組合只回一個ending_id；未達高門檻用fallback；MAIN-005不誤觸完整結局。結局後支線與存讀檔不能改寫首次結局快照。 | 未開始 | 尚未執行 |
| TASK-040 | **載具與街頭器具擴充**。角色：美術／工程；P2；7～11人日。依賴：TASK-034、TASK-026、TASK-027。輸出：`godot/data/vehicles.json`、`godot/data/weapons.json`、`assets/source/blender/vehicles/`、`assets/source/blender/props/`、`godot/assets/models/vehicles/`、`godot/assets/models/props/`、`assets/source/blender/weapons/`、`godot/assets/models/weapons/`、`assets/source/blender/animations/`、`godot/assets/models/animations/`。資產：ASSET-018、ASSET-065、ASSET-066、ASSET-067、ASSET-068、ASSET-070。執行：新增2款四輪車（共3）、保留1款自行車、增加3款遊戲器具（共6）；共用控制與資料。驗收：車型與器具各有可辨識差異；所有新項可拾取／搭乘／存檔；不新增不同物理底層。 | 未開始 | 尚未執行 |
| TASK-041 | **街道變體與園區破損變體**。角色：環境／道具美術；P2；6～9人日。依賴：TASK-034、TASK-027。輸出：`assets/source/blender/environment/variants/`、`godot/assets/models/environment/variants/`、`godot/data/destructibles.json`、`assets/source/blender/destructibles/`、`godot/assets/models/destructibles/`、`assets/source/blender/world/`、`godot/assets/models/world/`、`assets/source/blender/street/`、`godot/assets/models/street/`。資產：ASSET-046、ASSET-047、ASSET-056、ASSET-057、ASSET-058、ASSET-059。執行：六區使用70項基礎清冊的派生配色／標示／破損；核心證據物保存替代證明。驗收：每區有至少2個辨識地景；破壞state存讀一致；遠處不常駐碎片RigidBody。 | 未開始 | 尚未執行 |
| TASK-042 | **交通與行人簡化沙盒**。角色：遊戲工程；P1；6～9人日。依賴：TASK-034、TASK-017、TASK-014。輸出：`godot/scripts/traffic/traffic_manager.gd`、`godot/scripts/ai/civilian_ai.gd`。執行：路徑跟隨車輛、信號停等與遇事故避讓；行人非戰鬥互動、危險逃散；總活動預算固定。驗收：正常車流不撞紅燈行人；20分鐘無永久堵路；近景車≤12＋行人≤24＋敵人≤16上限。 | 未開始 | 尚未執行 |
| TASK-043 | **三棟可進入建築整合**。角色：關卡／美術；P1；8～12人日。依賴：TASK-034、TASK-025。輸出：`godot/scenes/interiors/`、`godot/data/maps/interior_links.json`、`assets/source/blender/buildings/`、`godot/assets/models/buildings/`。資產：ASSET-054、ASSET-055、ASSET-069。執行：含切片核心商辦，共3棟具可進入關鍵樓層；其餘高樓用外殼；室內loading傳送帶清晰過場。驗收：三個入口與出口雙向可走；室內外存檔復原到安全點；沒有承諾每棟每層可進入。 | 未開始 | 尚未執行 |
| TASK-044 | **完整任務音效與字幕**。角色：音效／敘事；P2；6～9人日。依賴：TASK-036、TASK-037、TASK-029。輸出：`godot/assets/audio/dialogue/`、`godot/data/localization/zh_TW.csv`、`CREDITS.md`。執行：補齊12主線與12支線文字對白、重要角色少量配音、音效混音；標題與貨幣全部虛構。驗收：字幕fallback不缺字；對白重播不會破壞任務；音源／字型均有許可證據。 | 未開始 | 尚未執行 |
| TASK-045 | **資料擴充與存檔遷移**。角色：工程；P1；5～7人日。依賴：TASK-039、TASK-040、TASK-030。輸出：`godot/scripts/save/save_migrations.gd`、`tools/validate_game_data.py`、`docs/modding-guide.md`。執行：建立舊版本fixture遷移、JSON任務／道具擴展驗證；僅純資料模組，MVP不執行外部腳本。驗收：切片存檔升級不丟道具／分支；非法循環與未知資產拒載；樣例新增任務可離線導入。結局後完成支線、存讀與遷移仍保留原結局快照。 | 未開始 | 尚未執行 |
| TASK-046 | **全內容回歸與效能門檻**。角色：QA／工程；P0；8～12人日。依賴：TASK-038、TASK-039、TASK-041、TASK-042、TASK-043、TASK-044、TASK-045。輸出：`qa/mvp-acceptance.md`、`qa/mvp-performance.csv`、`qa/known-issues.md`。執行：測試完整12主線12支線8活動、三結局、交通、存讀、資料擴展、弱硬體低檔與引用來源。驗收：P0/P1清零；參考機p95≤20ms目標、p99≤33.3ms目標；60分鐘壓力無crash；全部任務可達。 | 未開始 | 尚未執行 |
| TASK-047 | **開源發行包準備**。角色：工程／素材管理；P0；3～5人日。依賴：TASK-046、TASK-003。輸出：`deliverables/mvp-windows/`、`deliverables/mvp-linux/`、`docs/build-from-source.md`、`docs/release-checklist.md`。執行：準備源碼含LFS實檔、Blender源檔、遊戲二進位、Godot／第三方版權；Windows主驗收，Linux相容驗證；只在本機打包。驗收：乾淨目錄按說明可建置；兩平臺啟動證據齊；秘密／未授權素材掃描無發現；公開發布另按當次授權。 | 未開始 | 尚未執行 |

### Implementation Phase 3

- **GOAL-003**：擴充研究。用獨立原型與實測評估更大城市、合作連線及更多載具，再訂生產排程。

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-048 | **更大城市與晝夜天氣**。角色：研發／美術；P3；20～40人日。依賴：TASK-047。輸出：`docs/future/city-expansion-study.md`。執行：研究完整七期風格更大地圖、多時段燈光、雨夜，先評估內存、工作量與任務密度。驗收：產出研究與測量原型后重新估算；不是首版驗收或現有完成狀態。 | 未開始 | 尚未執行 |
| TASK-049 | **連線合作研究**。角色：網路工程；P3；20～40人日。依賴：TASK-047。輸出：`docs/future/co-op-study.md`。執行：評估2~4人同步、房主權威、反作弊、存檔分歧；與單機代碼清晰隔離。驗收：獨立原型證明載具／破壞同步與重連，之后才能列生產工單；不把單機MVP改稱已支援多人。 | 未開始 | 尚未執行 |
| TASK-050 | **更多載具與物理研究**。角色：研發／動畫；P3；12～25人日。依賴：TASK-047。輸出：`docs/future/vehicle-study.md`。執行：研究機車、載具損壞外觀與更真實自行車；保持Slice的arcade版本可用。驗收：獨立原型有控制與效能比較，未經過驗證不替換原控制器。 | 未開始 | 尚未執行 |

TASK-023只驗證五主線的灰盒串接；成品美術製作集中TASK-024～027，來源於TASK-003登記。TASK-031整合正式模型、動畫、介面、聲音及存檔，TASK-032用同一build做新手測試，TASK-033封裝同一已驗證版本。TASK-033通過才開MVP工單；TASK-047僅準備本機發行包。

## 3. Alternatives

- **ALT-001**：Unity runtime 可接Blender，但本案優先採Godot以符合整套開源工具方向，並避免直接混入既有Unity專案。
- **ALT-002**：直接導入.blend方便本機熱更新；本案採GLB作交換資產，減少每個工程環境的Blender依賴。
- **ALT-003**：即時全建築破壞成本高；先採預製三狀態破損與有限碎片。
- **ALT-004**：先做大地圖會延後完整體驗驗收；先以兩街廓切片驗證所有核心機制。

## 4. Dependencies

- **DEP-001**：TASK-002鎖定相容工具版本及參考機；後續性能標準使用同一機器和流程。
- **DEP-002**：TASK-004建立Blender→GLB→Godot契約；正式美術任務必須通過同一導入流程。
- **DEP-003**：TASK-018把創作任務資料變成執行目標，TASK-030提供持久化；任務不得繞過狀態機自行發獎勵。
- **DEP-004**：TASK-033為MVP開工基準，TASK-046為發行準備基準；獨立子工作可平行但不得跳過相依票。
- **DEP-005**：每張票的depends_on為完整直接依賴；間接依賴可經圖追溯，不需重複手填。

## 5. Files

- **FILE-001**：`planning/tickets.json`，50張工單及唯一狀態資料。
- **FILE-002**：`docs/creative-bible.md`、`docs/missions.json`，創作來源與任務索引。
- **FILE-003**：`docs/blender-production.md`、`docs/asset-register.json`，源檔、匯出、pivot、動畫及素材驗收。
- **FILE-004**：`spec/spec-design-game-systems.md`，共用狀態、系統介面、存檔與驗收。
- **FILE-005**：`godot/`、`assets/source/blender/`、`tools/`、`qa/`、`deliverables/`，未來各工單建立的遊戲與製作檔案。

## 6. Testing

- **TEST-001**：規劃靜態檢查：JSON可解析、唯一ID、依賴存在且無循環、phase先後、估算合計與相對路徑。
- **TEST-002**：開發後任務系統檢查：重試、checkpoint、event去重、三分支、三結局閾值與毀損fallback。
- **TEST-003**：開發後載具檢查：上下車、占用、安全出口、碰撞、坡道、翻覆恢復與讀檔。
- **TEST-004**：開發後美術檢查：GLB重匯入、材質、骨架、動作、LOD、64px剪影與正式模型替換。
- **TEST-005**：開發後效能：固定測試路線、近景數量上限、原始frame-time資料、3次量測與30／60分鐘穩定性。
- **TEST-006**：發行準備：來源授權、LFS實檔、乾淨重建、Windows／Linux啟動、離線運行。

## 7. Risks & Assumptions

- **RISK-001**：開放世界、載具和動態破壞同時整合容易造成軟鎖及效能尖峰；先以Slice量測縮小範圍。
- **RISK-002**：自行車腳踏／手把動畫與控制對齊是獨立工作，不視為汽車換模型即可完成。
- **RISK-003**：Blender自訂節點不一定可直接映射glTF；以PBR可匯出材質為契約。
- **RISK-004**：第三方模型有下載權不等於有發行權；沒有權利證據不得進發行清冊。
- **RISK-005**：AI協助可節省部分時間，無法預先保證整體工期下降；第一次切片後以實際速度重估。
- **ASSUMPTION-001**：畫風採風格化3D，使用原創七期風格都市，不追求逐棟實景掃描與真人肖像。
- **ASSUMPTION-002**：先針對Windows鍵鼠／手把單機；Linux於MVP準備階段驗證。
- **ASSUMPTION-003**：目前沒有確定的人力或預算；文中工期為配置3～4人的暫估。
- **ASSUMPTION-004**：此次不安裝軟體、不產模型、不開遊戲開發、不公開發布。

## 8. Related Specifications / Further Reading

- [系統規格](../spec/spec-design-game-systems.md)
- [創作內容與任務](../docs/creative-bible.md)
- [Blender資產製作](../docs/blender-production.md)
- [Godot 3D匯入官方文件](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- [Godot官方授權](https://godotengine.org/license/)

官方資料存取日期：2026-10-02。

