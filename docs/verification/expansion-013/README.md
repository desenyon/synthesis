# Expansion #13 — connected welcome dashboard

An optional Dashboard opens from navigation, View, quick-open or the saved startup preference. It shows recently edited entities, unfinished documents/ideas, pending proposals, active project outlines and latest saved object activity. Entries open current records, maps, graph/history inspectors or the proposal in Review. The compact assistant follows Dashboard context; Manual mode has all local tools without generation.

Projects are actual draft entities in the Projects category. They support writing, sections, links, revisions, archive and portable exports. Later full narrative-project requirements remain open. The activity query returns latest saved states per object, explicitly labelled, not a complete event log.

`./scripts/check.sh`: strict lint, **196 tests / 50 suites**, optimized ad-hoc build. Four new tests cover scoped activity, archived sources, canon/proposal status, bounded queries, disk reopening and project archive round-trip, source links, failed-save guards, Manual mode and startup persistence. Initial compilation/test-macro and lint errors were corrected before this passing run.

Captured `dashboard,light-dashboard,manual-dashboard,dashboard-empty,dashboard-project,dashboard-new-project,dashboard-review,dashboard-long,dashboard-activity,light-dashboard-activity` at **1440×900 and 1024×768** with `verify-ui.sh`. Initial desktop inspection revealed offscreen activity beside unused space. Activity now shares the right column. Repeated the same 20 captures into `refined/`, built contact sheets and inspected every final state in eight row crops. Smaller windows stack and scroll; long titles truncate; proposal review and project editing show real sources. README retains the final 1440px dashboard. PNGs pruned after sheets.

No live model call, foreground event automation, animation-pacing claim, release or restart of the owner's app. Canon and pending proposals remain unchanged by dashboard navigation.
