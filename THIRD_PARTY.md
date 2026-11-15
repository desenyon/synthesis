# Third-party software

## Excalidraw

The Canvas workspace embeds the Excalidraw editor (`@excalidraw/excalidraw` 0.18.1, with React) as a locally bundled web component. Source: https://github.com/excalidraw/excalidraw

MIT License

Copyright (c) 2020 Excalidraw

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The bundle in `Sources/SynthesisUI/CanvasBundle` also contains Excalidraw's dependencies and its bundled fonts (Excalifont, Nunito, Virgil, Cascadia, Comic Shanns, Liberation Sans, Lilita One, Assistant) under their respective open licences; see `CanvasWeb/node_modules/*/LICENSE` after `npm install`.

## Lucide 1.73.0

Authored native UI uses the upstream `lucide-static` icon font, bundled at `Sources/SynthesisUI/Assets/Icons/lucide.ttf`. The associated ISC license is in `Assets/Icons/LICENSE`; semantic aliases are in `aliases.json` and `StudioIcon.swift`. Canvas uses `lucide-react` at the same exact version. Source: https://github.com/lucide-icons/lucide . To update, update both pinned packages in CanvasWeb, copy the upstream static font/license, regenerate glyph mappings from that release's `font/lucide.css`, and rebuild/reinspect both renderers. Do not substitute generated or hand-drawn artwork.
