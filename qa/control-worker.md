# 控制工程交接

狀態：VERIFIED。2026-10-03 美術 freeze 並由 supervisor 最後重匯入後，使用 `4.7.2.stable.official.ed1daf0bf` 執行真實 headless 控制測試，44 項全部通過；守衛持久化另有 16 項通過。三支控制腳本載入、編譯與執行皆無控制 runtime error。

## 邊界與共用契約

- `SevenPlayer extends CharacterBody3D`，來源為 `godot/scripts/player/player_controller.gd`。
- `ArcadeVehicle extends CharacterBody3D`，來源為 `godot/scripts/vehicles/arcade_vehicle.gd`。
- `SevenGuard extends CharacterBody3D`，來源為 `godot/scripts/combat/guard.gd`。
- 模型使用底部原點、局部 +Z 朝前；環境 `collision_layer=1`，角色與載具 `collision_layer=2`，行動碰撞與攻擊遮擋 `collision_mask=3`。地面查詢使用 `mask=1`。
- 三類都提供 `setup_visual(scene: PackedScene)`，可以在加入場景前或加入後呼叫。可設定 `visual_scale`。
- 可傷害物件加入 `damageable` group，提供 `apply_hit(hit_id: String, source_id: String, damage: float)`。
- 動畫遞迴找 `AnimationPlayer`，名稱比對支援 `idle` 及 `Rig/idle` 等路徑。`animations_missing` 保存缺少的 clip，不將程式擺動冒稱為骨架 clip。

## 玩家 API

- `get_camera() -> Camera3D`：在 `_ready` 後取得第三人稱鏡頭。
- `grant_weapon(name: String) -> bool`：拾取並裝備。接受 `wrench/bat/pulse`、`WPN-002/WPN-001/WPN-003` 及對應中文名稱。`equip_weapon(name) -> bool` 只裝備已持有工具。
- `inventory: Dictionary`：`melee` 陣列容量 2、`ranged` 陣列容量 1。初始為空，由主線取得第一把扳手。
- `equipped_weapon: String`、`pulse_energy: int=12`、`health`、`maximum_health`、`controls_enabled` 可供 HUD／任務／存檔存取。重複拾取脈衝器不補能量。
- `begin_attack() -> bool`：主線或測試可直接啟動攻擊。沒有可見角色或當前手持工具 GLB 時回傳 false，不造成隱形傷害；`weapon_visual_available` 與 `weapons_missing` 可查缺項。
- `set_mounted(vehicle: Node3D, seat_position: Vector3, riding: bool=false)` 與 `clear_mounted(exit_position: Vector3)` 由載具管理步行停用、碰撞停用、騎姿與鏡頭跟隨。
- `apply_hit(...)` 防重複，`restore_health()` 恢復生命值；`clear_inventory()` 清空工具並重置脈衝能量，供新遊戲或載入存檔前使用。
- 訊號：`health_changed(current, maximum)`、`attacked(weapon_id)`、`weapon_changed(weapon_id)`、`interaction_requested()`、`mount_requested()`、`defeated()`。

模型有 `attack` clip 時播放該 clip；`WeaponSwing` 自動載入 `res://assets/models/wrench.glb`、`bat.glb`、`pulse.glb`，對齊工具 `GripSocket` 與角色 `HandToolSocket`，以 `BoneAttachment3D` 跟隨右臂骨骼，並在相同時間窗擺動模型工具。缺 clip 時使用可見工具／身體擺動作為降級呈現，並記錄缺項。近戰逐時間窗檢查距離、前向 dot 與牆遮擋，同一揮擊對同一物件只傷害一次。脈衝器一次只擊中最近的有效目標，排除生命值已歸零的目標。

| 工具 | 傷害 | 距離 | 打擊窗 | 完整動作 |
| --- | ---: | ---: | --- | ---: |
| wrench | 24 | 2.1 m | 0.18–0.36 s | 0.60 s |
| bat | 36 | 2.8 m | 0.25–0.49 s | 0.82 s |
| pulse | 45 | 20 m | 0.23–0.28 s | 0.70 s |

## 載具 API

- 在加入場景前設定 `type="car"` 或 `type="bike"`，以建立對應碰撞尺寸。
- `enter(player: SevenPlayer) -> bool`：距離 4 公尺內、玩家有生命且未騎別台車、車未占用才成功。
- `exit() -> bool`：速度需低於 2.8 m/s。依序檢查左右、左右後方、車尾；地面斜率、玩家膠囊空間與離車路徑都可通過才退出。
- `occupied: bool`、`driver: SevenPlayer`、`speed_mps`、`get_speed_kmh()` 可供主線與 HUD 使用。
- `last_exit_error`、`exit_blocked(reason)`：保留無法安全下車的原因。失敗時保持原占用狀態。
- `reset()`：回到生成 transform，清除速度，保持占用關係。生成 transform 延至 `_ready` 後擷取，容許 root 先 `add_child` 再設位置；`capture_spawn()` 可明確覆寫重置點。
- `force_release(exit_position: Vector3)`：給已驗證的存檔位置或任務回點使用，解除占用並放回玩家；一般操作必須用具有出口檢查的 `exit()`。
- `seat_offset: Vector3`：非零時覆寫預設座位。未覆寫時，讀取 `RiderSeat/DriverSeat` 並減去角色 `SeatHipSocket`，對齊實際模型騎姿。
- `occupancy_changed(is_occupied)`：上下車成功後通知。
- 汽車正向上限 60 km/h，自行車 25 km/h；倒車上限為正向的 30%。自行車維持直立碰撞，以視覺傾斜呈現轉向。
- 名稱包含 `wheel` 的模型節點會依速度轉動，名稱含 `front` 或以 `fl/fr` 結尾的輪子另做轉向。
- 輪子必須本身是 mesh 或包含 mesh 子節點，空的 axis marker 不會被當成輪子。自行車的真實 `Crank` mesh 也依輪速旋轉。

## 守衛 API

- `target: SevenPlayer` 可明確指定；未指定則從 `player` group 取得。
- `patrol_points: Array[Vector3]` 為世界座標，沒有巡邏點則停在首次生成位置。
- `state` 使用 `patrol/chase/attack/hit/knockdown/defeated`。
- 14 公尺內追逐，1.65 公尺內啟動攻擊；打擊窗 0.28–0.43 秒，傷害 12。攻擊距離、正面角度及牆遮擋都需成立，單次攻擊只傷害一次。
- `apply_hit(...)` 去重並產生受擊停頓。生命歸零後保留倒地動作 0.75 秒，才送 `defeated()`；倒下模型不刪除。
- `get_state()->Dictionary` 保存生命值、世界座標 `[x,y,z]` 與狀態；`restore_state(data)->bool` 驗證後恢復。活著的守衛恢復巡邏及碰撞；已倒下的守衛保持倒地末幀，清除阻路碰撞，不重新發送 defeated。壞資料不變更原狀。
- 受困者必須由另一類 NPC 實作，不把守衛 AI 套到受困者。

## InputMap

必要：`move_left/right/forward/back`、`sprint`、`jump`、`attack`、`interact`、`mount`、`cycle_weapon`。

可選：`brake`、`reset_vehicle`。騎乘時 `jump` 也可煞車。建議 root 使用 `Space` 煞車、`R` 重置。滑鼠移動只有在 `Input.MOUSE_MODE_CAPTURED` 時轉動鏡頭；root 負責擷取與釋放滑鼠。

## 執行證據

官方 runtime 由 supervisor 下載、SHA-512 校驗並唯一執行 editor import。控制 worker 隨後在兩個獨立 headless 入口驗證，不重寫 editor class cache。

```text
<local-tool-cache>
--headless --path ./godot
--quit-after 3600 --script <local-tool-cache>

CONTROL_CHECKS=44 FAILURES=0
exit_code=0
```

44 項通過涵蓋實際角色／武器 GLB 載入與右臂 BoneAttachment、背包容量、重複拾取不補能量、打擊窗前不傷害、單次揮擊去重、背後及牆後不命中、玩家與守衛受擊去重、延遲倒地且只送一次事件、脈衝最近單一目標／有限能量、W 方向／Sprint／Jump 回落、汽車與自行車限速、汽車加速轉向與煞車、高速下車拒絕、膠囊安全出口、堵住出口時占用保留、任務回點 force_release、reset 回生成位置、真正的自行車輪 mesh 在行駛時旋轉、缺少模型時不造成隱形傷害。

首輪獨立輪子 probe 發現自行車只有 `bicycle/BicycleFrame` 單一 mesh，`_wheels.size()==0`。美術 worker 已將真實 `WheelFront/WheelRear/Crank` mesh 分離並以輪心／曲柄中心作 pivot。最後重匯入後，測試明確檢查輪節點擁有 mesh 幾何，並檢查真實行駛後旋轉量，已通過；僅旋轉空 marker 不算可見輪動畫。

首次 `main --self-test` 未通過，原因是 root main 的 `Array` 指派至 `Array[Vector3] patrol_points` 型別錯誤，以及存檔 roundtrip equality assertion；均已回報 supervisor，未把 Godot 回傳 exit 0 當成測試通過。該輪在 assertion 停住，尚未執行 main 的運動 case；上列獨立控制測試有實際執行運動，完整 main 的最終驗收由 supervisor 負責。

2026-10-03 新增守衛存檔接口後，使用工具 cache 的 `alpha_guard_save_test.gd` 執行定向測試，結果 `GUARD_SAVE_CHECKS=16 FAILURES=0`、exit 0、無 script error。包含 JSON 往返、倒地姿勢保持、載入已倒守衛不重複送事件、重試回到活著檢查點、重建碰撞及 damageable group，以及無效資料保持原狀。

完整場景的可視品質、手持姿勢與鏡頭構圖由 supervisor 的截圖／遊玩檢驗負責，本文件的判定限於已執行的控制、動畫資源與模型節點契約驗證。
