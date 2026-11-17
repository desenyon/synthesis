import { cpSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const out = resolve(__dirname, "../Sources/SynthesisUI/CanvasBundle");

// Excalidraw loads its fonts at runtime from EXCALIDRAW_ASSET_PATH. They are copied into the
// bundle so the canvas never needs the network. Xiaolai (12 MB of CJK handwriting subsets) is
// left out to keep the application small; CJK text falls back to system fonts.
function bundleFonts() {
  return {
    name: "synthesis-bundle-fonts",
    closeBundle() {
      const graph = resolve(__dirname, "../Sources/SynthesisUI/Assets/Graph");
      mkdirSync(graph, { recursive: true });
      cpSync(resolve(__dirname, "node_modules/@dagrejs/dagre/dist/dagre.min.js"), resolve(graph, "dagre.min.js"));
      cpSync(resolve(__dirname, "node_modules/@dagrejs/dagre/LICENSE"), resolve(graph, "LICENSE"));
      cpSync(resolve(__dirname, "node_modules/@dagrejs/dagre/dist/dagre.min.js.LEGAL.txt"), resolve(graph, "DEPENDENCY_LICENSES.txt"));
      const source = resolve(__dirname, "node_modules/@excalidraw/excalidraw/dist/prod/fonts");
      const target = resolve(out, "fonts");
      mkdirSync(target, { recursive: true });
      for (const family of readdirSync(source)) {
        if (family === "Xiaolai") continue;
        cpSync(resolve(source, family), resolve(target, family), { recursive: true });
      }
      if (!existsSync(resolve(out, "index.html"))) throw new Error("bundle is missing index.html");
    },
  };
}

export default defineConfig({
  base: "./",
  plugins: [react(), bundleFonts()],
  define: { "process.env.IS_PREACT": JSON.stringify("false") },
  build: {
    outDir: out,
    emptyOutDir: true,
    target: "safari17",
    chunkSizeWarningLimit: 4000,
    sourcemap: false,
    rollupOptions: {
      output: {
        // Stable names keep rebuild diffs in the repository small.
        entryFileNames: "assets/[name].js",
        chunkFileNames: "assets/[name].js",
        assetFileNames: "assets/[name][extname]",
      },
    },
  },
});
