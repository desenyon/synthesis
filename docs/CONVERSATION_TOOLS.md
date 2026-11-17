# Conversation branches and prompt recipes

Requirements: expansion #43 and #44. The final checkpoint passed 334 native tests / 81 suites, strict lint and the optimized build. Initial native captures have been inspected; corrected three-size visual acceptance remains pending after the owner's save-and-handoff request. [Exact checkpoint](verification/expansion-parallel-checkpoint/README.md).

## Explore an alternative

Use **Branch from here** on a user or assistant message. The new conversation receives the original thread through that message, inclusive, and opens for further writing. The original conversation remains unchanged. Rename and archive branches using the existing conversation controls; Archive offers Undo.

The branch header links to the original at its exact fork point. An archived original has an explicit **Restore original & open fork point** action. The conversation menu lists its direct branches. Branching again creates traceable nested lineage.

Copied messages retain their roles, completion states and source pointers. Sources resolve against the current world's records. Historical discussion remains historical discussion; the assistant's current retrieval settings and canon safeguards still apply. An authored example stays labeled as an example. Proposal approvals are not copied: review a proposal in the response that originally created it.

Branching makes no provider request and changes no lore. The creator sends a new message explicitly to continue. Manual mode permits browsing, branching, renaming and archiving without enabling AI.

## Reuse an approach

Open **Prompt recipes** from the Conversation toolbar or any composer's attachment/mode menu. Create a recipe with a name, instructions and one of the existing assistant modes. **Save draft as recipe** starts from the current unsent text. Recipes belong to the selected universe.

**Add to draft** appends instructions after the current text, including typing that has not reached its debounce save. It selects the recipe's assistant mode, but never enables AI, sends a message, changes lore access or approves canon. References and the current workspace still supply context at send time.

Search matches names, instructions and modes. Edit retains unsaved text on validation or storage failure. Concurrent edits are rejected rather than overwriting newer content. Saved edits and archive/restore operations offer version-checked Undo. Archived recipes remain available in the manager and must be restored before use.

## Persistence and portability

Migration `0017_conversation_tools.sql` adds three tables:

| Table | Purpose |
| --- | --- |
| `conversation_branches` | Child conversation, parent conversation and exact source message |
| `conversation_message_origins` | Immediate source of each copied message |
| `prompt_recipes` | World-scoped instructions, assistant mode, optimistic version and archive state |

Branch copies use new message IDs in a transaction. Source citations are copied only when their records belong to the same world. Proposal ownership is unchanged. Recipe writes validate their world, content length and mode. The domain validator rejects cyclic or inconsistent lineage and malformed recipes during import.

Conversation read positions are device-local session state. An explicit fork-point jump takes precedence over a remembered read position; new streamed text follows only while the reader remains at the end.

## Verification targets

- Core: selected-message prefix, source preservation, nested lineage, original thread and canon preservation, no duplicated proposal approval, world isolation, malformed import rejection, recipe optimistic concurrency, archive/restore and disk reopening.
- Native actions: pending composer insertion, Manual mode, no model requests, branch/open-original navigation, archive Undo and safe anchor validation.
- Captures: branch/source, recipes list/editor/empty/archive/applied, light and dark, Manual, compact window and companion composer. Captures use isolated authored examples and never fabricate a model response.

Run `./scripts/check.sh` through the coordinated verification owner. Use `./scripts/verify-ui.sh` and `scripts/contact-sheets.py` for background rendering, then inspect every contact sheet. Compilation and fixture rendering do not establish physical interaction coverage.

Initial visual review: [1440×900 native contact sheet](verification/expansion-parallel-initial/contact-1440x900.jpg) inspected for branch, original fork point, Canvas companion, recipe library, light recipe library, Manual recipe library, editor, empty/archive and applied states. Follow-up polish removes literal Markdown from lineage excerpts, keeps source navigation available in the title menu and hides Latest when the entire thread fits. These fixes pass the shared tests/build; final corrected and narrower-window captures still need inspection. No live subscription request was used.
