# Expansion #11 — reversible navigation

Back/Forward and the connected-record breadcrumb trail use real world-scoped addresses. Native View menu shortcuts are ⌘[ / ⌘]; right-click the arrows to jump in history. Successful visits are bounded to 100; repeated locations and failed saves leave the stacks intact. Navigating after Back clears the forward branch. Replay opens current records, skips archived destinations, surfaces database failures and never resurrects or copies lore.

Checks: `./scripts/check.sh` passed strict lint, **188 tests / 47 suites**, optimized build. Four navigation tests exercise the three-record journey, save failure, current-source resolution, archive/foreign rejection, world return, boards/maps/conversations, Manual mode, duplicate visits and bounds. The hover lifecycle test now also covers inactive-window cleanup in an unwindowed host.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=history-trail,history-back,history-map,manual-history-trail,light-history-trail,collapsed-history-trail,conversation-home,graph,timeline,canvas ./scripts/verify-ui.sh docs/verification/expansion-011`: **20 captures** inspected in contact-sheet rows. After correcting Atlas title compression and inactive hover feedback, repeated `history-back,history-map` at both sizes into `refined/`: **4** captures, both sheets inspected. PNGs pruned after sheets were built.

The first attempted capture rejected unregistered fixture names; this was fixed and verification rerun. No foreground key/pointer events, animation-pacing claim or model calls. History is in-memory for this item; full restart/session restoration remains #33. The owner's working app was not restarted.
