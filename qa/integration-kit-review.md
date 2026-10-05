# Integration-kit source and verifier review

Date: 2026-10-05. Status: **VERIFIED for source/tool review before packaging**.

This review used an independent agent context. It examined the handoff documents, result schema, packaging tool and receiving-project source. It did not access the other host, obtain the alternate game's source, rerun gameplay suites or publish a release.

## Baseline and receiving contracts

- The frozen game baseline is `f296dbdbee6696778891b7f471665db2a8bdba24`, with 1,169 tracked files. Its tree has no forbidden package paths, traversal names or case-colliding files. The kit's later committed source snapshot is a separate identifier; the production `v0.4.0` tag must retain its existing target.
- All 64 listed entrypoints/internal methods in the ten-module [contract inventory](../docs/integration-kit/module-contracts.json) exist in the actual GDScript source. Referenced data, tests and asset-license documents exist.
- The guide correctly uses `godot/project.godot`, the scripted `SevenDistrict` scene, bounded manager/UI adapters and Godot-specific lifecycle contracts. It distinguishes life `on_foot`, activity `foot` and controller `bike` tokens.
- Save boundaries are explicit: outer `schema: 1`, world `schema_version: 1`, subsystem `version: 1`, corrupt-primary preservation, validation before restoration, and separate device preferences. Existing IDs, reward rules and activity-count constraints require migration review when changed.
- Source and asset requirements cover metre scale, axes, sockets, the 53-bone baseline and eight animation names. Code/document MIT terms remain distinct from CC0 models, CC BY 3.0 bicycle, OFL font and CC BY 4.0 sound terms.
- The historical 17 groups / 8,561 checks are labelled as existing Alpha evidence. The alternate game remains not received and not merged.

## Tool and handoff checks

[integration_kit.py](../tools/integration_kit.py) reads a committed Git archive, requires a clean working tree, compares every frozen baseline byte, and permits only handoff overlays. It preserves tracked `.gd.uid` and `.import` metadata while excluding runtime caches and private files. The ZIP index hashes every payload file, including `INTEGRATION_KIT.json`, and explicitly excludes itself; the outer ZIP has its own SHA-256 sidecar.

Independent lightweight verification passed **21 path/verifier cases**: ordinary retained source paths, traversal/absolute/private paths, credential file extensions, symlink files and directory entries in ZIPs, clean extracted-directory inventory, unindexed source rejection and case-colliding index rejection. The result schema passed the JSON Schema Draft 2020-12 structural check.

Review findings were corrected before this report: symlink ZIP directory entries are rejected before directory handling; extracted-directory verification requires the exact indexed file set; private key/credential filename exclusions were strengthened. The README now includes pinned-commit cloning and an offline Git-initialization route, explaining its different local baseline commit and patch identifiers. Verification occurs before Git initialization or Godot import adds files.

No actionable source/tool findings remain in the reviewed scope. Final archive CRC, all payload hashes, exact committed-source comparison and external ZIP SHA must be verified after committing and building. Their post-build evidence belongs in `qa/integration-kit-artifact.json`; a final ZIP hash is intentionally not embedded in this source review to avoid a self-hash cycle.
