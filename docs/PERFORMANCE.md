# Performance measurements

Measured 2026-11-16 on the development Mac (Apple Silicon), debug test build, in-memory SQLite. These are single local runs, not guarantees; the tests that print them keep generous bounds so the suite stays reliable.

| Path | Size | Time | Test |
| --- | --- | --- | --- |
| Load all records | 2,000 records | 12 ms | `ScaleTests` |
| Review → Checks (all eight rules) | 2,000 records, 600 entities, 1,500 relationships, 300 events | 94 ms | `ScaleTests` |
| Indexed search | 20 queries over 2,000 records | 22–30 ms total | `ScaleTests`, `SearchScaleTests` |
| Relationships + events read | 1,500 + 300 | 7 ms | `ScaleTests` |
| Graph layout (bundled Dagre in JavaScriptCore) | 100 entities / 200 relationships | 52 ms | `GraphScaleTests` |
| Graph layout | 300 entities / 600 relationships | 127 ms | `GraphScaleTests` |
| Canvas connection routing with obstacle detours | 600 connections, 300 cards | 8 ms | `CanvasWeb/tests/scale.test.ts` |

`GraphScaleTests` also lays out a four-node chain and checks it runs left to right, proving the timings come from Dagre and not the grid fallback.

Not measured: Excalidraw rendering and hit-testing of a 300-card board inside WebKit, SwiftUI drawing of a 300-node Graph, and memory use. Those need a foreground session with Instruments.
