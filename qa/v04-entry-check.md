# Alpha 0.4 device entry / static package checks

Status: VERIFIED for this bounded entry/build lane. This report does not claim final deployment, browser rendering, complete gameplay or physical phone/tablet performance.

## Owned changes

- `tools/prepare_web_assets.mjs`: real project version; four independent root/phone/tablet/desktop launch documents; absolute shared `/game` executable, `/game.pck` and load-size keys; rooted engine/icon/CSS/JS resources; actual content hashes; canonical links, profile defaults, titles and instructions; redirects, Brotli packaging and retained license copies. An export with mismatched binary sizes or wrong engine paths is rejected before publishing.
- `tools/verify_web.mjs`: every public asset checked by byte hash and required MIME; decoded WASM magic and compression headers; distinct HTML/profile/defaults/configuration; canonical redirects and proper missing-resource 404. HTML returned as WASM, JavaScript or PCK cannot pass. Optional manifest argument permits isolated candidate verification without overwriting the final build report.
- `tools/serve_web.py`: correct `.wasm.br` MIME; only the real successful `/game.wasm` response gets Brotli encoding; actual directory and canonical alias handling with query preservation; missing nested assets remain unencoded HTML 404.
- `web/shell.html`, `web/play-site.js`, `web/play-site.css`: retain the earlier device lane, add generated entry metadata/hints and current Alpha 0.4 cultural-life copy. The actual DPR remains `window.sevenDistrictDevice.pixel_ratio`, while `pixel_ratio_cap` is its upper bound. Fixed commands remain whitelisted; no general runtime actions or eval interface.
- `tests/device_web.mjs`: preserve the original 54 contracts and add 45 genuine cross-component/entry/asset-rejection contracts.
- `README.md`, `CHANGELOG.md`, `docs/newv04-device-entry.md`: explain current source scope, distinct entry use and limits; explicitly mark final public integration/deployment pending. Historical Alpha 0.3 evidence stays labeled as historical.

## Executed verification

1. `node tests/device_web.mjs`: **99 checks, 0 failures**.
   - Existing hardware classification, manual/auto preference isolation, safe padding, fixed backend commands and pause behavior remain covered.
   - Device JSON and browser caps agree; actual DPR 1.00/1.25/2.00/3.00 uses the correct clamped canvas allocation.
   - Generated auto/phone/tablet/desktop documents have different profile defaults, content, canonical links and mode selection while passing the same root Engine API configuration.
   - Explicit URL override and generated metadata work; relative engine paths, stale JS hash, wrong profile/version/package sizes, malformed config and invalid engine/negative-size exports are rejected.
   - Even a matching body hash does not permit an HTML fallback, wrong binary MIME or missing WASM encoding to pass.
2. `node --check` for `web/play-site.js`, `tools/prepare_web_assets.mjs` and `tools/verify_web.mjs`: PASS.
3. `python -m py_compile tools/serve_web.py`: PASS.
4. Actual official Godot 4.7.2 Web release export of the current 0.4 project to ignored `qa/local/v04-entry-smoke/`: exit 0. No final production directory or public build manifest was overwritten.
5. Prepared that export with the new helper and served it through the actual Python HTTP server. `node tools/verify_web.mjs http://127.0.0.1:8794 qa/local/v04-entry-smoke-http.json qa/local/v04-entry-smoke-manifest.json`: **96 HTTP checks, 0 failures**.
   - Four real entry pages; 37 file manifest, excluding deployment metadata from public byte requests.
   - Shared PCK: **10,846,996 bytes** at this candidate snapshot.
   - WASM: **39,514,754 decoded bytes**, **8,041,529 transfer bytes**.
   - Eight redirect aliases resolved to canonical entries; four unknown/nested asset routes returned actual HTML 404 with no misleading Brotli encoding.
   - The temporary HTTP server was stopped after verification. Candidate package/manifests/results remain in the ignored local QA area; they are not release artifacts.
6. `git diff --check` on owned tracked changes: PASS. Repository line-ending conversion warnings are not whitespace failures.

The current source is still under main gameplay/activity integration. These candidate byte sizes and hashes are evidence for entry/network behavior at this snapshot, not guarantees about the final package. Re-export and verify the frozen final source before deployment.

## Root handoff contract

Expected paths are `/`, `/phone/`, `/tablet/` and `/desktop/`. Aliases without a slash redirect; all Engine fetches stay at the origin root. `game.html` and `index.html` canonicalize to `/`. The final Worker continues to handle only `/game.wasm`; other routes use static assets.

Browser initialization publishes frozen snapshots only. Root reads `sevenDistrictDevice.pixel_ratio` for UI scale and `requested_profile`, `device_hint` and `pointer_touch` for manager initialization. Fixed callback commands are `profile_auto`, `profile_phone`, `profile_tablet`, `profile_desktop`, and `jobs` in addition to the earlier menu/control whitelist. Root state reports `device_profile`; that state updates shell layout after a real mode change.

Final steps remain with root: freeze/export; actual rendered and input verification at phone/tablet portrait and landscape plus desktop; real world/cargo/story/activity checks; save and device-preference isolation; source/license/secret review; public deployment and repeat HTTP verification of all four entries. Then update pending deployment prose and add genuine 0.4 browser evidence. No deploy, commit, push, credentials access or browser UI was performed by this lane.

## 繁中文案 mode 2 摘要

直接套用常駐授權，未增加確認流程。主要變動如下：

| 原句 | 原因 | 改成什麼 |
| --- | --- | --- |
| Alpha 0.3 加入人體比例的角色、商辦街景、補給與街區挑戰 | 舊版介紹無法說明本輪生活內容 | Alpha 0.4 擴建 800 公尺街區，加入餐點、便利商店、包裹與街坊故事，另保留虛構／模擬界線。 |
| 建議使用電腦與滑鼠 | 專用手機／平板入口需要自己的出發說明 | 依目前模式顯示搖桿、觸控鍵或鍵盤滑鼠提示。 |
| Alpha 0.3 已上線 | 本輪不能借舊版部署宣稱 0.4 已公開 | README／CHANGELOG 明確標記候選 source 與最後部署待驗。 |
| 骑樓／放大画面 | 繁簡混用 | 騎樓／放大畫面。 |
| 较遠／該装置／右侧／切换／選单／脚本 | 新文件的繁簡混用 | 較遠／該裝置／右側／切換／選單／腳本。 |

保留歷史檢查數字、授權、網址及既有主線設定；沒有把 viewport 或 mock 測試說成實際手機驗收。
