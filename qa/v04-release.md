# Alpha 0.4 publication validation

Validated on 2026-10-05. Gameplay is a fictional Taiwan-inspired, single-player district; the map is not a surveyed Taichung replica.

- Complete native shipping RootScene: 41/41 distinct story/delivery routes, 321 successful actual station/UI actions, four playable cultural activities, nonzero rewards/save/retry and 32 reachable stations.
- Final import plus 17 suites: 8,561 checks passed, zero failures and no Script Error; canonical source/fixture digest `29c6c8c86b9c5a5950aac72dead196725defe8d35ccd18dd73892c27c5ef22d8`.
- Eight new character sources and real glTF round trips: 256 checks passed; 53 bones, eight clips, six material primitives each.
- All 52 primary research pages independently reread, with corrected dates and facts; authored data validation: 2,402 checks passed.
- Public HTTP export: 96 checks passed, including all four entry pages, MIME/hash/Brotli, redirects and genuine 404.
- Actual public WebGL: phone, tablet and desktop startup, 0.70/0.85/1.00 renderer scales, corresponding controls/UI, and shared same-origin saved position. See [browser observations](browser/v04/public-browser-check.json) and actual screenshots in that directory.
- Native scene profile captures record 90 frames per profile on the development RTX 2060; these and desktop viewport WebGL are not phone/tablet hardware FPS or thermal tests.
- Cloudflare deployment version: `f629e2b2-b6eb-4530-836c-cfee990818f6`. The final redeploy only refreshes the credits notice; the game payload is unchanged.

## Windows package

`deliverables/SevenDistrict-0.4.0-Windows-x64.zip` — 48,590,332 bytes, SHA-256 `a1d0110f0a277bc880395764b25eba1f75c78a7abcd9dc9609104401f3397c78`. Official Godot 4.7.2, x64 PE 0.4.0.0, embedded resources and required notices, ZIP CRC and quiet original-title startup verified. The native ZIP is not a full native manual-playthrough certificate.

## Publication gates

Generic and exact credential scans are required on the final staged tree before pushing. The GitHub source commit and Release are recorded in the final goal audit after actual publication; this file does not invent a commit or tag.
