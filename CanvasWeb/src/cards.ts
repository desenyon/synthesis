// Record cards and relationship arrows: the parts of a scene that Synthesis owns.
//
// A card is an ordinary Excalidraw group — a rounded rectangle plus four text elements — so it
// can be moved, duplicated, connected and drawn over like anything else. The rectangle carries
// the record ID; Synthesis rewrites the text whenever the record changes.

import { convertToExcalidrawElements, FONT_FAMILY, newElementWith } from "@excalidraw/excalidraw";
import { categoryColor, palette, type Theme } from "./palette";

export type RecordInfo = {
  id: string;
  title: string;
  body: string;
  kind: string;
  category: string;
  state: string;
  origin: string;
  canonKept: boolean;
};
export type RelationInfo = { id: string; sourceID: string; targetID: string; label: string };
type El = any;

export const CARD_WIDTH = 300;
const PAD = 16;
const FONT = FONT_FAMILY.Nunito;
const ROLES = ["category", "title", "body", "state"] as const;

let measurer: CanvasRenderingContext2D | null = null;
/** Greedy word wrap using the same font the canvas draws with. */
export function wrap(text: string, size: number, maxWidth: number, maxLines: number): string {
  measurer ??= document.createElement("canvas").getContext("2d");
  const ctx = measurer!;
  ctx.font = `${size}px Nunito, "Helvetica Neue", sans-serif`;
  const lines: string[] = [];
  for (const paragraph of text.split("\n")) {
    if (!paragraph.trim()) {
      if (lines.length && lines[lines.length - 1] !== "") lines.push("");
      continue;
    }
    let line = "";
    for (const word of paragraph.trim().split(/\s+/)) {
      const candidate = line ? `${line} ${word}` : word;
      if (!line || ctx.measureText(candidate).width <= maxWidth) {
        line = candidate;
      } else {
        lines.push(line);
        line = word;
      }
    }
    lines.push(line);
  }
  while (lines.length && lines[lines.length - 1] === "") lines.pop();
  if (lines.length > maxLines) {
    const kept = lines.slice(0, maxLines);
    kept[maxLines - 1] = kept[maxLines - 1].replace(/[\s.,;:]*$/, "") + "…";
    return kept.join("\n");
  }
  return lines.join("\n");
}

function kindLabel(record: RecordInfo): string {
  if (record.category) return record.category;
  return record.kind === "entity" ? "Entity" : record.kind === "capture" ? "Idea" : "Document";
}
function stateLabel(record: RecordInfo): string {
  const state =
    record.state === "canon" ? "Canon" : record.state === "idea" ? "Idea" : record.state === "hypothetical" ? "Hypothetical" : "Draft";
  return (
    `● ${state}` +
    (record.canonKept && record.state !== "canon" ? "  ·  canon kept" : "") +
    (record.origin === "ai-proposed" ? "  ·  AI-proposed" : record.origin === "imported" ? "  ·  imported" : "")
  );
}
export function cardHash(record: RecordInfo | undefined, theme: Theme): string {
  return JSON.stringify([record ?? "archived", theme]);
}

function text(id: string, x: number, y: number, value: string, size: number, color: string, group: string, role: string): El {
  return convertToExcalidrawElements(
    [
      {
        type: "text",
        id,
        x,
        y,
        text: value || " ",
        fontSize: size,
        fontFamily: FONT,
        strokeColor: color,
        textAlign: "left",
        groupIds: [group],
        customData: { synthesis: "part", role },
      } as any,
    ],
    { regenerateIds: false },
  )[0];
}

/** Fresh elements for one card with its top-left corner at (x, y). */
export function buildCard(
  record: RecordInfo | undefined,
  recordID: string,
  x: number,
  y: number,
  theme: Theme,
  group: string,
  ids?: Partial<Record<"rect" | (typeof ROLES)[number], string>>,
  /** Height of artwork sitting at the top of the card, if it has any. */
  header = 0,
): { rect: El; parts: Record<string, El> } {
  const p = palette(theme);
  const inner = CARD_WIDTH - PAD * 2;
  const id = (role: string) => ids?.[role as "rect"] ?? `${group}:${role}`;
  const tint = categoryColor(p, record?.category ?? "");
  const parts: Record<string, El> = {};
  let cursor = y + header + 14;
  parts.category = text(id("category"), x + PAD, cursor, record ? kindLabel(record) : "Archived record", 12, tint, group, "category");
  cursor += parts.category.height + 6;
  parts.title = text(id("title"), x + PAD, cursor, wrap(record?.title ?? "Unavailable", 20, inner, 2), 20, p.text, group, "title");
  cursor += parts.title.height + 6;
  const body = record?.body?.trim() ? wrap(record.body, 14, inner, 5) : "";
  if (body) {
    parts.body = text(id("body"), x + PAD, cursor, body, 14, p.secondary, group, "body");
    cursor += parts.body.height + 10;
  } else {
    cursor += 4;
  }
  parts.state = text(
    id("state"),
    x + PAD,
    cursor,
    record ? stateLabel(record) : "Restore it from Library",
    12,
    record?.state === "canon" ? p.positive : p.muted,
    group,
    "state",
  );
  cursor += parts.state.height + 14;
  const rect = convertToExcalidrawElements(
    [
      {
        type: "rectangle",
        id: id("rect"),
        x,
        y,
        width: CARD_WIDTH,
        height: cursor - y,
        backgroundColor: p.surface,
        fillStyle: "solid",
        strokeColor: p.border,
        strokeWidth: 1,
        roughness: 0,
        roundness: { type: 3, value: 12 },
        groupIds: [group],
        customData: { synthesis: "card", recordID, hash: cardHash(record, theme) },
      } as any,
    ],
    { regenerateIds: false },
  )[0];
  return { rect, parts };
}

export const isCard = (el: El) => !el.isDeleted && el.type === "rectangle" && el.customData?.synthesis === "card";
export const isRelation = (el: El) => el.type === "arrow" && el.customData?.synthesis === "relation";
const groupOf = (el: El): string | undefined => el.groupIds?.[el.groupIds.length - 1];

/**
 * Brings every card up to date with its record and theme. Returns the new element list, or
 * null when nothing needed to change.
 */
export function syncCards(elements: readonly El[], records: Map<string, RecordInfo>, theme: Theme): El[] | null {
  const next = [...elements];
  let changed = false;
  const replace = (el: El) => {
    const index = next.findIndex((e) => e.id === el.id);
    if (index >= 0) next[index] = el;
    else next.push(el);
    changed = true;
  };
  for (const rect of elements.filter(isCard)) {
    const record = records.get(rect.customData.recordID);
    if (rect.customData.hash === cardHash(record, theme)) continue;
    const group = groupOf(rect);
    if (!group) continue;
    const existing: Record<string, El> = {};
    for (const el of elements) {
      if (!el.isDeleted && el.customData?.synthesis === "part" && groupOf(el) === group) existing[el.customData.role] = el;
    }
    const ids: any = { rect: rect.id };
    for (const role of ROLES) if (existing[role]) ids[role] = existing[role].id;
    // Artwork attached to the card stays at its top edge; the text flows beneath it.
    const art = elements.find(
      (el) => !el.isDeleted && el.type === "image" && el.customData?.role === "art" && groupOf(el) === group,
    );
    if (art && (art.x !== rect.x || art.y !== rect.y)) replace(newElementWith(art, { x: rect.x, y: rect.y }));
    const fresh = buildCard(record, rect.customData.recordID, rect.x, rect.y, theme, group, ids, art?.height ?? 0);
    replace(
      newElementWith(rect, {
        height: fresh.rect.height,
        backgroundColor: fresh.rect.backgroundColor,
        strokeColor: fresh.rect.strokeColor,
        customData: fresh.rect.customData,
      }),
    );
    for (const role of ROLES) {
      const part = fresh.parts[role];
      const old = existing[role];
      if (part && old) {
        replace(
          newElementWith(old, {
            x: part.x,
            y: part.y,
            width: part.width,
            height: part.height,
            text: part.text,
            originalText: part.originalText,
            strokeColor: part.strokeColor,
            fontSize: part.fontSize,
            fontFamily: part.fontFamily,
            lineHeight: part.lineHeight,
            angle: rect.angle,
          }),
        );
      } else if (part) {
        // Keep the new text directly above its card in the stacking order.
        const at = next.findIndex((e) => e.id === rect.id);
        next.splice(at + 1, 0, { ...part, groupIds: rect.groupIds, frameId: rect.frameId });
        changed = true;
      } else if (old) {
        replace(newElementWith(old, { isDeleted: true }));
      }
    }
  }
  return changed ? next : null;
}

function anchors(a: El, b: El) {
  const ac = { x: a.x + a.width / 2, y: a.y + a.height / 2 };
  const bc = { x: b.x + b.width / 2, y: b.y + b.height / 2 };
  const dx = bc.x - ac.x;
  const dy = bc.y - ac.y;
  const gap = 6;
  if (Math.abs(dx) / ((a.width + b.width) / 2) >= Math.abs(dy) / ((a.height + b.height) / 2)) {
    return {
      start: { x: dx >= 0 ? a.x + a.width + gap : a.x - gap, y: ac.y },
      end: { x: dx >= 0 ? b.x - gap : b.x + b.width + gap, y: bc.y },
    };
  }
  return {
    start: { x: ac.x, y: dy >= 0 ? a.y + a.height + gap : a.y - gap },
    end: { x: bc.x, y: dy >= 0 ? b.y - gap : b.y + b.height + gap },
  };
}

/** A labelled arrow bound to two card rectangles. Returns the arrow, its label and the rects. */
export function buildArrow(a: El, b: El, label: string, theme: Theme, customData: Record<string, unknown>): El[] {
  const p = palette(theme);
  const { start, end } = anchors(a, b);
  const id = `arrow:${Math.random().toString(36).slice(2, 12)}`;
  const made = convertToExcalidrawElements(
    [
      {
        type: "arrow",
        id,
        x: start.x,
        y: start.y,
        width: Math.abs(end.x - start.x),
        height: Math.abs(end.y - start.y),
        points: [
          [0, 0],
          [end.x - start.x, end.y - start.y],
        ],
        strokeColor: p.accent,
        strokeWidth: 1,
        roughness: 0,
        endArrowhead: "arrow",
        customData,
        ...(label ? { label: { text: label, fontSize: 14, fontFamily: FONT, strokeColor: p.accent } } : {}),
      } as any,
    ],
    { regenerateIds: false },
  );
  const arrow = newElementWith(made[0] as any, {
    startBinding: { elementId: a.id, focus: 0, gap: 6 },
    endBinding: { elementId: b.id, focus: 0, gap: 6 },
  } as any);
  const bind = (rect: El) =>
    newElementWith(rect, { boundElements: [...(rect.boundElements ?? []), { type: "arrow", id: arrow.id }] });
  return [bind(a), bind(b), arrow, ...made.slice(1)];
}

/** The text bound to an arrow, if any. */
export function arrowLabel(arrow: El, elements: readonly El[]): El | undefined {
  const bound = (arrow.boundElements ?? []).find((b: any) => b.type === "text");
  return bound ? elements.find((e) => e.id === bound.id && !e.isDeleted) : undefined;
}

/**
 * Adds an arrow for every stored relationship whose two entities are both on the board and
 * that the creator has not removed from this board. Returns null when nothing changed.
 */
export function syncRelations(
  elements: readonly El[],
  relations: RelationInfo[],
  hidden: Set<string>,
  theme: Theme,
): El[] | null {
  let next: El[] | null = null;
  const current = () => next ?? elements;
  const cardFor = (recordID: string) => current().find((e) => isCard(e) && e.customData.recordID === recordID);
  const drawn = new Set(elements.filter((e) => isRelation(e) && !e.isDeleted).map((e) => e.customData.relationID));
  for (const relation of relations) {
    if (drawn.has(relation.id) || hidden.has(relation.id)) continue;
    const a = cardFor(relation.sourceID);
    const b = cardFor(relation.targetID);
    if (!a || !b) continue;
    const added = buildArrow(a, b, relation.label, theme, { synthesis: "relation", relationID: relation.id });
    const list = [...current()];
    for (const el of added) {
      const index = list.findIndex((e) => e.id === el.id);
      if (index >= 0) list[index] = el;
      else list.push(el);
    }
    next = list;
  }
  return next;
}
