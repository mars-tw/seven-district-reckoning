# 台灣生活街區地圖與 Blender 資產交接

範圍：新增世界模組、原創環境資產與本模組驗證。沒有修改主線、舊支線、玩家、HUD、存檔或既有 `DistrictLife`。完整遊戲整合與瀏覽器三端驗證由根工單接手。

新增 `TaiwanExpansion` 保留原 300 × 300 公尺核心，以四塊實際物理地面補齊到 800 × 800 公尺，世界邊界為 X/Z ±400 公尺。四塊外城地面面積合計 550,000 平方公尺，原核心 90,000 平方公尺。外環為連續道路與人行鋪面，四條主街接原核心 ±137 公尺道路，另有四條支路。八個新增街區各有四個保留的任務站點，共 32 站。

這是台灣文化題材的虛構濃縮街區，沒有拿實際測繪、真實商家或門牌作為完成聲明。

| 區域 ID | 名稱 | 主站 ID | 中心 X/Z |
| --- | --- | --- | --- |
| market | 晨光市場 | market_square | -270 / -270 |
| night_market | 南星夜市 | night_market | 270 / -270 |
| convenience | 日常便利街 | daily_store | 270 / 0 |
| parcel_hub | 橘盒物流街 | orange_parcel | 270 / 270 |
| greenway | 青禾里綠廊 | community_green | 0 / 270 |
| river | 柳岸河濱 | river_walk | -270 / 270 |
| heritage | 榕安老街 | old_arcade | -270 / 0 |
| creative | 木石創作巷 | creative_lane | 0 / -270 |

每區三個子站的 X/Z 偏移依序為 (-12,-12)、(12,-12)、(12,12)。所有中心 ±15 公尺前場均已用實際膠囊碰撞與地面射線確認可通行。站點的可互動身體、配送及角色任務不由此世界模組生成。

## 原創資產

Blender 5.2.0 LTS 背景 CLI 實產 13 款 CC0 資產，同時保存可編輯 `.blend`、自帶貼圖的 GLB、PBR 圖片與每款 Cycles 渲染。

- 有柱列的騎樓商店、鐵捲門、窗框、外掛冷氣、屋頂水塔。
- 虛構便利商店與橘盒取貨站，分別有雨遮、玻璃拉門、終端凹位、格櫃、包裹櫃台。
- 早餐、熱食、蔬果三款工作攤，含遮雨棚、爐面、蒸鍋、飲料、蔬果箱。
- 兩輪機車，含踏板空間、把手、後照鏡、座墊與空白車牌。機車為停放道具，沒有冒稱新增可駕駛系統。
- 燈籠門、候車亭、河岸涼亭、分類回收站、包裹架、附陽台欄杆的三層透天。

所有新貼圖最多 128 × 128；磁磚 UV 以公尺設定，單塊約 25 公分。新道路與鋪面使用 mipmap 和 anisotropic filtering。店名、配色、招牌與幾何為原創，沒有抓取街景照片、商標或 GTA 資產。

最終資產檢查包含 Godot 抽出的貼圖副本，Runtime source bytes 為 2,356,463，低於本工單 10 MiB 上限。這個量測不是整個遊戲 PCK 或 GPU 記憶體。

## 世界資料與效能契約

- 508 個靜態 GLB 實例；另有 16 位外城行人、4 輛外環動態汽車。人流復用既有 `civilian_human` 與 `zhou_human` 骨骼人物；沒有把復用人物列為新增造型。
- 2,454 個道路、標線、鋪面及河岸護欄實例，依 90 公尺空間 sector 合批。所有 MultiMesh 的 origin 在自身 sector 中央，instance transforms 使用局部座標。
- 479 個靜態 draw groups；485 個碰撞形狀合併到 40 個 sector 身體，另有四個地面身體。沒有為每条路線或裝飾建立獨立物理身體。
- 保留 Godot GLB 匯入器產生的 55 組實際拓撲 LOD index buffers；人物保留既有 walk/run 骨骼動畫。
- `apply_profile()` 接受 `building_distance`／`view_distance`、`prop_distance`、`shadows`。手機、平板、桌機切換僅改渲染距離、LOD／陰影，地面、碰撞與站點保持相同。
- 行人與汽車分別加入 `ambient_citizens`、`ambient_traffic`。`device_budget_active=false` 時立即停止 AI 位移與骨骼動畫；重新啟用續走原路線。暫停會停止模組時鐘與人車。
- 外環汽車以實際 Area3D 偵測玩家身體、煞停並轉動原車輪網格。對已上車玩家另有玩家位置的前方檢查。
- `set_hour()` 使用既有時鐘調整燈籠夜間 emission；沒有新增大量動態點光源。

## API

`static bootstrap(host, player=null)`、`setup(player=null)`、`get_regions()`、`get_station_positions()`、`get_obstacle_bounds()`、`is_walkable(point,radius)`、`get_counts()`、`get_navigation_roads()`、`get_visual_bounds()`、`apply_profile(profile)`、`set_hour(hour)`。

`get_navigation_roads()` 的每條資料包含 `id`、`a`、`b`、`width`、`surface_y`；端點為 `[x,z]`，道路清單對應實際渲染的道路。

## 實跑證據

| 驗證 | 結果 | 產物 |
| --- | --- | --- |
| Godot 地圖／人流／車流 | 151 PASS／0 FAIL | `qa/taiwan-expansion-result.json` |
| 原創 GLB、UV、PBR、SHA、貼圖與大小 | 179 PASS／0 FAIL | `qa/art/taiwan/taiwan-validation.json` |
| Blender 開啟原檔與 GLB 二次匯入 | 91 PASS／0 FAIL | `qa/art/taiwan/taiwan-roundtrip.json` |
| 真實 Native OpenGL renderer | 五張場景視圖，無 renderer errors | `qa/art/taiwan/native-review.json` |

Godot 逐段做了 7,968 個實際道路膠囊採樣，包含左右車道偏移 ±4 公尺；另外確認 32 站、八個 30 公尺前場、49 個地面接縫／外角及全體行人的每段步行路徑。動態驗证包含實際行走、車輪旋轉、預算停啟、Area 煞車和暫停。

渲染圖為世界模組美術審查，不是公開瀏覽器遊玩或手機 FPS 證據；沒有拿 headless dummy renderer 的測試計數冒稱三端效能完成。根工單仍須把主線、舊存檔、導航、任務 NPC 與配送站完整整合驗收。

## 重建

在專案根目錄以 Blender 5.2 執行 `tools/blender/build_taiwan_assets.py`，接著執行 Godot 4.7.2 `--headless --path godot --editor --import --quit`。

資產驗證：`python tools/blender/validate_taiwan_assets.py`；Blender 二次匯入：`tools/blender/verify_taiwan_roundtrip.py`；地圖驗證由 Godot 執行 `tests/taiwan_expansion.gd`；真 renderer 視圖由 Godot 執行 `tests/taiwan_expansion_preview.gd`，必須使用 OpenGL／Compatibility，不能加 `--headless`。

所有公開來源、工具與 JSON 使用專案相對路徑，私人暫存、下載、帳密與本機 runtime 不在交付內容內。
