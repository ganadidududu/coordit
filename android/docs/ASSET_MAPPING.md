# Native asset provenance

Source: coordit/coordit/Assets.xcassets at bd1f931. Artwork only, never entire UI screenshots. PNGs are in drawable-nodpi: Compose gives them the original design dimensions. SVGs are rasterized transparently at 4× viewBox size with @resvg/resvg-js 2.6.2, retaining SVG filter nodes. Original SVG content is not altered except explicit viewport width/height replacing percentage dimensions. Reproduce with `npm install --prefix tools` then `node tools/render-assets.cjs`.

| Source | Android resource | Pixel dimensions | Source SHA256 prefix |
|---|---|---|---|
| CoorditClosetFitBottom.imageset/closet-fit-bottom.svg | `coordit_closet_fit_bottom` | 500 × 992 (4× viewBox) | `48a7fc7f05af9402` |
| CoorditClosetFitTop.imageset/closet-fit-top.svg | `coordit_closet_fit_top` | 500 × 992 (4× viewBox) | `48a7fc7f05af9402` |
| CoorditFitDetail.imageset/fit-detail.svg | `coordit_fit_detail` | 500 × 992 (4× viewBox) | `f732421def3a602c` |
| CoorditFitLower.imageset/fit-lower.svg | `coordit_fit_lower` | 500 × 1032 (4× viewBox) | `f6083ea1d54d5eb2` |
| CoorditFitLowerLineMask.imageset/fit-lower-line-mask.svg | `coordit_fit_lower_line_mask` | 500 × 1032 (4× viewBox) | `4505f73f97bae993` |
| CoorditFitUpper.imageset/fit-upper.svg | `coordit_fit_upper` | 500 × 1032 (4× viewBox) | `86ed7f8dff0308ac` |
| CoorditFitUpperLineMask.imageset/fit-upper-line-mask.svg | `coordit_fit_upper_line_mask` | 500 × 1032 (4× viewBox) | `c08fd5fc218fb86f` |
| CoorditLoadingMannequin.imageset/loading-mannequin.svg | `coordit_loading_mannequin` | 204 × 382 (4× viewBox) | `6976a956d65a41ec` |
| CoorditLoadingOrbit.imageset/loading-orbit.svg | `coordit_loading_orbit` | 323 × 249 (4× viewBox) | `e467af4a8b8bdaa1` |
| CoorditMypageAccount.imageset/mypage-account.svg | `coordit_mypage_account` | 80 × 80 (4× viewBox) | `2518b5d2a73e68e6` |
| CoorditMypageBody.imageset/mypage-body.svg | `coordit_mypage_body` | 80 × 80 (4× viewBox) | `cf1b447dbddd5fed` |
| CoorditMypageNotifications.imageset/mypage-notifications.svg | `coordit_mypage_notifications` | 80 × 80 (4× viewBox) | `e126e8fcf606e360` |
| CoorditMypagePrivacy.imageset/mypage-privacy.svg | `coordit_mypage_privacy` | 80 × 80 (4× viewBox) | `ed9e2c05fa514765` |
| CoorditMypageSettings.imageset/mypage-settings.svg | `coordit_mypage_settings` | 80 × 80 (4× viewBox) | `708a0715cf2bc8ed` |
| CoorditMypageTitle.imageset/mypage-title.svg | `coordit_mypage_title` | 56 × 50 (4× viewBox) | `855c287cace485e4` |
| CoorditRechargePlay.imageset/recharge-play.svg | `coordit_recharge_play` | 80 × 80 (4× viewBox) | `59deeec7e1a210aa` |
| CoorditSplashReference.imageset/splash-reference.png | `coordit_splash_reference` | 402 × 874 (original) | `a85d4e7f2d2de11a` |
| CoorditStars.imageset/stars.svg | `coordit_stars` | 432 × 80 (4× viewBox) | `a5de6eadba5d2b61` |
| CoorditYarn.imageset/yarn.svg | `coordit_yarn` | 216 × 216 (4× viewBox) | `dd25c0dff6141206` |
| FigmaLogoO1.imageset/o1.svg | `figma_logo_o1` | 74 × 60 (4× viewBox) | `354fb72b71317bf0` |
| FigmaLogoO2.imageset/o2.svg | `figma_logo_o2` | 74 × 60 (4× viewBox) | `131b00a80d4642a4` |
| FigmaTabCloset.imageset/closet.svg | `figma_tab_closet` | 78 × 77 (4× viewBox) | `55ba8e2c81dfc7e9` |
| FigmaTabFit.imageset/fit.svg | `figma_tab_fit` | 78 × 61 (4× viewBox) | `a8ef45cbb0488e4d` |
| FigmaTabHome.imageset/home.svg | `figma_tab_home` | 80 × 80 (4× viewBox) | `33b3785d49f91353` |
| FigmaTopMy.imageset/my.svg | `figma_top_my` | 120 × 120 (4× viewBox) | `387890531e7ad897` |
| FigmaTopSun.imageset/sun.svg | `figma_top_sun` | 124 × 124 (4× viewBox) | `5f4ce74758f4ad86` |

Fonts are byte-for-byte copies: GmarketSansLight.otf → gmarket_sans_light.otf, GmarketSansMedium.otf → gmarket_sans_medium.otf, GmarketSansBold.otf → gmarket_sans_bold.otf, Mona12TextHK.otf → mona12_text_hk.otf, ClimateCrisisKRVF.ttf → climate_crisis_kr.ttf. Named Climate instances use actual YEAR values 2012 (2010), 2019 (2019), 2028 (2030). Android glyph rasterization and baselines still require device comparison.

Liquid Glass limitation: native Foundation capsule geometry, tint, stroke, and selected pill are implemented. Apple refraction/backdrop sampling has no identical Android renderer; current translucent surfaces do not claim equivalent glass rendering.
