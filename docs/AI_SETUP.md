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
| Tools | none (`--tools ""`), no MCP servers, no slash commands | read-only sandbox |
| Your configuration | ignored (`--safe-mode`) | ignored (`--ignore-user-config`, `--ignore-rules`; apps, plugins, browser and computer use disabled) |
| Working folder | new empty folder, removed afterwards | new empty folder, removed afterwards |
| Session | not saved (`--no-session-persistence`) | not saved (`--ephemeral`) |
| Streaming | word by word | one update when the answer is ready |

Claude Code therefore can only read what Synthesis sends and write text. Codex keeps its built-in shell inside a read-only sandbox; it is told not to use it and has an empty folder to work in, but that is an instruction and a sandbox, not the absence of the tool. Prefer Claude Code if that distinction matters to you.

Inherited `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN` and `OPENAI_API_KEY` variables are removed from the harness's environment so a stray key cannot replace your subscription sign-in.

## OpenAI API key

Choose "OpenAI API key", enter a key and a model ID, and save. The key goes to macOS Keychain; the model name is a local preference. Saving makes no request. The adapter uses the Responses API with SSE streaming and `store:false`. Account billing and provider retention policies apply.

## What is sent

The composer always states who receives a message. A request contains your message, the recent conversation, and up to 16 records from the selected world chosen for relevance; the transcript shows exactly which ones under "Read N records from your world". Records from other worlds and archived records are never included.

Modes (Create, Develop, Critique, Simulate, Canonize) are instructions, not permissions. The model cannot accept canon. When it proposes changes they are staged for your review and become drafts only when you accept them.

Stop cancels the request and, for a harness, terminates its process. Switching to Manual does the same and blocks new requests in the core. A request already received by a provider cannot be recalled.

## What has been verified

One live request through each harness on 2026-11-13 (`SYNTHESIS_LIVE_HARNESS=claude-code|codex ./scripts/test.sh --filter LiveHarnessTests`): both answered from world context with record citations and returned a change set that was staged and not applied. The default test suite uses stand-in executables and scripted answers, so it spends no subscription usage. The OpenAI API path has not been called live.
