import '@fontsource/inter/400.css';
import '@fontsource/inter/500.css';
import '@fontsource/inter/600.css';
import "./canvasFilter";
import { createRoot } from "react-dom/client";
import "@excalidraw/excalidraw/index.css";
import "./canvas.css";
import { App } from "./App";

createRoot(document.getElementById("root")!).render(<App />);
