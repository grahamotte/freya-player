# Freya Player migration map

This migration audited all 180 files tracked by `/Users/graham/Code/freya-player` at commit `dcb387c`. Build products, Git internals, user-specific Xcode state, credentials, `.DS_Store` files, and other ignored local files were excluded.

## Coverage totals

| Source group | Files | Disposition |
| --- | ---: | --- |
| `FreyaPlayer/**` | 128 | Moved to `apps/apple/App/**` byte-for-byte: 77 Swift files, 47 asset-catalog files, and four configuration files. |
| `FreyaPlayer.xcodeproj/**` | 2 | Project file adapted to the new source root; generated workspace shell retired. |
| `assets/**` | 27 | Moved byte-for-byte. |
| `docs/**` | 4 | Moved byte-for-byte, including `docs/privacy-policy.md`. |
| Root app files | 5 | `.gitignore` and `AGENTS.md` merged, `LICENSE` retained byte-for-byte, `README.md` workflow adapted, and `mise.toml` replaced by the foundation task graph. |
| `.agents/**` | 2 | Merged into the foundation publish workflow. |
| `releases/**` | 3 | Current metadata consolidated; historical 1.17.7 input retired. |
| `scripts/**` | 9 | Replaced by foundation build, simulation, deployment, and publishing tooling. |
| **Total** | **180** | Every tracked source file has a disposition below. |

A checksum review found no content differences in the 128 directly moved app-tree files or the 32 directly retained `assets/**`, `docs/**`, and `LICENSE` files. The normalized ten App Store screenshots are also byte-identical to their source assets. The App Store description, keywords, and 1.17.8 release notes match `releases/1.17.8.json` exactly.

## Direct moves

| Source | Destination | Disposition |
| --- | --- | --- |
| `FreyaPlayer/**/*.swift` | `apps/apple/App/**/*.swift` | All 77 Swift source files moved without changing application behavior. |
| `FreyaPlayer/Assets.xcassets/**` | `apps/apple/App/Assets.xcassets/**` | All 47 catalog files moved together so icon, top-shelf, accent, and logo references remain intact. |
| `FreyaPlayer/Config/**` | `apps/apple/App/Config/**` | All four platform plist and entitlement files moved. Code Moto's `ExportOptions.plist` remains beside them. |
| `FreyaPlayer.xcodeproj/project.pbxproj` | `apps/apple/App.xcodeproj/project.pbxproj` | Moved into the Code Moto project slot; the synchronized source root and plist paths changed from `FreyaPlayer` to `App`. The original two-target layout remains because it is required for tvOS plus the shared iOS/Mac Catalyst target. |
| `README.md` | `README.md` | Replaced the foundation placeholder and updated commands for the Code Moto workflow. |
| `assets/**` | `assets/**` | All 27 tracked logos, screenshots, sample videos, and source attribution files moved. The sample library is intentional project/reference content, not a build product. |
| `docs/**` | `docs/**` | All four source documents and images moved; the Freya privacy policy replaces the Code Moto policy while `apple-credentials.md` remains from the foundation. |

## Merges and replacements

| Source | Destination | Disposition |
| --- | --- | --- |
| `.gitignore` | `.gitignore` | Freya's `.build`, Xcode-user-state, local mise, credential, and environment exclusions were merged into Code Moto's broader ignore list. |
| `AGENTS.md` | `AGENTS.md` | Freya architecture, model, layout, playback, and platform guidance was adapted to `apps/apple/App` and merged with the foundation rules. |
| `LICENSE` | `LICENSE` | The files were byte-identical, so the existing destination copy was retained. |
| `mise.toml` | `mise.toml` | The Code Moto task graph remains authoritative. `mise simulate` replaces Freya's build/start scripts, `$publish` replaces its release tasks, and a path-correct `mise xcode` task was added. |
| `releases/base.json` | `apps/config.json` | Description and keywords were consolidated into Code Moto's single App Store configuration. |
| `releases/1.17.8.json` | `apps/config.json` | Current version and release notes were consolidated into the active configuration. |
| `releases/1.17.7.json` | none | Historical input for the retired publisher; it is not read by Code Moto and remains available in the source repository history. |
| `assets/screenshots/iOS/**` | `apps/screenshots/ios-*.png` | All four iPhone/iPad screenshots were also copied into normalized App Store paths. |
| `assets/screenshots/macOS/**` | `apps/screenshots/macos-*.png` | All three Mac Catalyst screenshots were also copied into normalized App Store paths. |
| `assets/screenshots/tvOS/**` | `apps/screenshots/tvos-*.png` | All three Apple TV screenshots were also copied into normalized App Store paths. |
| `.agents/skills/publish/SKILL.md` | `.agents/skills/publish/SKILL.md` | Replaced by Code Moto's resumable multi-target publish workflow and branded for Freya Player. |
| `.agents/skills/version-bump/SKILL.md` | `.agents/skills/publish/SKILL.md` | Its semantic-version analysis is already part of the Code Moto publish skill and `deploy:set-version` implementation. |

## Retired source-only infrastructure

| Source | Replacement or exclusion reason |
| --- | --- |
| `FreyaPlayer.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Xcode-generated single-project workspace shell; the migrated project generates it when needed. |
| `scripts/ExportOptions-AppStoreConnect.plist` | Replaced by `apps/apple/App/Config/ExportOptions.plist`. |
| `scripts/app-store-submit.rb` | Replaced by `deploy/lib/apps/app_store_connect.rb` and the deployment patch pipeline. |
| `scripts/publish.sh` | Replaced by `mise deploy:publish` and `$publish`. |
| `scripts/build-ios.sh` | Replaced by the configured iOS target used by `mise simulate` and the archive pipeline. |
| `scripts/build-macos.sh` | Replaced by the configured Mac Catalyst target used by `mise simulate` and the archive pipeline. |
| `scripts/build-tvos.sh` | Replaced by the configured tvOS target used by `mise simulate` and the archive pipeline. |
| `scripts/start.sh` | Replaced by `mise simulate iphone|ipad|macos|tv`. |
| `scripts/stop.sh` | Not transferred because the Code Moto simulator flow launches one requested target and does not own a long-running app process manager. |
| `scripts/generate-app-assets.sh` | One-off generator retired because every generated catalog output is tracked and migrated. |

## Foundation files intentionally retained

The Rails backend, React frontend/toolchain, deploy system, shared gems, Android placeholder, foundation test suites, root dependency configuration, and Code Moto maintenance skills remain in place. The template `FocusTimer` app, its test, template icons, placeholder screenshots, and `README.txt` were removed because Freya Player replaces that example application.

The source repository's ignored `.build/`, `dist/`, `.env`, `creds.txt`, `xcuserdata/`, `.DS_Store`, and Git metadata were not transferred because they are generated, secret, user-specific, or repository-local state.
