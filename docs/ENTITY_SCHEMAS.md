# Entity types, properties and templates

Expansion requirements 61–66 share one additive model. Existing record categories and prose are preserved; creating or assigning a structured type is optional. No provider call is involved.

## Creator workflow

- Open an entity, then **Properties**. **Manage types** defines a named world-owned type and its fields. The same manager is available in **New record → Entity**.
- A type may inherit from another type in the same universe. A child can override a field or its default without changing its parent. An entity can override a default; **Use inherited value** removes that override. **Unknown** is an explicit value, distinct from inheriting.
- Fields support text, finite numbers, yes/no, authored world dates, numeric ranges, durations with creator-defined units, single or multiple choices, single or multiple entity links, coordinates with creator-defined units, PNG/JPEG references, and computed numeric formulas. An image is embedded in portable exports, never uploaded by this feature.
- Conditional visibility compares another field with a typed value. Multi-value lists support an explicit empty value and preserve archived references. Hidden values remain stored and recover when their condition applies; **Show conditional fields** makes them inspectable.
- **Save as template** preserves starting prose and property overrides. Templates can also be authored in the manager. New entities receive independent draft copies. Changing a template does not rewrite entities already created from it.
- **Review properties for canon** shows a frozen value snapshot. Explicit acceptance preserves that snapshot separately from the record's accepted writing. Later defaults, schema edits and entity edits produce property drafts; they cannot change accepted property canon. A changed profile or inherited schema invalidates an open review.
- Property history restores a new draft. Type and template editors can load a previous version before saving. Archiving types/templates preserves existing entities and supports restore/Undo.

## Data and limits

Migration `0016_entity_schemas.sql` adds `entity_types`, `entity_profiles`, `entity_profile_history`, `entity_type_history`, `entity_templates`, `entity_template_history`, and a disposable property FTS index. All durable rows are world-owned. Archive format 10 and JSON schema 13 include the new durable tables; old archives import with empty schema tables. Imports remap nested entity references, reject foreign references and invalid schemas atomically, and rebuild the search index.

Schemas support up to 100 fields, 1000 types per world and 16 inheritance generations. Keys are stable lowercase identifiers. Incompatible field deletion/type changes are rejected if they would invalidate saved overrides, defaults or templates. Image references are valid PNG/JPEG files up to 6 MB and 8192 pixels per side; one property set is bounded to 24 MB. World archive size limits still apply.

World dates preserve authored text and uncertainty; they do not imply Earth-calendar precision. Ranges and coordinates use finite numbers. Formulas accept field keys, numeric literals, arithmetic, parentheses, `min`, `max`, `abs`, `round`, `floor`, and `ceil`. They cannot execute code, access files, call providers or inspect other worlds. Dependencies are cycle-checked and memoized. Missing inputs and arithmetic errors remain unknown with a local explanation.

Structured values are searchable through Library/global search and eligible assistant retrieval. Only already permitted record context is serialized for the assistant; excluded linked entities are redacted and image bytes are omitted. Working values and accepted property snapshots have separate context budgets. New schema/property approval methods are not exposed as model tools; model-authored type/typed-field proposals are not implemented. The existing image export includes current schema/template/property media and frozen accepted images, deduplicated with covers, artwork and board images. It preserves valid PNG bytes and converts other raster input with explicit failure reporting. Markdown includes readable working and accepted properties; JSON and `.synthesis` archives retain full schemas, media and histories.

## Verification scope

New tests cover persistence/reopen, all field kinds, inheritance, condition retention, explicit/stale canon review, draft restore, foreign-world rejection, formula grammar/cycles/dense dependencies, template copies and history, archive remapping/rollback/old-format compatibility, search and context restrictions. Native isolated capture fixtures cover empty/filled/inherited/conditional profiles, property review/history, type management, templates and every editable field kind in dark/light/manual states. The parent run records actual executed checks and inspected contact sheets in `docs/STATE.md` and `docs/PROGRESS.md`; source/fixtures alone are not verification.

The saved checkpoint passed 334 native tests / 81 suites, strict lint and the optimized build, including historical malformed-import and image-export regressions. All 26 schema capture states remain prepared but uninspected at the owner's freeze. #61–66 stay In progress until final native visual verification. [Exact errors, checks and continuation](verification/expansion-parallel-checkpoint/README.md).
