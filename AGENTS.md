# COORDIT workspace instructions

## iOS Simulator workflow

- Use SimSlim (`simslim`) for iOS Simulator discovery, boot, shutdown, cloning, and slimming.
- Before building or running on a simulator, run `simslim list --json`, then apply `config/simslim/coordit-dev.json` with `simslim on <udid> --profile config/simslim/coordit-dev.json`.
- Verify the applied profile with `simslim verify <udid> --profile config/simslim/coordit-dev.json`.
- Before testing authentication, purchases, links, or photo import, run `simslim doctor <udid> --requires push,storekit,universal-links,keychain-sync,photos`.
- Use `xcodebuild` or Xcode tooling for compilation, installation, launch, UI automation, and logs after SimSlim has prepared the simulator.
- Do not run `simslim erase`, `simslim delete`, or `simslim disk-clean` without explicit user authorization.

## AR development branch

- On `codex/camera-auto-guides`, follow `docs/AR_DEVELOPMENT_BRANCH.md`. This branch develops AR capture, measurement landmarks, related ML/data tooling, and their tests.
- Keep the normal app's release camera/AR/AI flags disabled as on `main`; use the explicit Debug field-test entry points for research.
- Bring unrelated product/release fixes in from `main` instead of developing them here. Preserve published history; do not force-push it.
- Preserve ignored local datasets, annotations, checkpoints, and credentials. Never clean `ml/artifacts/` or interrupt training as part of branch synchronization.
- Phase 3 single-RGB estimation and additional paid Vision API calls remain out of scope unless the user explicitly changes those instructions.
