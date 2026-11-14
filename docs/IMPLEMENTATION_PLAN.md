# Background verification and open-source graph engine — 2026-11-13

1. Replace activating captures with a never-ordered native window, prohibited activation policy, fresh temporary DB and separate temporary bundle. Failure paths must exit, never open alerts. Run all checks as a bounded background workflow; no persistent watcher.
2. Pin MIT SwiftFlow; adapt real entities/relationships to its nodes/edges. Use native custom nodes, routed edges, handles, selection, pan/zoom and layout. Keep semantic writes in WorkspaceStore with explicit labeling/review. Canvas remains manually curated; use engine layout only on explicit arrange/graph transfer.
3. Test projection/isolation, connection validation, layout transfer and background lifecycle; inspect generated native screenshots without touching the user's desktop. Document exact scope and outstanding gesture limits; commit.

Alternatives considered: Grape specializes in force visualization, Dagre in layout only, while SwiftFlow covers the requested interactive connection engine. Keep a small adapter around the pinned dependency and retain SQLite as the source of truth. No browser/UI automation during this work.

Completed: engine integration, isolated background workflow, 23 app tests, 291 upstream tests, two negative startup guards, optimized build/signature and 27 inspected hidden captures. Review: docs/verification/BACKGROUND_GRAPH_REVIEW.md. Physical gesture and large-world performance acceptance remain separate follow-up work; no foreground automation was performed.
