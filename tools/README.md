# Development tools

## Fit Score v1.4 playground

Open [fit-score-tester.html](fit-score-tester.html) directly in a browser. The
page includes its own scripts and styles; no installation or server is needed
for sample calculations and fallback reports.

This is a historical v1.4 playground, not the production v2 engine. See the
[current engine documentation](../docs/fit-engine/FIT_ENGINE.md) and
[backend implementation](../backend/src/modules/fit/) for current behavior.

The optional Ollama report button calls the URL configured on the page and
requires a separately running Ollama server. Local calculations do not require
that service.
