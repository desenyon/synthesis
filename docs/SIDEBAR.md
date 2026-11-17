# Sidebar refinement — 2026-11-16

The creator is organizing a universe, not a filesystem. Navigation should be quiet, precise and imaginative. Graphite material provides continuity; the selected world's artwork supplies personality. Workspace selection is a restrained slate surface. History and ordinary counts remain secondary to destinations and the world identity.

## Composition and scope

- Expanded width 284pt; compact rail 72pt. The existing compact-window navigation behavior stays intact.
- Fixed native header and identity/actions, one scrolling middle, persistent utility footer.
- 16pt outer inset, 38pt navigation rows, 34pt history, 36pt matched actions, 24pt section headers, 17pt navigation icons, 8pt shared radius.
- Bundled Inter and Phosphor remain. Category icons are monochrome in navigation; semantic color inside content is unchanged.
- World artwork is 40pt, the name truncates, and the menu uses one dropdown indicator. New Chat and Search retain their actions and shortcuts.
- History actions always reserve their width. Active history has a quieter treatment than the selected workspace. Ordinary counts are tabular text; Review has a compact attention count.
- Appearance shows the current state. Search and appearance remain accessible in the compact rail.

`Theme.swift` defines `SidebarPalette`/`SidebarMetric`; `Components.swift` defines the shared control style and material. `Sidebar.swift` composes existing Studio actions. No routes, canon rules, database schema or content behavior change.

## Material and accessibility

An explicitly themed `NSVisualEffectView` samples behind the window beneath an 88% opaque graphite tint. Reduce Transparency and Increase Contrast use the opaque token. The material covers the header and body continuously. Actual macOS window buttons remain native; inactive background screenshots show gray controls.

Hover/selection transitions last 150ms and honor Reduce Motion. Keyboard focus uses a stable 2pt outline, without resizing the control. Native buttons keep their activation semantics. Menus expose expanded/collapsed values; section disclosures rotate a fixed-size chevron. All icon-only controls have names and tooltips.

## Verification

Evidence and exact checks are recorded in [the verification ledger](verification/sidebar/README.md), STATE and PROGRESS: 25 sidebar captures and seven README screens inspected, 12 pixel checks, four menu registration/action checks, and 115 tests in 27 suites passing. The isolated capture runner supports long names, 1,024 real fixture records, eight persisted conversations, folded groups and opaque surfaces. These fixtures are never loaded into normal user databases. `SYNTHESIS_SIDEBAR_AUDIT=1` validates shortcut registrations and dispatches the native menu actions in the non-key verification window; it does not represent a foreground pointer/trackpad or VoiceOver walkthrough.

Design refinement used the Unslop workflow by [Damir Sokolovsky](https://heydamir.design/unslop), licensed CC BY 4.0, adapted to the owner's native-sidebar brief.
