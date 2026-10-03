# Alpha 0.2 獨立上下文整合覆核

狀態：VERIFIED（完整 runner 的 775 項 reported checks，其中 RootScene 整合 driver 為 214 項）。本報告來自 harness 獨立上下文 worker，與 root 使用相同模型；不是不同模型覆核。覆核未改動任何遊戲來源、部署或 Git，只新增 `tests/v02_integration.gd` 與本報告。續作另更新 `tools/test_game.py` 與 `qa/engine-checks.json`。已讀核心規則、專案 AGENTS、dispatch 與 orchestrator skill；未使用外部派工、憑證或瀏覽器。

實際執行 Godot 4.7.2 的 `main.tscn`。整合 driver 的子類只把自動儲存改寫到 slot 94，其他世界、HUD、物理、載具與任務程式仍是目前來源。這支 driver 拒絕覆寫已存在的 slot 94，結束後移除自行建立的 `save94.json`、`.bak` 與 `.tmp`，不讀寫 slot 1 或 95–98，也不啟動 editor import。續作的完整 runner 另在隔離副本做乾淨匯入與既有 95–98 測試。

```text
godot --headless --path godot --script ../tests/v02_integration.gd
```

## 已驗證的範圍

- 實際 RootScene 有六區、十個可選內容；44 個目標均找到實際靜態物理可站立、從出生點連通、且通過互動視線的接近點。路網有 4526 個連通採樣點，4 m 網格間以 1 m 間距檢查膠囊 clearance。
- 接單走 HUD 的 `optional_selected` 信號，目標使用實際 `_update_interaction`、`nearest` 與 Player 互動信號；載具由實際 `enter` 綁定，路標與停車走實際 `ContentWorld.step`。六支線各完成一次，共 850 零件券；十項首次成果合計 1100。錯誤載具沒有推進目標。
- 主線重試保留已完成支線，以及活動中的相簿點、已收取世界物件與獎勵。slot 94 的實際存讀也保留這些資料；取消後重接相簿未重領單點獎勵。模擬舊 Alpha 缺少 optional／city_life 欄位時，實際 root restore 初始化空的可選成果。
- 計時從實際活動出發事件開始；手機暫停會凍結 Player、兩台載具、guard、救援者、城市時鐘與活動時間。失敗後透過手機重接同一活動會重置計時與本次目標。
- 停車的外側 3 m 橫停、仍在移動及不足 1.5 秒的停妥均被拒絕；對齊、整台車落在標示範圍、速度為零且停妥足夠時間時才驗收。
- 真實 GUI 同幀按下／放開觸控「互動」Button，Player 互動正確打開委託手機；選單暫停會釋放觸控 action。按住 ↑ 後縮小畫布也會釋放 action。測試使用 `Viewport.push_input(..., true)`，排除 headless 外部座標轉換造成的假陰性。
- 觸控關閉，以及觸控開啟但沒有按住任何按鈕時，外部 `Input.action_press("brake")` 都經過實際 process／physics 保持 pressed 並讓真實車輛減速。GUI「跳／煞」持有的 jump 與 brake，則會在關閉觸控時一併釋放。
- 844×390 有 14 個可見觸控按鈕，全部在畫面內；462×260 與 390×219 的小畫布改為隱藏按鈕並顯示「請用全螢幕或橫向，放大操作區」。三種尺寸的委託選單都在畫面內。小畫布提示不是該尺寸可直接觸控遊玩的證明。

以上互動流程使用可達位置的 fixture 擺位，沒有把瞬移當成人類走路、騎車或駕車完成全流程的證據。未測車輛沿全路線的人類操控時間、所有手機瀏覽器、多點觸控、Web 幀率或美術品質。

## 問題與修正狀態

| 優先序 | 問題 | 實測證據與狀態 |
| --- | --- | --- |
| P1 | SIDE-007 背包落在既有商辦西牆邊，無法從外部通過互動 LOS。 | 原位置 `(-67, 0.12, -104)`；0.25 m 細採樣得到 212 個可站點，0 個有可用 LOS。root 已加入既有 building bounds 到安全擺位，最新 44／44 目標、SIDE-007 與獎勵總額通過。 |
| P1 | 停車只驗角色中心距離，橫停於車格外也完成。 | 原測試 car `(116, 0.12, 104)`、target `(113, 0.12, 104)`、yaw `PI/2` 得到 completed。root 已加車格線、四角包含與角度限制；最新拒絕外側／移動／短停並接受完整合法停車。 |
| P1 | 觸控按住前進時縮小畫布，按鈕隱藏後 action 仍然 pressed。 | 真實 GUI 按住 ↑ 後由 844×390 改成 462×260，曾持續前進。root 已在過小畫布的布局路徑呼叫 release_all；最新 `shrinking_touch_viewport_releases_hidden_held_action` 通過。 |
| P1 | 觸控停用時每幀釋放外部 brake，讓原主場景煞車／下車測試失敗。 | 完整 runner 捕獲 main self-test 的 car.exit assertion；root 定位為 release_all 無條件釋放 brake，已改為只釋放自己持有的 jump 配對 brake。新增四項真 GUI／物理驗證均通過。 |
| P1 | 新可選物件擋住背景行人的既有路線。 | 完整 runner 捕獲 district_life 的 route clearance failure；城市 worker 調整路線後，最新真場景的 47 項檢查全部通過，原膠囊／靜態物理 clearance 檢查保留。 |
| P2 | non-solid 活動 marker 被 restore 重新啟用碰撞，停車合法中心有 barrier。 | 新遊戲／prepare_task 的 `DistrictObject.restore` 曾重新啟用碰撞。root 已增加 non_solid 旗標，set_collected／restore 均保留；最新實際車輛 BoxShape 在停車中心無 blocker，檢查通過。 |
| P2 | 小畫布操作區原先溢出。 | root 已改成明確提示放大操作區，委託選單尺寸亦已修正；目前版布局驗收通過，但手機 inline 小畫布仍需依提示切換全螢幕或放大。 |
| P2 | 文案含「骑车出發」。 | root 已改成「騎車出發」；worker 只覆核，未改遊戲來源。 |

root 修正後的整合 driver 最新測試：**214 checks passed、0 failures，exit code 0**。

## 完整 runner 續作

`tools/test_game.py` 保留原來的 import、主場景 self-test、mission_contract、controls、guard_persistence、release_regressions，新增 optional_content、district_life 與 v02_integration。每個 suite 必須輸出自己的真實 summary；缺少 summary、SCRIPT ERROR、非零 exit、超時或回報 failure 都會失敗。匯入失敗會停止，其餘 suite 失敗會繼續收集後續結果。每次覆核仍會寫回 `qa/engine-checks.json`。

```text
python tools/test_game.py --godot godot
```

runner 把 Godot 專案複製到獨立臨時目錄，略過 `.godot`；在副本的 `[editor]` 取代或補上 `import/use_multiple_threads=false`，不重複追加 section、不改 root 正在匯出的來源與快取。Godot 的匯入程式確實從 ProjectSettings 讀這個值。[Godot 4.7.2 匯入來源](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/editor/file_system/editor_file_system.cpp)

子程序的 APPDATA／LOCALAPPDATA 或 Linux XDG 路徑都指向臨時目錄；Windows 的 Godot user data 由 APPDATA 解析。[Godot 4.7.2 Windows 路徑來源](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/windows/os_windows.cpp) runner 只稽核隔離目錄的 save 檔名，拒絕 94–98 以外的存檔；不查看真實玩家存檔目錄。公開 JSON 的命令與輸出使用 repository／isolated-run／Godot placeholders。

首輪乾淨 runner 捕獲原 self-test car.exit assertion，以及 district_life 的行人路線 clearance failure，沒有把 exit 0 的 SCRIPT ERROR 誤判為成功。車輛煞車由 root 修正；行人路線由城市 worker 修正。最終重跑使用這兩項修正後的來源、214 項整合 driver、最新字型與 Web 右鍵鏡頭／HUD 程式。

| 檢查 | 實際數量 | 最終結果 |
| --- | ---: | --- |
| clean Godot import／parse | 1 個程序 | PASS |
| main self-test | 9 個整合群組 | PASS |
| mission_contract | 233 | PASS |
| controls | 44 | PASS |
| guard_persistence | 16 | PASS |
| release_regressions | 37 | PASS |
| optional_content | 175 | PASS |
| district_life | 47 | PASS |
| v02_integration | 214 | PASS |

最終結果：**8 suites、775 reported checks、0 failures，exit code 0**。其中 766 是各 script 的檢查數，另 9 是既有 main self-test 的整合群組，沒有把它們當成 775 個獨立底層 assertion。完整記錄在 `qa/engine-checks.json`。每個程序只有測試槽 94–98；所有 slot 檔位於隔離的 user-data 目錄。Python 編譯檢查與 `git diff --check` 也通過。

獨立 diff／公開範圍覆核：README 與 Web 操作文件明確限定五主線、六支線、四活動與現有 300 × 300 m 地圖；歷史 Windows 0.1 下載和舊截圖有版本說明；背景行人／交通採固定路線、手機實機矩陣與完整 MVP 尚未完成均有列出。新增字型保留 OFL 並改名；Web preset 為單執行緒，沒有新增帳號或多人服務。本 worker 未發現剩餘 P0／P1 功能問題，也沒有將 headless 或 source diff 當成公開部署與真 Web 遊玩的驗證。

## Web 靜態檢查與界線

`main.gd` JavaScriptBridge 只接受固定選單／存讀／觸控開關／視角命令；沒有 mission event、任務完成、位置改寫或任意 GDScript eval 入口。頁面命令來自固定 DOM button map；状态摘要使用 `textContent`，不是 HTML 拼接。狀態中的座標用於檢查，沒有供玩家任意改寫世界的命令。

Web preset 的 thread_support 為 false；shell CSP 使用 self 與 wasm-unsafe-eval，沒有一般 unsafe-eval。Brotli 工具確認 WASM 魔數後才壓縮；生成的 `_headers` 指定 WASM MIME 與 `Content-Encoding: br`。這裡只讀來源，未聲稱 public host、CSP、Brotli 解壓與實際 Web Engine 啟動已驗收。真瀏覽器與 Cloudflare 網路驗證由 root 負責。

繁中文案按核心規則 mode 2 做只讀校對：唯一發現的遊戲用字已由 root 修正，原句「骑车出發」、原因「含簡體字」、改為「騎車出發」。數字與驗證範圍隨實際測試更新。
