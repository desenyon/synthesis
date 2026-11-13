# Syntehsis — native macOS design proposal

Status: design for owner review, 2026-11-12. Supersedes the initial Next.js implementation plan. Application implementation is paused at the owner's request. The spelling Syntehsis follows the latest request literally.

## Instruction reconciliation

The native macOS/GPUI requirement replaces the earlier suggested Next.js stack. The product name changes from WorldOS to Syntehsis. Canon ownership, explicit proposal approval, traceability, data preservation, world isolation and portable storage remain protected. The native equivalent of server-only provider secrets is a trusted provider subsystem with macOS Keychain storage; prompts, lore, logs and exports never contain keys. Model outputs have no approval capability.

The TypeScript scaffold and SQLite/domain tests remain in the repository as historical work; they are not the native application. Do not continue that implementation. At implementation start, update AGENTS.md's name and operational stack guidance with a narrow, recorded patch, preserving protected behavior. Mark old documents superseded. Retire obsolete scaffold files in an inspectable change without deleting user instructions or lore.

## Design direction

- Product: a personal writing workspace with structured memory for fictional universes.
- Character: exact, quiet, focused.
- World: a creator's IDE with the precision of a drafting desk.
- Moments: beautifully typeset lore and readable, meaningful connections.
- Signature: small source markers beside linked names and claims, opening exact records in context.

Pure black (#000000) writing canvas, restrained near-black chrome, off-white (#E6E9EF) text and icy-blue (#A9C7FF) selection. Draft, canon and hypothetical states always have text labels, not color alone. SF Pro for controls and headings, JetBrains Mono Nerd Font for writing and metadata, with a sans-serif reading view. No serif default. Tight 32px navigation rows, 4px spacing system, 16px icons, quiet hairlines. Avoid ornamental imagery, metrics and cards. Native titlebar controls, menus and keyboard conventions. Motion is brief and functional, honors reduced motion, and never delays typing.

Default window target: 1440×900 logical points; validate at smaller MacBook sizes. Resizable 224px navigation and 300px context pane flank a flexible document canvas. Prose stays around 65–75 characters per line. Both side panes collapse; focus mode centers the document. Document tabs, back/forward, quick open and a discreet save status support working across records. Context and Assistant share the right pane, with the contextual Assistant visible by default. Writing retains the largest share of space.

## Architecture proposal

Rust + upstream GPUI, with a pinned compatible dependency set after a build spike. Evaluate the maintained GPUI component library for input primitives; do not assume GPUI includes Zed's editor or accessibility coverage. Build the writing experience in GPUI, not a webview. Keep domain types independent of rendering.

- app: lifecycle, commands, menus, windows and workspace restoration.
- ui: design tokens, shell, writing, navigation, inspector and later graph/timeline.
- domain: worlds, records, links, revisions, canon and proposals.
- storage: SQLite, migrations, transactional writes, FTS5, backups and exports.
- agents (later): provider adapters, scoped read context, source validation and proposal staging.

SQLite is authoritative; Markdown and versioned JSON are export formats. Background persistence/search avoids blocking rendering. Record IDs survive renames. Accepted canon snapshots remain separate from editable working drafts. Review checks the version that was shown to the creator. Native app packaging uses an .app bundle; signing/notarization are separate release work.

## Phases and exit criteria

### 0 — Native foundation and editor feasibility

Set up Rust and verify Xcode/Metal toolchain; pin GPUI; launch a real window; establish typography/tokens, native menus and commands. Prove a multiline editor with selection, clipboard, IME composition, undo/redo and smooth scrolling. Check accessibility/VoiceOver capabilities explicitly. Exit: native window and editing exercised on this Mac, blockers documented before expanding.

### 1 — The writing desk (first product build)

World creation/opening, collapsible/resizable shell, page navigation, document editing, quick-capture inbox, reliable autosave, recovery, version snapshots and session restoration. Context pane shows actual metadata; assistant explains its unavailable state. Basic Markdown source editing and GPUI rendered reading view; defer complex rich blocks. Source markers and entity previews in the design become functional in Phase 2.

Exit: create a world, capture an idea, convert it to a draft, edit it, quit and relaunch, and recover the same content. Verify undo, focus/keyboard navigation, failed-save state and no cross-world data. Design review at real display sizes is part of completion.

### 2 — Structured memory and connections

Entity records, tags, aliases, stable linked mentions, backlinks, world-scoped FTS5 search and quick open. Typed relations, graph navigation and a basic source-linked timeline read the same database. No inferred relation silently becomes fact.

Exit: create and link a character, rename it without breaking links, find it by alias, follow a relation, open a graph/timeline source, and verify isolation.

### 3 — Safe assistance and canon review

Provider configuration in Keychain; explicit disclosure of external processing; all five modes; source-linked answers and bounded read tools; reviewable document/entity/relation proposals. Diff shows before/after, evidence, affected records and base versions. Only an explicit user command scoped to the proposal accepts canon. Critique/simulation remain analysis/hypotheses.

Exit: automated provider doubles verify invalid evidence, cross-world references, failed calls, stale/repeated approvals and rejection. Live calls require configured provider and deliberate user action; no paid test calls by default.

### 4 — Release hardening

Large-world responsiveness, long-document editing, crash/recovery and migration tests, keyboard/accessibility pass, native dialogs, export/backup restoration, app icon and reproducible .app packaging. Signed/notarized distribution only when owner authorizes and credentials exist.

Later: branches, rules lab, canvas, maps and richer simulation. They do not delay the daily workspace.

## Observed environment

`rustc` is not on PATH and no ~/.cargo/bin/rustc or cargo was found. xcode-select currently points to /Library/Developer/CommandLineTools. Full Xcode/Metal readiness has not been verified. No native build or UI test has run. The HTML design study is a conversation prototype, not a running GPUI application.

## Revised review concept

The owner requested a redesign following the existing instructions. `syntehsis-native-review.html` replaces the earlier visual concept for review, preserving the prior file as reference. It includes sample lore navigation, connected-record graph, capture conversion, quick open, five-mode assistant controls with no provider, and an illustrative two-step canon review. None of these preview interactions persist or call a model.

Observed design checks: headless Chrome via Playwright exercised graph/source navigation, proposal review, capture conversion, quick open and assistant prompt/mode selection. No horizontal overflow at viewport widths 1024, 736, 390 and 320. Desktop screenshot inspected. These are prototype checks, not GPUI application validation.
