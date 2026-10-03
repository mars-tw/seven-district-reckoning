# Alpha 0.3 人物資產來源

六款人體以 MakeHuman Community 的 hm08 真實人體拓樸為基礎，使用 MPFB 儲存庫的亞洲成年目標、成年比例目標、game-engine 骨架與權重。周成另外混合官方亞洲男性老年目標。角色不是 GTA、Mixamo 或其他商業遊戲的資產。

官方明確區分程式碼與圖像資產：所有 core assets 採 CC0，包含 base mesh、targets、rigs、weights；程式碼的 GPL 授權沒有套用到這些資料。此專案沒有複製 MPFB 或 MakeHuman 的程式邏輯。

- [MakeHuman 官方資產授權](https://static.makehumancommunity.org/about/license.html)
- [官方 MPFB 輸出與資產授權說明](https://github.com/makehumancommunity/mpfb2/blob/master/LICENSE.md)
- [CC0 法律全文](../../assets/source/makehuman/LICENSE.ASSETS.md)
- [官方來源版本、下載網址、大小與 SHA-256](v03-human-sources.json)

原始資料完整保留於 `assets/source/makehuman/`。服裝裁片、鞋楦、髮型、眼部、包袋、識別配件、128px 紋理與八種骨骼動畫為本專案重製；圖像內容採 CC0-1.0，可修改和再散布。Blender 建置／驗證程式沿用專案 MIT。

| 檔案 key | 造型 |
| --- | --- |
| hero_human | 阿遠，深藍工作夾克、斜背郵差包 |
| guard_human | 保全，深色制服、帽子、識別章 |
| civilian_human | 女性市民，陶紅上衣、長褲、及肩髮 |
| mei_human | 美晴，墨綠工作外套、工作證、短 bob |
| yuan_human | 予安，沙色連帽外套、淺色球鞋、較寬年輕臉型 |
| zhou_human | 周成，炭灰西裝、暗紅領帶、較成熟臉型 |

每款採 53 根骨骼，含手指、肩膀、手肘、膝蓋和腳掌。`hand.r`、`HandToolSocket`、`SeatHipSocket` 保留現有遊戲控制器契約。動畫名稱為 `idle`、`walk`、`run`、`attack`、`hit`、`drive`、`pedal`、`knockdown`。動畫是骨骼通道，角色移動速度由遊戲控制器負責。

這批是適合網頁的低面數、成人比例遊戲人物；沒有照片級皮膚掃描、臉部表情骨架或衣料物理。裁片採固定 skinning，精細手腳與每種車輛的接觸點仍需依實際座艙調校。

建置方式：

```text
blender --background --python tools/blender/build_human_characters.py
blender --background --python tools/blender/verify_human_characters.py
```

模型位於 `godot/assets/models/*_human.glb`；同 key 的可編輯 `.blend` 位於 `assets/source/blender/`，使用相對紋理路徑，紋理也已打包於 Blender 檔。機器 manifest、正／側／背、臉部與動作圖在 `qa/art/v03-human/`。
