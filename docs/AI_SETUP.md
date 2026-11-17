# Connecting the assistant

The assistant is optional. Every manual tool works without it, and nothing is sent anywhere until you send a message in AI Assisted mode.

Open Settings (⌘,) → Assistant and choose how Synthesis reaches a model.

## Claude Code or Codex — your subscription (default)

If Claude Code or Codex is installed and signed in on this Mac, Synthesis uses it. No API key is involved and Synthesis never sees your sign-in; it belongs to the harness.

- **Codex** (recommended): install it, run `codex login` and sign in with your ChatGPT subscription.
- **Claude Code**: install it, run `claude` in Terminal once and sign in with your Claude subscription.

"Check sign-in" asks the harness for its own status and sends no message. Choosing a provider does not start a status check or a model request. Expand **Model & connection details** for the optional Model field, which passes a model name to the harness (`sonnet`, `opus`, `haiku` for Claude Code); leave it empty to use your default.

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

Only HOME, USER, LOGNAME, TMPDIR, locale and CODEX_HOME are retained from the environment; PATH is built from known executable locations. API keys, prompt overrides and unrelated agent/editor/session variables are not inherited. Codex additionally disables memories, external memory import, skill search and web search, skips host skill discovery and sets project document bytes to zero. Subscription authentication stays with the CLI, never in model context. Administrator-managed CLI policies remain outside Synthesis's control.

## Subscription authentication only

Direct API configuration and transport are removed. A saved preference for the retired API provider migrates to Codex; a valid existing subscription provider selection is preserved. Old Keychain entries are not read or deleted.

Before every generation, the native adapter checks subscription sign-in. Claude must report `authMethod: claude.ai`; Codex must report ChatGPT sign-in. API-only authentication is refused. Status checks time out after 8 seconds; generation processes after 180 seconds. Stop or Manual terminates the process; process exit is awaited asynchronously so it cannot block the UI executor.

## What is sent

The composer always states who receives a message. Every submission snapshots the current workspace (for example Timeline or Atlas), without sending background requests on navigation. A request contains your message, the recent conversation, and up to 16 records from the selected world chosen for relevance; the transcript shows exactly which ones under "Read N records from your world". A bounded world index also includes up to 100 record identities, 100 relationships, 60 events, and 24 boards with up to 80 placements each. Selected Canvas records are included in retrieval. The index excludes image bytes, archived records and other worlds. The transcript records the retrieved source list; the additional world-index snapshot is not yet retained as a separate trace.

Modes (Create, Develop, Critique, Simulate, Canonize) are instructions, not permissions. The model cannot accept canon. When it proposes changes they are staged for your review and become drafts only when you accept them.

Stop cancels the request and, for a harness, terminates its process. Switching to Manual does the same and blocks new requests in the core. A request already received by a provider cannot be recalled.

## What has been verified

One live request through each harness on 2026-11-13 (`SYNTHESIS_LIVE_HARNESS=claude-code|codex ./scripts/test.sh --filter LiveHarnessTests`): both answered from world context with record citations and returned a change set that was staged and not applied. The default test suite uses stand-in executables and scripted answers, so it spends no subscription usage. The subscription-only changes on 2026-11-15 were tested with stand-in executables, not a new live call. The historical live result does not certify the new CLI flags. The 0.0.1 flags were checked against installed CLI help/features and stand-in executable tests, not a new live model call.

## Reviewable operations

The supported contract is create/revise record, relate entities, add event, create canvas, place/move a linked card, place/move a marker on an existing map, link records, and add a draft rule. The native layer validates world membership, dependencies and coordinates before staging. Acceptance rejects stale revisions and archived source records. Rules appear in the entity details inspector and remain manually editable. Every operation needs an explicit UI review; canon needs its separate approval. This is single-shot retrieval and proposal execution, not unrestricted autonomous control over every tool.

## Generating an illustration (explicit, Codex only)

Canvas (**Add → illustration**) and Atlas (**Sample illustrations…** / **Choose an illustration…**) open the illustration library, which now has **Generate with Codex**. Type a description and press **Generate image**. That one press makes one Codex request with your ChatGPT subscription; nothing else triggers it, chat keeps image generation disabled, and Manual mode refuses before any request.

The request contains only your description, never world lore. It runs read-only in an empty scratch folder with shell, apps, plugins, browsing and memories disabled, and only Codex's built-in image tool enabled. Codex saves its output under `$CODEX_HOME/generated_images` (the CLI's own documented location); Synthesis imports the newest PNG, JPEG or WebP written there during the request, up to 12 MB, and adds it to the board or map where you started. Codex keeps its own copy in that folder. **Stop** cancels the request. An image is never canon.

Verification status: covered by stand-in executable tests (arguments, prompt, environment, ignoring older files, rejecting non-images). A live generation has not been run, because it uses subscription allowance and needs your go-ahead.
