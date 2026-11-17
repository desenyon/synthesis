# Workspace sessions

Synthesis remembers the working context of each universe on this Mac. Under Settings → General, choose **Last workspace** to reopen that context at launch. Choosing another startup workspace keeps the saved document tabs available while opening the chosen home.

A session retains open and pinned documents, their subpages, both editor panes, text selection and scroll position, conversation position, the newest unsent message, Graph arrangement and framing, Timeline view/branch/folds, Atlas framing/layers/selection, Canvas selection and saved viewport, Library filters, and optional inspectors. Focus mode is temporary and does not return at launch. Native text Undo does not cross a process restart; revision history remains available.

Changing universes checkpoints the outgoing context and restores the destination universe's context. Removed or archived addresses are discarded individually. Unreadable session preferences are preserved before replacement. Manual mode remains authoritative: session restoration never enables AI or resumes a model request.

Sessions contain local presentation addresses, not copies of lore or canon. They are excluded from world archives. Editors and the Canvas still use their normal persistence paths; a failed save prevents closing the window. A short debounce persists ordinary view changes, while navigation and closing create explicit checkpoints.

Expansion #33 remains In progress for final visual acceptance. The checkpoint passed 334 native tests / 81 suites, strict lint and optimized build. `./scripts/verify-session.sh` then ran two separate executions of that final binary and restored the exact saved state without a window or model request. Initial native root/Canvas reconstruction captures passed; corrected three-size inspection remains pending. [Evidence and resume command](verification/expansion-parallel-checkpoint/README.md).
