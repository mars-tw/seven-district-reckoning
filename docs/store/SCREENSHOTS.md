# 真實遊戲截圖清單

**R4／0.8.0 狀態：BLOCKED。下列 PNG 仍為歷史 0.7.0，不能作為新美術版截圖。** 本輪限定純 Godot headless，實測 dummy renderer 不提供像素；沒有開啟瀏覽器或可見視窗。保留舊圖與原 manifest，詳見 `screenshots/R4_STATUS.json`。

目的地：`docs/store/screenshots/`。只寫檔，沒有上傳。這些是 Godot 4.7.2 正式 Web 匯出在無頭 Chromium 的實際畫面，沒有合成標語、後製、生成圖片或縮放圖片；**不是 iOS／iPadOS 實機截圖**。送審前應以同版簽章成品取代或核對。

| 編號／檔名尾碼 | 真實遊戲畫面 | 一句說明 |
|---|---|---|
| 1 `title.png` | 街區背景、斷鏈標誌、留證開場與開始按鈕 | 從一則客服說詞，開始阿遠的調查。 |
| 2 `street.png` | 出生點、阿遠、美晴車店導引、實際觸控鍵 | 步行到車店，找美晴核對收據。 |
| 3 `evidence.png` | 甲客服訊息、乙轉帳收據、三句待核對說詞 | 公司專戶的保證，和收據對得上嗎？ |
| 4 `link.png` | 已選說詞與可連結的收據紀錄 | 選出能直接指出矛盾的那項證物。 |
| 5 `sealed.png` | 已封存案卷、有限度的推論、返回街區 | 說清楚證據能支持什麼，再繼續斷鏈。 |

每張各準備兩個尺寸：

- `1290x2796-*.png`：430×932 CSS 視口，瀏覽器 deviceScaleFactor 3，實際 PNG 1290×2796。
- `2064x2752-*.png`：1032×1376 CSS 視口，deviceScaleFactor 2，實際 PNG 2064×2752。

`manifest.json` 記錄 PNG SHA-256、PCK SHA-256、版本、實際遊戲階段、從開場到車店／封存的操作秒數、瀏覽器錯誤與外部請求阻擋。最終截圖以 `--lifecycle off` 擷取；跨程序讀回由原生 suite 驗證。另一次 Web 生命週期探測的手機讀回通過，平板在等待外圍建置時 240 秒逾時，見 `docs/evidence/r3-store/web-lifecycle-probe.json`，不能算平板 Web 重開通過。操作使用真實 W／E／Enter 輸入、原有公開選單命令和實際物理移動，沒有瞬移、改寫存檔或透過 JavaScript 設定案卷完成狀態。

重現：`node tools/r3_store_evidence.mjs --web-dir <本機匯出目錄> --playwright-module <已安裝模組> --chromium-executable <已安裝 Chromium>`。工具固定 `headless:true`，只提供 localhost 靜態檔，阻擋其他來源請求。`--matrix small --output <本機證據目錄>` 可擷取手機直橫與矮桌機補充畫面。

數字一律為「並發載量測，僅供參考」。操作秒數不是真人 beta 完成率，也不是 GPU／手機效能；WebGL 使用 SwiftShader 軟體算圖。
