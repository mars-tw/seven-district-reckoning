"""Write the closeout only from the final on-disk evidence."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))
def main():
 audit=read('docs/evidence/r9-art/artifact-verification.json');perf=read('docs/evidence/r9-art/performance.json');budget=read('docs/evidence/r9-art/export-budget.json');art=read('assets/art/r9/manifest.json')
 runs=perf['runs'];phone=next(x for x in runs if x['pixels']==[390,844]);desktop=next(x for x in runs if x['pixels']==[1366,768])
 tests=audit['tests'];height=audit['subject_height_css_px']
 report=f'''# 美術第六輪交付（repo R9）

2026-10-18，main，版本 **0.13.0**。基準 95d73c0／0.12.0。依 ART_RESCORE5_MUSE 的唯一五項清單執行，並優先收尾 RESCORE4 持續點名的街區人物與去原型化。美術修整為 EXECUTED，來源、原尺寸畫面與回歸證據為 VERIFIED；整體出貨仍為 **BLOCKED**。獨立 8 分以上尚未重評，不自行填分。

## 五項驗收與原尺寸畫面

| 項目 | 改後結果及邊界 | 1290×2796／2064×2752 原尺寸路徑 |
|---|---|---|
| 1．檢視頁滿版 | VERIFIED：同張紙底延伸到頁腳，返回鍵落在連續紙面內。上下黑底合計 24 CSS px；兩個商店視口約 2.58%／1.74%，均低於高度 10%。文件與返回命中區仍不重疊，既有紅圈、黃線與文字安全區守門保留。568×320 也可完整顯示。 | `docs/store/screenshots/1290x2796-message-inspection.png`、`docs/store/screenshots/1290x2796-receipt-inspection.png`；`docs/store/screenshots/2064x2752-message-inspection.png`、`docs/store/screenshots/2064x2752-receipt-inspection.png`。 |
| 2．立繪下緣 | VERIFIED：新美晴腰上圖保留原身份，阿遠用原圖腰上裁切；移除淡出 shader，硬邊裁切與不透明對話標頭相接。沒有透明大腿、穿插腳踏車或無腳懸空。 | `docs/store/screenshots/1290x2796-dialogue-meiqing.png`、`docs/store/screenshots/2064x2752-dialogue-meiqing.png`；阿遠為同目錄 `1290x2796-dialogue.png`、`2064x2752-dialogue.png`。 |
| 3．美晴識別 | EXECUTED／畫面自審：實際骨架模型補不對稱短髮、曲面紅圍裙、黃抹布，idle 彎肘持扳手；調整鏡位與少量視覺比例，保留原交談點及任務判定。扳手軸向檢查抓住並修正朝下遮在主角背後的問題。390 寬投影參考高度為美晴 {height['mei_height_px']:.1f}px、阿遠 {height['hero_height_px']:.1f}px，均超過 40px。腳下接觸陰影保留。遮掉標記的實際裁圖另存 QA，尚非真人盲測或獨立重評。 | `docs/store/screenshots/1290x2796-street.png`、`docs/store/screenshots/2064x2752-street.png`；`docs/evidence/r9-art/mei-without-marker.png`、`docs/evidence/r9-art/mei-64px.png`。 |
| 4．資訊／操作外型 | VERIFIED：戶名、時間、金額改為左欄名、右側值及細分隔線，資料本身沒有米色按鈕底；右側獨立「比對」分頁才可操作，保留焦點、按壓、三種選證及錯誤回饋。568×320 採三欄純文字資料加獨立操作，所有命中區 ≥44px，沒有捲到下方才能比對。 | `docs/store/screenshots/1290x2796-link.png`、`docs/store/screenshots/2064x2752-link.png`。 |
| 5．車店去原型化 | EXECUTED／畫面自審：工作台真實工具及掛鉤加厚，減少無意義小眼孔面數；補家具接觸陰影。包袋改低彩度舊帆布、布褶、翻蓋與連續胸背帶。R8 屋簷、電線、招牌實景光、暖光天空及低彩度機車沿用，均在真 3D 中呈現。縮圖可見車店招牌、拿工具的紅圍裙人物與到店主角；五官、手部及部分遠景仍簡化，未宣稱全街達寫實完成度。 | 同上兩張 `*-street.png`；`docs/evidence/r9-art/street-list-thumbnail.png`；三個實際轉向為 `docs/art/compare/r9-after/390x844-street-angle-1.png`～`-3.png`。 |

封存動作沿用並重拍：`docs/store/screenshots/1290x2796-seal-action.png`、`2064x2752-seal-action.png`。各有 50／130／320ms 三幀，在 `docs/art/compare/r9-after/*-seal-controlled-*.png`。由真實瀏覽器時鐘步進並暫停 Godot 畫面，沒有注入解題狀態或合成圖像；320ms 可見木柄印章。完成頁另有 `*-sealed.png`，不以靜態結果冒充動作。

## 新美術、包體及授權

新增 **1 張生成母圖、2 張 UI runtime 圖（含 1 張如實標示的舊圖裁切）、3 組修整 GLB／Blender 原檔**。實際圖片工具 **image_gen.imagegen**，工具沒有揭露模型 slug，manifest 記 null；不推定為特定 gpt-image 型號。標題背景、Logo、App 圖提案、圖示與乾淨紙沿用，不在五項清單外為湊數重畫。共用前綴、完整 prompt、參考圖雜湊與後製在 `assets/art/r9/`、`docs/art/PROMPTS.json` round9。

透明素材保留工具的真 alpha，清理透明 RGB、裁切與 LANCZOS 縮圖後壓縮 PNG；母圖無損 WebP。UI 圖共 {art['runtime_bytes']:,} bytes，解碼 RGBA {art['decoded_rgba_bytes']:,} bytes，兩張 alpha 可見人物的亮度／飽和度雙閘均實測通過。3D 匯出的 11 張內嵌材質衍生圖及其 import recipe 一併保留，修正乾淨匯入時只留 recipe、缺少 PNG 的問題。未虛構 normal／ORM。實際 Godot 逐角色遮罩雙閘仍缺。

新 GLB：美晴 7,867、阿遠 9,402、工作台 18,320 三角形，三組合計 35,589；舊三組合計 44,928，約少 20.8%。人物材質批次有增加，不能把局部面數降低當成整個場景 GPU 成本降低 20.8%。每人八個真骨架 clip 保留，背景 Blender 5.2 來源與 GLB 16 項讀回檢查通過。正側背實際來源渲染在 `docs/art/character-sheets/r9/`；身份金標沿用 R7 三視圖與表情表。授權及原第三方出處在 CREDITS 全數保留。

Web PCK 為 **{budget['pck_bytes']:,} bytes**，較 0.12.0 增 **{budget['increase_bytes']:,} bytes（{budget['increase_percent']:.2f}%）**。沒有製作 IPA／APK。隔離包排除已替代歷史圖片及初始未追蹤草稿，原檔未刪除。

## 效能必修：尚未過關

歷史 R8 手機／桌機三跑 p95 中位為 **33.3／33.4ms**；本輪改前重新跑同一 0.12.0 PCK，為 **16.7／50.1ms**。定稿為 **{phone['p95_median']:.1f}／{desktop['p95_median']:.1f}ms**。門檻為 ≤18ms；效能狀態 **{perf['status']}**。不把手機一項通過寫成整體通過。

量測方法：同一 headless Chromium、指定四個 GPU 旗標、實際 NVIDIA ANGLE D3D11 WebGL；390×844／DPR1 手機 profile 與 1366×768／DPR1 桌機 profile，走實際開場，等待完整世界準備後採三跑、每跑 180 個 RAF 間隔，取每跑 p95 的中位。各跑原值及 Godot 主迴圈／物理時間、draw calls、primitives 在 `docs/evidence/r9-art/performance.json` 與捕圖 manifest。TIME_PROCESS 是引擎主迴圈時間，不能稱為純腳本 CPU 時間。這是**並發載量測，僅供參考**，不是實際手機或原生 GPU timer。

調查已核對新舊面數、材質批次、貼圖預算、陰影與後處理設定。原 profile 的解析度比例 .70／.85／1.0、LOD、天空／街景貼圖、視距、陰影策略與後處理全部保留，沒有降低截圖品質。已快取重複日夜發光材質設定，固定時刻也不再重送相同 sky／light 值；正常日夜循環仍維持 5Hz。

本線瀏覽器與 Godot 都關閉時，共享 GPU 仍為 **96% 使用率、11,472MiB 顯存**；另一個預覽時為 97%／11,599MiB。這證明本輪受其他 GPU 負載影響，**不能單憑它斷定上一輪歷史退步的唯一原因**。未中止其他線路，沒有乾淨機況對照，因此前輪特定退步根因與桌機 ≤18ms 仍為 BLOCKED，不能宣稱效能必修已完成。詳細盤點與原始改前跑數在 `performance-investigation.json`、`docs/art/compare/r9-before/live-phone/manifest.json`、`live-desktop/manifest.json`。

## 驗證與保留

指定工具實際為 Godot 4.7 stable／5b4e0cb0f；全程 --headless 與 headless Chromium，未開編輯器或可見瀏覽器。改前 native_touch **12／12** 通過；定稿同樣通過，舊 fixture BLOCKED 未重現。

定稿完整 **{tests['suites']} 套、{tests['checks']:,} 項、0 失敗**，另含匯入／解析。新增 R9 幾何、資料列、下緣及握工具方向守門，保留所有既有測試與斷言。完整回歸先抓到 568×320 遮擋，新增測試另抓到證物紙面過高；兩者均修到原斷言通過。定稿在隔離來源跑測試與匯出，受保護的 export_presets 與 touch_controls 採 HEAD 版，不依賴他人未提交修補。測試指紋與 PCK 在 `artifact-verification.json` 對齊。

改前 `docs/art/compare/r9-before/`，改後 `docs/art/compare/r9-after/`；兩種商店原尺寸共 **20 張**。十視口涵蓋窄手機、直橫、iPad 直橫、矮桌機與 1920×1080，每個走完對話、尋人、查證、返回、連結、封存及三次重開案卷。商店圖是原尺寸 Web 畫面，沒有縮圖放大、拼貼或用插畫取代 3D 街區。

初始 {audit['protected_files_unchanged']} 個工作檔雜湊維持一致；.gitignore、export_presets.cfg、touch_controls.gd、qa、native 與 workflow 未改未提交，初始未追蹤檔未刪。秘密掃描涵蓋 Git index 文字檔，零命中。版本更新只針對現行專案、Web shell 與 README；歷史證據、素材來源版本及他人原生設定保留。只本機繁中 commit，未 push、部署、操作商店、發訊息或外部派工。

**Apple 4.3 風險：中。** 案卷查證與黃昏台灣車店有專屬識別，仍缺獨立 8 分重評、桌機效能過關及原生實機。3D 臉、手部與部分遠景尚簡化；逐項缺件見 `docs/art/R9_MISSING_3D.md`。交付的 VERIFIED 是來源與證據核對，並非美術 8 分或商店通過。

繁中依 speak-human-tw mode 2 直接校對。本輪可見新增文字為「比對」；戶名、金額、時間、原說詞及推論全部保留。報告更正：「預設黃昏是靜態」／實際預設日夜循環會前進／「固定時刻才略過相同更新，正常循環維持 5Hz」。
'''
 (ROOT/'docs/CODEX_RESPONSE_R9_ART.md').write_text(report,encoding='utf8')
 print('VERIFIED report written from final evidence')
if __name__=='__main__':main()
