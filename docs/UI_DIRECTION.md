# Current UI study — canvas-first

The owner rejected the prior editorial light interface. The current review target is the **running native window**, implemented in `CanvasDesign.swift` and `DesignSurface.swift`. It is an interactive UI study; no AI generation or new backend modules are part of this pass.

## Reference mapping

- Latest image 1: deep slate/graphite surfaces, restrained blue-green atmosphere, fine dividing lines, compact sans-serif hierarchy.
- Latest image 2: infinite dotted canvas, floating compact node cards, modular left panel, small controls and quiet connection lines. Business/developer content is replaced by worldbuilding modules.
- Latest image 3: compact sidebar grouping, restrained selected rows, an open conversation surface and a composer with a separate context strip.
- Zeron's new-chat reference: floating multiline composer above character artwork, with controls contained inside it. Its artwork, branding and product copy are not copied.

## Implemented visual contract

48-point integrated header, no separate macOS title bar or fake traffic lights. 224-point module panel collapses to a 56-point rail. Graphite default; corresponding light variant keeps identical geometry. UI text is system sans-serif, generally 10–14 points; no oversized serif welcome. Cards use 10-point corners, panels 10–13, composer 17. Fine neutral borders, subdued cyan accent, no purple gradients.

The sidebar contains World, Systems and Stories modules, including Power Systems and Universal History. Custom modules can be added locally. The center is a pannable/zoomable canvas; a guided composer floats above it. Conversation is a full central workspace mode. Clicking a working fragment opens a temporary editor; it is closed by default.

## Interaction scope

Starter cards are creation actions, not fake world facts. Guided creation uses authored questions, explicitly not model replies. Answers become local working fragments. Each module has a five-step sequence; custom modules receive an appropriate general sequence. Notes, module selection, fragment editing, search, sidebar collapse, chat visibility, composer expansion, theme switching and canvas movement are real UI interactions.

This study does **not** write its fragments into lore or canon. The composer labels that boundary. Local review state resets when the process closes. Existing SQLite data and the previously implemented application modules remain preserved in source. Broader functional integration resumes after the interface direction is accepted.

## Performance work

The composer owns its draft state locally; keystrokes do not publish through the application store or write SQLite. Canvas pan/zoom has a separate view model. Card dragging updates a local offset and commits layout on release. ASCII art is generated at build time and decoded once; thousands of text glyphs are not redrawn during typing. Use the optimized build for review. Motion uses short 120–200ms transitions and respects macOS Reduce Motion; no continuous background animation.

An observed optimized process was idle at 0.0% CPU with approximately 136 MB RSS during one inspection. This is a point sample, not a frame-rate guarantee. Screenshot PNG encoding time is not interaction latency.
