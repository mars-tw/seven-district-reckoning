# Alpha 美術技法研究與應用

日期：2026-10-02。此文記錄本次可玩 alpha 的美術選擇，不代表規劃清冊 70 項已完成。

Kenney 的開源 [City Builder](https://github.com/kenneyNL/Starter-Kit-City-Builder) 與 [3D Platformer](https://github.com/kenneyNL/Starter-Kit-3D-Platformer) 使用低面數輪廓與可辨識材質區分遊戲物件。觀察它們的模型與公開截圖，本案採用三項方法：以輪廓而非紋理噪訊區分用途；重複城市 kit 建立比例一致性；人形關節使用實際骨架動畫。

本次底模採 Kenney 官方 CC0 [Mini Characters](https://kenney.nl/assets/mini-characters)、[City Kit Commercial](https://kenney.nl/assets/city-kit-commercial)、[City Kit Roads](https://kenney.nl/assets/city-kit-roads)、[Car Kit](https://kenney.nl/assets/car-kit)、[Furniture Kit](https://kenney.nl/assets/furniture-kit)。原始網格下載後在 Blender 重工，不能以同色 cube 代替商辦或人物。自行車採 [Bicycle by Poly by Google](https://poly.pizza/m/19VoUuA2pcN)，CC BY 3.0，保留作者、來源與修改註記。

應用：外送員採藍色外套、橘色背包及亮鞋帶；警衛採藍綠制服、帽沿與胸章；受困者採暖色便服與不同頭髮輪廓。眼睛、眉毛與鼻子做成可渲染網格。建築以淡藍玻璃、暖灰結構和退縮雨遮整合，保留不同高樓的既有立面拓撲；街道配件採低飽和灰，讓角色與互動物的亮點更清楚。

光照以大面積暖日光與冷天空補光檢查輪廓。輸出透明背景角色證據、正側背視圖與 64px 縮圖，另記錄亮度、飽和度閘門結果。閘門只適用有色人物像素，不將透明背景納入平均；工程與遊戲場景的視覺驗收仍需由整合端實際檢查。

