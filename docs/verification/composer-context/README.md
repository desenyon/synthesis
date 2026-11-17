# Composer and context — 2026-11-16

Unreleased main work after `6fba482`. Native app implementation, no separate preview, no new release and no live model request. The owner's running app and database were left alone.

## Checks

- `./scripts/check.sh` — strict Swift format lint, **174 tests / 41 suites**, optimized ad-hoc native build; exit 0. Full output: [check.log](check.log).
- Regression runs observed actual failures for lost old board attachments, archived exclusions re-enabling history, wrong truncated placement totals, unreadable context preferences and lost selected-entity neighbours. The final suite passes their fixes. Red evidence: [boundaries](boundaries-red.log), [preferences](preferences-red.log), [neighbours](neighbors-red.log).
- A screenshot exposed the new draft being replaced with the placeholder at 1024×768. Composer saves now require the shared draft to match the view's last observed value. The regression and existing immediate-world-switch persistence test pass; the repeated capture retains its typed message.
- `git diff --check` passed.

## Rendering

```sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 \
SYNTHESIS_CAPTURE_STATES=conversation-home,composer-attached,light-composer-attached,composer-context,light-composer-context,composer-browser,composer-overflow,composer-expanded,conversation,conversation-loading,manual-conversation,companion,library-companion,graph-selected,timeline-companion,editor \
./scripts/verify-ui.sh /tmp/synthesis-composer-verified
uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-composer-verified
```

**32 final captures**, all inspected in [1440×900](contact-1440x900.jpg) and [1024×768](contact-1024x768.jpg) contact sheets. The full attached composer was also inspected individually; before/after Conversation images were compared at the same viewport and output size. Earlier iterations corrected fallback icons, the misleading restricted-history checkbox and attachment overflow discoverability. Final log: [capture.log](capture.log).

The previous [Conversation screenshot](conversation-before.png) is retained for comparison with the [new one](../../screenshots/conversation.png). The README also carries the [attached composer](../../screenshots/composer.png) and [context inspector](../../screenshots/composer-context.png).

## Limits

The screenshots are native background captures with isolated authored fixtures and a transport that refuses model calls. Popover content is rendered inline by the verification harness; no foreground popover, pointer/keyboard, trackpad, animation pacing or VoiceOver walkthrough occurred. Existing Canvas web code was unchanged; its Node suite was not rerun in this slice. These checks do not establish completion of the entire expansion brief or production readiness.
