# Canvas dependency maintenance

## 2026-11-15

Retain `@excalidraw/excalidraw` 0.18.1. npm's suggested downgrade to 0.17.6 is not applied.

Scoped overrides in `CanvasWeb/package.json`:

- `lodash-es` 4.18.1: addresses the [template imports advisory](https://github.com/advisories/GHSA-r5fr-rjxr-66jc) and earlier pollution issue.
- `katex` 0.18.2: addresses the [trust restriction bypass](https://github.com/advisories/GHSA-238p-pmpm-9mq7). Mermaid uses its public rendering API.
- Excalidraw's Nano ID dependency → 3.3.20, preserving its major version.
- Mermaid-to-Excalidraw's Nano ID dependency → 5.1.16. Its ESM consumers use the unchanged `nanoid()` function. See [upstream releases](https://github.com/ai/nanoid/releases).

Observed: `npm audit` decreased from 12 findings (9 high / 1 moderate / 2 low) to zero. Typecheck, eight Node tests, Vite build and 19 isolated WebKit engine integration checks passed. The committed offline bundle was rebuilt. Audit scope is the installed dependency graph; it is not proof of absence of all vulnerabilities in prebundled vendor code.

Install still emits peer warnings because Excalidraw includes older Radix components whose peer declarations predate React 19. The actual offline engine passed the integration runner. Do not suppress the warning by claiming full compatibility or force-upgrade arbitrary engine internals. Reassess these overrides with the next engine release; remove only after the lockfile resolves patched versions without them.
