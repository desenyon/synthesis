# Native sidebar verification — 2026-11-16

Source: sidebar changes over `3d0d12e` on canonical `main`. Actual SwiftUI/AppKit windows, isolated SQLite data, no provider requests or foreground activation.

- `before-*.jpg`: six baseline captures at the same two viewport sizes.
- `before-after.png`: original-resolution crops from the baseline and final 1440×900 Graph windows, labeled with their actual widths. No simulated UI.
- `contact-1440x900.jpg`, `contact-1024x640.jpg`: 22 final states; both inspected.
- `contact-1024x520.jpg`: three minimum-height states; inspected. Navigation/history scroll while identity and utilities stay fixed.
- `readme-contact.jpg`: seven native workspaces; inspected and copied to README's PNGs.
- `capture.log`, `short-capture.log`, `pixels.log`, `check.log`: observed checks. 115 tests / 27 suites, strict lint, optimized build, 12 pixel assertions, four menu binding/action checks.

The stress world contains 1,024 real fixture records and eight saved conversations, with long world/conversation names. These are created only in the isolated capture database. Ordinary counts, active history, empty history, both disclosure states, dark/light, rail and opaque fallback were inspected. Static captures disable animations to avoid an occluded compositor retaining an old selection frame. They do not verify animation timing or live hover/focus behavior.

Foreground Tab/Space traversal, pointer/context menus, live popovers and VoiceOver were **not run**. Menu checks validate shortcut registrations and dispatch native actions; they do not send physical keystrokes. The running user application was not restarted. No changes to canon, navigation routes, schema or user data.

Reproduce:

```sh
./scripts/check.sh
SYNTHESIS_SIDEBAR_AUDIT=1 \
SYNTHESIS_CAPTURE_STATES=graph,light-graph,collapsed,sidebar-long,light-sidebar-long,sidebar-history,sidebar-folded,sidebar-opaque,light-sidebar-opaque,empty-sidebar,light-collapsed \
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x640 \
./scripts/verify-ui.sh /tmp/synthesis-sidebar
uv run --with pillow python scripts/audit-sidebar-captures.py /tmp/synthesis-sidebar
uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-sidebar
SYNTHESIS_CAPTURE_STATES=sidebar-history,sidebar-folded,collapsed \
SYNTHESIS_CAPTURE_SIZES=1024x520 ./scripts/verify-ui.sh /tmp/synthesis-sidebar-short
```
