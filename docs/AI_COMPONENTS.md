# Assistant activity components

Synthesis chat is SwiftUI. `Sources/SynthesisUI/AIActivity.swift` is the native adaptation of Kokonut UI AI Loading and the supplied AI Tool Calls behavior. It uses the app’s Inter typography, Phosphor icons, theme and reduced-motion setting.

## Import

Executed against a temporary React staging project, not the native application root:

```sh
npx --yes shadcn@latest add https://kokonutui.com/r/ai-loading.json --yes --cwd /tmp/synthesis-kokonut-import
```

The registry created `src/components/kokonutui/ai-loading.tsx` (v2.0.0). Its MIT notice is preserved in `THIRD_PARTY.md`. Native production code excludes demo playback and timer-driven invented steps.

## Native usage

```swift
AIActivityView(steps: studio.activity, t: studio.t)
```

`AgentEngine.submit(onActivity:onDelta:)` emits stable IDs for actual local retrieval (`lore`), the subscription request (`response`), and validation/staging (`review`). Replace an existing step with the same ID rather than appending duplicates. End timestamps exist only for observed completions. These are application operations, not claims about hidden model reasoning or harness tool calls.

The live list folds after completed steps. Saved answers retain their actual lore references through `message_context`, with navigable source rows and an icon stack. Historical replies do not claim a duration. Manual mode emits no steps and makes no provider request. Switching worlds or cancelling invalidates the UI callback.

`UnifiedComposer` is shared by Conversation, Canvas, Library, Graph, Timeline, Atlas, Review and entity editors. Keep attachments, mentions, draft persistence and stop behavior there rather than introducing workspace-specific text boxes.
