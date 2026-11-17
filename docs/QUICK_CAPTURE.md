# Quick capture

While Synthesis is running, press **Control–Option–Space** from any app to open the native capture panel. The same command is in **File → Quick Capture…** and Search and Commands. No Accessibility permission or background helper is required. If another application owns the shortcut, the panel reports that it is unavailable; the menu and palette still work.

Write a fragment, paragraph or idea. Return inserts a new line; **Command–Return** saves it to the chosen universe's Library as an **idea**. It does not become canon, invoke an assistant, open an editor or change the main workspace. The first line becomes its title. **Escape** and the native close button dismiss the panel while keeping the scratch draft.

The panel initially selects the active universe. Its universe picker changes only the capture destination. Each universe has a separate draft; switching the picker flushes the old draft before loading the next. Drafts are kept locally after a short typing pause and synchronously before dismissal, destination changes and normal application termination. Failed writes leave the text and panel available for retry. Unsaved drafts are excluded from portable world exports.

Saving the record, recording its retry identity and clearing its scratch draft happen in one database transaction. Retry identity includes a local digest of the submitted content, so identical retries return the existing record while divergent edits survive independently. A late retry cannot clear a newer draft. Captures use the existing record, search, revision and activity systems. They carry `kind: capture`, `category: Ideas`, `state: idea`, `origin: user-authored` and no canonical content.

The panel uses the app's typeface, appearance and controls. Its native nonactivating window receives typing without bringing Synthesis's main window to the front. It is resizable from 420 to 920 points wide. The shortcut operates only while the application runs; it is not installed by automated capture or test processes.

## Verification

Implementation and acceptance evidence are tracked in [the #34 verification record](verification/expansion-034/README.md). Background rendering and model-level tests do not establish physical shortcut delivery, switching between real applications, VoiceOver behavior or subjective typing feel.
