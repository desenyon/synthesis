# Connecting the assistant

The assistant is optional. Every manual tool works without it, and nothing is sent anywhere until you send a message in AI Assisted mode.

Open Settings (⌘,) → Assistant and choose how Synthesis reaches a model.

## Claude Code or Codex — your subscription (default)

If Claude Code or Codex is installed and signed in on this Mac, Synthesis uses it. No API key is involved and Synthesis never sees your sign-in; it belongs to the harness.

- **Claude Code** (recommended when installed): install it, run `claude` in Terminal once and sign in with your Claude subscription.
- **Codex**: install it, run `codex login` and sign in with your ChatGPT subscription.

"Check sign-in" asks the harness for its own status and sends no message. The optional Model field passes a model name to the harness (`sonnet`, `opus`, `haiku` for Claude Code); leave it empty to use your default.

How each message is run:

| | Claude Code | Codex |
| - | - | - |
| Command | `claude -p` (headless) | `codex exec` |
| Tools | none (`--tools ""`), no MCP servers, no slash commands | read-only sandbox, shell tool disabled |
| Your configuration | ignored (`--safe-mode`) | ignored (`--ignore-user-config`, `--ignore-rules`; shell tool, apps, plugins, browser and computer use disabled) |
| Working folder | new empty folder, removed afterwards | new empty folder, removed afterwards |
| Session | not saved (`--no-session-persistence`) | not saved (`--ephemeral`) |
| Streaming | word by word | one update when the answer is ready |

Neither adapter gives the model a project checkout or application write tools. Model output is interpreted as validated domain proposals, not shell commands. Unsupported CLI versions fail visibly; Synthesis does not fall back to an API key.

Inherited `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN` and `OPENAI_API_KEY` variables are removed from the harness's environment so a stray key cannot replace your subscription sign-in.

## Subscription authentication only

Direct API configuration and transport are removed. A saved preference for the retired API provider migrates to an installed subscription harness, or Claude Code if neither is installed. Old Keychain entries are not read or deleted.

Before every generation, the native adapter checks subscription sign-in. Claude must report `authMethod: claude.ai`; Codex must report ChatGPT sign-in. API-only authentication is refused. Status checks time out after 8 seconds; generation processes after 180 seconds. Stop or Manual terminates the process; process exit is awaited asynchronously so it cannot block the UI executor.

## What is sent

The composer always states who receives a message. A request contains your message, the recent conversation, and up to 16 records from the selected world chosen for relevance; the transcript shows exactly which ones under "Read N records from your world". A bounded world index also includes up to 100 record identities, 100 relationships, 60 events, and 24 boards with up to 80 placements each. Selected Canvas records are included in retrieval. The index excludes image bytes, archived records and other worlds. The transcript records the retrieved source list; the additional world-index snapshot is not yet retained as a separate trace.

Modes (Create, Develop, Critique, Simulate, Canonize) are instructions, not permissions. The model cannot accept canon. When it proposes changes they are staged for your review and become drafts only when you accept them.

Stop cancels the request and, for a harness, terminates its process. Switching to Manual does the same and blocks new requests in the core. A request already received by a provider cannot be recalled.

## What has been verified

One live request through each harness on 2026-11-13 (`SYNTHESIS_LIVE_HARNESS=claude-code|codex ./scripts/test.sh --filter LiveHarnessTests`): both answered from world context with record citations and returned a change set that was staged and not applied. The default test suite uses stand-in executables and scripted answers, so it spends no subscription usage. The subscription-only changes on 2026-11-15 were tested with stand-in executables, not a new live call. The historical live result does not certify the new CLI flags.

## Reviewable operations

The supported contract is create/revise record, relate entities, add event, create canvas, place/move a linked card, place/move a marker on an existing map, link records, and add a draft rule. The native layer validates world membership, dependencies and coordinates before staging. Acceptance rejects stale revisions and archived source records. Rules appear in the entity details inspector and remain manually editable. Every operation needs an explicit UI review; canon needs its separate approval. This is single-shot retrieval and proposal execution, not unrestricted autonomous control over every tool.
