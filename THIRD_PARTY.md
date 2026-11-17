# Third-party software

## Excalidraw

The Canvas workspace embeds the Excalidraw editor (`@excalidraw/excalidraw` 0.18.1, with React) as a locally bundled web component. Source: https://github.com/excalidraw/excalidraw

MIT License

Copyright (c) 2020 Excalidraw

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The bundle in `Sources/SynthesisUI/CanvasBundle` also contains Excalidraw's dependencies and its bundled fonts (Excalifont, Nunito, Virgil, Cascadia, Comic Shanns, Liberation Sans, Lilita One, Assistant) under their respective open licences; see `CanvasWeb/node_modules/*/LICENSE` after `npm install`.

## Phosphor

Native controls bundle the regular Phosphor 2.1.2 font from `@phosphor-icons/web`, under MIT. Canvas uses `@phosphor-icons/react` 2.1.10. Source: https://github.com/phosphor-icons . The font and full license are in `Sources/SynthesisUI/Assets/Icons`; `aliases.json` records semantic mappings. Updating the font requires regenerating codepoints from that version's `src/regular/style.css` and checking both renderers. No generated icons.

## Inter

Native typography bundles Inter 4.1 Regular, Medium, SemiBold and Bold under SIL Open Font License 1.1, with the full license in `Sources/SynthesisUI/Assets/Fonts/LICENSE.txt`. Source: https://github.com/rsms/inter . Canvas uses the offline `@fontsource/inter` 5.3.0 package. Fonts load from the application bundle, never a CDN. Existing user-rich-text formatting is preserved.

## Dagre

Graph auto-layout uses `@dagrejs/dagre` 3.1.3 (MIT) inside native JavaScriptCore. Only the bundled fixed script and world-scoped record IDs/dimensions are evaluated; there is no browser, network, shell, or generated code. `CanvasWeb` pins and copies the distributable into `Sources/SynthesisUI/Assets/Graph` during its build. Full Dagre and bundled Graphlib licenses are stored beside it. Source and API: https://github.com/dagrejs/dagre/wiki .

## Kokonut UI

`AIActivity.swift` adapts the AI Loading State and AI Tool Calls interactions for SwiftUI. Source: https://kokonutui.com/r/ai-loading.json and https://github.com/kokonut-labs/kokonutui . The registry component was imported with shadcn into an isolated staging project; no React/shadcn runtime was added to the native chat. Demo playback is excluded. Phosphor remains the application icon system.

MIT License

Copyright (c) 2025 kokonutUI

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
