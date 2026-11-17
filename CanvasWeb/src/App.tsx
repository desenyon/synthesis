import {
  CaptureUpdateAction,
  convertToExcalidrawElements,
  Excalidraw,
  getCommonBounds,
  MainMenu,
  newElementWith,
  restore,
  viewportCoordsToSceneCoords,
} from "@excalidraw/excalidraw";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  arrowLabel,
  buildArrow,
  buildCard,
  CARD_WIDTH,
  isCard,
  isRelation,
  syncCards,
  syncRelations,
  type RecordInfo,
  type RelationInfo,
} from "./cards";
import { palette, type Theme } from "./palette";
import { acceptsSession, containsCardPoint } from "./sceneRules";
import { arrangeCards } from "./layout";
import { exportBoard } from "./exportBoard";
import { StudioOverlay } from "./StudioOverlay";

type El = any;
type Api = any;

let activeSession = "";
let loadEpoch = 0;

/** Messages to the native application. Outside the app (plain browser) they are logged. */
function post(message: Record<string, unknown>) {
  const handler = (window as any).webkit?.messageHandlers?.synthesis;
  if (handler) handler.postMessage({ ...message, sessionID: activeSession });
  else console.debug("synthesis →", message);
}

type LegacyCard = { id: string; text: string; recordID?: string; image?: string; x: number; y: number; group?: string };
type LegacyEdge = { label?: string; source: string; target: string };
type FitInsets = { top: number; right: number; bottom: number; left: number };
type LoadPayload = {
  fitInsets?: FitInsets;
  sessionID: string;
  assisted: boolean;
  name: string;
  theme: Theme;
  scene: { elements: El[]; appState?: Record<string, unknown>; files?: Record<string, El> } | null;
  legacy: { cards: LegacyCard[]; edges: LegacyEdge[] } | null;
  hiddenRelations: string[];
  records: RecordInfo[];
  relations: RelationInfo[];
};

const randomId = () => Math.random().toString(36).slice(2, 12);

function imageMime(base64: string): string {
  if (base64.startsWith("/9j/")) return "image/jpeg";
  if (base64.startsWith("R0lGOD")) return "image/gif";
  if (base64.startsWith("UklGR")) return "image/webp";
  return "image/png";
}
function imageSize(dataURL: string): Promise<{ width: number; height: number }> {
  return new Promise((resolve) => {
    const image = new Image();
    image.onload = () => resolve({ width: image.naturalWidth || 300, height: image.naturalHeight || 200 });
    image.onerror = () => resolve({ width: 300, height: 200 });
    image.src = dataURL;
  });
}

// Native supplies this before any paint; subsequent switches use the bridge.
const initialTheme: Theme = new URLSearchParams(window.location.search).get("theme") === "light" ? "light" : "dark";

export function App() {
  const [api, setApi] = useState<Api>(null);
  const [assisted, setAssisted] = useState(true);
  const [theme, setTheme] = useState<Theme>(initialTheme);
  const [name, setName] = useState("Board");
  const live = useRef({
    api: null as Api,
    theme: initialTheme,
    fitInsets: { top: 76, right: 80, bottom: 176, left: 32 } as FitInsets,
    records: new Map<string, RecordInfo>(),
    relations: [] as RelationInfo[],
    hidden: new Set<string>(),
    loaded: false,
    applying: false,
    asked: new Set<string>(),
    pointerLog: [] as string[],
    selectionKey: "",
    saveTimer: 0,
    analyzeTimer: 0,
    filesKey: "",
  });

  /** Applies element changes without adding them to the undo history. */
  const apply = useCallback((elements: El[], appState?: Record<string, unknown>) => {
    const s = live.current;
    if (!s.api) return;
    s.applying = true;
    s.api.updateScene({ elements, ...(appState ? { appState } : {}), captureUpdate: CaptureUpdateAction.NEVER });
    s.applying = false;
  }, []);

  const getRecords = useCallback(() => live.current.records, []);
  const getRelations = useCallback(() => live.current.relations, []);

  const synchronise = useCallback(() => {
    const s = live.current;
    if (!s.api || !s.loaded) return;
    let elements: El[] = s.api.getSceneElementsIncludingDeleted();
    const cards = syncCards(elements, s.records, s.theme);
    if (cards) elements = cards;
    const relations = syncRelations(elements, s.relations, s.hidden, s.theme);
    if (relations) elements = relations;
    let presentationChanged = false;
    elements = elements.map(e => {
      if (["card", "part"].includes(e.customData?.synthesis) && e.opacity !== 0) {
        presentationChanged = true;
        return newElementWith(e, {opacity:0});
      }
      return e;
    });
    if (cards || relations || presentationChanged) apply(elements);
  }, [apply]);

  const serialise = useCallback((withFiles: boolean) => {
    const s = live.current;
    const elements: El[] = s.api.getSceneElements();
    const state = s.api.getAppState();
    const used = new Set(elements.filter((e) => e.type === "image" && e.fileId).map((e) => e.fileId));
    const files = Object.fromEntries(Object.entries(s.api.getFiles() as Record<string, El>).filter(([id]) => used.has(id)));
    const filesKey = Object.keys(files).sort().join(",");
    const scene: Record<string, unknown> = {
      elements,
      appState: {
        scrollX: state.scrollX,
        scrollY: state.scrollY,
        zoom: state.zoom?.value ?? 1,
        gridModeEnabled: state.gridModeEnabled ?? false,
      },
    };
    // Image data is large; it is only sent again when the set of images changes.
    if (withFiles || filesKey !== s.filesKey) scene.files = files;
    s.filesKey = filesKey;
    return { scene, hiddenRelations: [...s.hidden] };
  }, []);

  const save = useCallback(() => {
    const s = live.current;
    if (!s.api || !s.loaded) return;
    post({ type: "change", ...serialise(false) });
  }, [serialise]);

  /** Looks for things only the creator's edits can cause, once the scene has settled. */
  const analyse = useCallback(() => {
    const s = live.current;
    if (!s.api || !s.loaded) return;
    const state = s.api.getAppState();
    if (state.newElement || state.multiElement || state.editingTextElement || state.selectedElementsAreBeingDragged) return;
    const all: El[] = s.api.getSceneElementsIncludingDeleted();
    const byId = new Map(all.map((e) => [e.id, e]));
    for (const el of all) {
      if (el.type !== "arrow") continue;
      if (isRelation(el)) {
        const id = el.customData.relationID as string;
        const relation = s.relations.find((r) => r.id === id);
        if (el.isDeleted) {
          // Removing the arrow hides the relationship on this board; the relationship remains.
          if (relation && !s.hidden.has(id)) {
            s.hidden.add(id);
            post({ type: "relationHidden", relationID: id, label: relation.label });
          }
          continue;
        }
        // Undo restores the engine element; restore its board visibility as well.
        if (s.hidden.delete(id)) save();
        const label = arrowLabel(el, all)?.originalText?.trim() ?? "";
        if (relation && label && label !== relation.label) {
          relation.label = label;
          post({ type: "relabel", relationID: id, label });
        }
        continue;
      }
      if (el.isDeleted || el.customData?.synthesis || s.asked.has(el.id)) continue;
      const a = el.startBinding && byId.get(el.startBinding.elementId);
      const b = el.endBinding && byId.get(el.endBinding.elementId);
      if (!a || !b || !isCard(a) || !isCard(b) || a.id === b.id) continue;
      // Relationships join entities; an arrow touching a document stays a plain arrow.
      if (s.records.get(a.customData.recordID)?.kind !== "entity" || s.records.get(b.customData.recordID)?.kind !== "entity") continue;
      // An arrow drawn between two cards may be a relationship; the application asks.
      s.asked.add(el.id);
      post({
        type: "connect",
        arrowID: el.id,
        source: a.customData.recordID,
        target: b.customData.recordID,
        label: arrowLabel(el, all)?.originalText?.trim() ?? "",
      });
    }
  }, [save]);

  /// Tells the application which record cards are selected, so its bar can act on them.
  const reportSelection = useCallback(() => {
    const s = live.current;
    if (!s.api || !s.loaded) return;
    const selected = s.api.getAppState().selectedElementIds ?? {};
    const elements: El[] = s.api.getSceneElements();
    const cards = elements.filter((e) => isCard(e) && selected[e.id]);
    const recordIDs = [...new Set(cards.map((c) => c.customData.recordID as string))];
    const withArt = recordIDs.filter((id) =>
      cards.some(
        (c) =>
          c.customData.recordID === id &&
          elements.some((e) => e.type === "image" && e.customData?.role === "art" && e.groupIds?.some((g: string) => c.groupIds?.includes(g))),
      ),
    );
    const key = recordIDs.join(",") + "|" + withArt.join(",");
    if (key === s.selectionKey) return;
    s.selectionKey = key;
    post({ type: "selection", recordIDs, withArt });
  }, []);

  const onChange = useCallback(() => {
    const s = live.current;
    if (!s.loaded) return;
    reportSelection();
    if (s.applying) return;
    window.clearTimeout(s.saveTimer);
    s.saveTimer = window.setTimeout(save, 350);
    window.clearTimeout(s.analyzeTimer);
    s.analyzeTimer = window.setTimeout(() => { analyse(); synchronise(); }, 200);
  }, [save, analyse, reportSelection, synchronise]);

  /** A free spot near the centre of the current view, in scene coordinates. */
  const openSpot = useCallback((offset: number) => {
    const s = live.current;
    const state = s.api.getAppState();
    const centre = viewportCoordsToSceneCoords(
      { clientX: state.offsetLeft + state.width / 2, clientY: state.offsetTop + state.height / 2 },
      state,
    );
    const taken: El[] = s.api.getSceneElements().filter(isCard);
    let x = centre.x - CARD_WIDTH / 2 + offset * 340;
    let y = centre.y - 90;
    let tries = 0;
    while (tries < 60 && taken.some((c) => Math.abs(c.x - x) < CARD_WIDTH + 20 && Math.abs(c.y - y) < c.height + 20)) {
      tries += 1;
      x += 340;
      if (tries % 3 === 0) {
        x -= 340 * 3;
        y += 230;
      }
    }
    return { x, y };
  }, []);

  useEffect(() => {
    if (!api) return;
    const s = live.current;
    s.api = api;

    const bridge = {
      async load(payload: LoadPayload) {
        const epoch = ++loadEpoch;
        activeSession = payload.sessionID;
        setAssisted(payload.assisted);
        window.clearTimeout(s.saveTimer);
        window.clearTimeout(s.analyzeTimer);
        s.selectionKey = "";
        s.loaded = false;
        s.theme = payload.theme;
        if (payload.fitInsets) s.fitInsets = payload.fitInsets;
        s.records = new Map(payload.records.map((r) => [r.id, r]));
        s.relations = payload.relations;
        s.hidden = new Set(payload.hiddenRelations);
        s.asked = new Set();
        s.filesKey = "";
        setTheme(payload.theme);
        setName(payload.name);
        try {
          await Promise.race([
            (document as any).fonts.load('20px "Nunito"', "Aa"),
            new Promise((resolve) => setTimeout(resolve, 800)),
          ]);
        } catch {}
        if (epoch !== loadEpoch || !acceptsSession(activeSession, payload.sessionID)) return;
        api.resetScene();
        let elements: El[] = [];
        let appState: Record<string, unknown> = {};
        let fit = false;
        if (payload.scene) {
          const restored = restore(
            { elements: payload.scene.elements, appState: payload.scene.appState as any, files: payload.scene.files ?? {} },
            null,
            null,
          );
          elements = restored.elements as El[];
          const saved = payload.scene.appState ?? {};
          if (typeof saved.scrollX === "number") {
            appState = {
              scrollX: saved.scrollX,
              scrollY: saved.scrollY,
              zoom: { value: Math.min(4, Math.max(0.1, Number(saved.zoom) || 1)) },
              gridModeEnabled: Boolean(saved.gridModeEnabled),
            };
          } else {
            fit = true;
          }
          api.addFiles(Object.values(payload.scene.files ?? {}));
          s.filesKey = Object.keys(payload.scene.files ?? {}).sort().join(",");
        } else if (payload.legacy) {
          elements = await migrate(payload.legacy, s.records, payload.theme, api);
          fit = true;
        }
        if (epoch !== loadEpoch || !acceptsSession(activeSession, payload.sessionID)) return;
        s.applying = true;
        api.updateScene({
          elements,
          appState: { ...appState, selectedElementIds: {}, selectedGroupIds: {}, editingGroupId: null, theme: payload.theme, viewBackgroundColor: "transparent" },
          captureUpdate: CaptureUpdateAction.NEVER,
        });
        api.history.clear();
        s.applying = false;
        s.loaded = true;
        synchronise();
        if (fit && api.getSceneElements().length) {
          api.scrollToContent(undefined, { fitToViewport: true, viewportZoomFactor: 0.94, canvasOffsets: s.fitInsets, animate: false });
        }
        post({ type: "loaded", migrated: Boolean(payload.legacy && !payload.scene), ...serialise(true) });
      },
      setAssistance(enabled: boolean) { setAssisted(enabled); },
      setTheme(next: Theme) {
        s.theme = next;
        setTheme(next);
        if (!s.loaded) return;
        apply(api.getSceneElementsIncludingDeleted(), { theme: next, viewBackgroundColor: "transparent" });
        synchronise();
      },
      /** Latest records and relationships from the world. */
      sync(records: RecordInfo[], relations: RelationInfo[]) {
        s.records = new Map(records.map((r) => [r.id, r]));
        s.relations = relations;
        synchronise();
      },
      addCards(ids: string[]) {
        const added: El[] = [];
        const existing: El[] = api.getSceneElements();
        const selected: Record<string, true> = {};
        ids.forEach((id, index) => {
          const already = existing.find((e) => isCard(e) && e.customData.recordID === id);
          if (already) {
            selected[already.id] = true;
            return;
          }
          const spot = openSpot(added.length ? index : 0);
          const group = `card:${randomId()}`;
          const { rect, parts } = buildCard(s.records.get(id), id, spot.x, spot.y, s.theme, group);
          added.push(rect, ...Object.values(parts));
          selected[rect.id] = true;
          for (const part of Object.values(parts)) selected[part.id] = true;
        });
        const all = [...api.getSceneElementsIncludingDeleted(), ...added];
        api.updateScene({
          elements: all,
          appState: { selectedElementIds: selected },
          captureUpdate: CaptureUpdateAction.IMMEDIATELY,
        });
        synchronise();
        const targets = api.getSceneElements().filter((e: El) => selected[e.id]);
        if (targets.length) api.scrollToContent(targets, { fitToContent: false, animate: true });
        onChange();
      },
      async addImage(base64: string) {
        const epoch = loadEpoch;
        const dataURL = `data:${imageMime(base64)};base64,${base64}`;
        const size = await imageSize(dataURL);
        if (epoch !== loadEpoch || !s.loaded) return;
        const width = Math.min(480, size.width);
        const height = (width / size.width) * size.height;
        const fileId = `file:${randomId()}`;
        api.addFiles([{ id: fileId, dataURL, mimeType: imageMime(base64), created: Date.now() }]);
        const spot = openSpot(0);
        const image = convertToExcalidrawElements(
          [{ type: "image", x: spot.x, y: spot.y, width, height, fileId, status: "saved" } as any],
          { regenerateIds: true },
        );
        api.updateScene({
          elements: [...api.getSceneElementsIncludingDeleted(), ...image],
          appState: { selectedElementIds: { [image[0].id]: true } },
          captureUpdate: CaptureUpdateAction.IMMEDIATELY,
        });
        onChange();
      },
      /** Sets or clears the picture at the top of a record's card. */
      async setCardArt(recordID: string, base64: string | null) {
        const epoch = loadEpoch;
        const all: El[] = api.getSceneElementsIncludingDeleted();
        const selected = api.getAppState().selectedElementIds ?? {};
        const rect =
          all.find((e) => isCard(e) && e.customData.recordID === recordID && selected[e.id]) ??
          all.find((e) => isCard(e) && e.customData.recordID === recordID);
        if (!rect) return;
        const group = rect.groupIds?.[0];
        const isArt = (e: El) => !e.isDeleted && e.type === "image" && e.customData?.role === "art" && e.groupIds?.includes(group);
        let next = all.map((e) =>
          isArt(e)
            ? newElementWith(e, { isDeleted: true })
            : e.id === rect.id
              ? // An empty hash makes the next sync lay the text out again around the picture.
                newElementWith(e, { customData: { ...e.customData, hash: "" } })
              : e,
        );
        if (base64) {
          const dataURL = `data:${imageMime(base64)};base64,${base64}`;
          const size = await imageSize(dataURL);
          if (epoch !== loadEpoch || !s.loaded) return;
          const height = Math.min(150, (CARD_WIDTH / size.width) * size.height);
          const fileId = `file:${randomId()}`;
          api.addFiles([{ id: fileId, dataURL, mimeType: imageMime(base64), created: Date.now() }]);
          const art = convertToExcalidrawElements(
            [{ type: "image", x: rect.x, y: rect.y, width: CARD_WIDTH, height, fileId, status: "saved" } as any],
            { regenerateIds: true },
          )[0];
          const at = next.findIndex((e) => e.id === rect.id);
          next = [
            ...next.slice(0, at + 1),
            { ...art, groupIds: rect.groupIds, frameId: rect.frameId, customData: { synthesis: "part", role: "art" } },
            ...next.slice(at + 1),
          ];
        }
        api.updateScene({ elements: next, captureUpdate: CaptureUpdateAction.IMMEDIATELY });
        synchronise();
        s.selectionKey = "";
        onChange();
      },
      /** Explicitly saving board text creates a shared idea; geometry stays at the same spot. */
      captureSaved(elementID: string, recordID: string) {
        const all: El[] = api.getSceneElementsIncludingDeleted();
        const source = all.find(e => e.id === elementID && !e.isDeleted && e.type === "text" && !e.customData?.synthesis);
        const record = s.records.get(recordID);
        if (!source || !record) return;
        const card = buildCard(record,recordID,source.x,source.y,s.theme,randomId());
        api.updateScene({elements:[...all.map(e => e.id === elementID ? newElementWith(e,{isDeleted:true}) : e),card.rect,...Object.values(card.parts)],captureUpdate:CaptureUpdateAction.IMMEDIATELY});
        synchronise(); save();
      },
      /** Board visibility is independent from the world relationship, and participates in Undo. */
      hideRelationship(id: string) {
        const all: El[] = api.getSceneElementsIncludingDeleted();
        const edge = all.find(e => isRelation(e) && !e.isDeleted && e.customData.relationID === id);
        if (!edge) return;
        const label = arrowLabel(edge, all);
        api.updateScene({elements:all.map(e => e.id === edge.id || e.id === label?.id ? newElementWith(e,{isDeleted:true}) : e), captureUpdate:CaptureUpdateAction.IMMEDIATELY});
        analyse(); save();
      },
      /** The creator named a relationship for an arrow they drew. */
      relationSaved(arrowID: string, relation: RelationInfo) {
        s.relations = [...s.relations.filter((r) => r.id !== relation.id), relation];
        const all: El[] = api.getSceneElementsIncludingDeleted();
        const arrow = all.find((e) => e.id === arrowID);
        if (!arrow) { synchronise(); save(); return; }
        const a = all.find((e) => e.id === arrow.startBinding?.elementId);
        const b = all.find((e) => e.id === arrow.endBinding?.elementId);
        if (!a || !b) return synchronise();
        // Replace the hand-drawn arrow with a labelled relationship arrow.
        const label = arrowLabel(arrow, all);
        const without = all.map((e) =>
          e.id === arrowID || e.id === label?.id
            ? newElementWith(e, { isDeleted: true })
            : e.id === a.id || e.id === b.id
              ? newElementWith(e, { boundElements: (e.boundElements ?? []).filter((x: any) => x.id !== arrowID) })
              : e,
        );
        const rectA = without.find((e) => e.id === a.id);
        const rectB = without.find((e) => e.id === b.id);
        const made = buildArrow(rectA, rectB, relation.label, s.theme, { synthesis: "relation", relationID: relation.id });
        const merged = [...without];
        for (const el of made) {
          const index = merged.findIndex((e) => e.id === el.id);
          if (index >= 0) merged[index] = el;
          else merged.push(el);
        }
        apply(merged);
        onChange();
      },
      /** A relabel was refused (for example a canonical relationship); show the stored label. */
      relabelRejected(relationID: string, label: string) {
        const relation = s.relations.find((r) => r.id === relationID);
        if (relation) relation.label = label;
        const all: El[] = api.getSceneElementsIncludingDeleted();
        const arrow = all.find((e) => isRelation(e) && !e.isDeleted && e.customData.relationID === relationID);
        const text = arrow && arrowLabel(arrow, all);
        if (!text) return;
        apply(all.map((e) => (e.id === text.id ? newElementWith(e, { text: label, originalText: label }) : e)));
      },
      showHiddenRelations() {
        s.hidden = new Set();
        synchronise();
        onChange();
      },
      setFitInsets(insets: FitInsets) { s.fitInsets = insets; },
      command(name: string, insets?: FitInsets) {
        if (name === "arrange") {
          const all: El[] = api.getSceneElementsIncludingDeleted();
          const cards = all.filter(isCard);
          const state = api.getAppState();
          const positions = arrangeCards(cards.map(c => ({...c, recordID: c.customData.recordID})), s.relations, state.width >= state.height);
          const offsets = new Map(cards.map(card => { const p = positions.get(card.id)!;
            return [card.groupIds[0], {x: p.x - card.x, y: p.y - card.y}]; }));
          api.updateScene({elements: all.map(element => {
            const delta = offsets.get(element.groupIds?.[0]);
            return delta && !element.isDeleted ? newElementWith(element, {x: element.x + delta.x, y: element.y + delta.y}) : element;
          }), captureUpdate: CaptureUpdateAction.IMMEDIATELY});
          synchronise(); save(); bridge.command("fit");
          return;
        }
        if (insets) s.fitInsets = insets;
        const key = (k: string, extra: Record<string, unknown> = {}) =>
          document.querySelector(".excalidraw")?.dispatchEvent(new KeyboardEvent("keydown", { key: k, code: `Key${k.toUpperCase()}`, metaKey: true, bubbles: true, ...extra }));
        if (name === "undo") key("z");
        else if (name === "redo") key("z", { shiftKey: true });
        else if (name === "selectAll") key("a");
        else if (["zoomIn", "zoomOut", "resetZoom"].includes(name)) {
          const state = api.getAppState();
          const old = state.zoom.value;
          const zoom = name === "resetZoom" ? 1 : Math.min(4, Math.max(0.1, old * (name === "zoomIn" ? 1.2 : 1/1.2)));
          api.updateScene({appState: {zoom: {value: zoom}, scrollX: state.scrollX + state.width / 2 * (1/zoom - 1/old), scrollY: state.scrollY + state.height / 2 * (1/zoom - 1/old)}, captureUpdate: CaptureUpdateAction.NEVER});
        }
        else if (name === "fit" && api.getSceneElements().length) {
          api.scrollToContent(undefined, { fitToViewport: true, viewportZoomFactor: 0.94, canvasOffsets: s.fitInsets, animate: true, duration: 180 });
        } else if (name === "flush") {
          window.clearTimeout(s.saveTimer);
          window.clearTimeout(s.analyzeTimer);
          analyse(); synchronise();
          if (s.loaded) post({ type: "change", ...serialise(true) });
        }
      },
      async exportImage() {
        const exportingSession = activeSession;
        try {
          if (!s.loaded) throw new Error("Wait for this board to finish loading, then export again.");
          synchronise();
          const blob = await exportBoard(api.getSceneElements(), api.getAppState(), api.getFiles(),
            new Map(s.records), [...s.relations], s.theme);
          if (activeSession !== exportingSession) return;
          const data = await new Promise<string>((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(String(reader.result).split(",")[1] ?? "");
            reader.onerror = () => reject(new Error("The exported image could not be read."));
            reader.readAsDataURL(blob);
          });
          if (!data) throw new Error("The board image was empty. Please retry.");
          if (activeSession === exportingSession) post({ type: "exported", data });
        } catch (error) {
          if (activeSession === exportingSession) post({ type: "exportFailed", message: error instanceof Error ? error.message : "This board could not be exported." });
        }
      },
      /** Deterministic, isolated WebKit integration checks. Never calls a model. */
      async audit() {
        const results: string[] = [];
        const check = (name: string, ok: boolean) => results.push(`${ok ? "PASS" : "FAIL"} ${name}`);
        const wait = () => new Promise(resolve => setTimeout(resolve, 100));
        const original: LoadPayload = structuredClone({sessionID:activeSession,assisted:true,name,theme:s.theme,fitInsets:s.fitInsets,
          scene:serialise(true).scene as any,legacy:null,hiddenRelations:[...s.hidden],records:[...s.records.values()],relations:s.relations.map(r=>({...r}))});
        const card = api.getSceneElements().find(isCard);
        if (!card) return ["FAIL fixture has no card"];
        await wait();
        bridge.command("fit");
        await new Promise(resolve => setTimeout(resolve, 300));
        const fitState = api.getAppState(), fitBounds = getCommonBounds(api.getSceneElements());
        const screen = [ (fitBounds[0]+fitState.scrollX)*fitState.zoom.value,
          (fitBounds[1]+fitState.scrollY)*fitState.zoom.value,
          (fitBounds[2]+fitState.scrollX)*fitState.zoom.value,
          (fitBounds[3]+fitState.scrollY)*fitState.zoom.value ];
        check("fit clears native composer and toolbars", screen[0] >= s.fitInsets.left - 1 && screen[1] >= s.fitInsets.top - 1 && screen[2] <= fitState.width - s.fitInsets.right + 1 && screen[3] <= fitState.height - s.fitInsets.bottom + 1);
        const stockToolbar = document.querySelector(".App-menu_top");
        check("custom toolbar replaces stock controls", !stockToolbar || getComputedStyle(stockToolbar).display === "none");
        check("custom cards paint above engine", Number(getComputedStyle(document.querySelector(".studio-overlay")!).zIndex) > 2 && document.querySelectorAll(".studio-record").length > 0);
        (document.querySelector('[aria-label="Pan · H"]') as HTMLButtonElement).click(); await wait();
        check("custom pan tool reaches engine", api.getAppState().activeTool.type === "hand");
        (document.querySelector('[aria-label="Select · V"]') as HTMLButtonElement).click(); await wait();
        const before = api.getAppState().zoom.value;
        (document.querySelector('[aria-label="Zoom in"]') as HTMLButtonElement).click(); await wait();
        check("custom zoom control reaches engine", api.getAppState().zoom.value > before);
        bridge.command("resetZoom"); await wait();
        const initial = {...api.getSceneElements().find((e:El)=>e.id===card.id)};
        await bridge.testDrag(card.customData.recordID, 40, 25); await wait();
        const moved = {...api.getSceneElements().find((e:El)=>e.id===card.id)};
        check(`overlay permits real engine card drag (${moved.x-initial.x}, ${moved.y-initial.y})`, Math.abs(moved.x-initial.x-40)<1 && Math.abs(moved.y-initial.y-25)<1);
        bridge.command("undo"); await wait();
        const undone = api.getSceneElements().find((e:El)=>e.id===card.id);
        check("custom undo restores dragged card", Math.abs(undone.x-initial.x)<1);
        bridge.command("redo"); await wait();
        check("custom redo restores move", Math.abs(api.getSceneElements().find((e:El)=>e.id===card.id).x-moved.x)<1);
        const relation = s.relations.find(r=>api.getSceneElements().some((e:El)=>isRelation(e)&&e.customData.relationID===r.id));
        if (relation) {
          bridge.sync([...s.records.values()],s.relations.map(r=>r.id===relation.id?{...r,label:"audit updated"}:r));
          const arrow=api.getSceneElements().find((e:El)=>isRelation(e)&&e.customData.relationID===relation.id);
          check("stored relationship endpoints are locked to their records",arrow.locked === true);
          check("stored relationship labels are locked and inspectable",arrowLabel(arrow,api.getSceneElements())?.locked === true && !!document.querySelector('.studio-relationship-hit'));
          check("stored relationship rename refreshes label",arrowLabel(arrow,api.getSceneElements())?.originalText==="audit updated");
          bridge.sync([...s.records.values()],s.relations.filter(r=>r.id!==relation.id));
          check("archived relationship disappears",!api.getSceneElements().some((e:El)=>isRelation(e)&&e.customData.relationID===relation.id));
        }
        const second = api.getSceneElements().filter(isCard)[1];
        if (second) {
          const oldTitle = s.records.get(second.customData.recordID)?.title;
          api.updateScene({elements:api.getSceneElementsIncludingDeleted().map((e:El)=>e.customData?.synthesis === "card" || e.customData?.synthesis === "part" ? {...e,groupIds:[...e.groupIds,"audit:outer"]} : e)});
          bridge.sync([...s.records.values()].map(r=>r.id===card.customData.recordID?{...r,title:"Updated first card"}:r),s.relations);
          const title = api.getSceneElements().find((e:El)=>e.customData?.role==="title" && e.groupIds?.[0]===second.groupIds[0]);
          check("grouping cards never mixes their record content",title?.originalText===oldTitle);
        }
        const files=Object.keys(original.scene!.files??{});
        await bridge.load(original); await wait();
        check("image files survive board reload",files.length>0 && files.every(id=>api.getFiles()[id]?.dataURL));
        const selectedCard=api.getSceneElements().find(isCard);
        api.updateScene({appState:{selectedElementIds:{[selectedCard.id]:true}}}); await wait();
        bridge.setAssistance(false); await wait();
        check("manual mode removes canvas AI action",!document.querySelector('[aria-label="Reference in conversation"]'));
        bridge.setAssistance(true); await wait();
        check("assisted mode restores contextual reference",!!document.querySelector('[aria-label="Reference in conversation"]'));
        await bridge.load(original); await wait();
        const beforeArrange = api.getSceneElements().filter(isCard).map((c:El) => ({id:c.id,x:c.x,y:c.y}));
        bridge.command("arrange"); await wait();
        check("auto arrangement moves existing records without changing identity", beforeArrange.length === api.getSceneElements().filter(isCard).length
          && beforeArrange.some((old:El) => api.getSceneElements().some((c:El) => c.id === old.id && (c.x !== old.x || c.y !== old.y))));
        bridge.command("undo"); await wait();
        check("auto arrangement can be undone", beforeArrange.every((old:El) => api.getSceneElements().some((c:El) => c.id === old.id && c.x === old.x && c.y === old.y)));
        await bridge.load(original); await wait();
        try {
          const blob = await exportBoard(api.getSceneElements(), api.getAppState(), api.getFiles(), s.records, s.relations, s.theme);
          (window as any).__synthesisAuditPNG = await new Promise<string>((resolve, reject) => {
            const reader = new FileReader(); reader.onload = () => resolve(String(reader.result).split(',')[1]);
            reader.onerror = reject; reader.readAsDataURL(blob);
          });
          const signature = new Uint8Array(await blob.slice(0,8).arrayBuffer());
          check("board export produces a real PNG",blob.size>100 && signature[0]===137 && signature[1]===80 && signature[2]===78 && signature[3]===71);
        } catch { check("board export produces a real PNG",false); }
        return results;
      },
      /** For the interaction self-test: where things are on screen right now. */
      probe() {
        const state = api.getAppState();
        const scene: El[] = api.getSceneElements();
        const cards = scene.filter(isCard).map((c: El) => ({
          recordID: c.customData.recordID,
          art: scene.some((e) => e.type === "image" && e.customData?.role === "art" && e.groupIds?.some((g: string) => c.groupIds?.includes(g))),
          x: c.x,
          y: c.y,
          width: c.width,
          height: c.height,
          clientX: (c.x + c.width / 2 + state.scrollX) * state.zoom.value + state.offsetLeft,
          clientY: (c.y + c.height / 2 + state.scrollY) * state.zoom.value + state.offsetTop,
        }));
        return JSON.stringify({
          cards,
          zoom: state.zoom.value,
          relations: api.getSceneElements().filter(isRelation).length,
          pointer: s.pointerLog.slice(-8),
        });
      },
      /**
       * Drags a card by dispatching pointer events inside the page. Used by the self-test,
       * because WebKit reports no pressed button for mouse drags that are posted to the
       * window rather than made with a real mouse.
       */
      async testDrag(recordID: string, dx: number, dy: number) {
        const state = api.getAppState();
        const card = api.getSceneElements().find((e: El) => isCard(e) && e.customData.recordID === recordID);
        const canvas = document.querySelector("canvas.interactive") as HTMLCanvasElement | null;
        if (!card || !canvas) return "missing";
        const x = (card.x + card.width / 2 + state.scrollX) * state.zoom.value + state.offsetLeft;
        const y = (card.y + 24 + state.scrollY) * state.zoom.value + state.offsetTop;
        const fire = (target: EventTarget, type: string, cx: number, cy: number, buttons: number) =>
          target.dispatchEvent(
            new PointerEvent(type, {
              bubbles: true, cancelable: true, composed: true, clientX: cx, clientY: cy, pointerId: 1,
              pointerType: "mouse", isPrimary: true, button: 0, buttons, view: window,
            }),
          );
        const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
        // The person's own pointer may be over the window; keep its events out of this drag.
        const shield = (event: Event) => {
          if (event.isTrusted) event.stopImmediatePropagation();
        };
        const shielded = ["pointermove", "pointerdown", "pointerup", "mousemove", "mousedown", "mouseup"];
        for (const type of shielded) window.addEventListener(type, shield, true);
        try {
          return await run();
        } finally {
          for (const type of shielded) window.removeEventListener(type, shield, true);
        }
        async function run() {
        fire(canvas!, "pointerdown", x, y, 1);
        await wait(40);
        for (let step = 1; step <= 10; step += 1) {
          // Excalidraw handles one move per frame and only when its target is an element.
          fire(canvas!, "pointermove", x + (dx * step) / 10, y + (dy * step) / 10, 1);
          await wait(34);
        }
        fire(canvas!, "pointerup", x + dx, y + dy, 0);
        await wait(60);
        return "done";
        }
      },
    };
    (window as any).synthesis = bridge;

    // Double-clicking a card opens its record instead of starting a text edit.
    const openOnDoubleClick = (event: MouseEvent) => {
      if (!s.loaded) return;
      const state = api.getAppState();
      const point = viewportCoordsToSceneCoords({ clientX: event.clientX, clientY: event.clientY }, state);
      const hit = [...api.getSceneElements()]
        .reverse()
        .find((e: El) => isCard(e) && containsCardPoint(e, point));
      if (!hit || (event.target as HTMLElement)?.closest?.(".layer-ui__wrapper, .excalidraw-textEditorContainer, .studio-overlay button")) return;
      event.stopPropagation();
      event.preventDefault();
      post({ type: "openRecord", id: hit.customData.recordID });
    };
    window.addEventListener("dblclick", openOnDoubleClick, true);
    // A short trace of pointer activity, read by the interaction self-test.
    const trace = (event: PointerEvent) => {
      s.pointerLog.push(`${event.type}:${event.buttons}:${event.isTrusted ? "t" : "s"}`);
      if (s.pointerLog.length > 40) s.pointerLog.splice(0, 20);
    };
    for (const type of ["pointerdown", "pointermove", "pointerup"]) window.addEventListener(type, trace as any, true);
    const settle = () => {
      reportSelection();
      window.clearTimeout(s.analyzeTimer);
      s.analyzeTimer = window.setTimeout(analyse, 120);
    };
    window.addEventListener("pointerup", settle, true);
    window.addEventListener("keyup", settle, true);
    post({ type: "ready" });
    return () => {
      window.removeEventListener("dblclick", openOnDoubleClick, true);
      window.removeEventListener("pointerup", settle, true);
      window.removeEventListener("keyup", settle, true);
      for (const type of ["pointerdown", "pointermove", "pointerup"]) window.removeEventListener(type, trace as any, true);
      window.clearTimeout(s.saveTimer);
      window.clearTimeout(s.analyzeTimer);
    };
  }, [api, apply, analyse, onChange, openSpot, reportSelection, serialise, synchronise, save]);

  return (
    <div className={`synthesis-board ${theme}`}>
    <Excalidraw
      excalidrawAPI={setApi}
      theme={theme}
      name={name}
      onChange={onChange}
      aiEnabled={false}
      validateEmbeddable={() => false}
      handleKeyboardGlobally={false}
      autoFocus={false}
      UIOptions={{
        canvasActions: {
          loadScene: false,
          saveToActiveFile: false,
          export: false,
          toggleTheme: false,
          changeViewBackgroundColor: false,
          saveAsImage: false,
          clearCanvas: false,
        },
      }}
      onLinkOpen={(element: El, event: CustomEvent) => {
        const link: string = element.link ?? "";
        if (link.startsWith("synthesis://record/")) {
          event.preventDefault();
          post({ type: "openRecord", id: link.replace("synthesis://record/", "") });
        }
      }}
    >
      <MainMenu>
        <MainMenu.Item onSelect={() => post({ type: "request", action: "library" })}>Add from library…</MainMenu.Item>
        <MainMenu.Item onSelect={() => post({ type: "request", action: "entity" })}>New entity…</MainMenu.Item>
        <MainMenu.Item onSelect={() => post({ type: "request", action: "image" })}>Add image…</MainMenu.Item>
        <MainMenu.Separator />
        <MainMenu.Item onSelect={() => post({ type: "request", action: "export" })}>Export board as PNG…</MainMenu.Item>
        <MainMenu.DefaultItems.SearchMenu />
        <MainMenu.DefaultItems.Help />
        <MainMenu.Separator />
        <MainMenu.DefaultItems.ClearCanvas />
      </MainMenu>
    </Excalidraw>
    {api && <StudioOverlay api={api} theme={theme} assisted={assisted} records={getRecords} relations={getRelations} post={post}/>}
    </div>
  );
}

/** Converts a board saved by the earlier native canvas into Excalidraw elements. */
async function migrate(
  legacy: { cards: LegacyCard[]; edges: LegacyEdge[] },
  records: Map<string, RecordInfo>,
  theme: Theme,
  api: Api,
): Promise<El[]> {
  const p = palette(theme);
  let elements: El[] = [];
  const anchor = new Map<string, string>(); // legacy card id → element id arrows can bind to
  const sharedGroups = new Map<string, string>();
  for (const card of legacy.cards) {
    const outer = card.group ? (sharedGroups.get(card.group) ?? sharedGroups.set(card.group, `group:${randomId()}`).get(card.group)!) : null;
    const extra = outer ? [outer] : [];
    const top = card.y - 85;
    let art: El | null = null;
    if (card.image) {
      const dataURL = `data:${imageMime(card.image)};base64,${card.image}`;
      const size = await imageSize(dataURL);
      const width = CARD_WIDTH;
      const height = Math.min(card.recordID ? 150 : 260, (width / size.width) * size.height);
      const fileId = `file:${randomId()}`;
      api.addFiles([{ id: fileId, dataURL, mimeType: imageMime(card.image), created: Date.now() }]);
      art = convertToExcalidrawElements(
        [{ type: "image", x: card.x - width / 2, y: card.recordID ? top : card.y - height / 2, width, height, fileId, status: "saved" } as any],
        { regenerateIds: true },
      )[0];
      if (!card.recordID) {
        elements.push({ ...art, groupIds: extra });
        anchor.set(card.id, art.id);
      }
    }
    if (card.recordID) {
      const group = `card:${randomId()}`;
      const { rect, parts } = buildCard(
        records.get(card.recordID), card.recordID, card.x - CARD_WIDTH / 2, top, theme, group, undefined, art?.height ?? 0,
      );
      // Rectangle first, artwork over its top edge, text above both.
      elements.push({ ...rect, groupIds: [group, ...extra] });
      if (art) elements.push({ ...art, groupIds: [group, ...extra], customData: { synthesis: "part", role: "art" } });
      for (const el of Object.values(parts)) elements.push({ ...el, groupIds: [group, ...extra] });
      anchor.set(card.id, rect.id);
    } else if (!card.image) {
      const note = convertToExcalidrawElements(
        [{ type: "text", x: card.x - 120, y: card.y - 12, text: card.text, fontSize: 18, fontFamily: 6, strokeColor: p.text } as any],
        { regenerateIds: true },
      )[0];
      elements.push({ ...note, groupIds: extra });
    }
  }
  for (const edge of legacy.edges) {
    const a = elements.find((e) => e.id === anchor.get(edge.source));
    const b = elements.find((e) => e.id === anchor.get(edge.target));
    if (!a || !b || a.type !== "rectangle" || b.type !== "rectangle") continue;
    for (const el of buildArrow(a, b, edge.label ?? "", theme, { synthesis: "plain" })) {
      const index = elements.findIndex((e) => e.id === el.id);
      if (index >= 0) elements[index] = el;
      else elements.push(el);
    }
  }
  void getCommonBounds;
  return elements;
}
