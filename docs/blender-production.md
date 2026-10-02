# Blender 生產規劃與 Godot 資產契約

專案：**《七期：斷鏈行動》／Seven District: Break the Chain**  
規劃日期：2026-10-02  
階段：Planning。本文與資產清冊是後續工單的製作規格；目前沒有完成模型、貼圖、動畫、GLB 或遊戲導入驗收。所有數量、效能與美術預算都是**設計上限，尚未實測**。

## 1. 製作範圍

Blender 負責模型、UV、貼圖製作與烘焙、骨架及動畫；Godot 負責遊戲規則、控制器、互動、物理、任務、音訊、AI 與執行檔。Windows 單機先做出可完整遊玩的垂直切片，再擴成 MVP。

| 範圍 | 垂直切片 Slice | MVP |
| --- | --- | --- |
| 地圖 | 300 × 300 公尺、兩個虛構街廓 | 800 × 800 公尺、六區 |
| 可遊玩內容 | 20～30 分鐘、5 條主線任務 | 12 條主線、12 條支線、8 種活動 |
| 車輛 | 一款可駕駛汽車＋一款可騎自行車 | 合計 3 款可駕駛四輪車＋1 款自行車，含 Slice 兩款 |
| 可拾取武器 | 球棒、扳手、虛構脈衝器具 | 合計 6 種，新增伸縮棍、幻想電擊器、泡沫投射器 |
| 破壞物 | 必要 6 類，另有玻璃同類視覺變體 | 追加販賣機與貨箱兩類可選擴充；沿用同一三態契約 |
| 商辦室內 | 一棟主要商辦的大廳、標準辦公層、機房、屋頂 | 合計 3 棟商辦可進關鍵樓層，含 Slice；其他兩棟重用 kit 各做入口＋至少一個任務標準層 |

自行車是 Slice 的必要資產與必要控制器，不延後到 MVP 之後。

地圖取臺中七期的城市印象：寬街廓、商辦玻璃立面、商場裙樓、景觀植栽、行人廣場、雨棚與高樓天際線。建築、招牌、企業、人物與室內動線全部原創；不複製真實園區的門禁、保全配置或攻擊布局。主要商辦以「一個可玩標準層＋有限任務區」形成高樓體驗，沒有逐層製作整棟大樓的承諾。

## 2. 視覺方向與資產階段

採風格化 3D、低至中模，輪廓清楚，材質保留城市的玻璃、石材、金屬與柏油差異。角色與武器須在第三人稱遊戲鏡頭下辨識，破壞前後的狀態也要明確。

資產有三個品質階段：

1. **Graybox**：可用 Blender 腳本產生尺寸標記、立方體體塊、道路及碰撞原型，用來驗證尺度與可達性。
2. **Gameplay art**：完成可識別輪廓、人物骨架、車輪樞紐、互動插槽、破壞狀態與基本材質。
3. **Reviewable art**：人工設計建築 kit、修整拓樸與 UV、處理配色及構圖、完成 LOD 與遊戲鏡頭驗收。

程序化素體不算完成美術。主要商辦的入口、立面節奏、窗框、雨棚、大廳與屋頂必須有人工設計和修整工單；樓高、面積或多生成幾個方塊不能作為完成判定。

## 3. 來源與輸出目錄

```text
assets/source/blender/<category>/<slug>.blend
assets/source/textures/<category>/<editable-source>
assets/provenance/<ASSET-ID>/source.json
assets/provenance/<ASSET-ID>/license-copy.txt
godot/assets/models/<category>/<slug>.glb
godot/assets/textures/<category>/<texture>.png
godot/assets/materials/<category>/<material>.tres
godot/scenes/player/<player-wrapper>.tscn
godot/scenes/actors|vehicles|props|world/<wrapper>.tscn
```

清冊 `docs/asset-register.json` 的 `source_path` 與 `export_path` 是**預定交付路徑**，不是現有檔案證據。Blender 原始檔保留在 Godot 專案根外；引擎只讀輸出的 GLB 與貼圖。來源相同的 kit 可輸出多個命名 mesh，由 Godot wrapper 決定遊戲行為。主玩家 wrapper 放在 `godot/scenes/player/`；NPC wrapper 放在 `godot/scenes/actors/`，兩者共用 ASSET-001 人形骨架。

GLB 是本案預設交接格式。Godot 官方推薦 glTF 2.0，也支援 GLB；直接導入 `.blend` 會呼叫本機 Blender 轉換，因此團隊及 CI 若採 `.blend` 導入都需要 Blender。以 GLB 作為明確輸出有利於固定版本及重複導入；GLB 的二進位差異不易人工檢閱，原始檔、匯出設定與驗證報告必須一起保留。[Godot 可用 3D 格式](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)

本次只規劃新專案，不修改上層目錄原有的 Unity 專案。本次未安裝或啟動 Blender／Godot；生產版本尚未鎖定。主工單 TASK-002 鎖定官方工具版本、作業系統與匯出設定；TASK-004 執行尺寸、軸向、材質、動畫和重複 GLB 導入驗證。BLD-01 是這兩張主工單的美術細項。

## 4. 尺度、軸向與命名契約

| 項目 | 規格 |
| --- | --- |
| Blender Scene Units | Metric，Unit Scale = 1.0；1 Blender unit = 1 公尺 |
| 地圖軸向 | Blender +X 東、+Y 北、+Z 上；導入後 Godot +X 東、-Z 北、+Y 上 |
| 有正面的模型 | Blender -Y 為正面；GLB／Godot +Z 為 model front |
| 相機 | Godot -Z 是相機前向；不得據此把角色模型的前向改成 -Z |
| 變換 | 綁骨前完成可見 mesh 與 Armature 的 Rotation／Scale；預期 rotation = 0、scale = 1；禁止負 scale |
| 可動物原點 | 位於操作中心：角色腳底中心、車體底盤中心、門鉸鏈、輪軸、工具握把 |
| 靜態 kit 原點 | 地面接點或對齊角落；0.5 公尺吸附格，主牆／路段以 2、4、8 公尺倍數製作 |
| Mesh 命名 | `ASSET_015_compact_car_render_LOD0`、`..._LOD1`、`..._collision` |
| 材質命名 | `M_char_hero`、`M_city_trim` 等穩定名稱；匯出後不任意改名 |
| Socket 命名 | `socket_hand_r`、`socket_seat_driver`、`socket_pedal_l` 等 |
| 動畫命名 | `loc_idle`、`loc_walk`、`ride_bike_pedal` 等 ASCII 固定 ID |

Godot 官方將模型 +Z 前面與相機 -Z 前向分開。控制器以 `Vector3.MODEL_FRONT`／`look_at(..., use_model_front=true)` 使用模型慣例；若既有 controller 必須採 -Z，僅在 wrapper 的 VisualPivot 做一次明確轉換，並記錄及驗證，不能在多個地方重複轉 180 度。[Godot 模型匯出注意事項](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html)

MVP 的車輛與武器新增款不是只換顏色：ASSET-018 貨運車、ASSET-065 商務房車分別沿用 arcade 控制並驗證上下車；ASSET-066～068 三武器有不同輪廓與 gameplay 行為；ASSET-055、069 分別交付第二／第三棟的可玩關鍵樓層。

尺寸檢查場景包含 1 公尺量尺、1.75 公尺人形、一般門框、車輛與自行車。將同一 GLB 重匯兩次，尺度、正面、材質名稱和 socket 位置都不得漂移。不要在已完成蒙皮的骨架上盲目 Apply Transforms；骨架變更要重驗所有動畫。

## 5. 角色、Rig 與動畫交付

### 共用人形契約

清冊 ASSET-001 為共用骨架。角色服裝可變，主要骨架與蒙皮契約維持一致。

- A-pose 為本案 bind pose；若要接 Godot Humanoid retarget，另在導入工單建立 BoneMap 和 rest pose 校正，不能假設所有外部動畫自動相容。
- 一個 root、一個 pelvis；spine、neck、head、左右手臂及腿部命名固定。設計上限 65 根 deform bones、每 vertex 最多 4 個權重。
- IK 控制器、constraint、driver 可存在 `.blend` 作者檔；交付動畫須 bake 至 deform bones。引擎不依賴 Blender constraint。
- 角色用 capsule 碰撞，武器命中範圍由 Godot 定義；不可使用角色 skinned render mesh 作即時碰撞。
- `socket_hand_r`、`socket_hand_l`、`socket_back`、`socket_head` 以骨架 attachment 對應；拾取物與手持版本要共享同一資產 ID。
- 動畫基準為 30 fps。Slice locomotion 採 in-place，位移由 controller 決定；轉身與步頻需配合遊戲速度。後續若用 root motion 要另改契約與驗收。
- 攻擊接觸、拾取、上車等事件在 Godot 行為資料中記錄時間點，不依賴 Blender marker 自動轉成引擎事件。
- 所有角色完成走動、蹲姿、持物、騎乘四種代表姿勢的關節與服裝穿插檢查；遠距 NPC 可共用較少的動畫。

### Slice 動畫最小集合

| 套件／ID | 動畫 | 驗收條件 |
| --- | --- | --- |
| ASSET-010 locomotion | idle、walk、run、sprint、turn、jump、fall、land、crouch、pickup | 每個 loop 連續；落地不滑步；不夾帶全場景位移 |
| ASSET-011 action | bat_swing、wrench_swing、pulse_aim、pulse_fire、hit_front、hit_back、knockdown、recover | 攻擊姿勢可辨識；命中時間可由程式設定；不以寫實傷口為重點 |
| ASSET-012 car rider | enter_car、drive_idle、drive_turn、exit_car | 入座及下車位置對齊同一款汽車 socket |
| ASSET-013 bicycle rider | mount_bike、bike_idle、bike_pedal、bike_brake、dismount_bike | 手把、坐墊、腳踏接點連續；不同速度不出現腳跟瞬移 |
| ASSET-014 NPC reaction | talk、phone、sit、panic、flee、surrender | NPC 狀態切換可讀；恐慌後移動仍服從避障控制 |

### 創作角色與模型映射

人物姓名、年齡與劇情身分以 `docs/creative-bible.md` 為正本；JSON 頂層 `character_asset_mapping` 將角色 ID 對應固定資產。以下服裝剪影是規劃中的美術識別條件，尚未製作成模型。

| 創作 CHAR-ID | 資產 ID | 角色／年齡／身分 | 規劃中的服裝剪影與專用變體 |
| --- | --- | --- | --- |
| CHAR-PLAYER | ASSET-002 | 林至遠，29 歲，外送員／玩家主角 | 外送工作短外套、長褲、斜背配送袋；可選外觀仍以「阿遠」為劇情身分 |
| CHAR-YU | ASSET-003 | 許予安，27 歲，地方記者 | 淺色短外套、原創記者識別證與斜背採訪袋；專用臉部身分 |
| CHAR-MEI | ASSET-004 | 陳美晴，31 歲，自行車店主 | 工作背心、短袖、修車腰包與騎車長褲；專用臉部身分與完整騎姿 |
| CHAR-LIAO | ASSET-005 | 廖啟宏，41 歲，虛構集團負責人／反派 | 深色合身西裝、原創領帶／胸針；專用臉部身分 |
| CHAR-CAPTAIN | ASSET-006 | 江岳，36 歲，園區安保主管 | 保全套件中的專用制服短外套、識別肩線與工作腰帶；專用臉部身分 |
| CHAR-CHENG | ASSET-009 | 周成，24 歲，受困招募員 | 略皺襯衫、原創識別證掛繩與便鞋；受困／救出狀態保持同一臉部身分 |
| CHAR-AUNT | ASSET-008 | 吳素蓉，56 歲，早餐店女性店主 | 路人套件內固定具名變體：短捲髮、素色工作上衣、前綁圍裙、寬直長褲、平底工作鞋；圍裙形成清楚的早餐店工作剪影 |

共用 ASSET-001 骨架、基礎拓樸與動畫可減少製作量。七位具名角色仍須有獨立的臉部身分、髮型與服裝識別，不得只替同一張臉換色；江岳不能被一般保全替換，吳素蓉不能被隨機女性路人替換。代表鏡頭與角色同場截圖要能辨識角色，並驗證角色 ID 與 wrapper 綁定一致。

`technical_ally`、`courier_ally` 等既有 source slug 保持穩定；ASSET-003 身分已定為記者許予安，ASSET-004 為自行車店主陳美晴。檔名不作劇情身分判定。台詞與任務細節仍由創作正本管理。

## 6. 汽車與自行車：Arcade 控制

### 汽車 ASSET-015

先做一款原創四門都會車，含車體、四輪、前輪轉向 pivot、車門、方向盤、座位與上下車 socket。車標與牌照均為虛構圖樣。

- Godot wrapper 使用 arcade 控制：單一車體碰撞＋地面偵測＋可調加速度、煞車、轉向、抓地力與最大傾斜。先驗證控制手感，不綁定必須使用某個車輛物理節點。
- 輪胎旋轉由移動距離驅動，前輪 steering 與輕微懸吊用視覺動畫呈現；懸吊與輪胎不做完整多剛體鏈。
- 車門作 visual child，由短動畫開關；入座時隱藏或停用玩家步行控制器，退出時先查安全空位。
- 車輛受損先做材質／配件狀態與輪廓變化，不做可即時摺曲的金屬車體。

驗收包含 10 分鐘道路行駛、完整 10 次上下車、低速撞障礙後能恢復、傾倒時能安全重置；沒有行人穿過車體、玩家退出落到地下或車輪軸跑偏。

### 自行車 ASSET-016

自行車與汽車同步進 Slice。含車架、前叉、輪子、曲柄、腳踏、手把、座位、騎乘 socket。騎乘不是步行角色套一個自行車外觀。

- 控制使用單一 CharacterBody3D／簡化車體 controller，地面碰撞與坡面判定獨立於兩個視覺輪子；不做二輪動態平衡、陀螺力或全套連桿物理。
- 車輪按速度轉動；曲柄按踩踏動畫旋轉。視覺 lean 根據速度與轉彎量做有上限的傾斜，停車自動回正。
- 角色為共用骨架，座位、手把及腳踏以 socket／IK 或 bake 動畫對齊。Slice 先採固定車型與固定騎姿尺寸，避免製作任意角色任意車架的適配系統。
- 低速可直接停車；摔車以有限狀態與短動畫處理；卡住時安全重置。倒車、輪胎爆胎、花式特技與精密自行車模擬不屬 Slice。

驗收包含 10 分鐘連續騎乘、10 次上下車、停車轉彎、起步／煞車、通過坡道與路緣測試；攝影機不持續穿入角色背部，手腳接點誤差在代表姿勢下不超過 5 公分。先做低速坡道測試才增加騎車任務。

## 7. 建築 Kit 與地圖組裝

主要商辦分開交付：

- **外殼 ASSET-034／035**：可辨識主入口、玻璃窗格、石材基座、雨棚、屋頂收邊；背景立面以 atlas／trim sheet 和重複 mesh 形成，不把每片窗戶拆成一個材質。
- **大廳 ASSET-036**：入口、服務櫃臺、休息區、電梯前室。由任務用途決定視線與動線。
- **標準辦公層 ASSET-037**：走道、辦公室、會議室、開放座位區；只做可玩樓層，非全樓層複製。
- **機房 ASSET-038**：遊戲化的虛構任務空間；機櫃狀態以任務互動呈現，不提供真實設施破壞或入侵操作。
- **屋頂 ASSET-039**：可玩範圍、設備輪廓、遠景；以清楚邊界防止出界。
- **門／電梯／樓梯 ASSET-040／041**：門 pivot 和碰撞獨立；電梯以樓層切換或短過場連接室內分區。Slice 不做整棟連續可破壞樓板。

道路、人行道、廣場、無障礙坡道、車道標線、自行車停放區先組成兩個虛構街廓。室內用區段啟用及遮蔽；室外按 100 × 100 公尺 chunk 組裝與量測，對齊 TASK-034；MVP 沿用此格。

ASSET-042 提供獨立導航與遮蔽 proxy。行人只在已烘焙可走區行走；車輛沿預設道路圖循環、有限停等和避障。Slice 與 MVP 使用相同同時活躍設計上限：**24 位行人、12 輛車輛（含玩家車輛）、16 位敵人**；非敵對 NPC 與敵人分開計數，依實測調整。沒有全城市居民生活模擬的承諾。

## 8. 破壞契約：預切三態

破壞採 `intact → damaged → broken` 三態。由 Godot wrapper 切換模型、碰撞、粒子與音效；Blender 預先切好破片並共用 pivot。建築主體不做即時全面坍塌。

Slice 必要六類是：展示機台（ASSET-043）、辦公桌（044）、玻璃隔屏（045）、路障（048）、招牌（049）、機櫃外殼（051）。ASSET-050 是玻璃同類的裝飾變體，不重複計入六類；販賣機（046）與貨箱（047）是 MVP 可選擴充類。每個必要類交付：

1. 完好與受損 mesh；受損輪廓、裂痕及材質不能只靠一個血量數字。
2. 破壞後的主體殘骸 mesh；破片另分最多 8 個 convex 物件。
3. 狀態 metadata：`asset_id`、`destructible_kind`、`state`、`debris_count`。
4. 同一原點與外形碰撞；破碎後清除失效障礙，不在可走路面留下看不見的牆。
5. 每次事件最多 8 個短命動態破片；同時活躍破片設計上限 60，壽命最多 6 秒後合併或回收，場景殘骸保留為靜態或純視覺狀態。
6. 存檔只記資產 instance ID 與三態；讀檔不重播所有物理碎片。

6 類物件各重複破壞 20 次：狀態不可跳回、碰撞不可殘留、音效不可無限疊加、物件數與記憶體不得持續上升。破壞事件不得造成任務唯一證據永遠消失；關鍵證據以獨立不可遺失的任務資料管理。

## 9. 美術效能預算

下表的 triangles 是 **匯出後、LOD0、可見 mesh 的設計上限**；draw call 欄是預估每個實例的材質 surface 上限，不是已量測的引擎 draw calls。陰影、透明、額外 passes、材質變體與視角都會改變實際提交數，須在 Godot profiler 測量。LOD1 初定約 LOD0 的 50%，LOD2 約 20%，仍以輪廓測試決定，不能機械刪面。

| 類別 | LOD0 triangles／個或模組 | 材質 surfaces／實例 | 貼圖設計上限 | Collision |
| --- | ---: | ---: | --- | --- |
| 玩家／主要 NPC | 20,000 | 3 | 1 套 2048² Albedo／Normal／ORM | capsule |
| 一般 NPC | 8,000 | 2 | 共用 1024² atlas | capsule |
| 汽車 | 22,000 | 3 | 2048² 共用車體；玻璃簡化 | box／簡化 convex |
| 自行車 | 9,000 | 2 | 1024² 共用 atlas | capsule／box 組合 |
| 手持武器 | 3,000 | 1 | 512²，必要時 1024² | 簡化 hit volume |
| 可破壞物完好／受損 | 4,000 | 2 | 1024² 共用 atlas | box／convex |
| 每個破壞物的全部殘骸 | 6,000 | 共用 2 | 重用原貼圖 | 每片簡化 convex |
| 立面／室內 kit 模組 | 6,000 | 2 | 共用 2048² trim sheet | 靜態簡化 box／有限 trimesh |
| 主要大樓外殼完整組合 | 100,000 | 8 個共享 material slots 目標 | 至多 3 套 2048²共享材質 | 分段靜態 proxy |
| 道路／人行道 20 公尺模組 | 2,000 | 2 | 1024² 重複材質＋標線 atlas | 靜態平面／box |
| 樹木／植栽 | 3,000 | 2 | 1024² atlas；優先 alpha scissor | 簡單 trunk capsule |
| 背景天際線／個 | 1,000 | 1 | 共用 1024² atlas | 無 |
| 小道具 | 1,500 | 1 | 512²共享 atlas | 需要互動才配置 |

Slice 代表視角暫定：同時可見 triangles ≤ 500,000、總 rendering draw calls ≤ 300、動態破片 ≤ 60。這是降載起點，不是 FPS 保證。渲染解析度、renderer、陰影與硬體基準在引擎工單鎖定後，記錄平均及 95th percentile frame time、VRAM、物件數與破壞尖峰，再修訂預算。

單一 2048² RGBA8 貼圖未壓縮約 16 MiB，完整 mip chain 約 21.3 MiB；三張圖約 64 MiB，實際壓縮、通道格式及引擎資源共享會改變用量。不要把每個窗戶、NPC 或破片獨立配置 2048² 材質。

GLB 對平面、UV seam 與法線邊界可能拆分 vertices；在 Blender 看見的 vertex count 不是匯出後 GPU vertex count。預算以匯出／引擎導入報告為準。

## 10. UV、材質與匯出程序

Blender 官方 glTF 匯出器支援 Principled／metal-rough 材質、UV、蒙皮和動畫，並將 quads／n-gons 轉成 triangles。glTF 未保留所有 Blender node graph；本案主動 bake 需要的程序材質，讓引擎看到明確的貼圖與參數。[Blender glTF 2.0 手冊](https://docs.blender.org/manual/en/latest/addons/scene_gltf2.html)

1. 作者檔保留未套用的可編輯 modifier；export collection 使用可重現副本。將 curves、必要 Geometry Nodes 輸出轉成 mesh；modifier 評估或 apply 策略固定，不在每次輸出改設定。
2. 綁骨前固定 unit、Rotation／Scale、rest pose 與骨名；靜態 mesh 可 Apply Rotation／Scale。移動原點時保持模型世界外觀與 socket 相對位置。
3. 確認 UV0 無 unintended overlap；trim sheet／tile 素材可有有意重疊。需烘焙光照的靜態物件提供無重疊 UV1（第二套 UV），或者明確指定由 Godot 產生。
4. 材質採 Principled BSDF 可識別連線，Albedo 為 sRGB，Normal／ORM 為 Non-Color；tangent-space normal，通道約定 ORM = R AO、G Roughness、B Metallic。複雜 procedural、UDIM 與特殊玻璃效果先 bake 或在引擎另作，不能假設 GLB 全數重現。
5. 不透明背面預設 cull；需雙面的葉片、布料或透明 glass 另列成本。一般建築玻璃先用受控簡化材質，避免透明層層覆蓋。
6. 在 export collection 以 Triangulate 固定拓樸、確認法線與 tangent；匯出器雖自動三角化，也要避免每次 modifier 變動導致破片／陰影變樣。
7. glTF 2.0 Binary `.glb`；固定 active export collection／selected objects、+Y Up、UVs、Normals、需要時 Tangents、Materials、Custom Properties。Armature 動畫 bake 至 deform bones，不輸出無用途控制骨；shape keys 使用時專項驗證設定。
8. 動畫只輸出命名且需要的 clips，避免 NLA／active action 不小心變成多個重複 clip。30 fps sampling 與 clip 長度寫進驗證報告。
9. 不在 Blender 匯出最終遊戲燈光、相機或完整 physics 設定；這些由 Godot wrapper 管理。暫存 render／collision／nav mesh collections 分開，碰撞名與 metadata 需可識別。
10. Godot 導入 GLB，建立 inherited／wrapper `.tscn`；互動、碰撞、音效和任務 script 放在 wrapper，避免重匯 GLB 覆蓋行為。共用材質抽成穩定 `.tres`，保留相同材質名稱。
11. 設定靜態 collision、動態 primitive／convex、LOD、UV／lightmap 和 nav proxy；生成設定與導入檔納入版本管理策略。依資產做一次單體驗證及代表場景驗證。
12. 重新從相同 `.blend` 輸出，導入兩次；比較命名、transform、bounds、triangles、material slots、texture 數、動畫 clip 與 socket。保留截圖與 JSON 報告；位元組雜湊不同不直接視為語義不同。

Godot Advanced Import 可配置 physics、LOD、lightmap、navigation 與外部材質。動態物件用 primitive／convex；trimesh 只安排給靜態場景。名稱穩定的外部材質在 reimport 時較容易維持連結。[Godot Advanced Import Settings](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html)

## 11. Blender 生產工單

以下全為 Planned。前置與驗收通過才進入下一階段；文件、導出腳本或空 `.blend` 不能替代完成的模型。

| ID | 工單與交付 | 前置 | 可驗收結果 |
| --- | --- | --- | --- |
| BLD-01 | TASK-002 工具版本鎖定＋TASK-004 尺寸、軸向與 GLB 導入驗證的美術細項 | 專案架構確認 | 量尺及正面樣本兩次導入一致；紀錄實際版本與選項 |
| BLD-02 | 共用人形骨架＋玩家＋一般 NPC | BLD-01 | 骨名、權重、關節姿勢與 socket 合格；可共用動畫 |
| BLD-03 | locomotion、互動與三武器動畫＋武器模型 | BLD-02 | 三武器可拾取與持有；必要 clips、loop、命中時間明確 |
| BLD-04 | 一款汽車＋上下車動畫與 pivots | BLD-01、02 | 導入後輪軸、座位、車門與駕駛姿勢對齊；可交控制器測試 |
| BLD-05 | 一款自行車＋完整騎乘動畫 | BLD-01、02；與 BLD-04 平行 | socket、曲柄及 wheel phase 可接速度；通過低速及坡道代表姿勢 |
| BLD-06 | 道路、人行道、廣場與天際線 kit | BLD-01 | 拼出 300 × 300 公尺兩街廓；吸附接縫無洞與碰撞臺階 |
| BLD-07 | 主要商辦 exterior＋四個可玩室內區 | BLD-01、06 | 人工設計 kit；入口、大廳、辦公層、機房、屋頂都能按任務使用 |
| BLD-08 | 招牌／玻璃隔屏／辦公桌／展示機台／機櫃外殼／路障六類預切三態 | BLD-01、03 | 所有 state 同原點；碎片數量合約可驗證；破壞後碰撞可替換 |
| BLD-09 | 貼圖、材質、UV／LOD／collision／nav proxy | BLD-02～08 的對應資產 | 每類代表資產合乎預算；輸出存在且導入成功；遠近輪廓合格 |
| BLD-10 | Slice 實景美術整合與修正 | BLD-03～09 | 步行、汽車、自行車、任務與破壞共同運作；實測資產成本與視覺缺陷清單 |
| BLD-11 | MVP 六區、第二／第三款四輪車、三種新武器、第二／第三棟可玩商辦及動作適配 | Slice 通過 | 合計 3 四輪＋1 自行車、6 武器、3 棟可進關鍵樓層；新增車型完整騎乘驗收；kit／rig／三態合約重用 |
| BLD-12 | 來源與許可證審計＋可重建交付包 | 各資產完成後持續，發布前完整 | 每 asset 來源證據、授權文本、歸屬及導出記錄齊全；沒有未核實第三方內容 |

工期由負責人在 BLD-01 完成、硬體與美術品質樣本確定後估算。這裡不以自動生成的數量宣稱可以在固定幾天內完成開放世界。

## 12. 資產授權與完成狀態

資產清冊規劃 **70 項**（55 項 Slice、15 項 MVP），使用固定 `ASSET-001`～`ASSET-070`。每項都有階段、用途、預定原始檔與輸出位置、許可意向、依賴及驗收條件。所有 `status` 都是 `Planned`；所有 `license` 都是 `Proposed / pending provenance`。

- 程式碼以 MIT 為方向；原創模型、貼圖、動畫以 CC BY 4.0 或 CC0 為方向，逐項決定，不把程式碼許可套在全部素材。
- 已有或下載的第三方素材須保留作者、來源 URL、版本、取得日期、license 原文及必要歸屬。許可證不明、禁止再散布或和開源目的衝突的素材不進交付包。
- 使用 GTA 的名稱作類型參考，不使用 GTA／Rockstar 的模型、地圖、音樂、商標、任務文本或介面資產。
- 真實建築照片、商標、人物 likeness 與掃描資料若要加入，另做來源與權利核查；目前不列為已獲授權素材。
- 當前不存在已完成的素材授權審計，因此不能把整個清冊標成 CC0，或聲稱可立即合法公開發行。

## 13. 官方查核紀錄與整合風險

存取日期均為 **2026-10-02**。以下為官方 primary sources；`stable`／`latest` URL 會更新，真正生產須記錄鎖定版本。

| 來源 | 已核到的內容 | 存取證據 |
| --- | --- | --- |
| [Blender glTF 2.0](https://docs.blender.org/manual/en/latest/addons/scene_gltf2.html) | GLB、+Y Up、triangle conversion、Principled／PBR、animation、bake需求 | web open 返回 402；同一官方 URL 用 PowerShell Invoke-WebRequest 取得 HTTP 200 並讀取內容 |
| [Godot 可用 3D 格式](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) | 推薦 glTF 2.0；GLB支援；.blend 呼叫 Blender | web open 成功 |
| [Godot 模型匯出注意事項](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html) | 模型／相機前向與地圖軸向區分 | stable 官方頁面以 PowerShell Invoke-WebRequest 取得 HTTP 200 並核到軸向內容 |
| [Godot Advanced Import Settings](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html) | LOD、碰撞、導航、外部材質與 reimport | web open 成功 |

最早應驗證的整合風險：

1. **軸向／bind pose**：一個轉向樣本先解決，不等全部角色完工。
2. **動畫輸出與 retarget**：Blender NLA／action 設置與 Godot BoneMap 需實跑；清冊中的動畫數量不是相容性證明。
3. **車輛手感與騎姿**：用一車一自行車驗證；特別避免先完成外觀而騎乘系統仍不能玩。
4. **透明玻璃與材質數**：商業大樓會放大 overdraw 與 draw calls；用實際入口視角測量。
5. **破碎碰撞與任務狀態**：破壞、存檔、讀檔共同測試，不只截圖看碎片。
6. **大圖範圍／人群／交通**：300 × 300 公尺量測通過再擴到 800 × 800 公尺；背景高樓不可全部設為可進入。
7. **GLB 重匯覆蓋**：所有行為放 wrapper，資產節點和材質名保持穩定；以二次導入驗收。
8. **開源來源證據**：來源不清的貼圖、動作捕捉、車輛與字型不得因能導入就視為可發布。

