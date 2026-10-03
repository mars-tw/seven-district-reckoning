# Alpha 0.3 街區補給與成長

狀態：VERIFIED，2026-10-03。獨立管理器的真實 Godot 4.7.2 執行結果為 `304` 項檢查通過、`0` 項失敗。世界、HUD、載具與玩家效應由根整合工作驗證，本報告不把管理器測試當成整個遊戲驗收。

## 檔案與執行

- 管理器：`godot/scripts/systems/district_systems.gd`。
- 原創內容：`godot/data/district_systems.json`。
- 真實管理器測試：`tests/district_systems.gd`。
- 在 `godot/` 工作目錄執行：`godot --headless --language en --path . --script ../tests/district_systems.gd`。
- 最終機器讀取紀錄：`DISTRICT_SYSTEMS_RESULT {"failures":[],"passed_count":304}`。
- 測試不存入任何玩家存檔，不接觸 slot 1；存檔契約以記憶體字典與 Godot JSON 實際序列化往返驗證。

## 實作內容

起始有 `120` 補給金，與主線零件券、委託零件券分開。三個挑戰各發一次獎勵：

| 挑戰 | 真實達成條件 | 補給金 | 經驗 |
|---|---|---:|---:|
| 用雙腳認路 | 實際步行累積 400 公尺 | 90 | 80 |
| 三份交代 | 完成三份不同的已製作 SIDE 委託 | 120 | 110 |
| 停用營運設備 | 工具實際停用八個不同的白名單設備或訓練道具 | 100 | 90 |

經驗門檻為 `0／80／180／280`，最高等級 `4`。步行不計搭車、空中位移、重生、超速跳位或過長的一次 delta。管理器拒絕不合理樣本，絕不把傳送距離縮小後給進度。任務事件與摧毀事件同時用目標 ID 與來源 UUID 去重，換一個來源 UUID 仍不能重領同一目標。

| 補給或整備 | 花費 | 解鎖等級 | 效應 |
|---|---:|---:|---|
| 急救補給 | 35 | 1 | 恢復至多 40 生命，最高 100；滿血不扣款，每份存檔最多 12 次 |
| 體能訓練 | 90 | 2 | 體力上限 100 → 120，一次購入 |
| 工具整備 | 140 | 3 | 工具傷害乘數 1.2，一次購入 |
| 自行車調校 | 105 | 2 | 自行車加速乘數 1.15，一次購入 |

自行車調校提供實際加速乘數。現有載具沒有生命值，因此不宣稱這項功能能修復不存在的損壞值。挑戰沒有伺服器日期或每日刷新，也沒有付費交易。

## 整合契約

`DistrictSystems` 繼承 `Node`，不主動操控場景，不引用 `Main`、玩家、HUD 或原任務管理器。

- `get_status()`：`credits`、`xp`、`rank`、`rank_name`、`completed_challenges`、`max_rank`。
- `get_offers()`：四列獨立副本，包含 `id`、`title`、`description`、`cost`、`unlock_rank`、`max_purchases`、`effect`、`purchased`、`unlocked`、`sold_out`、`affordable`、`available`。
- `get_challenges()`：三列獨立副本，原定義加 `progress` 與 `completed`；顯示進度最多為目標值。
- `get_stats()`：`max_stamina`、`tool_damage_multiplier`、`bike_accel_multiplier`；未購入時為 `100.0／1.0／1.0`。
- `purchase(id, current_health = 100.0)`：返回 `ok`、`reason`、`credits`、`effects`；成功時另有 `id`、`cost`、`stats`。急救返回實際 `healing` 與 `health_after`，根整合者才將其套入玩家。失敗不扣款、不加交易。暫停中的商店可明確購入。
- `record_walk(position, delta, on_foot, grounded = true)`：返回本次實際納入的水平距離；只接受 `0 < delta <= 0.25`、世界 `x/z ±200`、`y ±50` 的有限位置。先建立基準，再累加合法水平位移。每秒超過 10 公尺加 0.05 公尺容差或單次垂直差超過 1.25 公尺會拒絕；實際玩家衝刺速度應小於此上限。
- `record_action("side_completed", task_id, "optional:" + task_id)`：僅在該 SIDE 真正首次完成後呼叫，ACT、MAIN、未製作 SIDE 不接受。
- `record_action("destroy", object_id, "destroy:" + object_id)`：僅在 `object.broken` 已成立、武器實際造成摧毀後呼叫。不能用傷害許可查詢或一次命中代替摧毀。
- `set_paused(bool)`：停用步行與進度事件，並清除位移基準；不阻止使用者在商店選單明確購入。
- `reset_walk_sample()`：重生、傳送、讀檔、檢查點恢復或載具切換時可明確清除位移基準。
- `reset()`：新遊戲重置這份獨立成長，不改其他任務管理器。
- `to_dict()`／`from_dict(data)`：schema `1`。缺少此模組欄位的 Alpha 0.1／0.2 舊存檔，由根整合者呼叫 `reset()`，不能把整份舊存檔傳給 `from_dict({})`。
- `get_journal()`：最近至多 30 筆獨立副本，不包含個資或外部日期。
- 信號：`updated`、`notice(text)`、`rewarded({id,credits,xp,rank})`。`notice` 供 HUD 顯示原因，`updated` 供重畫資料，`rewarded` 供提示或存檔。

摧毀白名單為 `fake_sign`、`equipment_1..3`、`sandbox_0..7`、`SIDE_001_sign_1..3`、`SIDE_012_breakfast_sign`。`practice_1/2` 的練習命中、`record_1/2` 的毀證、路人與警戒角色完全不計入。

根整合者須沿用原來的任務 gate、距離、碰撞與真實物件狀態確認。此管理器接受可信任的世界回呼，不是對瀏覽器開放的發獎 API。原 MAIN／SIDE／ACT 檢查點重試應保留這份成長，避免一次性獎勵或已花的補給金被回滾；只有使用者開始新遊戲才 `reset()`。

## 存檔與測試證據

`from_dict()` 在任何寫入前完整驗證資料，失敗原子化保留目前狀態。檢查包含必要欄位、型別、有限數值、整數範圍、合法目標、目標來源 UUID、跨類型 UUID 重複、完整挑戰收據、XP 與等級推導、解鎖購入、永久升級購入上限、可重複急救上限與補給金守恆。

每筆交易日誌重新計算收入與支出；日誌保存當時的 credits／XP 與單調遞增 sequence。購入當時的 XP 亦須達到解鎖門檻。因此只把結尾錢包改對、亂改交易順序或在未解鎖階段塞入升級都會拒絕。Godot JSON 解析將整數轉為 float 的情況已實測並正規化，讀回仍保有正確的 int 欄位與相同狀態。

304 項檢查涵蓋實際 400 公尺樣本、合法世界與事件白名單、兩種去重、暫停、部分進度、完全達成、所有升級、急救上限、不可刷獎、字典與 JSON 往返，以及對每個必要欄位和非法存檔的拒絕。也驗證此管理器沒有修改既有 OptionalContent 狀態。原 main／optional 的發獎契約由整體回歸套件另外驗證。

## 文案處理

遵循常駐 mode 2，保持原角色、任務編號、價格和獎勵數字不變。新增文字採繁體中文台灣用語；新稿沒有既有原句需覆蓋。整合討論後有一項措辭調整：

| 原句 | 原因 | 改成什麼 |
|---|---|---|
| 用工具摧毀八個允許破壞的目標。 | 範圍不夠具體，容易把路人或證據誤當挑戰。 | 用工具停用八個詐團設備或訓練道具。同一個目標只計一次，路人與證據不計入。 |

程式識別字、目標白名單與 reward 數字未因文案調整而更名。
