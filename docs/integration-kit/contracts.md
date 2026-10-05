# 目前專案的整合契約

這份文件供另一台主機的製作者對照。接收端是 Alpha 0.4.0，基準 commit 為 `f296dbdbee6696778891b7f471665db2a8bdba24`，使用 Godot 4.7.2 stable 與 Blender 5.2.0。機器可讀清冊在 [module-contracts.json](module-contracts.json)。

本次直接檢查了目前的程式、資料與資產清冊；沒有重新執行遊戲測試。另一個遊戲的引擎與原始碼尚未提供，因此尚無跨遊戲相容性結論。

## 可以共用什麼

| 內容 | 接收方式 |
| --- | --- |
| 任務、站點、物品與活動 JSON | 保留現有 ID；檢查 schema、引用與規則，再轉成接收端資料結構。 |
| GLB／glTF 2.0、貼圖 | 保留來源與授權；檢查單位、軸向、材質、骨架、動畫、插槽與碰撞。 |
| Blender 原始檔 | 放在 `assets/source/blender/`，貼圖引用保持可攜；Godot 使用匯出的 GLB。 |
| GDScript、Godot 節點、訊號、場景與 UI | 依賴 Godot 生命週期與型別。其他引擎須移植規則或寫轉接層。 |
| 存檔與裝置偏好 | 依接收端驗證器另做轉換；不能將外來 JSON 直接放進正式存檔欄位。 |

先交付來源樹、引擎版本、資料格式、模型、授權與實際驗證結果，再決定逐模組移植、資料轉換或保留獨立遊戲。整個專案覆蓋、合併兩個入口場景、共用未轉換的存檔，都不能當成已完成整合。

## 現有入口與責任

| 模組 | 實際檔案 | 接點與責任 |
| --- | --- | --- |
| 遊戲入口 | [main.gd](../../godot/scripts/main.gd)、[main.tscn](../../godot/scenes/main.tscn) | `SevenDistrict` Node3D 建立管理器、世界、玩家、載具與 UI，註冊輸入並串接訊號。 |
| 生活任務 | [taiwan_life.gd](../../godot/scripts/content/taiwan_life.gd) | `start_task`、`choose_route`、`handle_action`；管理物品、選項、現金、信任、退貨與任務進度。 |
| 文化活動 | [taiwan_activities.gd](../../godot/scripts/content/taiwan_activities.gd) | `start`、`handle_input`、`visit_station`；由主程式提供時間、位置與交通方式，保存徽章與成績。 |
| 裝置設定 | [device_profiles.gd](../../godot/scripts/systems/device_profiles.gd) | `initialize`、`set_profile`、`apply_scene`；`profile_changed(settings)` 更新 phone／tablet／desktop。 |
| 存讀檔 | [save_manager.gd](../../godot/scripts/save/save_manager.gd) | `AlphaSave.save_state`、`load_state` 處理封套與備份；主程式再驗證及還原世界。 |
| 玩家／載具 | [player_controller.gd](../../godot/scripts/player/player_controller.gd)、[arcade_vehicle.gd](../../godot/scripts/vehicles/arcade_vehicle.gd) | CharacterBody3D，接收模型、輸入、碰撞與上下車。 |
| 地圖／生活角色 | [taiwan_expansion.gd](../../godot/scripts/world/taiwan_expansion.gd)、[taiwan_world.gd](../../godot/scripts/content/taiwan_world.gd) | 地圖碰撞與可達性；生活站點、NPC、貨物視覺。後者直接依賴主程式的內部方法與玩家 `_visual_root`。 |
| UI | [game_hud.gd](../../godot/scripts/ui/game_hud.gd)、[taiwan_activity_panel.gd](../../godot/scripts/ui/taiwan_activity_panel.gd) | UI 回呼送往主程式；管理器檢查是否可操作。回呼鍵見 JSON。 |

底線開頭的方法是現有內部接點，不是已發布且可跨版本替換的外掛 API。新模組應先寫有界轉接層，不要讓外來程式到處修改入口狀態。

## 資料與操作代碼

[taiwan_life.json](../../godot/data/taiwan_life.json) 的 `schema_version` 是 1。目前有 32 個站點、8 個人物、16 條人物任務、18 個配送模板，共 41 條不同路線。載入器將 `missions` 與 `delivery_templates` 收進任務字典。任務、人物、站點、物品、選項 ID 都有互相引用與存檔用途，既有 ID 的名稱與意義必須保留；新內容先用命名空間避開碰撞。

生活操作固定為 `talk`、`pickup`、`verify_code`、`deliver`、`return`。步驟檢查真實位置、目標、交通方式、物品與取件碼；取消後仍有貨物時會進入 `returning`，必須退回各自來源站。

[taiwan_activities.json](../../godot/data/taiwan_activities.json) 有四種活動：`rhythm`、`alternating`、`craft`、`walk`。輸入是 `tap`、`left`、`right` 或手作配色代碼。開始活動與集章要求距離站點 4.5 公尺內、`abs(y) <= 3.5`。文化活動只保存成績與收藏，不增加配送現金或人物信任。

**交通代碼需要轉換。** 主程式的生活流程使用 `on_foot`；活動流程接受 `foot`。現有 `_activity_vehicle()` 把 `on_foot` 轉為 `foot`，自行車與汽車維持 `bicycle`、`car`。載具控制器另有 `bike` 型別，不能把上述字串全部改成同一種名稱。

活動載入器目前固定檢查 `activities.size() == 4`；活動存檔字典也要求完整涵蓋目前的所有活動。新增第五種活動必須一起修改載入、遷移與測試，單加 JSON 不會完成整合。

## 存檔邊界

有三層版本欄位，名稱不同：

| 層次 | 欄位 |
| --- | --- |
| AlphaSave 外層封套 | `schema: 1`，另含 `saved_at`、`data` |
| 主程式世界快照 | `schema_version: 1` |
| 生活／活動子狀態 | `version: 1` |

正式遊戲使用 `user://save1.json`，自測主程式使用欄位 98。AlphaSave 限制欄位 1～99、讀取大小 8 MiB；寫入使用暫存檔與備份，損毀或不支援的原檔會保留。外層格式合法仍須通過 `_valid_world_save` 與各模組 `from_dict`。

生活狀態會按目前任務獎勵重算現金與信任，並檢查路線、物品來源、進度、冷卻與站點 ID。改掉既有 ID、獎勵或步驟順序可能使舊存檔失效。活動只保存 `version`、`best`、`completion_counts`、`attempts`、`badges` 五個欄位；未完成的活動場次在讀檔後重新開始。舊 Alpha 快照缺少生活／活動欄位時，目前主程式會重設該模組。

裝置偏好另外存於 `user://device-preferences-v1.cfg`，不隨世界存檔匯入。三種預設解析度比例為 0.70／0.85／1.00。跨引擎或跨遊戲存檔須另做明確的轉換器與原檔備份，不宣稱現有版本 1 可接收任何遊戲。

## 座標與資產

執行時以公尺計，Godot +Y 朝上，地面使用 X／Z。站點資料 `[x,z]` 與快照 `[x,y,z]` 不可混用；地圖範圍是 `[-400,-400,400,400]`，保留核心是 `[-150,-150,150,150]`，分區大小 90 公尺。模型正面是 Godot +Z，Blender -Y 匯出後對應 +Z；相機前方是 Godot -Z。這些座標屬虛構壓縮街區。

目前角色使用 `HandToolSocket`、`SeatHipSocket`，工具使用 `GripSocket`，載具使用 `RiderSeat`／`DriverSeat`；車輪與曲柄為 `WheelFront`、`WheelRear`、`Crank`。目前台灣人物清冊記錄 53 骨，右手骨為 `hand.r`。動畫代碼是 `idle`、`walk`、`run`、`attack`、`hit`、`drive`、`pedal`、`knockdown`。來源規劃文件的舊命名不能取代目前執行程式要求。

交付時同步更新 [地景清冊](../../godot/data/taiwan_asset_manifest.json)、[人物清冊](../../godot/data/taiwan_people_manifest.json)、[攜帶物清冊](../../godot/data/carry_asset_manifest.json) 與相應源檔、SHA-256、授權。沒有插槽時部分控制器會使用預設位置；匯入成功不足以證明握持、座位、腳掌與動畫已對齊。生活貨物目前掛在玩家 `_visual_root` 的局部位置，不能假設它已有通用手持插槽介面。

## 驗收依據

[qa/v04-release.md](../../qa/v04-release.md) 與 [qa/engine-checks.json](../../qa/engine-checks.json) 記錄的 **17 組／8,561 檢查通過**是既有公開基線，不是這份整合包重跑的結果。

接收端測試入口是 [tools/test_game.py](../../tools/test_game.py)，資料檢查是 [tools/validate_taiwan_life.py](../../tools/validate_taiwan_life.py)。重建方式見 [build-from-source.md](../build-from-source.md)。相關驗收：

- [taiwan_life.gd](../../tests/taiwan_life.gd)：生活任務、選項、退貨、獎勵與存檔。
- [taiwan_activities.gd](../../tests/taiwan_activities.gd)：活動節奏、順序、成績與收藏存檔。
- [v04_integration.gd](../../tests/v04_integration.gd)：實際入口、站點與 UI 操作。
- [taiwan_expansion.gd](../../tests/taiwan_expansion.gd)：地圖、碰撞與可達性。
- [device_profiles.gd](../../tests/device_profiles.gd)、[device_web.mjs](../../tests/device_web.mjs)：裝置及網頁入口。
- [controls.gd](../../tests/controls.gd)、[guard_persistence.gd](../../tests/guard_persistence.gd)、[release_regressions.gd](../../tests/release_regressions.gd)：操作、還原與退化檢查。

新增站點、任務、活動或模型時，擴充對應覆蓋與資料數量預期；保留原有驗收，不以刪除檢查或降低通過門檻處理失敗。整合後需產生自己的測試結果與來源摘要，才能判定新的內容是否可入庫。
