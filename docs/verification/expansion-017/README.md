# Expansion #17 — independent scrolling

The existing sidebar, native document editor and contextual inspector already use separate scroll regions. This item adds a repeatable rendered-app audit rather than replacing working layout code.

`ScrollAudit.swift` locates the three real NSScrollViews in the isolated capture window. It scrolls each separately, asserts the other two offsets stay unchanged, and asserts all three workspace frames stay fixed. Fixtures contain 80 paragraphs, 24 related entities and 24 conversations. Each capture starts from the same zero offsets, then leaves only its named region scrolled. An initial sequential run exposed the correctly retained document viewport from #16; the audit now resets its isolated fixture before testing movement.

`./scripts/check.sh` passed: strict lint, **204 tests / 52 suites**, optimized ad-hoc build. Captured `scroll-regions,scroll-regions-document,scroll-regions-inspector,scroll-regions-sidebar,light-scroll-regions-inspector,manual-scroll-regions-document` at 1440×900 and 1024×768: **36 scroll assertions and 12 captures**, both contact sheets inspected. Toolbar, document tabs, title/format controls, sidebar actions/footer and composer stay in place. Scrolling one content region leaves the others unchanged.

Verification uses actual native clip-view movement without activation or injected input. It establishes layout and scroll independence, not physical trackpad feel or VoiceOver. No user data, provider requests, release or restart of the owner's app. The initial one-state probe is retained separately.
