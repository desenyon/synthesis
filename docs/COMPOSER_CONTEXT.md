# World assistant composer and context

First implementation slice of the owner's 394-item expansion brief. Keep the native app, existing navigation, subscription harness, data and canon boundary. No new release is requested.

The supplied reference guides the shared composer: quiet World assistant heading, roomy expanding input, removable context chips, Explore/Propose choice, Canon protected disclosure and World context inspection. Full Conversation, companion and compact workspace bars share the same persisted state. Do not copy the reference's illustrative badge or hardcoded lore.

## Refinement direction

Product: a conversational worldbuilding workspace for an individual creator.
Character: quiet, deliberate and tactile, using the app's existing typography and palette.
Material: a graphite writing surface with restrained borders and consistent control geometry.
Emphasis: the creator's words and real lore references, followed by Send or Stop.
Signature: inspectable world context, with creation controls grouped in one adaptive toolbar.

The 2026-11-17 refinement uses 16pt bundled Inter for both placeholder and typed text, one 32pt toolbar, 8pt reference/control corners and a quieter 20pt outer surface. Attach, assistant preset and Explore/Propose sit together; World context and Send sit at the other end. Narrow companions condense labels without dropping actions. Canon protected remains an actionable explanation below the field, beside the provider disclosure and the saved send-shortcut hint. Ordinary line growth is immediate; expansion and control feedback respect Reduce Motion.

## Behavior contract

- Attach real records, maps, boards and history branches/periods by stable world-scoped IDs. Text/Markdown import and inline mentions remain available.
- World context selects relevant lore; Attachments only limits retrieval to attached or selected records and records represented on attached boards/history. Explicit exclusions win over all automatic sources. Context size bounds full record excerpts, not subscription cost or model reasoning.
- Preview locally, with no model call: source names/reasons/excerpts, structured workspace data, truncation limits and whether prior messages are included. The send path uses the same builder and revalidates against current data.
- Restricted context omits prior conversation messages to avoid reintroducing excluded lore. The request also filters inline Synthesis links whose sources are excluded. The app keeps the original draft and transcript. Ordinary prose typed by the creator travels as written.
- Explore produces prose only; any model proposal block is discarded with an explanatory notice. Propose retains validated, reviewable draft operations. Neither can alter canon.
- Context choices persist per world and survive workspace switches/restart. Manual remains enforced at the core boundary. Tests use stand-in transports; no new live subscription request is authorized.

## Use it

1. Open Conversation or any workspace companion. The compact bar opens the same conversation; the expand control gives the full composer more writing space.
2. Choose **+ → Attach lore, map, Canvas or history**. Search the real records or switch tabs. Chips remain attached to this world until removed; `@` still inserts an inline reference. Maps/boards attach their linked lore and metadata, not their images.
3. Open **World context**. Choose **Attachments only** for a restricted request, or retain World context to retrieve related sections and neighbours. Inspect source reasons, exact excerpts and the structured index. Exclude a record here or in the attachment browser; **Include** restores its eligibility.
4. Choose **Explore** for discussion without staging edits. Choose **Propose** for validated draft operations that appear in Review. Create/Develop/Critique/Simulate/Canonize still control the assistant's approach; they cannot override Explore or canon approval.
5. Send explicitly. Return/Shift-Return follows the existing shortcut preference; Stop cancels the active request. Navigation and context previews make no provider calls.

In Propose mode, “Create three competing coastal factions and connect them to the Tidekeepers” can return a single batch with three draft entities and their relationships. The review identifies which new record each relationship needs. Accept a prerequisite before its dependent change, or review and accept the batch in sequence. Dismissing a prerequisite leaves dependent changes pending for review. Accepting only creates drafts.

The default remains Propose with World context for compatibility with existing conversations. Context preferences belong to this device/world and are not exported as lore. Archiving excluded records preserves their exclusion and the restriction on earlier chat history. If saved context preferences become unreadable, access falls back to Explore/Attachments-only with workspace selection and history off; choose new settings explicitly to broaden it.

Excerpt limits are 8/16/32 records. The same size applies to the combined count of record chips and distinct inline references. Different links to the same record count once. Exceeding the limit blocks Send with an actionable error. The workspace index includes bounded identities and structured metadata. Board/history membership may exceed the excerpt limit, so inspect board placement totals and preview counts for partial coverage. Filtering cannot remove lore repeated in allowed prose.

## Verification

The 2026-11-17 refinement passed `./scripts/check.sh`: **175 tests / 42 suites**, strict lint and optimized build. The new native layout regression preserves the caret and intentional scrolling while clearing stale offsets after a growing composer reveals every line. **40 final background captures** at two sizes were inspected, including multiline drafts, unavailable provider, two-row companion attachments and light theme. Attachment wrapping and first-line clipping were found visually, corrected and recaptured. [Current evidence](verification/composer-polish/README.md).

The initial 2026-11-16 implementation passed `./scripts/check.sh` with **174 tests in 41 suites**, strict lint and optimized build. Its regressions cover exclusions, attachments-only scope, board/history membership and index limits, archive/foreign IDs, disk persistence, preview/send parity, Explore enforcement, selected entity neighbours and stale draft writes. Existing Manual/canon/Propose coverage remains green.

**32 final background native captures** were inspected at 1440×900 and 1024×768, including dark/light, full/compact/companion, attachments, context inspection, overflow and expanded writing. A missing icon, misleading history checkbox and stale-draft overwrite found during iteration were corrected and recaptured. [Evidence](verification/composer-context/README.md). No live model call, foreground interaction or animation/VoiceOver claim; capture-only popover content uses the same native panel without activating a real popover.

## Next expansion phases

1. Shared world foundations: typed attributes/facts, provenance, temporal validity and validated commands.
2. Conversation operations and context, then adaptive entity editing and contextual inspectors.
3. Unified temporal projections across Graph, Atlas, Timeline and conversation.
4. Queryable Graph and richer live Canvas components; geographic layers and chronology dependencies.
5. Explicit rule-driven simulations with separate reproducible state.
6. Three-way branch merging, extensible modules and later collaboration/publishing.

The brief's hosted API credentials do not supersede the protected subscription-only direction. New simulations, multiplayer, arbitrary executable UI and a global palette overhaul are not implied by this first slice. Preserve the accepted sidebar while implementing its composer reference.

Operation feedback follows actual app events: elapsed waiting, context preparation, response reception and proposal validation. Failed activity stays visible; it never changes to a success label. Simulate explicitly describes hypothetical AI exploration. Review reports the named change set and actual committed count, including partial failure; remaining decisions stay pending.
