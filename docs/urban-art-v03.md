# Alpha 0.3 城市美術

城市採七期商辦與綠廊的空間關係，仍是虛構的 300 公尺 Alpha 街區。這次沒有匯入真實地址、街景照片或 GIS 圖資，也沒有把真實建築指定為詐騙據點。

六組新 GLB 與六份可編輯 Blender 檔：`urban_tower_a`、`urban_tower_b`、`urban_tower_c`、`urban_sidewalk`、`urban_shopfront`、`urban_bench`。塔樓有逐層幕牆、1.5 公尺左右的窗模組、金屬收邊、門把、門廊與屋頂機房遮屏。玻璃採不透明 PBR，減少手機透明材質排序與過度繪製的負擔。地坪使用原創程序化花崗石、瀝青、鋪面與玻璃的 albedo、normal、ORM 貼圖。

三座塔樓原生樓層高度為 3.6 公尺，門高 3.1 公尺，人行道寬 3.2 公尺，長椅座面高 46 公分。現有 Alpha 的樓房碰撞範圍會縮放模板，部分樓層高度因此不同；不能把模板尺度當成全地圖每棟樓的實測數字。

`UrbanDetail.bootstrap(host)` 只加視覺材質、路口、雙黃線、路緣線、修補瀝青、地坪、排水溝與導盲紋理。道路沿現有的中心路、正負 76 公尺內環與正負 137 公尺外環配置，採 MultiMesh 合批。模組沒有碰撞、感應器或新的障礙物，`get_bounds()` 返回空陣列。原有任務碰撞與行人路線由原系統管理。

## 接入

在主場景建立城市後呼叫 `UrbanDetail.bootstrap(self).setup(player)`。模型映射為 `office_tower_a → urban_tower_a`、`office_tower_b → urban_tower_b`、`office_tower_c → urban_tower_c`。低於 12 公尺的外圍服務站與店面可改用 `urban_shopfront`，避免把高樓幕牆壓成玩具般的樓層。

## 重建與檢查

```powershell
blender --background --python tools/blender/build_urban_assets.py
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script ../tests/urban_detail.gd
```

Blender 原檔在 `assets/source/blender/urban/`，程序化材質與模型預覽在 `qa/art/urban/`，三角面、材質數、尺寸、檔案雜湊與預算由 `urban-manifest.json` 記錄。Godot 檢查驗證真實 GLB 載入、合批數與零新增阻擋；完整任務通行與手機效能由根專案整合驗證。

模型與貼圖採 CC0，程式碼採 MIT；授權與政府主源參考列在 `assets/provenance/v03-urban-sources.json`。參考頁只用於確認環境與公共設施關係，沒有複製頁面媒體。
