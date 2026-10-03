# Alpha 0.3 人物資產驗證

狀態：VERIFIED。Blender 5.2.0 LTS 已建立六款人類比例角色，來源／匯出契約檢查 192 項通過、0 項失敗。root 已實際看過最終阿遠臉部與美晴正、側面，接受這批作為成人比例 Alpha 美術。

阿遠與予安已統一原作角色名，沒有改寫遊戲台詞。原 hero、guard、civilian 舊檔案保留；新的模型檔使用 `_human` key。

| 角色 | 身高 | 三角面 | GLB KiB | 頭身比 |
| --- | --- | --- | --- | --- |
| 阿遠 | 1.78m | 8,042 | 687.0 | 7.47 |
| 園區保全 | 1.80m | 8,257 | 683.1 | 7.47 |
| 市民 | 1.68m | 8,015 | 667.7 | 7.67 |
| 美晴 | 1.69m | 8,046 | 667.2 | 7.67 |
| 予安 | 1.75m | 8,047 | 684.7 | 7.47 |
| 周成 | 1.77m | 7,858 | 666.6 | 7.33 |

六個 GLB 共 3.96 MiB；每角 53 bones、1 skinned mesh、6 材質 primitives。128×128 紋理完整嵌入 GLB，Blender 同時保留打包圖片與相對路徑。

驗證包含：成人公尺比例與腳底、53 根解剖骨骼、右手 bone／tool／hip sockets、八種源動畫的骨骼通道和姿態變化、drive 膝蓋確實彎曲、attack 時工具 socket 跟手、GLB 動畫名稱、面數／檔案／材質預算、所有 primitives 的 UV、嵌入紋理、bone-target 動畫，以及真正重匯入 GLB 後的 skeleton／尺度／socket。

每個角色的 `idle/walk/run/attack/hit/drive/pedal/knockdown` 均為真骨骼動畫。死亡姿態使用 Root 骨骼下降與骨盆轉動；跑步、踩踏與座姿由肩肘膝骨骼控制。

[六人造型接觸表](art/v03-human/character-lineup.png)、[正側背與臉部](art/v03-human/human-turnarounds.png)、[阿遠八種姿態](art/v03-human/hero-actions.png)、[機器 manifest](art/v03-human/manifest.json)、[192 項結果及動作座標](art/v03-human/validation.json)。

[CC0 資料來源與授權](../assets/provenance/v03-human-assets.md) 及 [固定 upstream 版本／SHA-256](../assets/provenance/v03-human-sources.json) 已保留；原始 mesh、morph、rig、weights 都是 MakeHuman Community 官方資料。自有建置工具沒有複製 upstream 程式邏輯。

重建：`blender --background --python tools/blender/build_human_characters.py`。驗證：`blender --background --python tools/blender/verify_human_characters.py`。接觸表：`python tools/blender/make_human_contact_sheets.py`。

限制：這是低面數的成人比例遊戲人物，皮膚紋理和衣料仍屬簡化 PBR，不是照片級掃描；沒有臉部表情系統、指尖 IK 或衣料物理。固定座姿要由 root 在實際汽車與自行車上再次檢查握把、座位和腳踏接觸。網頁匯入、實際載具與遊戲整合由 root 驗證。
