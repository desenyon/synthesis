// Synthesis colours for elements the application draws on the canvas.
//
// Excalidraw renders its dark theme by applying `invert(93%) hue-rotate(180deg)` to the canvas,
// so an element's stored colour is not what appears on screen. To make a card look exactly like
// the rest of the application in dark mode, the wanted colour is run through the inverse of that
// filter before it is stored.

export type Theme = "light" | "dark";

const HUE_180 = [
  [-0.574, 1.43, 0.144],
  [0.426, 0.43, 0.144],
  [0.426, 1.43, -0.856],
];

function parse(hex: string): [number, number, number] {
  const value = hex.replace("#", "");
  return [0, 2, 4].map((i) => parseInt(value.slice(i, i + 2), 16)) as [number, number, number];
}
function format(rgb: number[]): string {
  return "#" + rgb.map((c) => Math.max(0, Math.min(255, Math.round(c))).toString(16).padStart(2, "0")).join("");
}

/** Colour to store so that Excalidraw's dark-theme filter displays `hex`. */
export function forDarkCanvas(hex: string): string {
  const [r, g, b] = parse(hex);
  // A 180° hue rotation is its own inverse.
  const rotated = HUE_180.map((row) => row[0] * r + row[1] * g + row[2] * b);
  // invert(93%): out = 0.07·in + 0.93·(255 − in)  ⇒  in = (237.15 − out) / 0.86
  return format(rotated.map((c) => (237.15 - c) / 0.86));
}

const dark = {
  background: "#17191c",
  surface: "#111111",
  text: "#e6e9ef",
  secondary: "#b6bbc5",
  muted: "#8f96a3",
  border: "#2a2a2a",
  accent: "#a9c7ff",
  positive: "#8fc3a6",
  categories: {
    characters: "#d7b899",
    factions: "#b7b6e0",
    places: "#9cc7b5",
    "power systems": "#d4c48f",
    cosmology: "#c9a9d6",
  } as Record<string, string>,
};
const light = {
  background: "#f8f9fb",
  surface: "#ffffff",
  text: "#20232b",
  secondary: "#5c6573",
  muted: "#7d8593",
  border: "#dce1e8",
  accent: "#3b637f",
  positive: "#2f7653",
  categories: {
    characters: "#866042",
    factions: "#655a96",
    places: "#3b7461",
    "power systems": "#7a6a2e",
    cosmology: "#7b5391",
  } as Record<string, string>,
};

export type Palette = typeof dark;
export function displayPalette(theme: Theme): Palette { return theme === "dark" ? dark : light; }

/** Stored colours for the given theme: literal in light mode, pre-inverted in dark mode. */
export function palette(theme: Theme): Palette {
  if (theme === "light") return light;
  const convert = (value: any): any =>
    typeof value === "string"
      ? forDarkCanvas(value)
      : Object.fromEntries(Object.entries(value).map(([k, v]) => [k, convert(v)]));
  return convert(dark);
}
export function categoryColor(p: Palette, category: string): string {
  return p.categories[category.toLowerCase() === "systems" ? "factions" : category.toLowerCase()] ?? p.accent;
}

/** The exact CSS dark filter, applied to stored hex colours for WebKit PNG export.
 * Rendering as light avoids WebKit's missing Canvas2D filter and preserves image colours. */
export function displayColor(value: string, theme: Theme): string {
  if (theme !== 'dark' || !/^#[0-9a-f]{6}$/i.test(value)) return value;
  const inverse = parse(value).map(c => 237.15 - .86 * c);
  return format(HUE_180.map(row => row.reduce((sum, coefficient, i) => sum + coefficient * inverse[i], 0)));
}
