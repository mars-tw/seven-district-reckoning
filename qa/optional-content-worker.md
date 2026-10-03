# Alpha 0.2 可選內容 worker 驗證

狀態：VERIFIED（內容管理器與存讀測試）。世界擺位、真實交通工具條件、UI 與 Web 遊玩由 root 整合驗證。

只修改四個指定檔案：

- `godot/scripts/content/optional_content.gd`
- `godot/data/optional_content.json`
- `tests/optional_content.gd`
- `qa/optional-content-worker.md`

已讀取 `core-rules.md`、專案 `AGENTS.md`、`token-efficient-ai-dispatch/SKILL.md`、`speak-human-tw/SKILL.md`。本 worker 使用 harness 有界派工，未呼叫外部模型、憑證、Git、主線或部署工具。

## 實作範圍

六個支線：SIDE-001 招牌不會自己倒、SIDE-004 沒寄出去的信、SIDE-007 沒拿回來的背包、SIDE-010 美晴的零件單、SIDE-011 巷子裡的送達、SIDE-012 把早餐店開回來。

四個活動：ACT-001 自行車路標賽（四個依序檢查點，90 秒）、ACT-002 停車場繞標（三個依序檢查點與停車，120 秒）、ACT-005 街景留影（八個唯一拍照點）、ACT-006 社區急送（三個收件點，180 秒，順序自選）。這不代表企劃中的十二支線、八活動全部完成。

SIDE-007 在這版採取物與補給送達玩法，不新增主線救援計數，也不宣稱已實作新的動態 NPC 護送。

每個支線只結算一次。計時活動第一次完成發一次獎，重玩只更新個人最佳。街景每點首次給 20 零件券，取消、讀檔、重接均保留相簿與點獎去重。六支線總共 850 零件券；三個計時活動共 90；八街景共 160；全內容首次獎勵合計 1100。獨立社區成果為證據 8、信任 20、救援加計 0、成就 10 個，不改 `AlphaMissions`。

## 整合契約

`OptionalContent extends Node`；signals 為 `updated`、`notice(text)`、`objective_changed(target_key)`、`rewarded(reward_dictionary)`。

- `start_task(id) -> bool`：active 時拒絕接其他任務；failed/completed 可開始新的任務或重試活動；已完成支線拒絕重接。
- `cancel_task()`：釋放唯一可選任務槽，保留完成獎勵與街景進度。
- `handle_event(event, target) -> bool`：精確 event/target 配對，拒絕跨主線物件、錯誤順序、重複目標、失敗後的遲到事件。
- `advance_time(delta)`、`set_paused(bool)`：從活動出發事件才開始倒數，暫停與非有限／負 delta 不計時。時間到為 failed，UI 文案說明回委託板選同一活動可重試。updated 的計時通知節流至約每秒，內部時間仍精確累積。
- `get_active_title/text() -> String`；`get_active_target_keys()/get_target_keys() -> Array[String]`。
- `get_active_objective() -> Dictionary`：包含 event、events、targets、remaining_targets、target_key、required/completed，以及有設定的 vehicle/world_kind。
- `get_active_status() -> String`：idle/active/failed/completed。
- `get_active_time()/get_remaining_time() -> float`：剩餘秒。
- `get_status() -> Dictionary`：active_id/status、objective_index、timer_started、elapsed/remaining_time、wallet/parts_vouchers、scores、rescued_bonus、collected_count、achievements、best_times、completed_tasks。
- `get_menu_entries() -> Array`：十個已實作條目，含摘要、可重玩／完成狀態、個人最佳與相簿數。
- `to_dict()/from_dict(dictionary) -> bool`：schema 1，原子載入；存檔獎金、成果、成就必須與完成任務／照片點帳本吻合，驗證計時與目標順序。
- `reset()`：明確新遊戲才清掉整個獨立可選成果。

ACT-005 必須先接為 active 才接受拍照，取消後可續拍。世界不能只根據文字事件任意判過關，必須先驗證交通工具、空間距離與位置：自行車任務必須騎自行車；ACT-002 必須開車依序進檢查點，整台車在車格內且車速不超過 2.8 m/s 才發 park_car。世界用 `tasks[].objectives[]` 內的 world_kind/vehicle/targets 建物件。沒有外部網路、金流或加密貨幣功能。

## 執行證據

使用實際 Godot 4.7.2 console，從 repo root 執行：

```powershell
godot --headless --path 'godot' --script '..\tests\optional_content.gd'
```

測試涵蓋十個資料條目的真實流程、六支線 deterministic 獎勵、活動重玩與最佳時間、暫停／超時／重試、八照片點首次獎勵、取消後恢復、JSON 實體檔案存讀、schema／帳本／重複目標／進度缺口／NaN／最佳時間等壞存檔原子拒絕，以及主線狀態完全未變。測試只把臨時進度檔寫到 `user://`，執行後刪除。

結果：175 checks、0 failures，exit code 0。沒有宣稱世界或瀏覽器實測結果。

## 繁中文案校對（mode 2）

這次修正 3 處草稿用字，數值、ID、人物與劇情不變。

| 原句片段 | 原因 | 改成什麼 |
|---|---|---|
| 停車条件 | 簡體字 | 停車條件 |
| 拿回来就好 | 簡體字 | 拿回來就好 |
| 三分鐘够不够 | 簡體字 | 三分鐘夠不夠 |
