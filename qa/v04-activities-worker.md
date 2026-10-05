# Alpha 0.4／直接可玩文化活動

日期：2026 年 10 月 5 日。狀態：活動模組及實際 Native 介面輸入 VERIFIED；完整 Root、三端瀏覽器與部署待整合。沒有把此有界交付當成完整 goal 已完成。

## 交付與玩法

| 活動 ID | 實際場域 | 玩家操作與完成規則 |
| --- | --- | --- |
| `TW-ACT-TOP` | `green_class` 里民活動教室 | 游標每拍移動；金色區間點「轉動」或按 Space。8 拍至少 6 拍命中，容差 ±0.20 秒，每拍僅能計分一次。 |
| `TW-ACT-CLOGS` | `arcade_temple` 犁光廟埕 | 左／右腳按鈕或方向鍵依序交替踩拍；8 拍至少 6 拍命中，容差 ±0.21 秒。踩錯腳、提早、漏拍或同拍連按不增加分數。 |
| `TW-ACT-CRAFT` | `creative_workshop` 阿芸印刷工作室 | 三張不同底色、配色及圖案委託卡，9 次真正選材操作；錯選可重試但每次扣 10 分；完成三件作品才取得徽章。 |
| `TW-ACT-WALK` | `green_notice` 綠廊公告欄 | 依序在市場、老街、河岸里程牌及綠廊各蓋一章；步行或自行車、站點 4.5 公尺內才接受，汽車、跳站及重複站均拒絕。沒有倒數時間。 |

位置直接取自既有 `taiwan_life.json` 的 32 個正式站點，不另創複製座標。陀螺、木屐與手作須下車站在現場開始；集章另允許自行車。非有限座標、超出 4.5 公尺或不支援車種均拒絕。

活動只保存最佳分數、完成／嘗試次數與四個收藏徽章，沒有現金、人物信任或配送報酬；不改 `TaiwanLife` 的現金公式。8 拍成績為命中數轉 0–100，完成門檻 75 分；手作依錯誤扣分；集章完成為 100 分。這是文化題材的原創操作玩法，不宣稱陀螺剛體模擬或官方木屐賽規則。

## API 與根場景接法

`TaiwanActivities` 為 `Node`。定義／介面為：

- `load_definition()`、`reset()`、`start(id, player_position, vehicle="any")`。
- `handle_input(action)`；固定 `tap / left / right / red / blue / white / flower / stripes / dots`，沒有客戶端分數參數。
- `visit_station(station_id, player_position, vehicle="any")`；只接受集章目前下一站。
- `advance_time(delta)`、`set_paused(bool)`、`is_timed()`、`cancel()`。
- `get_rows()`、`get_session()`、`get_target_key()`、`get_active_title()`、`get_active_text()`。
- `to_dict()`、`from_dict()`；只保存收藏記錄，中斷的活動場次在重載時清理，可現場重玩。
- `updated`、`notice(text)`、`completed(id,outcome)` 三個 signal。

`any`／`foot` 代表步行，`bicycle` 只允許集章。`get_session()` 是只供畫面讀取的快照，含游標、目標／容差、下一拍／選材和訊息，不接受 UI 覆寫。

面板 `setup(hud, manager, callbacks)`，提供 `show_directory()`、`show_activity(id)` 與 `refresh()`。`manager.updated` 已接 `refresh`，不用另外讓瀏覽器任意傳時間或成績。面板有真實 Button、Space／左右 InputEventKey 及即時自畫游標。

根場景的 callbacks：`start(id)`、`input(action)`、`visit(station_id)`、`cancel()`、`mark(station_id)`、`resume()`、`close()`。根場景負責從真正玩家讀位置／車種；`start` 解除本活動 manager 暫停後呼叫，成功顯示活動面板。不能把 directory 按鈕當成遠距啟動授權。

節奏和手作面板 `hud._mode=="culture_activity"` 時，允許本 manager 操作；節奏的 `advance_time` 由根場景正常 delta 驅動。世界及配送時計仍依原暫停狀態停止。開設定、切其他選單、焦點離開或取消時須停本活動；離開定點場次回街上應取消／停止，不能留著游標偷偷計分。集章可回街上繼續走，現場互動才傳 `visit_station`。

`from_dict` 先驗全部欄位才改現況：版本、完整 ID、有限整數、分數可能值、成功／嘗試關係、最佳分數門檻、徽章集合及重複徽章都檢查。拒絕額外 session／未知欄位，接受 Godot JSON 產生的整數 float 表示。活動記錄可以保留主線 retry；新遊戲由根場景明確呼叫 `reset()`。

## 真實驗證

在 Godot 4.7.2 stable 執行：

```powershell
godot --headless --path godot --script ../tests/taiwan_activities.gd
```

結果與程序結束碼：

```text
TAIWAN_ACTIVITY_CHECKS=245 FAILURES=0
exit_code=0
```

245 項斷言涵蓋四定義與正式站點、遠距／車中／NaN／Inf 啟動、正在進行不能替換、暫停 input／clock、非法 delta、8 拍全命中、錯時機、同拍連按、錯腳與單腳連按失敗、錯材不推進、三張配色卡完成與最佳分數、重玩次數、四章順序與實際距離、汽車／跳站／重複蓋章拒絕、timer-free、取消、進行中 JSON 重載清場、全收藏 round-trip、15 組畸形存檔及每次原子拒絕。

GUI 檢查載入真 `GameHUD`／活動面板，以 `root.push_input(InputEventKey)` 證明 Space 命中一拍；echo 不重複。手作的紅色選擇使用真 InputEventMouseButton 的 down／up、實際 Button global rect，證明選材進度增加；切設定後按鍵不送進活動。沒有用改 manager 分數或填紀錄代替活動完成。另驗證逐幀 updated 不重建按鈕、完成後只做一次狀態切換，直接顯示重玩並移除已結束的節奏控件。

測試沒有讀寫玩家存檔或裝置偏好；活動 manager 本身不操作檔案保存。另補真 GameHUD 的 phone 360×800／844×390、tablet 1024×768、desktop 1366×768 控件矩形檢查：陀螺與木屐的游標和所有動作鍵須同在 scroll clip；手作六個選材鍵也全部可見，只顯示目前那張配色卡。

手機橫向 844×390 的真矩形：clip `(121,75;602,240)`；陀螺 gauge `(121,120;444,72)`；木屐 gauge `(121,120;444,146)`。原游標 y321、按鈕 y413 超出 clip 的問題已修。Active 把游標與按鈕並排且置前，完整 instructions 在下方；開始前 preview 保留全文。

這是 Native headless 事件與介面流程，不是公開瀏覽器、實機手機或平板效能驗證。

本輪最後來源 SHA-256：

| 檔案 | SHA-256 |
| --- | --- |
| `godot/data/taiwan_activities.json` | `17cc2713b10799e448c366859055a3a28305b6e366864309d5a36832428aea62` |
| `godot/scripts/content/taiwan_activities.gd` | `baca2262cc9ab0677e5bf2b6f43eb76dc5c193ec5a78c423ae159d3005f92dd3` |
| `godot/scripts/ui/taiwan_activity_panel.gd` | `4d51e3aa309419136744d69ba03610b9391aa1642864397095c9e98157e6d68f` |
| `tests/taiwan_activities.gd` | `3dfbbf4af6703b18d190ae50d5e63c44077ff05b8b2a9be53d8e6d4187293790` |

根工單須把模組接入正式站點、生活目錄與保存，並對主遊戲完成活動、模式切換、settings／focus 暫停及三端畫面重驗。沒有新增任何官方照片、錄音、商標或 3D 素材。

## 繁中編輯 mode 2

新增原創說明直接整理；木屐說明的「金色区間」已改「金色區間」，原因為繁簡混用。保留原文化事實、ID、數字與來源 URL，不將遊戲操作改寫成民俗歷史定論。
