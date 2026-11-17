# Expansion #15 — semantic graph zoom

Graph nodes reveal progressively richer content: titles below 55%, category/summary/state at 55–95%, and actual profile artwork plus relationship labels at 95% and above. Overview relationships remain readable through edge hover or the selected entity's relationship list. Selection emphasizes connected nodes; double-click/open, connection ports, inspection and copying still use real records.

Node world positions remain stable across zoom. Visible card bounds also drive edge routing and offscreen culling. A world-scoped artwork-ID query avoids loading all image payloads; visible detailed cards decode at most 192px thumbnails off the main actor, with a 32MB/100-entry revision cache. No schema or data mutation.

`./scripts/check.sh`: strict lint, **200 tests / 51 suites**, optimized ad-hoc build. New tests cover semantic port geometry and obstacle routing, bounded thumbnail decoding/corrupt input, and artwork revision/archive/world isolation. Existing focal-point and zoom-limit tests passed.

Captured eight states at 1440×900 and 1024×768: `graph-zoom-overview,graph-zoom-summary,graph-zoom-detail,light-graph-zoom-overview,light-graph-zoom-detail,manual-graph-zoom-detail,graph-selected,graph`. Initial captures exposed inactive-window edge hover; after fixing it, all **16 refined captures** were inspected in six contact-sheet rows. The narrow selected overview also exposed colliding labels: detailed edge labels now disclose by zoom/hover, while selection shows the complete relationship list. Both selected sizes were recaptured and inspected in `selection/`. README keeps the detailed graph capture.

These are background rendering and state/geometry checks. Physical trackpad feel, edge-click hit testing and VoiceOver were not reverified. No live provider call, release or restart of the owner's app.
