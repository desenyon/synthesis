import "./canvasFilter";
import { createRoot } from "react-dom/client";
import "@excalidraw/excalidraw/index.css";
import "./canvas.css";
import { App } from "./App";

createRoot(document.getElementById("root")!).render(<App />);
