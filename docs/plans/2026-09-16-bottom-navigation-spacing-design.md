# Bottom Navigation Spacing Design

## Goal

Move the shared Liquid Glass bottom navigation slightly away from the physical bottom edge without changing its size, visual treatment, or touch behavior.

## Considered approaches

1. Increase the component's scaled bottom padding from 10 to 18 points. This keeps layout and hit testing aligned and applies consistently everywhere the shared component is used.
2. Apply a negative vertical offset. This is visually simple but can separate the rendered position from the layout and hit-testing frame.
3. Increase the surrounding chrome or safe-area height. This has broader content-layout effects and risks changing scroll clearance across screens.

## Approved design

Use approach 1. Change only `CoorditLiquidGlassBottomNavigation` so the capsule sits 8 scaled points higher on every screen. Keep the existing `GlassEffectContainer`, capsule height, horizontal margins, materials, selection effects, and accessibility identifiers unchanged.

## Verification

- Build and run on the prepared iPhone simulator.
- Capture a fresh settled screen that includes the bottom navigation.
- Confirm the capsule is visibly separated from the bottom edge, remains centered, and does not clip or overlap page content.
- Exercise all three tab buttons and run the focused navigation UI test or closest existing flow.
