# 前後對照狀態

`before/` 保留 0.7.0 歷史實際算圖；本輪沒有覆寫歷史檔案。新版商店 manifest 已改為 0.8.1，不能用新版 manifest 解讀舊圖。

`after/manifest.json` 記錄 0.8.1 的實際 WebGL 畫面、遊戲狀態、PCK 雜湊、NVIDIA ANGLE D3D11 renderer、CSS 視窗及 DPR。Godot 全程 `--headless` 匯出，再以無頭 Chromium 擷取，沒有開啟可見視窗。截圖未合成或縮放；標題背景是遊戲本身使用的插畫。

包含 430×932（DPR 1／3）、390×844、1032×1376（DPR 2）、1376×1032，每組均有標題、阿遠／美晴對話、街景、證物、連結及封存。商店目錄只保留兩組指定原尺寸，其餘尺寸供回歸比較。它們是瀏覽器畫面，不是 iOS 原生實機截圖。

崩潰根因、回歸測試及仍缺少的 3D 美術，見 `docs/CODEX_RESPONSE_R4_1_FIX.md`。Logo 64px 衍生檢查圖位於 `docs/evidence/r4-1/`，不屬商店截圖。
