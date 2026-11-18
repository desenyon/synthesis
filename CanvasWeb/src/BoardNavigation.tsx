import { getCommonBounds } from '@excalidraw/excalidraw';
import { useEffect, useMemo, useRef, useState, type CSSProperties, type FormEvent, type MouseEvent } from 'react';
import {
  captureViewport, projectOverview, viewportBookmarkLimit, viewportBookmarkNameLimit,
  type Viewpoint, type Viewport, type ViewportBookmark,
} from './viewportNavigation';

export type BoardNavigationControls = {
  sessionID: string;
  bottom: number;
  bookmarks: ViewportBookmark[];
  setBookmarks: (sessionID: string, bookmarks: ViewportBookmark[]) => boolean;
  moveTo: (sessionID: string, point: Viewpoint) => void;
};

const overviewSize = { width: 216, height: 96 };
type SceneElement = Parameters<typeof getCommonBounds>[0][number];

export function BoardNavigation({ controls, elements, viewport, visible, selected }: {
  controls: BoardNavigationControls;
  elements: readonly SceneElement[];
  viewport: Viewport;
  visible: boolean;
  selected: boolean;
}) {
  const { sessionID, bottom, bookmarks, setBookmarks, moveTo } = controls;
  const [name, setName] = useState('');
  const [removed, setRemoved] = useState<{ bookmark: ViewportBookmark; index: number } | null>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const bounds = useMemo(() => !visible ? null : ({
    board: elements.length ? getCommonBounds(elements) : [],
    objects: elements
      .filter(element => !['part', 'referencePart', 'relationLabel'].includes(String(element.customData?.synthesis)))
      .map(({ x, y, width, height }) => ({ x, y, width, height })),
  }), [elements, visible]);
  const projection = bounds ? projectOverview(bounds.board, viewport, overviewSize) : null;

  useEffect(() => {
    const miniature = canvas.current;
    const context = miniature?.getContext('2d');
    if (!miniature || !context || !bounds || !projection) return;
    const colors = getComputedStyle(miniature);
    context.setTransform(2, 0, 0, 2, 0, 0);
    context.clearRect(0, 0, overviewSize.width, overviewSize.height);
    context.fillStyle = colors.getPropertyValue('--muted');
    context.globalAlpha = 0.45;
    for (const object of bounds.objects) {
      const a = projection.toMap(object.x, object.y);
      const b = projection.toMap(object.x + object.width, object.y + object.height);
      context.fillRect(a.x, a.y, Math.max(1, b.x - a.x), Math.max(1, b.y - a.y));
    }
    context.globalAlpha = 1;
    context.strokeStyle = colors.getPropertyValue('--focus');
    const view = projection.viewport;
    context.strokeRect(view.x, view.y, view.width, view.height);
  }, [bounds, projection]);

  const moveOnMap = (event: MouseEvent<HTMLButtonElement>) => {
    if (!projection || !canvas.current) return;
    const area = canvas.current.getBoundingClientRect();
    const x = event.detail ? (event.clientX - area.left) / area.width * overviewSize.width : overviewSize.width / 2;
    const y = event.detail ? (event.clientY - area.top) / area.height * overviewSize.height : overviewSize.height / 2;
    moveTo(sessionID, { ...projection.toScene(x, y), zoom: viewport.zoom.value });
  };

  const add = (event: FormEvent) => {
    event.preventDefault();
    const label = name.trim();
    if (!projection || !label || bookmarks.length >= viewportBookmarkLimit) return;
    const id = crypto.getRandomValues(new Uint32Array(4)).join('-');
    const bookmark = { id, name: label, ...captureViewport(viewport) };
    if (setBookmarks(sessionID, [...bookmarks, bookmark])) setName('');
  };

  const remove = (bookmark: ViewportBookmark, index: number) => {
    if (setBookmarks(sessionID, bookmarks.filter(entry => entry.id !== bookmark.id))) {
      setRemoved({ bookmark, index });
    }
  };

  const undoRemoval = () => {
    if (!removed || bookmarks.length >= viewportBookmarkLimit) return;
    const next = [...bookmarks];
    next.splice(removed.index, 0, removed.bookmark);
    if (setBookmarks(sessionID, next)) setRemoved(null);
  };

  if (!visible) return null;
  return <section className={`studio-navigation glass ${selected ? 'below-selection' : ''}`} aria-label="Board navigation"
    style={{ '--studio-navigation-bottom': `${bottom}px` } as CSSProperties}>
    <button type="button" className="studio-minimap" onClick={moveOnMap} disabled={!projection}
      aria-label="Minimap, move to the chosen point or press Enter to center the overview"
      onKeyDown={event => {
        const current = captureViewport(viewport);
        const dx = current.zoom > 0 ? viewport.width / current.zoom / 4 : 0;
        const dy = current.zoom > 0 ? viewport.height / current.zoom / 4 : 0;
        const steps: Record<string, number[]> = {
          ArrowLeft: [-dx, 0], ArrowRight: [dx, 0], ArrowUp: [0, -dy], ArrowDown: [0, dy],
        };
        const step = steps[event.key];
        if (!step) return;
        event.preventDefault();
        event.stopPropagation();
        moveTo(sessionID, { x: current.x + step[0], y: current.y + step[1], zoom: current.zoom });
      }}>
      <canvas ref={canvas} width={overviewSize.width * 2} height={overviewSize.height * 2} aria-hidden="true" />
    </button>
    <form onSubmit={add}>
      <input aria-label="Bookmark name" placeholder="Bookmark this view" value={name}
        maxLength={viewportBookmarkNameLimit} onChange={event => setName(event.target.value)} />
      <button type="submit" disabled={!name.trim() || !projection || bookmarks.length >= viewportBookmarkLimit}>Save</button>
    </form>
    {bookmarks.length > 0 && <ul aria-label="Viewport bookmarks">
      {bookmarks.map((bookmark, index) => <li key={bookmark.id}>
        <button type="button" title={bookmark.name} onClick={() => moveTo(sessionID, bookmark)}>{bookmark.name}</button>
        <button type="button" aria-label={'Remove bookmark ' + bookmark.name} onClick={() => remove(bookmark, index)}>Remove</button>
      </li>)}
    </ul>}
    {removed && <div role="status" className="studio-bookmark-undo">
      <span>Bookmark removed</span>
      <button type="button" onClick={undoRemoval} disabled={bookmarks.length >= viewportBookmarkLimit}>Undo</button>
    </div>}
    {bookmarks.length >= viewportBookmarkLimit && <p role="status">This board has 50 bookmarks.</p>}
  </section>;
}
