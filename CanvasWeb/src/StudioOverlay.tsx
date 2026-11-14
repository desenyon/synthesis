import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { isCard, type RecordInfo, type RelationInfo } from './cards';
import { cardFrame, visibleFrame } from './sceneRules';
import type { Theme } from './palette';
type Props = {
    api: any;
    theme: Theme;
    assisted: boolean;
    records: () => Map<string, RecordInfo>;
    relations: () => RelationInfo[];
    post: (message: Record<string, unknown>) => void;
};
const icons: Record<string, ReactNode> = {
    select: <path d="m5 3 14 9-7 1-3 7Z"/>, hand: <><path d="M8 12V6a2 2 0 0 1 4 0v5-7a2 2 0 0 1 4 0v8-5a2 2 0 0 1 4 0v9c0 5-9 7-12 3l-4-5a2 2 0 0 1 3-3l1 1"/></>,
    plus: <path d="M12 5v14M5 12h14"/>, entity: <><rect x="5" y="3" width="14" height="18" rx="3"/><path d="M9 8h6M9 12h6M9 16h3"/></>,
    note: <><path d="M14 3H5v18h14V8Z M14 3v6h6M9 13h6M9 17h4"/></>, image: <><rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8" cy="8" r="1"/><path d="m4 17 6-6 4 4 3-3 4 5"/></>,
    connect: <><circle cx="5" cy="17" r="2"/><circle cx="19" cy="7" r="2"/><path d="M7 17c9 0 1-10 10-10"/></>, frame: <><rect x="5" y="5" width="14" height="14" rx="1"/><path d="M5 2v20M19 2v20M2 5h20M2 19h20"/></>,
    draw: <><path d="m4 16 12-12 4 4-12 12-5 1Z M14 6l4 4"/></>, shape: <rect x="4" y="4" width="16" height="16" rx="3"/>,
    minus: <path d="M5 12h14"/>, fit: <><path d="M8 3H3v5M16 3h5v5M21 16v5h-5M8 21H3v-5"/><rect x="8" y="8" width="8" height="8" rx="1"/></>,
    undo: <><path d="m8 4-5 5 5 5M4 9h10a6 6 0 1 1 0 12"/></>, redo: <><path d="m16 4 5 5-5 5M20 9H10a6 6 0 1 0 0 12"/></>,
    open: <><path d="M14 3h7v7M21 3 10 14M10 4H4v16h16v-6"/></>, reference: <><circle cx="12" cy="12" r="4"/><path d="M16 8v7c6 2 7-12-3-12a9 9 0 1 0 4 17"/></>,
    close: <path d="m6 6 12 12M6 18 18 6"/>, settings: <><path d="M4 7h16M4 17h16M8 4v6M16 14v6"/></>, library: <><rect x="4" y="3" width="5" height="18" rx="1"/><path d="M12 3h4l4 17-4 1Z"/></>,
};
function Icon({ name }: {
    name: string;
}) { return <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.55" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{icons[name] ?? icons.entity}</svg>; }
function Tool({ label, icon, active = false, disabled = false, action }: {
    label: string;
    icon: string;
    active?: boolean;
    disabled?: boolean;
    action: () => void;
}) {
    return <button type="button" className={`studio-tool ${active ? 'is-active' : ''}`} title={label} aria-label={label} aria-pressed={active} disabled={disabled} onClick={action}><Icon name={icon}/><span className="studio-tooltip">{label}</span></button>;
}
const tones: Record<string, string> = { characters: '#e2b993', factions: '#b5a2e7', places: '#8bd9b7', 'power systems': '#e7d17d', cosmology: '#d6a8dc' };
/** Rich cards are a presentation of engine elements, never a second board model.
 * Pointer-transparent bodies preserve Excalidraw drag, selection, resize and undo.
 * Only explicit record actions and connection ports intercept the pointer. */
export function StudioOverlay({ api, theme, assisted, records, relations, post }: Props) {
    const [view, setView] = useState<any>(null);
    const [connecting, setConnecting] = useState<string | null>(null);
    const [styles, setStyles] = useState(false);
    const frame = useRef(0);
    useEffect(() => {
        const refresh = () => { cancelAnimationFrame(frame.current); frame.current = requestAnimationFrame(() => setView({ state: api.getAppState(), elements: api.getSceneElements(), files: api.getFiles(), records: new Map(records()) })); };
        const unsubscribe = api.onChange(refresh);
        refresh();
        return () => { unsubscribe(); cancelAnimationFrame(frame.current); };
    }, [api, records]);
    useEffect(() => { const cancel = (e: KeyboardEvent) => { if (e.key === 'Escape') {
        setConnecting(null);
        setStyles(false);
    } }; window.addEventListener('keydown', cancel); return () => window.removeEventListener('keydown', cancel); }, []);
    useEffect(() => { document.documentElement.classList.toggle('show-canvas-style', styles); return () => document.documentElement.classList.remove('show-canvas-style'); }, [styles]);
    if (!view)
        return null;
    const { state, elements, files } = view;
    const cards = elements.filter(isCard);
    const recordMap: Map<string, RecordInfo> = view.records;
    const chosen = cards.filter((c: any) => state.selectedElementIds[c.id]);
    const selectedIDs = new Set<string>(chosen.map((c: any) => c.customData.recordID));
    const neighbours = new Set(selectedIDs);
    for (const relation of relations()) {
        if (selectedIDs.has(relation.sourceID))
            neighbours.add(relation.targetID);
        if (selectedIDs.has(relation.targetID))
            neighbours.add(relation.sourceID);
    }
    const artByGroup = new Map<string, any>();
    for (const element of elements)
        if (element.type === 'image' && element.customData?.role === 'art' && element.groupIds?.[0])
            artByGroup.set(element.groupIds[0], element);
    const chooseTool = (type: string) => { setConnecting(null); api.setActiveTool({ type }); };
    const command = (name: string) => (window as any).synthesis?.command(name);
    const active = state.activeTool?.type;
    const connect = (id: string) => {
        if (!connecting) {
            setConnecting(id);
            return;
        }
        if (connecting === id) {
            setConnecting(null);
            return;
        }
        post({ type: 'connect', arrowID: `ports:${crypto.randomUUID()}`, source: connecting, target: id, label: '' });
        setConnecting(null);
    };
    return <div className={`studio-overlay ${theme}`}>
   <div className="studio-card-layer" aria-label="World records on this board">
     {cards.map((card: any) => {
            const bounds = cardFrame(card, state);
            if (!visibleFrame(bounds, state.width, state.height))
                return null;
            const record = recordMap.get(card.customData.recordID);
            const selected = !!state.selectedElementIds[card.id];
            const group = card.groupIds?.[0];
            const art = artByGroup.get(group);
            const artURL = art && files[art.fileId]?.dataURL;
            const related = chosen.length === 0 || neighbours.has(card.customData.recordID);
            const color = tones[record?.category.toLowerCase() ?? ''] ?? '#9bbfdd';
            return <article key={card.id} className={`studio-record ${selected ? 'is-selected' : ''} ${related ? '' : 'is-unrelated'} ${artURL ? 'has-art' : ''}`} style={{ '--record-accent': color, left: bounds.x + (bounds.width - card.width) / 2, top: bounds.y + (bounds.height - card.height) / 2, width: card.width, height: card.height, transform: `scale(${bounds.zoom}) rotate(${card.angle ?? 0}rad)` } as CSSProperties}>
         <div className="record-kicker"><i />{record?.category || record?.kind || 'Archived record'}<span>{record?.kind === 'entity' ? 'Entity' : 'Record'}</span></div>
         {artURL && <img className="record-art" src={artURL} alt="" style={{ height: Math.min(art.height, card.height - 90) }} draggable={false}/>}
         <div className="record-copy"><h2>{record?.title ?? 'Archived record'}</h2><p>{record?.body || 'Open this record to begin writing.'}</p></div>
         <footer><span className={`record-state ${record?.state === 'canon' ? 'is-canon' : ''}`}><i />{record?.state ?? 'Archived'}{record?.canonKept && record.state !== 'canon' ? ' · canon kept' : ''}</span><span>{record?.origin === 'ai-proposed' ? 'AI proposal' : record?.origin === 'imported' ? 'Imported' : ''}</span></footer>
         <div className="record-actions"><Tool label="Open record" icon="open" action={() => post({ type: 'openRecord', id: card.customData.recordID })}/></div>
         {record?.kind === 'entity' && ['in', 'out'].map(side => <button key={side} type="button" className={`record-port ${side} ${connecting === record.id ? 'connecting' : ''}`} title={connecting ? 'Connect to this entity' : 'Connect this entity'} aria-label={`${connecting ? 'Connect to' : 'Connect from'} ${record.title}`} onClick={() => connect(record.id)}/>)}
       </article>;
        })}
   </div>
   <div className="studio-add-bar glass" role="toolbar" aria-label="Worldbuilding tools">
     <Tool label="Add entity" icon="entity" action={() => post({ type: 'request', action: 'entity' })}/>
     <Tool label="Add from library" icon="library" action={() => post({ type: 'request', action: 'library' })}/>
     <span className="tool-separator"/>
     <Tool label="Write a note · T" icon="note" active={active === 'text'} action={() => chooseTool('text')}/>
     <Tool label="Add image" icon="image" action={() => post({ type: 'request', action: 'image' })}/>
   </div>
   <div className="studio-drawing-bar glass" role="toolbar" aria-label="Canvas tools">
     <Tool label="Select · V" icon="select" active={active === 'selection'} action={() => chooseTool('selection')}/>
     <Tool label="Pan · H" icon="hand" active={active === 'hand'} action={() => chooseTool('hand')}/>
     <span className="tool-separator"/>
     <Tool label="Connect · A" icon="connect" active={active === 'arrow'} action={() => chooseTool('arrow')}/>
     <Tool label="Shape · R" icon="shape" active={active === 'rectangle'} action={() => chooseTool('rectangle')}/>
     <Tool label="Draw · P" icon="draw" active={active === 'freedraw'} action={() => chooseTool('freedraw')}/>
     <Tool label="Group in a frame · F" icon="frame" active={active === 'frame'} action={() => chooseTool('frame')}/>
     <span className="tool-separator"/>
     <Tool label="Drawing style" icon="settings" active={styles} disabled={!Object.keys(state.selectedElementIds).length && ["selection", "hand"].includes(active)} action={() => { setStyles(v => !v); api.updateScene({appState:{openMenu:styles?null:"shape"}}); }}/>
   </div>
   <div className="studio-viewport glass" role="toolbar" aria-label="Canvas viewport">
     <Tool label="Undo · ⌘Z" icon="undo" action={() => command('undo')}/><Tool label="Redo · ⇧⌘Z" icon="redo" action={() => command('redo')}/>
     <span className="tool-separator"/><Tool label="Zoom out" icon="minus" action={() => command('zoomOut')}/>
     <button className="zoom-label" title="Reset zoom to 100%" onClick={() => command('resetZoom')}>{Math.round(state.zoom.value * 100)}%</button>
     <Tool label="Zoom in" icon="plus" action={() => command('zoomIn')}/><Tool label="Fit to content" icon="fit" action={() => command('fit')}/>
   </div>
   {connecting && <div className="studio-connect-hint glass" role="status"><span className="signal-dot"/>Choose another entity’s port to describe the relationship<Tool icon="close" label="Cancel connection · Escape" action={() => setConnecting(null)}/></div>}
   {chosen.length > 0 && !connecting && <div className="studio-selection glass"><span>{chosen.length === 1 ? recordMap.get(chosen[0].customData.recordID)?.title : `${chosen.length} records`}</span>{assisted && <Tool label="Reference in conversation" icon="reference" action={() => post({ type: 'request', action: 'reference' })}/>}{chosen.length === 1 && <Tool label="Attach artwork" icon="image" action={() => post({ type: 'request', action: 'artwork' })}/>}</div>}
   {cards.length === 0 && elements.length === 0 && <div className="studio-empty"><span className="empty-orbit">◇</span><h1>Room for a universe.</h1><p>Place your first record. Follow the connections.</p><button onClick={() => post({ type: 'request', action: 'entity' })}>Create an entity <span>↗</span></button></div>}
 </div>;
}
