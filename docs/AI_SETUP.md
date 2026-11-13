# Optional AI connection

Open Synthesis → Settings (⌘,). Enter an OpenAI API key and a model ID available to your account, then save. The key goes to macOS Keychain under the application's service identifier. The model name is a local preference. The application does not test the key by making a billable call when saving it.

Return to AI Assisted and submit a message to invoke the provider. The composer states that this sends your prompt and selected-world context to OpenAI. Choose Create, Develop, Critique, Simulate or Canonize from its menu. These are instruction modes, not autonomous permission grants. Simulations remain hypothetical and Canonize prepares text for review; the model cannot accept canon.

The adapter uses the [Responses API](https://platform.openai.com/docs/api-reference/responses), SSE text streaming and `store:false`. It includes bounded recent records and conversation history with source IDs and canon/draft labels. It is not yet an autonomous tool-calling retrieval agent. Account billing and provider retention policies still apply; `store:false` is not a promise of zero provider retention.

No key or model configured: the user message remains in local history and the app displays a connection affordance. Invalid credentials, model access, rate limits or network failures are reported honestly. Stop cancels the request; switching to Manual also invalidates its result and blocks new transport calls in the core. A request already received by the provider cannot be recalled.

Settings can remove the saved key. Never commit a key, paste it into lore, or distribute it inside a bundle. No live provider call has been made for this implementation's validation; tests use a separate injected transport that is never exposed as working AI in the product.
