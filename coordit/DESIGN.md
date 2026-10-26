# iOS tutorial and example flows

Use the existing `CoorditTypography`, `CoorditResponsiveMetrics`,
`CoorditClosetColors`, `CoorditFitLabPalette`, form cards, and
`CoorditContentActionButtonStyle`. This change introduces no visual tokens.

- Present link, size-chart photo, and manual entry as equal choices. Attach the
  method guide to the whole choice group, never to the link button alone.
- Keep guidance active for the selected method, then rejoin the shared result
  flow. Do not require a real product URL to learn the flow.
- Offer an explicit secondary "예시 링크로 체험하기" action. Never replace an
  entered URL without the user's action.
- Mark example inputs and results as examples. Example data stays local, never
  changes the real wardrobe/history, and never consumes threads.
- Reuse the real size review, reference selection, and result components.
- Keep help inside the content scroll view. Never dim the surrounding screen or
  move the scroll position automatically when a guide step or result changes.
- Explain the real analysis prerequisite immediately above the example action,
  after the three input choices: register a
  well-fitting garment in Closet and select it as a compatible reference.
  Provide an entry to reference management and explain the sample exception.
- Render the example notice once within each screen's scrollable content.
- Use the existing 44-point minimum action height, multiline Korean copy,
  semantic accessibility identifiers, and scrollable content. Respect the
  app's existing color and reduced-motion policies.

Verify all three source choices and both example flows on iOS Simulator,
including leaving the example and returning to ordinary input.
