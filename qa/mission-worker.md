# 第一章任務、存檔與 UI 交接

範圍：Godot 4.7.2 的五個主線任務。來源為 `docs/missions.json` 與 `docs/creative-bible.md`；MAIN-005 只顯示切片成果，不執行 MAIN-012 的完整戰役結局。未刻意拉長遊玩時間，實際時長仍須真人試玩量測。

## 檔案

- `godot/data/alpha_missions.json`：事件／目標、繁中任務提示、正本獎勵與分支映射。
- `godot/scripts/missions/mission_manager.gd`：`AlphaMissions`，明確的事件／目標配對與保存復原。
- `godot/scripts/save/save_manager.gd`：`AlphaSave`，使用者資料目錄中的 schema-1 存檔。
- `godot/scripts/ui/game_hud.gd`：`GameHUD`，繁中 HUD、導航、標題、暫停、任務手機與切片成果畫面。

## 公開 API

`AlphaMissions` 提供 `updated`、`mission_completed(id)`、`chapter_completed(branch)`。`mission_index` 與 `current_objective` 從 0 起算；第 5 個任務完成後 `mission_index == 5`、`chapter_complete == true`。

`scores` 只使用正本四欄：`evidence_score`、`community_trust`、`rescued_count`、`heat_level`，初始為 0／50／0／0。數值上限為 100／100／4／5；救援上限 4 僅限本 alpha 的四名 NPC。

方法：`start_campaign()`、`handle_event(event_name, target_id) -> bool`、`get_current_title()`、`get_objective_text()`、`get_target_key()`、`get_current_mission()`、`get_current_objective()`、`to_dict()`、`from_dict(data) -> bool`、`restart_current()`。

當前目標字典保留 `key`、`text`、`events`、`targets`、`required`；另外提供 `completed`、`remaining_targets`、`target_key`。`event_targets` 存在時以此檢查精確配對，不能把維修通道事件套到安保 ID。

| 任務 | 依序觸發的事件／target |
| --- | --- |
| MAIN-001 | `talk_mei/mei` → `read_phone/phone` → `pickup_wrench/wrench` → `practice_hit/practice_1`、`practice_2` |
| MAIN-002 | `defeat_guard/guard_1`、`guard_2`，或 `alternate_route/service_gate` → `disable_sign/fake_sign` → `collect_pass/pass` |
| MAIN-003 | `mount_bicycle/bicycle` → `route_checkpoint/route_1` → `route_2` → `route_3` → `return_shop/mei_shop` → `unlock_car/car` |
| MAIN-004 | `free_rescue/rescue_A`、`rescue_B` → `escort_safe/rescue_A`、`rescue_B` |
| MAIN-005 | `select_branch/smash`、`evidence` 或 `rescue` → 下列一條解法 → `return_shop/mei_shop` |
| 破壞 | `destroy_target/equipment_1`、`equipment_2`、`equipment_3` |
| 蒐證 | `collect_evidence/record_1`、`record_2` → `disable_console/console` |
| 救援 | `escort_safe/extra_A`、`extra_B` → `disable_console/console` |

護送階段的導航 marker 為 `safe_point`，選分支時為 `branch_console`。MAIN-002 與 MAIN-004 的可選紀錄分別是 `collect_evidence/summary` 與 `collect_evidence/shift_note`，各在該任務完成時增加 E +8。

救援 target 映射到正本唯一 ID：`rescue_A/B` → `NPC-M004-01/02`，`extra_A/B` → `NPC-M005-01/02`。NPC 到安全點才增加救出人數；世界控制器須在 `handle_event` 回傳 true 後才把該 NPC 標記為已交付。

`evidence_destroyed/record_1` 或 `record_2` 若尚未保存，會把蒐證解法改為破壞，顯示後備說明；開始砸設備前也可改選救援。已保存的紀錄不會被倒扣。可選紀錄損毀只失去該份額外 E，不阻擋主線。

沙盒事件另有 `street_damage/object_id`、`civilian_hit/npc_id`、`enemy_sighting/guard_id`；每個事件／唯一世界 ID 只扣分或升警戒一次。本段失敗後回復任務入口的數值與旗標。

## 重試與成果

重試不清除已領取任務獎勵。MAIN-003 已通過路標後保留最近路段階段；世界控制器必須在對應路段放回可騎乘的自行車。其他任務回入口，清除本次未結算分支、可選紀錄、救援與數值變化。MAIN-005 切片完成後不可透過 `restart_current()` 再領獎；改玩其他分支需開始新遊戲。

基本零件券總數為 780。未保存可選紀錄時：破壞 E 10／信任 55／救出 2 人；蒐證 E 30／信任 55／救出 2 人；救援 E 10／信任 63／救出 4 人。兩份可選紀錄共可增加 E 16。任務敵人與練習物不扣信任。

## 存檔與介面

`AlphaSave.save_state(data, slot=1) -> Error`、`load_state(slot=1) -> Dictionary`。檔案為 `user://save1.json`，包裝為 `{schema:1,saved_at,data}`，讀取回傳原始 `data`。寫入先建立 `.tmp`、讀回驗證、備份原檔到 `.bak`，最後 rename 替換。原檔損毀時只讀有效備份，保留損檔；明確儲存也拒絕覆寫損毀原檔。`AlphaSave.last_message` 提供繁中結果，無有效檔時回傳 `{}`。世界控制器需驗證自身 player／物件／載具狀態，並處理 `AlphaMissions.from_dict()` 的 false。

HUD 信號為 `resume_requested`、`save_requested`、`load_requested`、`retry_requested`、`new_game_requested`、`quit_requested`、`branch_selected(branch)`。方法為 `bind_missions(manager)`、`update_status(hp,weapon,heat,vehicle,prompt)`、`set_map_markers(playerXZ,targetXZ)`、`show_title()`、`show_pause()`、`show_phone()`、`show_chapter_complete(branch)`、`hide_menus()`、`is_menu_open()`、`get_menu_mode()`、`show_message(message)`。

HUD 的 modal 會暫停樹並顯示游標；`hide_menus()` 取消暫停，root 處理游標捕捉。所有按鈕最低 48 px，內容使用 Container 與 ScrollContainer。繁中字型優先 `NotoSansTC-Regular.otf`，其次 `.ttf`，未提供時用 Microsoft JhengHei／Noto Sans CJK TC 系統字型。

## 驗證紀錄

JSON 靜態驗證通過：schema-1、正本 MAIN-001～005、5 筆任務、有效的事件／目標數、基本零件券 780。

2026-10-02 已使用父代理下載並驗證官方 SHA-512 的 Godot `4.7.2.stable.official.ed1daf0bf` 執行 headless contract 測試，輸出 `ALPHA_CONTRACT_CHECKS=233 FAILURES=0`，process exit 0，沒有 script parse／runtime error。測試腳本位於工具快取 `<local-tool-cache>`，不加入公開遊戲包。

涵蓋：三分支完成與確切分數、錯序／重複事件、錯誤的 event／target 配對、中途保存復原、MAIN-003 路段重試、護送重試回滾、NPC 唯一計數、證據損毀後備、一次性獎勵、錯誤 mission state 不覆寫 live state、JSON 存檔實際恢復任務、二次儲存替換、上一份備份復原、損毀原檔不覆寫、schema-2 拒絕，以及 1366×600 HUD modal、按鈕至少 44 px、pause／resume／phone／complete。

第一次執行修正一個 GDScript 型別推導 parse error（`is_optional` 加顯式 bool）。第一次完整 contract 的三個 save equality 失敗是原始 typed Dictionary 與 JSON 載入 Variant 直接比較；已改成 JSON canonical 比較，並另驗證讀回的任務資料可實際 `from_dict()`、恢復切片完成與四名救援。未因 exit 0 就宣稱 parse 通過。

存檔 fixture 只使用 slot 96，主檔／備份／暫存檔原先不存在才開始；測後清除本次建立的三個檔案，沒有碰觸 save1。以上 UI 檢查為 headless 的實際 Container 尺寸與狀態驗證，未替代可視畫面審查。完整 world 互動、第三人稱操作、字型顯示與可視畫面由 root 整合後另驗。

繁中文案依 speak-human-tw mode 2。這次是新寫的 UI 與任務提示，未改寫使用者既有原句，需另外列出的修改為 0 處。
