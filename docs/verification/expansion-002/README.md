# Expansion #2 — restrained frosted surfaces

One `FrostedSurface` uses native in-window vibrancy plus the current Theme tint. Floating toolbars, inspectors, popovers and composers share it. Reduce Transparency, Increase Contrast or the isolated opaque capture fixture select an opaque fallback. The sidebar, documents, graph cards and other ordinary content retain their existing surfaces.

`./scripts/check.sh` passed strict Swift lint, **175 tests / 42 suites** and the optimized native build. Canvas theme subscriptions were narrowed to actual palette changes; no web engine sources changed in this item.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=conversation-home,light-conversation-home,opaque-conversation,graph-selected,opaque-graph,light-opaque-graph,composer-context,light-composer-context ./scripts/verify-ui.sh docs/verification/expansion-002` produced **16 native captures**. Both contact sheets were inspected for surface contrast, overlay bounds and light/opaque fallback. Source PNGs pruned after inspection. Background captures establish rendering, not physical keyboard/popover interaction or animation timing. No provider request or restart of the owner's running app.
