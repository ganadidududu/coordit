# Rewarded Ad Production Activation Design

## Goal

Enable Coordit's rewarded-ad flow in production without cross-app tracking. A signed-in user can open the thread charge screen, choose **광고 보고 실타래 충전하기**, finish a rewarded ad, and receive exactly one server-verified thread.

## Privacy model

- Do not request App Tracking Transparency authorization and do not use IDFA-based cross-app tracking.
- Configure Google Mobile Ads for non-personalized or more restrictive ad treatment based on the user's applicable consent state.
- Use Google's consent flow where required and do not load an ad until consent information has been refreshed.
- Disable publisher first-party identifier personalization.
- Keep App Store privacy disclosures aligned with the data the Google Mobile Ads and User Messaging Platform SDKs may collect even when ATT is not requested.

## Production data flow

1. The authenticated app requests monetization readiness from the backend.
2. The backend exposes rewarded ads only after its production configuration, reward schema, and SSV callback are ready.
3. Before loading an ad, the app refreshes consent information and selects non-personalized or limited delivery as required.
4. The app creates a one-time reward attempt on the server.
5. The rewarded ad receives that attempt identifier as SSV custom data.
6. Google calls the production SSV endpoint after a completed reward.
7. The backend verifies Google's signature, ad unit, reward item and amount, custom data, expiry, and replay constraints.
8. The backend credits one thread atomically; the app polls the server balance and updates the UI only after that credit is visible.

## Failure handling

- Keep the CTA hidden while the backend gate is closed.
- Never credit from the client-side reward callback alone.
- Invalid signatures, mismatched ad units, expired attempts, duplicate callbacks, and timeouts must not change the balance.
- A consent or ad-load failure leaves purchases usable and offers a retry path.
- If AdMob app verification is still pending, keep production rewarded ads disabled until verification succeeds.

## Verification

- Confirm the submitted binary contains Google Mobile Ads, User Messaging Platform, the production app ID, and rewarded unit ID.
- Confirm the production database has the hardened reward schema and replay protection.
- Verify the AdMob SSV URL and save the verified configuration.
- Update App Store privacy answers to match the non-ATT advertising implementation.
- Deploy the backend configuration, then verify authenticated readiness returns `rewardedAdsEnabled: true`.
- On a real device, verify CTA visibility, ad presentation, one-thread credit, duplicate-callback resistance, and no credit on failed or abandoned ads.

